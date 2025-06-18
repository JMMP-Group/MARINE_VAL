#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_mxl.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1
else echo 'running mk_mxl.bash'
fi

RUNID=$1
TAG=$2
FREQ=$3
GRID='T'

# name
RUN_NAME=${RUNID#*-}

# download data if needed
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-${GRID}

# check presence of input file
FILE=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]${GRID}.nc`
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_mxl.bash $@ (see SLURM/${RUNID}/mk_mxl_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# generate tmask of southern ocean weddelll
TMASK=${DATPATH}/${RUNID}/tmask_WG.nc
if [ ! -f $TMASK ] ; then
   python ${SCRPATH}/tmask_zoom.py -W -31.250 -E 37.500 -S -66.500 -N -60.400 -j 3 -i -63.5 -m ${DATPATH}/${RUNID}/mesh.nc -o $TMASK
   if [[ $? -ne 0 ]]; then exit 42; fi 
fi

# make mxl
FILEOUT=WMXL_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v somxzint1 -c longitude latitude -A max -o $FILEOUT -m $TMASK

