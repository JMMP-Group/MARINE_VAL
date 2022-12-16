#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 4 ]]; then echo 'mk_sst.bash [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

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
FILE=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]${GRID}.nc`
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_sst.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_sst_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make sst
set -x
FILEOUT=SO_sst_nemo_${RUN_NAME}o_${FREQ}_${TAG}*_grid-${GRID}.nc
jlimits=$($CDFPATH/cdffindij -w 0.0 1.0 -60.000  -40.000 -c mesh.nc -p T | tail -2 | head -1 | tr -s ' ' | cut -d' ' -f4-5)
echo "jlimits : $jlimits"
$CDFPATH/cdfmean -f $FILE -v '|thetao|thetao_con|votemper|' -surf -w 0 0 ${jlimits} 1 1 -p T -minmax -o tmp_$FILEOUT 

# mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfmean; exit"; echo "E R R O R in : ./mk_sst.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_sst_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

FILEOUT=NWC_sst_nemo_${RUN_NAME}o_${FREQ}_${TAG}*_grid-${GRID}.nc
ijbox=$($CDFPATH/cdffindij -w -50.190 -32.873 41.846 54.413 -c mesh.nc -p T | tail -2 | head -1 )
echo "ijbox : $ijbox"
$CDFPATH/cdfmean -f $FILE -surf -v '|thetao|thetao_con|votemper|' -w ${ijbox} 1 1 -p T -minmax -o tmp_$FILEOUT 

#mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfmean; exit"; echo "E R R O R in : ./mk_sst.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_sst_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi
