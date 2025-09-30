#!/usr/bin/env python

'''
Routine to compute the overturning streamfunction
in depth space accross a model transect.

@author: Diego Bruciaferri
@date: August 2025
'''

import sys
import numpy as np
import xarray as xr
import nsv
import gsw

if __name__ == "__main__":

     Fsection = sys.argv[1] # NetCDF file of the brokenline section
     label    = sys.argv[2] # to be used on the name of the output file 
     int_dir  = sys.argv[3] # direction of integration: "top2bot" or "bot2top"

     ds = xr.open_dataset(Fsection).squeeze(dim='y')
     ds = ds.rename_dims({'time_counter':'t','deptht':'z'})

     vnorm = ds.vo
     timed = ds.time_centered.data
     depthw = ds.gdepw_1d.squeeze().data

     #MODEL grid metrics       
     zz = ds.e3v_0
     xx = ds.e1v
     #xx = np.repeat(xx[:,np.newaxis,:], zz.shape[0], axis=1)
     # Land-sea mask
     mask = ds.vmask

     # Grid cell area
     area = zz * xx

     # Mask the area and vnorm
     area  = area.where(mask==1, 0.)
     vnorm = vnorm.where(mask==1, 0.)
 
     # Vflux
     vflux = vnorm * area

     # Dealing with the vertical integration direction
     if int_dir == "top2bot":
        stp = 1
     elif int_dir == "bot2top":
        stp = -1
     else:
        print('Error: direction of integration not recognised!')
        quit()

     # Compute MOC from flux in density bins
     print('Compute the overturning streamfunction in depth coordinates')
     nt = vflux.t.size
     nz = vflux.z.size
     ny = 1
     nx = 1
     MOC_z = np.zeros((nt, nz, ny, nx))
     for t in range(vflux.t.size):
         # Integrate along x
         xint = -vflux[t,:,:].sum(dim='x').values
         # Convert from m3/s to Sv
         xint = xint / 1.e6
         # integrate bottom to top
         MOC_z[t,:,0,0] = xint[::stp].cumsum()[::stp]

     # Saving datarray and netCDF file
     ds_moc = xr.Dataset(
                   data_vars=dict(
                         amoc_rapid=(["time_counter", "depthw","y","x"], MOC_z.data),
                         Total_max_amoc_rapid=(["time_counter","y","x"], np.nanmax(MOC_z.data, axis=1)), 
                   ),
                   coords=dict(
                         time_centered=(["time_counter"], timed),
                         depthw=(["depthw"], depthw),
                   ),
                   attrs=dict(description="Overturning streamfunction profile in depth space at the RAPID array and its maximum"),
              )
     

     enc = {"time_centered"        : {"_FillValue": None }}
     ds_moc.to_netcdf('moc_z_' + label + '.nc', encoding=enc, unlimited_dims={'time_counter':True})

