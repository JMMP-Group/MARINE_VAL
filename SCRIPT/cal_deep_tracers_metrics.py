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
    parser.add_argument("-t", "--tmask", action="store",dest="tmask",  help="tmask file", nargs=1, type=str, required=True)
    parser.add_argument("-densthresh", metavar='Density threshold', help="Density threshold for the mask", type=float, nargs=1, required=False)
    parser.add_argument("-salvar", metavar='salinity variable', help="salinity variable in the dataset", type=str, nargs=1, required=False)
    parser.add_argument("-tempvar", metavar='temperature variable', help="temperature variable in the dataset", type=str, nargs=1, required=False)
    parser.add_argument("-timevar", metavar='time variable', help="time variable in the dataset", type=str, nargs=1, required=True)
    parser.add_argument("-freq", metavar='frequency', help="frequency of the data", type=str, nargs=1, required=True)
    parser.add_argument("-datf", metavar='data file', help="the input file (full path) to work from", type=str, nargs=1 , required=True)
    parser.add_argument("-meshf", metavar='mesh file', help="the mesh file (full path) to work from", type=str, nargs=1 , required=True)
    parser.add_argument("-outf", metavar='output file', help="the output filename", type=str, nargs=1 , required=True)
    parser.add_argument("-obsout", metavar='obs output filename prefix', help="the output filename prefix for obs data", type=str, nargs=1 , required=False)
    parser.add_argument("-obsref", metavar='obs reference', help="the reference for obs data", type=str, nargs=1 , required=False)
    parser.add_argument("-datadir", metavar='data directory', help="directory of data", type=str, nargs=1, required=True)
    parser.add_argument("-marvaldir", metavar='Marine val directory', help="directory of marine val", type=str, nargs=1, required=True)
    # flags
    parser.add_argument("-obs", help="Flag to indicate if obs data is used", action='store_true')
    # parse args
    args = parser.parse_args()
    # assertions
    if args.obs and not (args.obsout and args.obsref):
        parser.error("For obs data, both -obsout (obs output prefix) and -obsref (obs reference) must be specified.")

    if not (args.salvar or args.tempvar):
            parser.error("At least one of -salvar or -tempvar must be specified. Both must be specified for density calculations.")

    if (args.salvar and args.tempvar):
        if not args.densthresh:
            parser.error("For density calculations, -densthresh (density threshold) must be specified.")
        if not (args.salvar and args.tempvar):
            parser.error("For density calculations, both -salvar (practical salinity) and -tempvar (potential temperature) must be specified.")
        if args.salvar[0] != 'so_pra':
            parser.error(f"'{args.salvar[0]}' is not valid. Use 'so_pra' for practical salinity, which is converted into absolute salinity.")
        if args.tempvar[0] != 'thetao_pot':
            parser.error(f"'{args.tempvar[0]}' is not valid. Use 'thetao_pot' for potential temperature, which is converted into conservative temperature.")
        if not (args.obsout and args.obsref):
            parser.error("For density calculations, to create dummy obs files, both -obsout (obs output prefix) and -obsref (obs reference) must be specified.")

    return args

def get_bounds(tmask, args):
    """
    Get the bounds of the tmask array based on the valid ocean points.
    """
    nav_lev_sums = [int(tmask.isel(nav_lev=i).sum().values) for i in range(tmask.sizes['nav_lev'])]
    z_min = next((i for i, s in enumerate(nav_lev_sums) if s > 0), None)
    if z_min is None:
        raise ValueError("No valid ocean points found.")
    z_max = next((i for i, s in reversed(list(enumerate(nav_lev_sums))) if s > 0), None)
    z_max = z_max + 1 if z_max < tmask.sizes['nav_lev'] - 1 else None

    tmask_squeezed = tmask.isel(nav_lev=z_min)
    y_indices, x_indices = np.where(tmask_squeezed.values)

    y_min, y_max = (y_indices.min(), y_indices.max()) 
    x_min, x_max = (x_indices.min(), x_indices.max()) 
    y_min, y_max = (y_min, y_max + 1) if y_max < tmask.sizes['y'] - 1 else (y_min, None)
    x_min, x_max = (x_min, x_max + 1) if x_max < tmask.sizes['x'] - 1 else (x_min, None)

    # print(f"z_min: {z_min}, z_max: {z_max}, y_min: {y_min}, y_max: {y_max}, x_min: {x_min}, x_max: {x_max}")

    args.z_range = [z_min, z_max]
    args.y_range = [y_min, y_max]
    args.x_range = [x_min, x_max]

