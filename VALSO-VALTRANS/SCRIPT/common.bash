#!/bin/bash

# create repository
#DATPATH=${SCRATCH}/MARINE_VAL/$RUNID/           
#DATPATH=${SCRATCH}/VALSO/DATA/$RUNID/           
DATPATH=${DATPATH}/${RUNID}
#DATPATH=${SCRATCH}/MARINE_VAL/VALSO/$RUNID/
DATINPATH=${SCRATCH}/MARINE_VAL/DATA/$RUNID/
if [ ! -d $DATPATH ]; then mkdir -p $DATPATH ; fi
if [ ! -d $DATINPATH ]; then mkdir -p $DATINPATH ; fi

# check mesh mask
cd ${DATPATH}
if [ ! -L mesh.nc     ] ; then ln -s ${MSKPATH}/mesh_mask_${CONFIG}-GOSI9-Tenten.nc mesh.nc ; fi
if [ ! -L mask.nc     ] ; then ln -s ${MSKPATH}/mesh_mask_${CONFIG}-GOSI9-Tenten.nc mask.nc ; fi
basin_mask=${MSKPATH}/subbasins_${CONFIG}-GO6.nc
if [ ! -f ${basin_mask} ] ; then
  basin_mask=${MSKPATH}/subbasins_${CONFIG}.nc
fi
if [ ! -L bathymetry.nc ] ; then ln -s ${MSKPATH}/bathymetry_${CONFIG}-GOSI9-Tenten.nc bathymetry.nc ; fi
if [ ! -L subbasin.nc     ] ; then ln -s ${basin_mask} subbasin.nc ; fi
if [ ! -L mesh.nc     ] ; then echo "mesh.nc is missing; exit"; exit 1 ; fi
if [ ! -L mask.nc     ] ; then echo "mask.nc is missing; exit"; exit 1 ; fi
if [ ! -L subbasin.nc ] ; then echo "subbasin.nc is missing; exit"; exit 1 ; fi
