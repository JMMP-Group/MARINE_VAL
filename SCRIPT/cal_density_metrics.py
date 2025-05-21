from util import filter_lat_lon
import argparse # 1.1
import xarray as xr # 2025.1.2
import numpy as np # 2.2.3
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import gsw
import warnings
from xarray import SerializationWarning
warnings.filterwarnings("ignore", category=SerializationWarning)

def load_argument():
    parser = argparse.ArgumentParser()
    # inputs
    parser.add_argument("-lonmin", metavar='Minimum latitude', help="Minimum longitude bounding box value", type=float, nargs=1, required=True )
    parser.add_argument("-lonmax", metavar='Maximum latitude', help="Maximum longitude bounding box value", type=float, nargs=1, required=True )
    parser.add_argument("-latmin", metavar='Minimum longitude', help="Minimum latitude bounding box value", type=float, nargs=1, required=True )
    parser.add_argument("-latmax", metavar='Maximum longitude', help="Maximum latitude bounding box value", type=float, nargs=1, required=True )
    parser.add_argument("-mindepth", metavar='Minimum depth constraint', help="Min depth for the mask", type=int, nargs='+', required=False)
    parser.add_argument("-maxdepth", metavar='Maximum depth constraint', help="Maximum depth for the mask", type=int, nargs=1, required=False)
    parser.add_argument("-densthresh", metavar='Density threshold', help="Density threshold for the mask", type=float, nargs=1, required=False)
    parser.add_argument("-vartype", metavar='variable type', help='variable type of interest: density, salinity or temperature', type=str, nargs=1, required=True)
    parser.add_argument("-salvar", metavar='salinity variable', help="salinity variable in the dataset", type=str, nargs=1, required=False)
    parser.add_argument("-tempvar", metavar='temperature variable', help="temperature variable in the dataset", type=str, nargs=1, required=False)
    parser.add_argument("-timevar", metavar='time variable', help="time variable in the dataset", type=str, nargs=1, required=True)
    parser.add_argument("-depthvar", metavar='depth variable', help="depth variable in the dataset", type=str, nargs=1, required=True)
    parser.add_argument("-freq", metavar='frequency', help="frequency of the data", type=str, nargs=1, required=True)
    parser.add_argument("-datf", metavar='data file', help="the input file (full path) to work from", type=str, nargs=1 , required=True)
    parser.add_argument("-meshf", metavar='mesh file', help="the mesh file (full path) to work from", type=str, nargs=1 , required=True)
    parser.add_argument("-outf", metavar='output file', help="the output filename", type=str, nargs=1 , required=True)
    parser.add_argument("-datadir", metavar='data directory', help="directory of data", type=str, nargs=1, required=True)
    parser.add_argument("-marvaldir", metavar='Marine val directory', help="directory of marine val", type=str, nargs=1, required=True)
    # flags
    parser.add_argument("-obs", help="Flag to indicate if obs data is used", action='store_true')
    # parse args
    args = parser.parse_args()
    # assertions
    if args.vartype[0].lower() not in ['salinity', 'temperature', 'density']:
        parser.error("Invalid -vartype. Must be one of: salinity, temperature, density.")

    if args.vartype[0].lower() == 'density':
        if not args.densthresh:
            parser.error("For density calculations, -densthresh (density threshold) must be specified.")
        if not (args.salvar and args.tempvar):
            parser.error("For density calculations, both -salvar (practical salinity) and -tempvar (potential temperature) must be specified.")
    else:
        if not (args.mindepth and args.maxdepth):
            parser.error("For salinity/temperature calculations, -mindepth and -maxdepth must be specified.")
        if not (args.salvar or args.tempvar):
            parser.error("For salinity/temperature calculations, at least one of -salvar or -tempvar must be specified.")

    return args

def calc_metrics(data, mesh, args):

    time_counter = data[args.timevar[0]]
    time_centered = data['time_centered']

    if args.vartype[0].lower() == 'density':
        salinity = data[args.salvar[0]] # practical salinity 
        temperature = data[args.tempvar[0]] # potential temperature 
        depth = data[args.depthvar[0]] # 1D array
        latitude, longitude = 'nav_lat', 'nav_lon'
        latitude, longitude = data[latitude], data[longitude]
        pressure = gsw.p_from_z(-depth, latitude)
        salinity = gsw.SA_from_SP(salinity, pressure, longitude, latitude) # absolute salinity
        temperature = gsw.CT_from_pt(salinity, temperature) # conservative temperature
        sigma4 = gsw.density.sigma4(salinity, temperature) # potential density referenced to 4000 dbar
        density_mask = ((sigma4 > args.densthresh[0]) & (latitude > args.latmin[0]) & (latitude < args.latmax[0]) & (longitude > args.lonmin[0]) & (longitude < args.lonmax[0])).values
        cell_volume = mesh['e3t_0'] * mesh['e1t'] * mesh['e2t']
        total_volume = (cell_volume.where(density_mask).sum())
        total_volume = xr.Dataset({"sigma4Vol": ([], total_volume.data)}, coords={"time_centered": time_centered, args.timevar[0]: time_counter})
        total_volume.to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_density_volume.nc")
        outputs = [sigma4.where(density_mask).max(dim=args.depthvar[0])]
        return outputs

    else:
        argmap = {args.vartype[0]: args.salvar[0]} if args.vartype[0].lower() == 'salinity' else {args.vartype[0]: args.tempvar[0]}
        diag = data[argmap[args.vartype[0]]].mean(dim=args.timevar[0]).expand_dims(dim={args.timevar[0]:[0]}).fillna(-1) # ASSUMPTION: Time = 1 for model data, Time > 1 for obs data. Ensure 4D shape with first dimension = 1, averaging for obs.
        depth_mask = mesh['gdept_0'][0].values # nk x nj x ni array, depth levels 
        diag = filter_lat_lon(diag, mesh, [args.lonmin[0], args.lonmax[0], args.latmin[0], args.latmax[0]], new_val=-1) # nt x nk x nj x ni array, 0 for all values outside the domain    
        diag = diag.where((depth_mask >= args.mindepth[0]) & (depth_mask <= args.maxdepth[0]), np.nan).dropna(dim=args.depthvar[0], how='all')
        max_diag = diag.max(dim=args.depthvar[0]) # nt x nj x ni array, maximum salinity value for each grid point    
        max_depth = diag[args.depthvar[0]].isel({args.depthvar[0]:diag.argmax(dim=args.depthvar[0])})  # nt x nj x ni array, max diagnostic values at the corresponding depth index
        max_diag = max_diag.where(max_diag != -1, np.nan)
        max_depth = max_depth.where(max_diag.notnull())
        lat, lon = ('y', 'x') if 'y' in max_diag.dims else ('lat', 'lon')

        if args.obs:
            with open(f"{args.marvaldir[0]}/OBS/{args.outf[0]}_{args.vartype[0].lower()}.txt", "w") as f:
                f.write(f"ref = Max {args.vartype[0].lower()} NOAA_WOA13v2: 1955-2012\n")
                f.write(f"mean = {max_diag.mean(dim=[lat, lon]).values[0]}\n")
                f.write(f"std = {max_diag.std(dim=[lat, lon]).values[0]}\n")

            with open(f"{args.marvaldir[0]}/OBS/{args.outf[0]}_{args.vartype[0].lower()}_depth.txt", "w") as f:
                f.write(f"ref = Max depth NOAA_WOA13v2: 1955-2012\n")
                f.write(f"mean = {max_depth.mean(dim=[lat, lon]).values[0]}\n")
                f.write(f"std = {max_depth.std(dim=[lat, lon]).values[0]}\n")
        else:
            max_diag['time_centered'] = time_centered
            max_diag['time_counter'] = time_counter
            max_diag.mean(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_mean.nc") # nt array, mean for each time period
            max_diag.std(dim=[lat, lon]) .to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_std.nc") # nt array, stdev for each time period
            max_depth['time_centered'] = time_centered
            max_depth['time_counter'] = time_counter
            max_depth.mean(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_mean_depth.nc") # nt array, mean depth for each time period
            max_depth.std(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_std_depth.nc") # nt array, stdev depth for each time period

        outputs = [max_diag, max_depth]
    
    return outputs

def plot_map(output, data, args, i):
    
    time_counter = 0
    pad = 5
    lat, lon = ('y', 'x') if 'y' in output.dims else ('lat', 'lon')
    metrics_text = f"Mean: {output.mean(dim=[lat, lon])[time_counter].values}, \
                     Std: {output.std(dim=[lat, lon])[time_counter].values}"
    lat, lon = ('nav_lat', 'nav_lon') if 'nav_lat' in list(data.variables.keys()) else ('lat', 'lon')
    cmaps = ["cividis","plasma"]

    if args.latmax[0] <= 60 and args.latmin[0] <= -60:
        projection = ccrs.SouthPolarStereo()
    elif args.latmax[0] >= 60 and args.latmin[0] >= -60:
        projection = ccrs.NorthPolarStereo()
    else:
        projection = ccrs.PlateCarree()

    if args.vartype[0].lower() == 'density':
        title = f"Density anomaly for sigma4 density > {args.densthresh[0]} at {data[args.timevar[0]][time_counter].values}"
    else:
        title = f"{args.vartype[0].title()} anomaly for depths between {args.mindepth[0]}m - {args.maxdepth[0]}m at {data[args.timevar[0]][time_counter].values}"
    
    fig, ax = plt.subplots(figsize=(10, 10), subplot_kw={'projection': projection})
    fig.suptitle(title, fontsize=16, fontweight='bold')
    ax.set_extent([args.lonmin[0] - pad, args.lonmax[0] + pad, args.latmin[0] - pad, args.latmax[0] + pad], crs=ccrs.PlateCarree())
    ax.coastlines()
    ax.add_feature(cfeature.LAND, edgecolor='black', facecolor='tan') 
    ax.add_feature(cfeature.BORDERS, linestyle=':')
    ax.add_feature(cfeature.OCEAN, facecolor='lightblue')
    ax.text(0.5, -0.1, metrics_text, transform=ax.transAxes, ha='center', va='top', fontsize=10)
    plot = ax.pcolormesh(data[lon], data[lat], output.isel({args.timevar[0]: time_counter}), transform=ccrs.PlateCarree(), cmap=cmaps[i], shading='auto')
    fig.colorbar(plot, ax=ax, orientation='horizontal', label=title)
    plt.tight_layout()
    plt.savefig(f"{args.marvaldir[0]}/FIGURES/{args.outf[0]}_{args.vartype[0]}_{i}.png", dpi=300)

def main():

    args = load_argument()
    data = xr.open_dataset(args.datf[0], decode_times=False) if args.obs else xr.open_dataset(args.datf[0])
    mesh = xr.open_dataset(args.meshf[0])
    outputs = calc_metrics(data, mesh, args)
    for i, df in enumerate(outputs):
        plot_map(df, data, args, i)

if __name__=="__main__":
    main()