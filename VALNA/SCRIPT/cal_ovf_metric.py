import nsv
import xarray as xr
import numpy as np
import netCDF4 as nc
import sys
import gsw
import os
import sklearn #needed for section finder


def add_density_to_obs(obs_ds, timevar):
    # Computing potential density anomaly and adding to observational dataset

    lon = obs_ds.longitude.values  # [ni]
    lat = obs_ds.latitude.values  # [ni]
    depth = obs_ds.depth.values  # [nk]
    PT = obs_ds.potential_temperature.values  # Potential temperature [nt,nk,ni]
    PS = obs_ds.practical_salinity.values  # Practical salinity [nt,nk,ni]

    if timevar:
        ni = PT.shape[2]
        nk = PT.shape[1]
        nt = PT.shape[0] #time
    else:
        ni = PT.shape[1]
        nk = PT.shape[0]

    depth2d = np.repeat(depth[:, np.newaxis], ni, axis=1)
    pressure2d = gsw.p_from_z(-depth2d, lat)  # http://www.teos-10.org/pubs/gsw/html/gsw_p_from_z.html
    lon2d = np.repeat(lon[np.newaxis, :], nk, axis=0)
    lat2d = np.repeat(lat[np.newaxis, :], nk, axis=0)

    AS = gsw.SA_from_SP(PS, pressure2d, lon2d,
                        lat2d)  # absolute salinity #http://www.teos-10.org/pubs/gsw/html/gsw_SA_from_SP.html

    CT = gsw.CT_from_pt(AS, PT)  # conservative temperature #http://teos-10.org/pubs/gsw/html/gsw_CT_from_pt.html

    rho = gsw.density.sigma0(AS, CT)

    if timevar:
        obs_ds['sigma_theta'] = xr.DataArray(data=rho, dims=["time", "depth", "station"],
                                         coords=[obs_ds.time, obs_ds.depth, obs_ds.station])
    else:
        obs_ds['sigma_theta'] = xr.DataArray(data=rho, dims=["depth", "station"],
                                         coords=[obs_ds.depth, obs_ds.station])

    return obs_ds


def create_obs_overflow_data_locally(dir):

    # Selecting model data at observational overflow cross sections in NA subpolar gyre

    section_osnap_obs = nsv.Standardizer().osnap
    section_osnap_obs = add_density_to_obs(section_osnap_obs, timevar=True)
    section_osnap_obs.to_netcdf(dir + 'osnap_Xsection.nc')

    section_ovide_obs = nsv.Standardizer().ovide
    section_ovide_obs.to_netcdf(dir + 'ovide_Xsection.nc')

    section_denmark_obs = nsv.Standardizer().latrabjarg_climatology
    section_denmark_obs.to_netcdf(dir + 'latrabjarg_clim_Xsection.nc')

    section_eel_obs = nsv.Standardizer().eel
    section_eel_obs.to_netcdf(dir + 'eel_Xsection.nc')

    section_kogur_obs = nsv.Standardizer().kogur
    section_kogur_obs.to_netcdf(dir + 'kogur_Xsection.nc')

    section_hansen_obs = nsv.Standardizer().ho2000
    section_hansen_obs = add_density_to_obs(section_hansen_obs, timevar=False) #no variation in time
    section_hansen_obs.to_netcdf(dir + 'hansen_Xsection.nc')

    print ('obs data saved locally')
    return


def extract_model_at_Xsection(ds_obs, domain, ds_tgrid, obs_name, runid):

    if obs_name == 'ovide':
        ds_obs = ds_obs.drop(["mid_longitude", "mid_latitude"])

    finder = nsv.SectionFinder(domain)

    stations = finder.nearest_neighbor(
        lons=ds_obs.cf["longitude"],
        lats=ds_obs.cf["latitude"],
        grid="t"
    )

    if runid == 'u-ai758' or runid == 'u-ar435' or runid == 'u-ah494' or runid == 'u-cq175':
        ds_tgrid = ds_tgrid.rename_dims({'x_grid_T': 'x', 'y_grid_T': 'y'})

    section_model = ds_tgrid.isel({dim: stations[f"{dim}_index"] for dim in ("x", "y")})

    return section_model


