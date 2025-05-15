from util import filter_lat_lon
import argparse # 1.1
import xarray as xr # 2025.1.2
import numpy as np # 2.2.3
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import warnings
from xarray import SerializationWarning
warnings.filterwarnings("ignore", category=SerializationWarning)

def load_argument():
    parser = argparse.ArgumentParser()
    parser.add_argument("-lonmin", metavar='Minimum latitude', help="Minimum longitude bounding box value", type=float, nargs=1, required=True )
    parser.add_argument("-lonmax", metavar='Maximum latitude', help="Maximum longitude bounding box value", type=float, nargs=1, required=True )
    parser.add_argument("-latmin", metavar='Minimum longitude', help="Minimum latitude bounding box value", type=float, nargs=1, required=True )
    parser.add_argument("-latmax", metavar='Maximum longitude', help="Maximum latitude bounding box value", type=float, nargs=1, required=True )
    parser.add_argument("-mindepth", metavar='Minimum depth constraint', help="Min depth for the mask", type=int, nargs='+', required=True)
    parser.add_argument("-maxdepth", metavar='Maximum depth constraint', help="Maximum depth for the mask", type=int, nargs=1, required=True)
    parser.add_argument("-timevar", metavar='time variable', help="time variable in the dataset", type=str, nargs=1, required=True)
    parser.add_argument("-salvar", metavar='salinity variable', help="salinity variable in the dataset", type=str, nargs=1, required=True)
    parser.add_argument("-depthvar", metavar='depth variable', help="depth variable in the dataset", type=str, nargs=1, required=True)
    parser.add_argument("-freq", metavar='frequency', help="frequency of the data", type=str, nargs=1, required=True)
    parser.add_argument("-datf", metavar='data file', help="the input file (full path) to work from", type=str, nargs=1 , required=True)
    parser.add_argument("-meshf", metavar='mesh file', help="the mesh file (full path) to work from", type=str, nargs=1 , required=True)
    parser.add_argument("-outf", metavar='output file', help="the output filename", type=str, nargs=1 , required=True)
    parser.add_argument("-datadir", metavar='data directory', help="directory of data", type=str, nargs=1, required=True)
    parser.add_argument("-marvaldir", metavar='Marine val directory', help="directory of marine val", type=str, nargs=1, required=True)
    parser.add_argument("-obs", help="Flag to indicate if obs data is used", action='store_true')
    return parser.parse_args()

def calc_metrics(data, mesh, args):

    salinity = data[args.salvar[0]].mean(dim=args.timevar[0]).expand_dims(dim={args.timevar[0]:[0]}).fillna(-1) # ASSUMPTION: Time = 1 for model data, time > 1 for obs data. Ensure 4D shape with first dimension = 1, averaging for obs.
    depth_mask = mesh['gdept_0'][0].values # nk x nj x ni array, depth levels 
  
    salinity = filter_lat_lon(salinity, mesh, [args.lonmin[0], args.lonmax[0], args.latmin[0], args.latmax[0]], new_val=-1) # nt x nk x nj x ni array, 0 for all values outside the domain    
    salinity = salinity.where((depth_mask >= args.mindepth[0]) & (depth_mask <= args.maxdepth[0]), np.nan).dropna(dim=args.depthvar[0], how='all')
    max_salinity = salinity.max(dim=args.depthvar[0]) # nt x nj x ni array, maximum salinity value for each grid point    
    max_depth = salinity[args.depthvar[0]].isel({args.depthvar[0]:salinity.argmax(dim=args.depthvar[0])})  # nt x nj x ni array, max salinity values at the corresponding depth index
    max_salinity = max_salinity.where(max_salinity != -1, np.nan)
    max_depth = max_depth.where(max_salinity.notnull())
    lat, lon = ('y', 'x') if 'y' in max_salinity.dims else ('lat', 'lon')

    if args.obs:
        with open(f"{args.marvaldir[0]}/OBS/{args.outf[0]}_salinity.txt", "w") as f:
            f.write(f"ref = Max salinity NOAA_WOA13v2: 1955-2012\n")
            f.write(f"mean = {max_salinity.mean(dim=[lat, lon]).values[0]}\n")
            f.write(f"std = {max_salinity.std(dim=[lat, lon]).values[0]}\n")

        with open(f"{args.marvaldir[0]}/OBS/{args.outf[0]}_depth.txt", "w") as f:
            f.write(f"ref = Max depth NOAA_WOA13v2: 1955-2012\n")
            f.write(f"mean = {max_depth.mean(dim=[lat, lon]).values[0]}\n")
            f.write(f"std = {max_depth.std(dim=[lat, lon]).values[0]}\n")
    else:
        max_salinity.mean(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_mean.nc") # nt array, mean salinity for each time period
        max_salinity.std(dim=[lat, lon]) .to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_std.nc") # nt array, std deviation for each time period
        max_depth.mean(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_mean_depth.nc") # nt array, mean depth for each time period
        max_depth.std(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_std_depth.nc") # nt array, std deviation for each time period

    return max_salinity, max_depth

def plot_sal(max_salinity, max_depth, data, args): 

    time_counter = 0
    data_list = [max_salinity.isel({args.timevar[0]: time_counter}), max_depth.isel({args.timevar[0]: time_counter})]
    titles = ["Max salinity", "Depth of max salinity"]
    lat, lon = ('y', 'x') if 'y' in max_salinity.dims else ('lat', 'lon')
    metrics_text = [
        f"Mean: {max_salinity.mean(dim=[lat, lon])[time_counter].values:.2f}, \
          Std: {max_salinity.std(dim=[lat, lon])[time_counter].values:.2f}, \
          Min: {max_salinity.min(dim=[lat, lon])[time_counter].values:.2f}, \
          Max: {max_salinity.max(dim=[lat, lon])[time_counter].values:.2f}",
        f"Mean: {max_depth.mean(dim=[lat, lon])[time_counter].values:.2f}, \
          Std: {max_depth.std(dim=[lat, lon])[time_counter].values:.2f}, \
          Min: {max_depth.min(dim=[lat, lon])[time_counter].values:.2f}, \
          Max: {max_depth.max(dim=[lat, lon])[time_counter].values:.2f}"
    ]
    lat, lon = ('nav_lat', 'nav_lon') if 'nav_lat' in list(data.variables.keys()) else ('lat', 'lon')
    cmaps = ["cividis", "plasma"]
    pad = 5

    fig, axes = plt.subplots(1, 2, figsize=(15, 7), subplot_kw={'projection': ccrs.PlateCarree()})
    fig.suptitle(f"Salinity analysis for depths between {args.mindepth[0]}m - {args.maxdepth[0]}m at {data[args.timevar[0]][time_counter].values}", fontsize=16, fontweight='bold')
    for i, ax in enumerate(axes):
        ax.set_extent([args.lonmin[0] - pad, args.lonmax[0] + pad, args.latmin[0] - pad, args.latmax[0] + pad], crs=ccrs.PlateCarree())
        ax.set_title(titles[i])
        ax.coastlines()
        ax.add_feature(cfeature.LAND, edgecolor='black', facecolor='tan') 
        ax.add_feature(cfeature.BORDERS, linestyle=':')
        ax.add_feature(cfeature.OCEAN, facecolor='lightblue')
        ax.text(0.5, -0.1, metrics_text[i], transform=ax.transAxes, ha='center', va='top', fontsize=10)
        plot = ax.pcolormesh(data[lon], data[lat], data_list[i], transform=ccrs.PlateCarree(), cmap=cmaps[i], shading='auto')
        fig.colorbar(plot, ax=ax, orientation='horizontal', label=titles[i])

    plt.tight_layout()
    plt.savefig(f"{args.datadir[0]}/{args.outf[0]}_salinity.png", dpi=300)

def main():

    args = load_argument()
    data = xr.open_dataset(args.datf[0], decode_times=False) if args.obs else xr.open_dataset(args.datf[0])
    mesh = xr.open_dataset(args.meshf[0])

    max_salinity, max_depth = calc_metrics(data, mesh, args)
    plot_sal(max_salinity, max_depth, data, args)

if __name__=="__main__":
    main()