#!/bin/bash
#SBATCH --mem=30G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_ovf.bash [RUNID (u-ak108)] [TAG (19801201)] [FREQ (1y)]'; exit 1 ; fi

# to test mk_ovf.bash separately so errors are printed to terminal, run:
# ./SCRIPT/mk_ovf.bash u-ak108 19801201 1y

RUNID=$1
TAG=$2
FREQ=$3

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see ${JOBOUT_PATH}/mk_ovf_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

##############################
# choose observational cross section to map model to for metric and choose to crop to Irminger basin only
# (default is Irminger and Icelandic basin)

OBS_NAME=ovide
# options: latrabjarg_clim, ovide, eel, kogur, hansen & osnap

crop_to_Irmin_basin=False
crop_to_Icel_basin=False
# options: True or False only for osnap observations, otherwise keep False
# note ovide is already cropped to Icelandic basin to avoid repetition with osnap in Irminger
##############################

FILEOUT=$DATPATH/nemo_${RUN_NAME}o_${FREQ}_${TAG}_${OBS_NAME}_Xsection.nc

python3 ${SCRPATH}/cal_ovf_metric.py $DATPATH/$FILET ${RUNID} ${CONFIG} $MSKPATH $OBS_NAME $FILEOUT $crop_to_Irmin_basin $crop_to_Icel_basin

