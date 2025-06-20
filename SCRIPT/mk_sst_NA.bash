#!/bin/bash
#SBATCH --mem=50G
#SBATCH --time=15
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_sst.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3
GRID='T'

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
if [[ ${RUNID} = u-ah494 ]]; then
  FILE=`ls ${RUNID}o_${FREQ}_${TAG}*T.nc`
else
  FILE=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid-T.nc`
fi

echo $FILE
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_sst.bash $@ (see ${JOBOUT_PATH}/mk_sst_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# generate tmask of newfoundland surface
TMASK=${DATPATH}/${RUNID}/tmask_SS_newfound.nc
if [ ! -f $TMASK ] ; then
   python ${SCRPATH}/tmask_zoom.py -W -43.0 -E -37.0 -S -45.0 -N 50.0 -j -40 -i 2.5 -maxdepth 1.5 -m ${DATPATH}/${RUNID}/mesh.nc -o $TMASK
   if [[ $? -ne 0 ]]; then exit 42; fi 
fi

## calculate sst
FILEOUT=SSTav_Newfound_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py --surf -i $FILE -v thetao_pot -c longitude latitude -A mean -G measures -g cell_area \
	                          -o tmp_$FILEOUT -m $TMASK

#mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running reduce_fields.py; exit"; echo "E R R O R in : ./mk_sst.bash $@ (see ${JOBOUT_PATH}/mk_sst_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi




