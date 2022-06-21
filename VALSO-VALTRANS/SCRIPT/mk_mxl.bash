#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 4 ]]; then echo 'mk_mxl.bash [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

CONFIG=$1
RUNID=$2
TAG=$3
FREQ=$4
GRID='T'

# load path and mask
. param.bash
. ${SCRPATH}/common.bash

cd $DATPATH/

# name
RUN_NAME=${RUNID#*-}

# download data if needed
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-${GRID}

# check presence of input file
FILE=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]${GRID}.nc`
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_mxl.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_mxl_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make mxl
FILEOUT=WMXL_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -31.250   37.500  -66.500  -60.400 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILE -v '|somxzint1|sokaraml|' -p T -w ${ijbox} 0 0 -minmax -o tmp_$FILEOUT

# mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfmxl; exit"; echo "E R R O R in : ./mk_mxl.bash $@ (see SLURM/${CONFIG}/${RUNID}/mxl_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi
#
