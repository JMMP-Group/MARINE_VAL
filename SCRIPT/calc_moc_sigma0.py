#!/usr/bin/env python

'''
Routine to compute the overturning streamfunction
in sigma-theta space accross a model transect.

@author: Diego Bruciaferri
@date: March 2025
'''

import sys
import numpy as np
from numba import jit, float64
import xarray as xr
import nsv
import gsw


def compute_potential_sigma(ds):
    # Absolute Salinity
    press = gsw.p_from_z(-ds.depth, ds.latitude)
    abs_s = gsw.SA_from_SP(ds.practical_salinity,
                           press,
                           ds.longitude,
                           ds.latitude
    )
    # Conservative Temperature
    con_t = gsw.CT_from_pt(abs_s,
                           ds.potential_temperature
    )
    # Potential density anomaly
    ds['sigma_theta'] = gsw.density.sigma0(abs_s, con_t)

    return ds

def depth2rho(vflux, rho, minsig, maxsig, stpsig):
    bins      = np.arange(minsig, maxsig, stpsig)
    bins_sect = 0.5*(bins[1:]+bins[:-1])
 
    vflux_rho = rho_bin_loop(vflux, rho, bins)   
 
    vflux_rho = xr.DataArray(
                     data=vflux_rho,
                     dims=('t','x','rho_bin'),
                     name='vflux_rho'
                )  

    return bins_sect, vflux_rho      

#@jit(nopython=True)
def rho_bin_loop(vflux, rho, bins):
    nt  = vflux.shape[0]
    nx  = vflux.shape[2]
    nbins = len(bins)

    vflux_rho = np.zeros((nt,nx,nbins-1))

    for t in range(nt):
        print('time-step', t)
        for i in range(nx):
            for r in range(nbins-1):
                indexes = np.where((rho[t,:,i]>=bins[r])&(rho[t,:,i]<bins[r+1]))
                vflux_rho[t,i,r] = np.nansum(vflux[t,indexes,i])

    return vflux_rho

if __name__ == "__main__":

     Fsection = sys.argv[1] 
     label    = sys.argv[2]
     minsig   = float(sys.argv[3])
     maxsig   = float(sys.argv[4])
     stpsig   = float(sys.argv[5])

     if "obs_osnap" in Fsection:

        ds = nsv.Standardizer().osnap

        if "east" in Fsection:
           ds = ds.isel(station=slice(80, None)) # only osnap east
        elif "west" in Fsection:
           ds = ds.isel(station=slice(None,80)) # only osnap west

        ds = ds.rename_dims({'time':'t','depth':'z','station':'x'})
        ds = ds.transpose("t", "z", "x")

        ds = compute_potential_sigma(ds)
        
        vnorm = ds.velo
        timed = ds.time.data

        # OSNAP observational grid metrics
        depth_o = ds.depth.values
        depth_b = np.zeros((len(depth_o)+1))
        depth_b[1:-1] = 0.5*(depth_o[1:]+depth_o[:-1])
        depth_b[0] = depth_o[0] - (depth_b[1] - depth_o[0])
        depth_b[-1] = depth_o[-1] + (depth_o[-1] - depth_b[-2])
        dz = depth_b[1:]-depth_b[:-1]
        x_o = ds.distance.values*1000.
        x_b = np.zeros((len(x_o)+1))
        x_b[1:-1] = 0.5*(x_o[1:]+x_o[:-1])
        x_b[0] = x_o[0] - (x_b[1] - x_o[0])
        x_b[-1] = x_o[-1] + (x_o[-1] - x_b[-2])
        dx = x_b[1:]-x_b[:-1]
        xx, zz = np.meshgrid(dx,dz)
        # Land-sea mask
        mask   = np.ma.masked_invalid(vnorm.isel(t=[0])).mask.squeeze()

     else:

        ds = xr.open_dataset(Fsection).squeeze(dim='y')
        ds = ds.rename_dims({'time_counter':'t','deptht':'z'})

        ds['sigma_theta'] = gsw.density.sigma0(ds.so_abs, 
                                               ds.thetao_con
                            )

        vnorm = ds.vo
        timed = ds.time_centered.data

        #MODEL grid metrics       
        zz = ds.e3v_0.values
        xx = ds.e1v.values
        xx = np.repeat(xx[:,np.newaxis,:], zz.shape[0], axis=1)
        # Land-sea mask
        mask = np.ma.masked_invalid(vnorm).mask

     # Grid cell area
     area = zz * xx

     # Mask the area
     area = np.ma.masked_where(mask, area)
 
     # Vflux
     Vflux = vnorm * area

     # Potential density
     s_sect = ds.sigma_theta
  
     # Transforming from depth to sigma space
     bins_sect, vflux_rho = depth2rho(vflux=Vflux.values, 
                                      rho=s_sect.values,
                                      minsig=minsig,
                                      maxsig=maxsig,
                                      stpsig=stpsig
                            )

     # Compute MOC from flux in density bins
     print('Compute the overturning streamfunction in sigma0 coordinates')
     MOC_rho = np.zeros((vflux_rho.t.size, bins_sect.size))
     for t in range(vflux_rho.t.size):
         # Integrate along x
         tmp = vflux_rho[t,:,:].sum(dim='x').values
         # Convert from m3/s to Sv
         tmp = tmp / 1.e6
         # integrate bottom to top
         MOC_rho[t,:] = tmp[::-1].cumsum()[::-1]

     # Saving datarray and netCDF file
     ds_moc = xr.Dataset(
                   data_vars=dict(
                         osnap_moc_sig=(["t", "rho_bins"], MOC_rho.data)
                   ),
                   coords=dict(
                         time=(["t"], timed),
                         rho_bins=(["rho_bins"], bins_sect),
                   ),
                   attrs=dict(description="Overturning streamfunction in sigma-0 space"),
              )

     ds_moc.to_netcdf('osnap_moc_sigma0_' + label + '.nc')