def crop_grid(array, args, depth=False):
    """
    Crop the input array based on the index ranges specified in args.
    Dependencies: 
    - get_crop_bounds must be called before this function to set args.y_range and args.x_range.
    - array must be of type xarray.DataArray or xarray.Dataset with dimensions 'y' and 'x'.
    """
    assert hasattr(args, 'x_range') and args.x_range is not None, "get_bounds must be called to set args.x_range"
    assert type(depth) == bool, "depth value for crop_grid must be a boolean value"

    slice_dict = {'y': slice(args.y_range[0], args.y_range[1]), 'x': slice(args.x_range[0], args.x_range[1])}
    if depth:
        slice_dict['nav_lev'] = slice(args.z_range[0], args.z_range[1])

    return array.isel(slice_dict)

def restore_grid(array_like, output, args):
    ''' Restore the 2D grid dimensions from the cropped array, for plotting.'''

    assert hasattr(args, 'x_range') and args.x_range is not None, "get_bounds must be called to set args.x_range"
    uncropped = xr.full_like(array_like.isel({args.timevar[0]: 0, args.depthvar[0]: 0}).expand_dims(dim={args.timevar[0]:[0]}), np.nan, dtype=np.float64)
    uncropped.loc[{'y': slice(args.y_range[0], args.y_range[1]), 'x': slice(args.x_range[0], args.x_range[1])}] = output

    return uncropped

def calc_sigma4(data, tmask, mesh, args):
    
    args.diagvar = 'sigma4'

    # Prepare inputs
    latitude = crop_grid(data['nav_lat'], args, depth=False)
    longitude = crop_grid(data['nav_lon'], args, depth=False)
    salinity = crop_grid(data[args.salvar[0]], args, depth=True) # practical salinity 
    temperature = crop_grid(data[args.tempvar[0]], args, depth=True) # potential temperature
    depth = crop_grid(mesh['gdept_0'].isel({'time_counter':0}), args, depth=True) # nk x nj x ni array, depth levels
    
    # Calculate sigma4 density
    pressure = gsw.p_from_z(-depth, latitude)
    salinity = gsw.SA_from_SP(salinity, pressure, longitude, latitude) # absolute salinity
    temperature = gsw.CT_from_pt(salinity, temperature) # conservative temperature
    sigma4 = gsw.density.sigma4(salinity, temperature) # potential density referenced to 4000 dba
    density_mask = (sigma4 > args.densthresh[0])

    # Calculate cell volume 
    cell_volume = mesh['e3t_0'] * mesh['e1t'] * mesh['e2t']
    cell_volume = crop_grid(cell_volume, args, depth=True)
    cell_volume = cell_volume.isel({args.timevar[0]: 0}) # 1 x nj x ni array, cell volume at the first time step

    # Broadcast tmask to match cell_volume dimensions
    tmask = xr.broadcast(tmask, cell_volume)[0]
    tmask = tmask.transpose(*cell_volume.dims) 

    # Calculate and save total volume
    cell_volume = cell_volume.where(density_mask & tmask)
    total_volume = cell_volume.sum()
    total_volume = xr.Dataset({"sigma4Vol": ([], total_volume.data)}, coords={"time_centered": args.time_centered, args.timevar[0]: args.time_counter})
    total_volume.to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_density_volume.nc")

    # Restore original dimensions for plotting
    cell_volume = cell_volume.mean(dim=args.timevar[0]).sum(dim='nav_lev')
    cell_volume = cell_volume.where(cell_volume > 0, np.nan)
    uncropped_volume = restore_grid(data[args.salvar[0]], cell_volume, args)

    # Create dummy observations files
    with open(f"{args.marvaldir[0]}/OBS/{args.obsout[0]}_{args.diagvar.lower()}.txt", "w") as f:
        f.write(f"ref = Volume of {args.diagvar.lower()} {args.obsref[0]}\n")
        f.write(f"mean = {total_volume.sigma4Vol.values}\n")
        f.write(f"std = {1e-5 * total_volume.sigma4Vol.values}\n")

    return [uncropped_volume]

def calc_max_diag(data, tmask, mesh, args):
    
    dummy_val = -1e14
    args.diagvar = args.salvar[0] if args.salvar else args.tempvar[0]
    
    # Prepare diagnostic 
    diag = data[args.diagvar]
    if not args.obs:
        assert diag.sizes[args.timevar[0]] == 1, f"Expected {args.timevar[0]} dimension to be 1 for model data, got {diag.sizes[args.timevar[0]]}" # Time = 1 for model data, Time > 1 for obs data. Ensure 4D shape with first dimension = 1, averaging for obs.
    diag = crop_grid(diag, args, depth=True) # 1 x nk x nj x ni array, 0 for all values outside the domain
    diag = diag.mean(dim=args.timevar[0]).expand_dims(dim={args.timevar[0]:[0]}) # 1 x nk x nj x ni array, mean across time
    
    # Mask diagnostic with tmask, select depth levels where non-zero values in tmask are present
    tmask = xr.broadcast(tmask, diag)[0]
    tmask = tmask.transpose(*diag.dims) # reorder tmask's dimensions to match diag
    diag = diag.where(tmask, dummy_val) # set values outside the tmask to dummy value

    # Calculate maximum diagnostic value and corresponding depth
    max_diag = diag.max(dim=args.depthvar[0]) # nj x ni array, maximum diagnostic value for each grid point across all levels
    argmax = diag.argmax(dim=args.depthvar[0]) # nt x nj x ni array, maximum depth for each grid points
    max_depth = crop_grid(mesh['gdept_0'], args, depth=True) # nk x nj x ni array, depth levels
    max_depth = max_depth.isel({args.depthvar[0]: argmax})
    max_diag = max_diag.where(max_diag != dummy_val, np.nan)
    max_depth = max_depth.where(max_diag.notnull(), np.nan)

    # Restore original dimensions for plotting
    uncropped_max_diag = restore_grid(data[args.diagvar], max_diag, args)
    uncropped_max_depth = restore_grid(data[args.diagvar], max_depth, args)

    lat, lon = ('y', 'x') if 'y' in max_diag.dims else ('lat', 'lon')

    if args.obs:
        with open(f"{args.marvaldir[0]}/OBS/{args.obsout[0]}_{args.diagvar.lower()}.txt", "w") as f:
            f.write(f"ref = Max {args.diagvar.lower()} {args.obsref[0]}\n")
            f.write(f"mean = {max_diag.mean(dim=[lat, lon]).values[0]}\n")
            f.write(f"std = {max_diag.std(dim=[lat, lon]).values[0]}\n")

        with open(f"{args.marvaldir[0]}/OBS/{args.obsout[0]}_{args.diagvar.lower()}_depth.txt", "w") as f:
            f.write(f"ref = Depth of max {args.diagvar.lower()} {args.obsref[0]}\n")
            f.write(f"mean = {max_depth.mean(dim=[lat, lon]).values[0]}\n")
            f.write(f"std = {max_depth.std(dim=[lat, lon]).values[0]}\n")
    
    else:
        max_diag['time_counter'] = args.time_counter
        max_depth['time_counter'] = args.time_counter
        max_diag['time_centered'] = args.time_centered
        max_depth['time_centered'] = args.time_centered

    # Write outputs to netcdf files
    max_diag[args.timevar[0]] = args.time_counter
    max_diag.mean(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_mean.nc") # nt array, mean for each time period
    max_diag.std(dim=[lat, lon]) .to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_std.nc") # nt array, stdev for each time period
    max_depth[args.timevar[0]] = args.time_counter
    max_depth.mean(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_mean_depth.nc") # nt array, mean depth for each time period
    max_depth.std(dim=[lat, lon]).to_netcdf(f"{args.datadir[0]}/{args.outf[0]}_std_depth.nc") # nt array, stdev depth for each time period

    return [uncropped_max_diag, uncropped_max_depth]

def plot_map(output, mesh, args, i):
    
    time = 0
    pad = 3
    lat, lon = ('y', 'x') if 'y' in output.dims else ('lat', 'lon')
    labels = [f"{args.diagvar}", f"Depth (m)"]
    metrics_text = f"Mean: {output.mean(dim=[lat, lon])[time].values} \
                     Std: {output.std(dim=[lat, lon])[time].values}"
    lat_grid, lon_grid = ('nav_lat', 'nav_lon') if 'nav_lat' in list(mesh.variables.keys()) else ('lat', 'lon')
    cmaps = ["cividis","plasma"]  

    # Extract bounds for projection and extent
    lon_slice = crop_grid(mesh[lon_grid], args, depth=False)
    lat_slice = crop_grid(mesh[lat_grid], args, depth=False)
    lon_min = lon_slice.min()
    lon_max = lon_slice.max()
    lat_min = lat_slice.min()
    lat_max = lat_slice.max()

    # print(f"lon_min: {lon_min}, lon_max: {lon_max}, lat_min: {lat_min}, lat_max: {lat_max}")
    
    # Set projection
    if lat_max <= 60 and lat_min <= -60:
        projection = ccrs.SouthPolarStereo()
    elif lat_max >= 60 and lat_min >= -60:
        projection = ccrs.NorthPolarStereo()
    else:
        projection = ccrs.PlateCarree()

    # Set title
    tmask_depths = args.tmask[0].split('/')[-1].split('.')[0].split('_')
    mindepth = next((chunk.split('-')[1] for chunk in tmask_depths if 'mindepth' in chunk), None)
    maxdepth = next((chunk.split('-')[1] for chunk in tmask_depths if 'maxdepth' in chunk), None)
    title = f"Obs " if args.obs else "Model "
    title = f"Depth of {title.lower()}" if i==1 else title
    if (args.salvar and args.tempvar):
        title += f"volume of {args.diagvar} > {args.densthresh[0]} "
    else:
        title += f"{args.diagvar} anomaly "
    if (mindepth and maxdepth):
        title += f"for depths between {mindepth}m - {maxdepth}m "
    elif mindepth:
        title += f"for depths greater than {mindepth}m "
    elif maxdepth:
        title += f"for depths less than {maxdepth}m "
    else:
        title += f"for all depths "

    title += f"\naveraged over {args.obsref[0].split(' ')[-1]}" if args.obs else f"\nat {args.time_counter[0]}"

    # Configure the plot
    fig, ax = plt.subplots(figsize=(10, 10), subplot_kw={'projection': projection})
    fig.suptitle(title, fontsize=16, fontweight='bold')
    ax.set_extent([lon_min - pad, lon_max + pad, lat_min - pad, lat_max + pad], crs=ccrs.PlateCarree())
    ax.coastlines()
    ax.add_feature(cfeature.LAND, edgecolor='black', facecolor='tan') 
    ax.add_feature(cfeature.BORDERS)
    ax.add_feature(cfeature.OCEAN, facecolor='lightblue')
    ax.text(0.5, -0.1, metrics_text, transform=ax.transAxes, ha='center', va='top', fontsize=10)
    plot = ax.pcolormesh(mesh[lon_grid], mesh[lat_grid], output.isel({args.timevar[0]: time}), transform=ccrs.PlateCarree(), cmap=cmaps[i], shading='auto')
    fig.colorbar(plot, ax=ax, orientation='horizontal', label=labels[i])

    plt.tight_layout()
    plt.savefig(f"{args.marvaldir[0]}/FIGURES/{args.outf[0]}_{args.diagvar.lower()}_{i}.png", dpi=300)

def main():

    args = load_argument()
    depth_vars = ['nav_lev', 'deptht', 'depth']
    args.depthvar = [next(d for d in depth_vars if d in xr.open_dataset(args.datf[0], decode_times=False).dims)]
    decode_times = False if args.obs else True
    drop_variables = None if args.depthvar[0] == 'nav_lev' else [args.depthvar[0]]

    ### Load data ###
    # Load and prepare tmask
    tmask = xr.open_dataset(args.tmask[0])['tmask'] # nk x nj x ni array, 1 for ocean, 0 for land
    get_bounds(tmask, args) # Extract bounds useful for cropping, where tmask values are 1
    tmask = crop_grid(tmask, args, depth=True) # 1 x nj x ni array, 0 for all values outside the domain
    # Load diagnostics
    data = xr.open_dataset(args.datf[0], drop_variables=drop_variables, decode_times=decode_times).rename_dims({args.depthvar[0]:'nav_lev'})
    args.depthvar = ['nav_lev']
    # Load mesh
    mesh = xr.open_dataset(args.meshf[0])

    # Average time dimension for obs, model data has time dimension of size 1
    args.time_centered = data['time_centered'] if not args.obs else None
    time_dim = data[args.timevar[0]] if not args.obs else [0]
    args.time_counter = data[args.timevar[0]].mean(dim=args.timevar[0]).expand_dims(dim={args.timevar[0]:time_dim})

    # Calculate metrics
    if (args.salvar and args.tempvar):
        outputs = calc_sigma4(data, tmask, mesh, args)
    else:
        outputs = calc_max_diag(data, tmask, mesh, args)
    
    # Plot outputs
    for i, df in enumerate(outputs):
        plot_map(df, mesh, args, i)

if __name__=="__main__":
    main()
