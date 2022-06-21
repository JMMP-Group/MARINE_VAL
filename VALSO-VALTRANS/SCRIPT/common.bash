#!/bin/bash

# create repository
DATPATH=${SCRATCH}/ACC/$RUNID/           
if [ ! -d $DATPATH ]; then mkdir -p $DATPATH ; fi

# check mesh mask
cd ${DATPATH}
if [ ! -L mesh.nc     ] ; then ln -s ${MSKPATH}/mesh_mask_${CONFIG}-GO6.nc mesh.nc ; fi
if [ ! -L mask.nc     ] ; then ln -s ${MSKPATH}/mesh_mask_${CONFIG}-GO6.nc mask.nc ; fi
if [ ! -L subbasin.nc ] ; then ln -s ${MSKPATH}/subbasins_${CONFIG}-GO6.nc subbasin.nc ; fi
if [ ! -L mesh.nc     ] ; then echo "mesh.nc is missing; exit"; exit 1 ; fi
if [ ! -L mask.nc     ] ; then echo "mask.nc is missing; exit"; exit 1 ; fi
if [ ! -L subbasin.nc ] ; then echo "subbasin.nc is missing; exit"; exit 1 ; fi
