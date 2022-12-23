#!/bin/bash
#SBATCH --mem=30G
#SBATCH --time=20
#SBATCH --ntasks=1


if [[ $# -ne 4 ]]; then echo 'mk_ovf.bash [CONFIG (ORCA12, ORCA025 ...)] [RUNID (u-ak108)] [TAG (19801201)] [FREQ (1y)]'; exit 1 ; fi

# to test mk_ovf.bash separately so errors are printed to terminal, run:
# ./SCRIPT/mk_ovf.bash ORCA1 u-ak108 19801201 1y

CONFIG=$1
RUNID=$2
TAG=$3
FREQ=$4

# load path and mask
. param.bash
. ${SCRPATH}/common.bash

cd $DATPATH/
JOBOUT_PATH=$DATPATH/JOBOUT/

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
FILET=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see ${JOBOUT_PATH}/mk_ovf_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

##############################
# choose observational cross section to map model to for metric and choose to crop to Irminger basin only
# (default is Irminger and Icelandic basin)

OBS_NAME=osnap
# options: latrabjarg_clim, ovide, eel, kogur, hansen & osnap

crop_to_Irmin_basin=False
crop_to_Icel_basin=False
# options: True or False only for osnap observations, otherwise keep False
# note ovide is already cropped to Icelandic basin to avoid repetition with osnap in Irminger
##############################

FILEOUT=$DATPATH/nemo_${RUN_NAME}o_${FREQ}_${TAG}_${OBS_NAME}_Xsection.nc

cd ${SCRPATH}/
python3 cal_ovf_metric.py $FILET ${RUNID} ${CONFIG} $DATPATH $OBS_NAME $FILEOUT $crop_to_Irmin_basin $crop_to_Icel_basin ${OBSPATH}

