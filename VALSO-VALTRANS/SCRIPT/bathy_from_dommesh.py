#! /usr/bin/env python

'''
Routine to output bathymetry at T-points in metres
starting from a NEMO 4 domain_cfg.nc file. 

Jan 2019 : Update to allow calculation of bathymetry
           from mesh_mask file. DS.

Mar 2019 : Add option to create a bathy_level field 
           (for a full-cell bathymetry) as well as
           a bathy_meter field. DS.

@author: Dave Storkey
@date: August 2018
'''

import numpy as np
import numpy.ma as ma
import netCDF4 as nc
import bottom_field as bf

def bathy_from_domcfg(domcfg=None, meshmask=None, bathymeter=None, bathylevel=None):

    if domcfg is not None:
        with nc.Dataset(domcfg,'r') as data_in:
            model_dims = data_in.dimensions
            nx = len(model_dims['x'])
            ny = len(model_dims['y'])
            for dimname in ['z','nav_lev']:
                try:
                    nz = len(model_dims[dimname])
                except KeyError:
                    pass
                else:
                    break
            else:
                raise Exception("Could not find vertical dimension")
            bottom_level =  data_in.variables['bottom_level'][:]
            e3t_0 = data_in.variables['e3t_0'][:]
            nav_lon = data_in.variables['nav_lon'][:]
            nav_lat = data_in.variables['nav_lat'][:]
    elif meshmask is not None:
        with nc.Dataset(meshmask,'r') as data_in:
            model_dims = data_in.dimensions
            nx = len(model_dims['x'])
            ny = len(model_dims['y'])
            for dimname in ['z','nav_lev']:
                try:
                    nz = len(model_dims[dimname])
                except KeyError:
                    pass
                else:
                    break
            else:
                raise Exception("Could not find vertical dimension")
            for e3t_name in ['e3t','e3t_0']:
                try:
                    e3t_0 = data_in.variables[e3t_name][:]
                except KeyError:
                    pass
                else:
                    break
            else:
                raise Exception("Could not find cell thickness (e3t)")
            tmask = data_in.variables['tmask'][:]
            nav_lon = data_in.variables['nav_lon'][:]
            nav_lat = data_in.variables['nav_lat'][:]
    else:
        raise Exception("Error: must specify one of domcfg or meshmask input file.")

    if bathymeter is None and bathylevel is None:
        raise Exception("Error: must specify at least one of bathymeter and bathylevel")

    # Create 3D versions of "level" and "bottom_level" arrays. 
    # Use these to create a tmask field (if starting from domcfg file; tmask just
    # read in meshmask file) and then mask e3t_0 and sum vertically. 

    if domcfg is not None:
        ones_3D = np.ones([nx,ny,nz])
        level_1D = np.arange(nz)+1
        level_3D = (level_1D * ones_3D).transpose()
        botlevel_3D = bottom_level * ones_3D.transpose()
        tmask = np.where( level_3D <= botlevel_3D, 1, 0 )
        
    if bathymeter is not None:

        bathy_meter = np.sum(e3t_0*tmask, axis=(0,1))

        with nc.Dataset(bathymeter,'w') as data_out:
            data_out.createDimension('x', nx)
            data_out.createDimension('y', ny)
            data_out.createDimension('z', nz)
            data_out.createVariable('nav_lon',datatype='f',dimensions=('y','x'))
            data_out.variables['nav_lon'][:] = nav_lon[:]
            data_out.variables['nav_lon'].standard_name = 'longitude'
            data_out.variables['nav_lon'].units = 'degrees_east'
            data_out.createVariable('nav_lat',datatype='f',dimensions=('y','x'))
            data_out.variables['nav_lat'][:] = nav_lat[:]
            data_out.variables['nav_lat'].standard_name = 'latitude'
            data_out.variables['nav_lat'].units = 'degrees_north'
            data_out.createVariable('Bathymetry',datatype='f',dimensions=('y','x'))
            data_out.variables['Bathymetry'][:] = bathy_meter[:]
            data_out.variables['Bathymetry'].standard_name = 'sea_floor_depth'
            data_out.variables['Bathymetry'].units = 'm'
            data_out.variables['Bathymetry'].coordinates = 'nav_lat nav_lon'
            data_out.createVariable('tmask',datatype='f',dimensions=('z','y','x'))
            data_out.variables['tmask'][:] = tmask[:]

    if bathylevel is not None:

        # first guess of bathy_level as sum of tmask in the vertical
        bathy_level = np.sum(tmask, axis=(0,1))

        # subtract 1 from bathy_level where the bottom partial cell thickness is 
        # less than 50% of the "ambient" cell thickness for that level
        ones_3D = np.ones([nx,ny,nz])
        e3t_0_ma = ma.array(e3t_0,mask=1-tmask)
        bottom_level,e3t_bottom = bf.bottom_field(e3t_0_ma)
        e3t_fullcell = np.amax(e3t_0,axis=(-1,-2))
        e3t_fullcell_3d = ma.array((e3t_fullcell * ones_3D).transpose(),mask=1-tmask)
        bottom_level, e3t_fullcell_bottom = bf.bottom_field(e3t_fullcell_3d)
        ratio = e3t_bottom/e3t_fullcell_bottom
        bathy_level = np.where(e3t_bottom < 0.5*e3t_fullcell_bottom, bathy_level-1, bathy_level)

        with nc.Dataset(bathylevel,'w') as data_out:
            data_out.createDimension('x', nx)
            data_out.createDimension('y', ny)
            data_out.createDimension('z', nz)
            data_out.createVariable('nav_lon',datatype='f',dimensions=('y','x'))
            data_out.variables['nav_lon'][:] = nav_lon[:]
            data_out.variables['nav_lon'].standard_name = 'longitude'
            data_out.createVariable('nav_lat',datatype='f',dimensions=('y','x'))
            data_out.variables['nav_lat'][:] = nav_lat[:]
            data_out.variables['nav_lat'].standard_name = 'latitude'
            data_out.createVariable('Bathy_level',datatype='f',dimensions=('y','x'))
            data_out.variables['Bathy_level'][:] = bathy_level[:]
            data_out.variables['Bathy_level'].standard_name = 'sea_floor_depth'
            data_out.variables['Bathy_level'].coordinates = 'nav_lat nav_lon'
            data_out.createVariable('tmask',datatype='f',dimensions=('z','y','x'))
            data_out.variables['tmask'][:] = tmask[:]

if __name__=="__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("-D", "--domcfg", action="store",dest="domcfg",default=None,
                         help="name of domain_cfg input file")
    parser.add_argument("-M", "--meshmask", action="store",dest="meshmask",default=None,
                         help="name of mesh_mask input file")
    parser.add_argument("-m", "--meter", action="store",dest="bathymeter",default=None,
                         help="name of bathymetry output file")
    parser.add_argument("-l", "--level", action="store",dest="bathylevel",default=None,
                         help="name of bathy_level output file")

    args = parser.parse_args()

    bathy_from_domcfg(domcfg=args.domcfg, meshmask=args.meshmask, bathymeter=args.bathymeter, bathylevel=args.bathylevel)
