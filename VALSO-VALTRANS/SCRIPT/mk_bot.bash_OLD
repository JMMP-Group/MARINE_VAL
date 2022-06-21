#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 4 ]]; then echo 'mk_bot.bash [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

CONFIG=$1
RUNID=$2
TAG=$3
FREQ=$4

GRID=T

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
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_bot.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_bot_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make bot
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_bottom-${GRID}.nc
$CDFPATH/cdfbottom -f $FILE -nc4 -o tmp_$FILEOUT

# mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfbottom; exit"; echo "E R R O R in : ./mk_bot.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_bot_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ;
   exit 1
fi

# Amundsen avg (CDW)
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -109.640 -102.230  -75.800  -71.660 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILEOUT -v '|thetao|votemper|' -p T -var -w ${ijbox} 0 0 -minmax -o AMU_thetao_$FILEOUT 
if [ $? -ne 0 ] ; then echo "error when running cdfmean (AMU)"; echo "E R R O R in : ./mk_bot.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_bot_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi

# WRoss avg (bottom water)
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w 157.100  173.333  -78.130  -74.040 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILEOUT -v '|so|vosaline|'     -p T -var -w ${ijbox} 0 0 -minmax -o WROSS_so_$FILEOUT 
if [ $? -ne 0 ] ; then echo "error when running cdfmean (WROS)"; echo "E R R O R in : ./mk_bot.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_bot_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi

# ERoss avg (CDW)
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -176.790 -157.820  -78.870  -77.520 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILEOUT -v '|thetao|votemper|' -p T -var -w ${ijbox} 0 0 -minmax -o EROSS_thetao_$FILEOUT 
if [ $? -ne 0 ] ; then echo "error when running cdfmean (EROSS)"; echo "E R R O R in : ./mk_bot.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_bot_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi

# Weddell Avg (bottom water)
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -65.130  -53.020  -75.950  -72.340 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILEOUT -v '|so|vosaline|'     -p T -var -w ${ijbox} 0 0 -minmax -o WED_so_$FILEOUT 
if [ $? -ne 0 ] ; then echo "error when running cdfmean (WWED)"; echo "E R R O R in : ./mk_bot.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_bot_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi
