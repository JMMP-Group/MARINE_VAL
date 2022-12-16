#!/bin/bash

# create repository
#DATPATH=${EXEPATH}/DATA/${RUNID}
DATPATH=${DATPATH}/${RUNID}
DATINPATH=${SCRATCH}/MARINE_VAL/DATA/$RUNID/
if [ ! -d $DATPATH ]; then mkdir -p $DATPATH ; fi

# check mesh mask
cd ${DATPATH}
#if [ ! -L mesh.nc     ] ; then ln -s ${MSKPATH}/mesh_mask_${CONFIG}-GO6.nc mesh.nc ; fi
#if [ ! -L mask.nc     ] ; then ln -s ${MSKPATH}/mesh_mask_${CONFIG}-GO6.nc mask.nc ; fi
if [ ! -L mesh.nc     ] ; then ln -s ${MSKPATH}/mesh_mask_${CONFIG}-GOSI9-Tenten.nc mesh.nc ; fi
if [ ! -L mask.nc     ] ; then ln -s ${MSKPATH}/mesh_mask_${CONFIG}-GOSI9-Tenten.nc mask.nc ; fi
if [ ! -L mesh.nc     ] ; then echo "mesh.nc is missing; exit"; exit 1 ; fi
if [ ! -L mask.nc     ] ; then echo "mask.nc is missing; exit"; exit 1 ; fi

basin_mask=${MSKPATH}/subbasins_${CONFIG}-GO6.nc
if [ ! -f ${basin_mask} ] ; then
  basin_mask=${MSKPATH}/subbasins_${CONFIG}.nc
fi
if [ ! -L subbasin.nc     ] ; then ln -s ${basin_mask} subbasin.nc ; fi
if [ ! -L subbasin.nc     ] ; then echo "subbasins.nc is missing; exit"; exit 1 ; fi
  
