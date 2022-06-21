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

# name
RUN_NAME=${RUNID#*-}

# download data if needed
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-V

# check presence of input file
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_mht.bash $@ (see SLURM/${CONFIG}/${RUNID}/mht_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make mht
set -x
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_mht.nc
$CDFPATH/cdfmhst -vt $FILEV -vvl -o tmp_$FILEOUT

# mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfmht; exit"; echo "E R R O R in : ./mk_mht.bash $@ (see SLURM/${CONFIG}/${RUNID}/mht_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

# extract only 26.5
case $CONFIG in
  eORCA1)
    jj=227
    ;;
  eORCA025)
    jj=793
    ;;
  eORCA12)
    jj=2364
    ;;
  *)
    echo "Unrecognised configuration."
    echo "error when running cdfmht; exit"; echo "E R R O R in : ./mk_mht.bash $@ (see SLURM/${CONFIG}/${RUNID}/mht_${TAG}.out)" >> ${EXEPATH}/ERROR.txt; exit 1
    ;;
esac
ncks -O -d y,$jj,$jj $FILEOUT nemo_${RUN_NAME}o_${FREQ}_${TAG}_mht_265.nc
