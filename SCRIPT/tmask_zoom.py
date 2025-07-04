import xarray as xr # 2025.1.2
import numpy as np # 2.2.3
import scipy.ndimage as ndimage # 1.15.2
import argparse # 1.1
from util import get_ij_from_lon_lat


def load_argument():
    parser = argparse.ArgumentParser()
    parser.add_argument("-W", "--west", dest="west", metavar="western limit", help="western limit of the domain", type=float, nargs=1, required=True)
    parser.add_argument("-E", "--east", dest="east", metavar="eastern limit", help="eastern limit of the domain", type=float, nargs=1, required=True)
    parser.add_argument("-S", "--south", dest="south", metavar="southern limit", help="southern limit of the domain", type=float, nargs=1, required=True)
    parser.add_argument("-N", "--north", dest="north", metavar="northern limit", help="northern limit of the domain", type=float, nargs=1, required=True)
    parser.add_argument("-m", "--mesh", dest="mesh", metavar="mesh file", help="the mesh file to work from", type=str, nargs=1 , required=True)
    parser.add_argument("-mindepth", metavar="depth constraint", help="min depth limit of the domain", type=float, nargs=1, required=False, default=[0.0])
    parser.add_argument("-maxdepth", metavar="depth constraint", help="max depth limit of the domain", type=float, nargs=1, required=False)
    parser.add_argument("-tlon, --target_lon", dest="target_lon", metavar="target longitude", help="longitude which should be present in the largest cluster", type=float, nargs=1, required=True)
    parser.add_argument("-tlat, --target_lat", dest="target_lat", metavar="target latitude", help="latitude which should be present in the largest cluster", type=float, nargs=1, required=True)
    parser.add_argument("-o, --outf", dest="outf", metavar="output file", help="name of output file", type=str, nargs=1, required=True)
    return parser.parse_args()

def filter_lat_lon(array, mesh_data, args):
    """
    Filters the latitude and longitude values from the arguments.

    Parameters:
    array (xr.array): Input 4D array with depth values.
    mesh_data (xr.Dataset): Mesh data from the mesh file.
    args (argparse.Namespace): Arguments from the command line.

    Returns:
    xr.array: Masked array.
    """

    assert args.west[0] < args.east[0], "W (western limit) must be less than E (eastern limit)"
    assert args.south[0] < args.north[0], "S (southern limit) must be less than N (northern limit)"
    assert -90 <= args.south[0] <= 90 and -90 <= args.north[0] <= 90, "Latitude values must be between -90 and 90"
    assert -180 <= args.west[0] <= 180 and -180 <= args.east[0] <= 180, "Longitude values must be between -180 and 180"

    if "nav_lon" in mesh_data.variables:
       lat_grid = mesh_data['nav_lat'].values # 1206 x 1440 array, latitudes of each grid point
       lon_grid = mesh_data['nav_lon'].values # 1206 x 1440 array, longitudes of each grid point
    else:
       lon_grid = mesh_data['glamt'].squeeze().values
       lat_grid = mesh_data['gphit'].squeeze().values    

    domain_mask = (lat_grid >= args.south[0]) & (lat_grid <= args.north[0]) & (lon_grid >= args.west[0]) & (lon_grid <= args.east[0]) # 1206 x 1440 array, boolean mask for a given domain
    
    return array.where(domain_mask, 0)

def filter_depth(array, mesh_data, args):
    """
    Filters the depth values from the arguments.

    Parameters:
    array (xr.array): Input 4D array with depth values.
    mesh_data (xr.Dataset): Mesh data from the mesh file.
    args (argparse.Namespace): Arguments from the command line.

    Returns:
    xr.array: Masked array.
    """
    MAXDEPTH = np.nanmax(mesh_data['gdept_0'])
    bathymetry = mesh_data['bathy_metry'][0] # 1206 x 1440 array, depth of the ocean floor in meters

    assert 0 <= args.mindepth[0] <= MAXDEPTH, f"Minimum depth value must be between 0 and {MAXDEPTH:.3f}"
    depth_mask = (bathymetry >= args.mindepth[0]) # 1206 x 1440 array, boolean mask for a given depth 

    if args.maxdepth:
        assert 0 <= args.maxdepth[0] <= MAXDEPTH, f"Maximum depth value must be between 0 and {MAXDEPTH:.3f}"
        assert args.maxdepth[0] > args.mindepth[0], "Maximum depth value must be greater than minimum depth value"
        depth_mask &= (bathymetry <= args.maxdepth[0])

    return array.where(depth_mask, 0) 

def filter_largest_cluster(array, mesh_data, args):
    """
    Retains only the largest cluster of non-zero values for each 2D array representation of a vertical level.

    Parameters:
    array (xr.array): Input 4D array with clusters of non-zero values.
    TARGET_J (int): Target J coordinate.
    TARGET_I (int): Target I coordinate.

    Returns:
    xr.array: 4D array with only the largest cluster of non-zero values retained.
    """
    if "nav_lon" in mesh_data.variables:
       lon = mesh_data['nav_lon'].values # 1206 x 1440 array, longitudes of each grid point
       lat = mesh_data['nav_lat'].values # 1206 x 1440 array, latitudes of each grid point
    else:
       lon = mesh_data['glamt'].squeeze().values
       lat = mesh_data['gphit'].squeeze().values
    TARGET_J, TARGET_I = get_ij_from_lon_lat(args.target_lon[0], args.target_lat[0], lon, lat) 
    
    for t in range(array.shape[0]):
        for olevel in range(array.shape[1]):
            
            labeled_array, num_features = ndimage.label(array[t,olevel,:,:], structure=ndimage.generate_binary_structure(2, 1)) # array of same shape as input array, where non-zero values are labeled with integers starting from 1, with each integer representing a different cluster. Structure option to allow for diagonal connections.
            cluster_sizes = ndimage.sum_labels(array[t,olevel,:,:], labeled_array, range(1, num_features + 1))

            if cluster_sizes.size == 0:
                continue
            
            largest_cluster_mask = (labeled_array == np.argmax(cluster_sizes) + 1) # 1206 x 1440 array, boolean mask for the largest cluster
            array[t,olevel,:,:] = array[t,olevel,:,:].where(largest_cluster_mask, 0) # 1 x 75 x 1206 x 1440 array, 0 for all values outside the largest cluster

            if not largest_cluster_mask[TARGET_J, TARGET_I]:
                print(f"WARNING: Target grid point (J={TARGET_J}, I={TARGET_I}) is outside the bounds of the largest cluster in olevel={olevel}.")
            
    return array


def main():

    args = load_argument()
    mesh_data = xr.open_dataset(args.mesh[0])
    tmask = mesh_data['tmask'] # 1 x 75 x 1206 x 1440 array, 1 for ocean, 0 for land
    masked_tmask = filter_lat_lon(tmask, mesh_data, args) # 1 x 75 x 1206 x 1440 array, 0 for all values outside the domain
    masked_tmask = filter_depth(masked_tmask, mesh_data, args) # 1 x 75 x 1206 x 1440 array, 0 for all values below the depth threshold
    masked_tmask = filter_largest_cluster(masked_tmask, mesh_data, args) # 1 x 75 x 1206 x 1440 array, 0 for all values outside the largest cluster
    masked_tmask = masked_tmask.squeeze() # 75 x 1206 x 1440 array, removes the first dimension
    masked_tmask.to_netcdf(args.outf[0])

if __name__=="__main__":
    main()