def interp_model_depth_to_obs(section_model, ds_obs, runid, var_thetao, var_lon):
    # interpolating model depths to obs, changing depth attribute name and saving model T & S to single dataset with obs

    # temperature
    if var_thetao == 'votemper':
        thetao_int_obs = section_model.votemper.interp({"deptht": ds_obs.depth.values}, method="linear")
    elif var_thetao == 'thetao':
        thetao_int_obs = section_model.thetao.interp({"deptht": ds_obs.depth.values}, method="linear")
    elif var_thetao == 'thetao_con':
        thetao_int_obs = section_model.thetao_con.interp({"deptht": ds_obs.depth.values}, method="linear")
    thetao_int_obs.deptht.attrs['long_name'] = 'Observational levels'

    # salinity
    if var_thetao == 'votemper':
        so_int_obs = section_model.vosaline.interp({"deptht": ds_obs.depth.values}, method="linear")
    elif var_thetao == 'thetao':
        so_int_obs = section_model.so.interp({"deptht": ds_obs.depth.values}, method="linear")
    elif var_thetao == 'thetao_con':
        so_int_obs = section_model.so_abs.interp({"deptht": ds_obs.depth.values}, method="linear")
    so_int_obs.deptht.attrs['long_name'] = 'Observational levels'

    return thetao_int_obs, so_int_obs


def create_new_ds_of_model_obs_T_S_den(thetao_int_obs, so_int_obs, ds_obs, obs_name):

    new_ds = thetao_int_obs.to_dataset(name='thetao_interp')
    new_ds['so_interp'] = so_int_obs

    # adding obs for reference
    if obs_name == 'kogur':
        new_ds['obs_salinity'] = ds_obs.salinity
    else:
        new_ds['obs_salinity'] = ds_obs.practical_salinity

    new_ds['obs_temperature'] = ds_obs.potential_temperature

    new_ds['obs_density'] = ds_obs.sigma_theta  # potential density referenced to 0 dbar

    return new_ds


def aver_densest_T_S_in_model(new_ds, obs_name, crop_to_Irmin_basin, crop_to_Icel_basin):
    # extracting T/S in model & obs where observational density > 27.8 isopycnal &
    # save T/S metric to dataset

    isopyc_thres = 27.8

    print('calc aver_densest')
    if obs_name == 'osnap':
        # cropping osnap west
        if crop_to_Irmin_basin == 'True':
            new_ds = new_ds.isel(station=slice(76, 143))
        elif crop_to_Icel_basin == 'True':
            new_ds = new_ds.isel(station=slice(143, 205))
        else:
            new_ds = new_ds.isel(station=slice(76, 205)) # Irminger and Icelandic basins



    if obs_name == 'eel':
        # average obs density by time and flip dimensions
        T_27_8_model = new_ds.thetao_interp.where(new_ds.obs_density.mean(dim='time').transpose().values
                                                   > isopyc_thres).mean(skipna=True, keep_attrs=True)
        S_27_8_model = new_ds.so_interp.where(new_ds.obs_density.mean(dim='time').transpose().values
                                                   > isopyc_thres).mean(skipna=True, keep_attrs=True)

    elif obs_name == 'ovide':
        #  no time dimen to average
        # selecting Irminger & Icelandic basins and excluding Xsection towards Portugal
        T_27_8_model = new_ds.thetao_interp.where((new_ds.obs_density.values > isopyc_thres) &
                                                  (new_ds.distance.values < 1500)).mean(skipna=True, keep_attrs=True)
        S_27_8_model = new_ds.so_interp.where((new_ds.obs_density.values > isopyc_thres) &
                                                  (new_ds.distance.values < 1500)).mean(skipna=True, keep_attrs=True)

    elif obs_name == 'kogur' or obs_name == 'osnap':
        # average obs density by time

        T_27_8_model = new_ds.thetao_interp.where(new_ds.obs_density.mean(dim='time').values
                                                  > isopyc_thres).mean(skipna=True, keep_attrs=True)
        S_27_8_model = new_ds.so_interp.where(new_ds.obs_density.mean(dim='time').values
                                              > isopyc_thres).mean(skipna=True, keep_attrs=True)

    elif obs_name == 'latrabjarg_clim' or obs_name == 'hansen':
        # no time dimen to average
        T_27_8_model = new_ds.thetao_interp.where(new_ds.obs_density.values > isopyc_thres).mean(skipna=True, keep_attrs=True)
        S_27_8_model = new_ds.so_interp.where(new_ds.obs_density.values > isopyc_thres).mean(skipna=True, keep_attrs=True)

    return T_27_8_model, S_27_8_model


