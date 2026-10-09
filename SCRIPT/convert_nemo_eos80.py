#! /usr/bin/env python

'''
Routine to convert nemo teos10 output file to eos80
@author: Catherine Guiavarc'h
'''

import netCDF4
import sys
import numpy as np
import gsw as gsw
import xarray


def convert_nemo_eos80(t_s_file=None,Tvarname=None,Svarname=None):
    if t_s_file is None:
        raise Exception('Error: must specify input file name.')
    else:
        print(' File', t_s_file)
    if Tvarname is None:
        Tvarname='thetao_con'
    if Svarname is None:
        Svarname='so_abs'
    #Open needed Files
    ncfile = netCDF4.Dataset(t_s_file,'a')
    SA = np.array(ncfile.variables[Svarname]).squeeze()
    CT = np.array(ncfile.variables[Tvarname]).squeeze()
    tdep   = np.array(ncfile.variables["deptht"]).squeeze()
    lon = np.array(ncfile.variables['nav_lon'])[:,:]
    lat = np.array(ncfile.variables['nav_lat'])[:,:]

 #Create a mask
    tmsk = np.ones(shape=SA.shape)
    tmsk[SA>100.] = 0.
 # Convert SA to SP
    tlon = np.repeat(lon[np.newaxis, :, :], tdep.shape[0], axis=0)
    tlat = np.repeat(lat[np.newaxis, :, :], tdep.shape[0], axis=0)
    tdep = np.repeat(tdep[:,np.newaxis], tlon.shape[1], axis=1)
    tdep = np.repeat(tdep[:,:,np.newaxis], tlon.shape[2], axis=2)
    pres = gsw.p_from_z(-tdep, tlat)
    SP = gsw.SP_from_SA(SA, pres, tlon, tlat)


 # Convert CT to PT
    PT = gsw.pt_from_CT(SA,CT)
 # Masking land
    SP[tmsk==0] = 1.e+20 #np.nan
    PT[tmsk==0] = 1.e+20 #np.nan
 
 # create variables
    thetao_pot = ncfile.createVariable('thetao_pot','f',(['time_counter', 'deptht', 'y', 'x']),zlib=True,fill_value=1.e+20)
    thetao_pot[0,:,:,:]  = PT[:,:,:].astype(np.single)
    thetao_pot.standard_name = "sea_water_potential_temperature" 
    thetao_pot.long_name = "Sea Water Potential" 
    thetao_pot.units = "degree_C" 
    thetao_pot.online_operation = "average" 
    thetao_pot.interval_operation = "1 month" 
    thetao_pot.interval_write = "1 month" 
    thetao_pot.cell_measures = "area: area" 
    thetao_pot.missing_value = 1.e+20 
    thetao_pot.coordinates = "time_centered deptht nav_lat nav_lon" 
    thetao_pot.cell_methods = "time: mean (thickness weighted)" 

    so_pra = ncfile.createVariable('so_pra','f',(['time_counter', 'deptht', 'y', 'x']),zlib=True,fill_value=1.e+20)
    so_pra[0,:,:,:]  = SP[:,:,:].astype(np.single)
    so_pra.standard_name = "sea_water_practical_salinity" 
    so_pra.long_name = "Sea Water Practical Salinity" 
    so_pra.units = "0.001" 
    so_pra.online_operation = "average" 
    so_pra.interval_operation = "1 month" 
    so_pra.interval_write = "1 month" 
    so_pra.cell_measures = "area: area" 
    so_pra.missing_value = 1.e+20 
    so_pra.coordinates = "time_centered deptht nav_lat nav_lon" 
    so_pra.cell_methods = "time: mean (thickness weighted)" 

   #close file
    ncfile.close()
    return


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--infile", action="store",dest="t_s_file",default=None,
                         help="name of input file")
    parser.add_argument("-T", "--tem", action="store",dest="Tvarname",default=None,
                         help="name of Conservative Temperature variable")
    parser.add_argument("-S", "--sal", action="store",dest="Svarname",default=None,
                         help="name of Absolute Salinity variable")
    args = parser.parse_args()

    convert_nemo_eos80(t_s_file=args.t_s_file, Tvarname=args.Tvarname, Svarname=args.Svarname)
