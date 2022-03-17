import xarray as xr
import netCDF4 as nc
import sys


def find_nearest(array, value):
    n = [abs(i-value) for i in array]
    idx = n.index(min(n))
    return idx, array[idx]


def calculate_metric_from_isotherm_lon(ds, runid, chosen_lon, chosen_depth, isotherm):

    # selecting chosen depth
    if runid == 'u-ah494':
        T_z_slice = ds.sel(deptht=[chosen_depth], method='nearest').votemper[0][0]
    else:
        T_z_slice = ds.sel(deptht=[chosen_depth], method='nearest').thetao[0][0]

    # selecting chosen longitude
    if runid == 'u-ar435' or runid == 'u-ah494' or runid == 'u-ai758':
        idx_x, lon_check = find_nearest(ds.nav_lon_grid_T[0, :].values, chosen_lon)  # y,x

    elif runid == 'u-ak108' or runid == 'u-aj393' or runid == 'mi-aq915':
        idx_x, lon_check = find_nearest(ds.nav_lon.values[0, :], chosen_lon)  # y,x
    else:
        print('name of nav_lon variable is unknown')
    print ('lon_check', lon_check)

    # finding lat at chosen isotherm
    idx_y, T_check = find_nearest(T_z_slice[:, idx_x].values, isotherm)
    print ('T_check', T_check)

    # Note if more than one value of chosen isotherm is found at chosen longitude,
    # #the code works by selecting the latitude with the isotherm closest to the chosen isotherm

    if runid == 'u-ar435' or runid == 'u-ah494' or runid == 'u-ai758':
        latitude = ds.nav_lat_grid_T[idx_y, idx_x].values
    elif runid == 'u-ak108' or runid == 'u-aj393' or runid == 'mi-aq915':
        latitude = ds.nav_lat[idx_y, idx_x].values
    else:
        print('name of nav_lat variable is unknown')

    print ('sep_latitude', latitude)

    return latitude


def add_metric_to_netcdf(tfile_NA, GS_sep_latitude, NAC_latitude):

    # Load input file
    file_input = nc.Dataset(tfile_NA, 'a', format='NETCDF4')

    new_variable = file_input.createVariable('GS_sep_lat', 'float64', 'time_counter')
    new_variable[:] = GS_sep_latitude

    new_variable2 = file_input.createVariable('NAC_lat', 'float64', 'time_counter')
    new_variable2[:] = NAC_latitude

    print (file_input.variables.keys())

    return


def main():

    tfile_NA = sys.argv[1]
    runid = sys.argv[2]

    ds = xr.open_dataset(tfile_NA)

    chosen_lon = -72
    chosen_depth = 200
    isotherm = 15
    GS_sep_latitude = calculate_metric_from_isotherm_lon(ds, runid, chosen_lon, chosen_depth, isotherm)


    chosen_lon = -41
    chosen_depth = 50
    isotherm = 10
    NAC_latitude = calculate_metric_from_isotherm_lon(ds, runid, chosen_lon, chosen_depth, isotherm)

    add_metric_to_netcdf(tfile_NA, GS_sep_latitude,NAC_latitude)

    return



if __name__ == "__main__":
    main()