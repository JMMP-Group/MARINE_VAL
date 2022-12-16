#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=60
#SBATCH --ntasks=1

if [[ $# -ne 4 ]]; then echo 'mk_gsl_nac.bash [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

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
if [[ ${RUNID} = u-ah494 ]]; then
  FILET=`ls ${DATINPATH}/${RUNID}o_${FREQ}_${TAG}*T.nc`
else
  FILET=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid-T.nc`
fi
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_gsl.bash $@ (see ${JOBOUT_PATH}/mk_gsl_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# crop region to NA
FILE_NA=nemo_${RUN_NAME}o_${FREQ}_${TAG}_NA_crop_T.nc
ijbox=$($CDFPATH/cdffindij -w -80.000 0.000 25.000 70.000 -c mesh.nc -p T | tail -2 | head -1 )
echo "ijbox : $ijbox"
$CDFPATH/cdfclip -f $FILET -o $FILE_NA -zoom $ijbox

# find GS separation latitude at 15degC, 200m isotherm and NAC latitude at 10degC, 50m isotherm:

cd ${SCRPATH}/
python3 cal_GS_sep_NAC_lat.py $DATPATH/$FILE_NA ${RUNID}


