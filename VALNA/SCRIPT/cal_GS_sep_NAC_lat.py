import xarray as xr
import netCDF4 as nc
import sys
import os


def find_nearest(array, value):
    n = [abs(i-value) for i in array]
    idx = n.index(min(n))
    return idx, array[idx]


def calculate_metric_from_isotherm_lon(ds, runid, chosen_lon, chosen_depth, isotherm, var_thetao, var_lon):

    # selecting chosen depth
    if var_thetao == 'votemper':
        T_z_slice = ds.sel(deptht=[chosen_depth], method='nearest').votemper[0][0]
    elif var_thetao == 'thetao':
        T_z_slice = ds.sel(deptht=[chosen_depth], method='nearest').thetao[0][0]
    elif var_thetao == 'thetao_con':
        T_z_slice = ds.sel(deptht=[chosen_depth], method='nearest').thetao_con[0][0]

    # selecting chosen longitude
    if var_lon == 'nav_lon_grid_T':
        idx_x, lon_check = find_nearest(ds.nav_lon_grid_T[0, :].values, chosen_lon)  # y,x

    elif var_lon == 'nav_lon':
        idx_x, lon_check = find_nearest(ds.nav_lon.values[0, :], chosen_lon)  # y,x
    else:
        print('name of nav_lon variable is unknown')
    print ('lon_check', lon_check)

    # finding lat at chosen isotherm
    idx_y, T_check = find_nearest(T_z_slice[:, idx_x].values, isotherm)
    print ('T_check', T_check)

    # Note if more than one value of chosen isotherm is found at chosen longitude,
    # #the code works by selecting the latitude with the isotherm closest to the chosen isotherm

    if var_lon == 'nav_lon_grid_T':
        latitude = ds.nav_lat_grid_T[idx_y, idx_x].values
    elif var_lon == 'nav_lon':
        latitude = ds.nav_lat[idx_y, idx_x].values
    else:
        print('name of nav_lat variable is unknown')

    print ('sep_latitude', latitude)

    return latitude


def add_metric_to_netcdf(tfile_NA, GS_sep_latitude, NAC_latitude):

    # Load input file
    #file_input = nc.Dataset(tfile_NA, 'a', format='NETCDF4')
    with nc.Dataset(tfile_NA, 'a', format='NETCDF4') as file_input:

        new_variable = file_input.createVariable('GS_sep_lat', 'float64', 'time_counter')
        new_variable[:] = GS_sep_latitude

        new_variable2 = file_input.createVariable('NAC_lat', 'float64', 'time_counter')
        new_variable2[:] = NAC_latitude

        print (file_input.variables.keys())

    return

def extract_vars(tfile_NA):
    '''
    Extract GS_sep_lat and NAC_lat into own file
    '''
    try:
        cmd = 'ncks -O -v time_centered,GS_sep_lat,NAC_lat '+tfile_NA+' '+os.path.join(os.path.dirname(tfile_NA), 'GS_NAC_'+os.path.basename(tfile_NA))
        print(cmd)
        os.system(cmd)
    except:
        raise Exception('Failed to extract GS_sep_lat, NAC_lat from '+tfile_NA)
    cmd = 'cp '+os.path.join(os.path.dirname(tfile_NA), 'GS_NAC_'+os.path.basename(tfile_NA))+' '+tfile_NA
    os.system(cmd)
    

def main():

    tfile_NA = sys.argv[1]
    runid = sys.argv[2]

    with nc.Dataset(tfile_NA, 'r') as fname:
        variables = fname.variables
        if 'thetao' in variables:
            var_thetao = 'thetao'
        elif 'votemper' in variables:
            var_thetao = 'votemper'
        elif 'thetao_con' in variables:
            var_thetao = 'thetao_con'
        else:
            raise Exception('Did not find suitable thetao variable in '+tfile_NA)

        if 'nav_lon_grid_T' in variables:
            var_lon = 'nav_lon_grid_T'
        elif 'nav_lon' in variables:
            var_lon = 'nav_lon'
        else:
            raise Exception('Did not find suitable nav_lon variable in '+tfile_NA)

    ds = xr.open_dataset(tfile_NA)

    chosen_lon = -72
    chosen_depth = 200
    isotherm = 15
    GS_sep_latitude = calculate_metric_from_isotherm_lon(ds, runid, chosen_lon, chosen_depth, isotherm, var_thetao, var_lon)


    chosen_lon = -41
    chosen_depth = 50
    isotherm = 10
    NAC_latitude = calculate_metric_from_isotherm_lon(ds, runid, chosen_lon, chosen_depth, isotherm, var_thetao, var_lon)

    print('add GS metric to file ',tfile_NA)
    add_metric_to_netcdf(tfile_NA, GS_sep_latitude, NAC_latitude)

    print('extract GS metric from file ',tfile_NA)
    extract_vars(tfile_NA)

    return



if __name__ == "__main__":
    main()
