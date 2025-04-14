import xarray as xr # 2025.1.2
import numpy as np # 2.2.3
import scipy.ndimage as ndimage # 1.15.2
import argparse # 1.1
from util import get_ij_from_lon_lat


def load_argument():
    parser = argparse.ArgumentParser()
    parser.add_argument("-w", metavar='coordinates list', help="LON_MIN, LON_MAX, LAT_MIN, LAT_MAX values", type=float, nargs='+', required=True )
    parser.add_argument("-c", metavar='mesh file', help="the mesh file to work from", type=str, nargs=1 , required=False, default=['mesh.nc'])
    parser.add_argument("-depth", metavar='depth constraint', help="value to qualify the mesh mask", type=float, nargs=1, required=True)
    parser.add_argument("-runid", metavar='runid' , help="used to look information in runid.db", type=str, nargs=1 , required=True)
    parser.add_argument("-dir", metavar='directory of input file', help="directory of input file", type=str, nargs=1, required=False, default=['./'])
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
    LON_MIN, LON_MAX, LAT_MIN, LAT_MAX = args.w

    assert LON_MIN < LON_MAX, "LON_MIN must be less than LON_MAX"
    assert LAT_MIN < LAT_MAX, "LAT_MIN must be less than LAT_MAX"
    assert -90 <= LAT_MIN <= 90 and -90 <= LAT_MAX <= 90, "Latitude values must be between -90 and 90"
    assert -180 <= LON_MIN <= 180 and -180 <= LON_MAX <= 180, "Longitude values must be between -180 and 180"

    lat_grid = mesh_data['nav_lat'].values # 1206 x 1440 array, latitudes of each grid point
    lon_grid = mesh_data['nav_lon'].values # 1206 x 1440 array, longitudes of each grid point
    
    domain_mask = (lat_grid >= LAT_MIN) & (lat_grid <= LAT_MAX) & (lon_grid >= LON_MIN) & (lon_grid <= LON_MAX) # 1206 x 1440 array, boolean mask for a given domain
    
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
    DEPTH = args.depth[0]
    assert 0 <= DEPTH <= 6003, "Depth value must be between 0 and 6003" 
    bathymetry = mesh_data['bathy_metry'][0] # 1206 x 1440 array, depth of the ocean floor in meters
    depth_mask = (bathymetry >= DEPTH) # 1206 x 1440 array, boolean mask for a given depth 

    return array.where(depth_mask, 0) 

def filter_largest_cluster(array, TARGET_J, TARGET_I):
    """
    Retains only the largest cluster of non-zero values for each 2D array representation of a vertical level.

    Parameters:
    array (xr.array): Input 4D array with clusters of non-zero values.
    TARGET_J (int): Target J coordinate.
    TARGET_I (int): Target I coordinate.

    Returns:
    xr.array: 4D array with only the largest cluster of non-zero values retained.
    """
    
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
    DATADIR = f"{args.dir[0]}/{args.runid[0]}"
    mesh_data = xr.open_dataset(f"{DATADIR}/{args.c[0]}")
    tmask = mesh_data['tmask'] # 1 x 75 x 1206 x 1440 array, 1 for ocean, 0 for land
    lon = mesh_data['nav_lon'].values # 1206 x 1440 array, longitudes of each grid point
    lat = mesh_data['nav_lat'].values # 1206 x 1440 array, latitudes of each grid point
    TARGET_J, TARGET_I = get_ij_from_lon_lat(-41, 49, lon, lat) 

    masked_tmask = filter_lat_lon(tmask, mesh_data, args) # 1 x 75 x 1206 x 1440 array, 0 for all values outside the domain
    masked_tmask = filter_depth(masked_tmask, mesh_data, args) # 1 x 75 x 1206 x 1440 array, 0 for all values below the depth threshold
    masked_tmask = filter_largest_cluster(masked_tmask, TARGET_J, TARGET_I) # 1 x 75 x 1206 x 1440 array, 0 for all values outside the largest cluster
    masked_tmask = masked_tmask.squeeze() # 75 x 1206 x 1440 array, removes the first dimension
    masked_tmask.to_netcdf(f"{DATADIR}/masked_tmask_NA_gyre.nc")

if __name__=="__main__":
    main()