def add_metric_to_netcdf(fileout, T_27_8_model, S_27_8_model):

    # adding np.array to netcdf with time dimension:
    file_input = nc.Dataset(fileout, 'a', format='NETCDF4')

    new_variable = file_input.createVariable('T_av_27_8_rho', 'float64', 'time_counter')
    new_variable[:] = T_27_8_model

    new_variable2 = file_input.createVariable('S_av_27_8_rho', 'float64', 'time_counter')
    new_variable2[:] = S_27_8_model

    print(file_input.variables.keys())

    return


def main():

    t_s_file = sys.argv[1] #input file
    runid = sys.argv[2]
    config = sys.argv[3]
    mskpath = sys.argv[4]
    obs_name = sys.argv[5]
    fileout = sys.argv[6]
    crop_to_Irmin_basin = sys.argv[7]
    crop_to_Icel_basin = sys.argv[8]
    obs_dir = sys.argv[9]

    # Save all observational data locally in netcdf (run once):
    # create_obs_overflow_data_locally(obs_dir)

    # obs cross-section file:
    ds_obs = xr.open_dataset(obs_dir+obs_name+'_Xsection.nc')

    # meshmask file:
    domain = xr.open_dataset(mskpath+'/mesh_mask_'+config+'-GO6.nc')

    print('fileout, file_in ',fileout, t_s_file)

    with nc.Dataset(t_s_file, 'r') as fname:
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

    # model temperature file:
    ds_tgrid = xr.open_dataset(t_s_file)

    ###################

    if config == 'eORCA12':
        # cropping domain to reduce memory load
        domain = domain.isel(x=slice(2800, 3500), y=slice(2800, 3500))
        ds_tgrid = ds_tgrid.isel(x=slice(2800, 3500), y=slice(2800, 3500))

    section_model = extract_model_at_Xsection(ds_obs, domain, ds_tgrid, obs_name, runid)

    thetao_int_obs, so_int_obs = interp_model_depth_to_obs(section_model, ds_obs, runid, var_thetao, var_lon)

    new_ds = create_new_ds_of_model_obs_T_S_den(thetao_int_obs, so_int_obs, ds_obs, obs_name)

    print ('crop_to_Irmin_basin = ', crop_to_Irmin_basin)
    print('crop_to_Icel_basin = ', crop_to_Icel_basin)

    if crop_to_Irmin_basin =='True':
        dir = os.path.dirname(fileout)
        file = os.path.splitext(os.path.basename(fileout))[0]
        fileout = dir + '/' + file + '_Irmin_basin_only.nc' #renaming fileout

    if crop_to_Icel_basin =='True':
        dir = os.path.dirname(fileout)
        file = os.path.splitext(os.path.basename(fileout))[0]
        fileout = dir + '/' + file + '_Icel_basin_only.nc' #renaming fileout

    new_ds.to_netcdf(fileout)

    T_27_8_model, S_27_8_model = aver_densest_T_S_in_model(new_ds, obs_name, crop_to_Irmin_basin, crop_to_Icel_basin)

    add_metric_to_netcdf(fileout, T_27_8_model, S_27_8_model)

    return


if __name__ == "__main__":
    main()
