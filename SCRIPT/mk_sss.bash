#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_sss.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3
GRID='T'

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
echo $RUNID
echo $TAG
if [[ ${RUNID} = u-ah494 ]]; then
  FILE=`ls ${RUNID}o_${FREQ}_${TAG}*T.nc`
else
  FILE=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid-T.nc`
fi

echo $FILE
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_sss.bash $@ (see ${JOBOUT_PATH}/mk_sst_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

## calculate sss in Labrador Sea (same region as MXL)
set -x
FILEOUT=SSSav_LabSea_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
ijbox=$($CDFPATH/cdffindij -w -60.000 -50.000  55.000  62.000 -c mesh.nc -p T | tail -2 | head -1 )
echo "ijbox : $ijbox"
$CDFPATH/cdfmean -f $FILE -surf -v '|so|so_pra|vosaline|' -w ${ijbox} 1 1 -p T -minmax -o tmp_$FILEOUT


#mv output file
if [[ $? -eq 0 ]]; then
   mv tmp_$FILEOUT $FILEOUT
else
   echo "error when running cdfmean; exit"; echo "E R R O R in : ./mk_sst.bash $@ (see ${JOBOUT_PATH}/mk_sst_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi




