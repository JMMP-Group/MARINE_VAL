#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 4 ]]; then echo 'mk_mht.bash [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

CONFIG=$1
RUNID=$2
TAG=$3
FREQ=$4

# load path and mask
. param.bash
. ${SCRPATH}/common.bash

cd $DATPATH/
JOBOUT_PATH=$DATPATH/JOBOUT

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_mht.bash $@ (see ${JOBOUT_PATH}/mk_mht_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# calculate mht
set -x
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_mht.nc
$CDFPATH/cdfmhst -vt $FILEV -vvl -o tmp_$FILEOUT
#[ -vvl ] : use time-varying  e3t for integration

# mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfmht; exit"; echo "E R R O R in : ./mk_mht.bash $@ (see ${JOBOUT_PATH}/mk_mht_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

# extract only 26.5N (hard coded from Pierre)

if [[ $CONFIG -eq eORCA1 ]]; then
    ncks -O -d y,227,227 $FILEOUT OHT_${RUN_NAME}o_${FREQ}_${TAG}_mht_26_5N.nc
fi
if [[ $CONFIG -eq eORCA025 ]]; then
    ncks -O -d y_grid_V,793,793 $FILEOUT OHT_${RUN_NAME}o_${FREQ}_${TAG}_mht_26_5N.nc
fi
if [[ $CONFIG -eq eORCA12 ]]; then
    ncks -O -d y,2364,2364 $FILEOUT OHT_${RUN_NAME}o_${FREQ}_${TAG}_mht_26_5N.nc
fi
