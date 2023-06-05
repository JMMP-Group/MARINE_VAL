#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1
#
# This version calculates the mean T/S over a deep box, rather than the mean
# of the bottom field over a particular area, to be more comparable to the
# obs that I'm using (EN4 profiles meaned over a 3D box). 
#
# NB. For the WWED and EROSS areas there are only summertime observation data
#     available so we use summertime mean model data to compare with if we are
#     using FREQ=1y. In that case "FREQ" passed to this routine is set to "1s"
#     so that it picks up the right files. 
#
# DS. May 2023
#

while getopts A: opt 
   do
   case $opt in
      A) areas=$OPTARG 
      ;;
   esac
done
shift `expr $OPTIND - 1`

if [[ -z "$areas" ]]; then areas="AMU WROSS EROSS WWED"; fi
print "mk_deepTS.bash: processing areas $areas" 

if [[ $# -ne 4 ]]; then echo 'mk_deepTS.bash -A [list of areas] [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

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
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_deepTS.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_deepTS_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# mean over relevant boxes
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_deepTS.nc

for area in $areas
do

if [[ "$area" == "AMU" ]]
then
# Amundsen avg (CDW)
# k = [38,75] => everything deeper than 390m
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -109.640 -102.230  -75.800  -71.660 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILE -v '|thetao|thetao_con|votemper|' -p T -var -w ${ijbox} 38 75 -minmax -o AMU_thetao_$FILEOUT 
if [ $? -ne 0 ] ; then echo "error when running cdfmean (AMU)"; echo "E R R O R in : ./mk_deepTS.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_deepTS_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi

elif [[ "$area" == "WROSS" ]]
then
# WRoss avg (bottom water)
# k = [38,75] => everything deeper than 390m
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w 157.100  173.333  -78.130  -74.040 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILE -v '|so|so_abs|vosaline|'     -p T -var -w ${ijbox} 38 75 -minmax -o WROSS_so_$FILEOUT 
if [ $? -ne 0 ] ; then echo "error when running cdfmean (WROSS)"; echo "E R R O R in : ./mk_deepTS.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_deepTS_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi

elif [[ "$area" == "EROSS" ]]
then
# ERoss avg (CDW)
# k = [38,75] => everything deeper than 390m
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -176.790 -157.820  -78.870  -77.520 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILE -v '|thetao|thetao_con|votemper|' -p T -var -w ${ijbox} 38 75 -minmax -o EROSS_thetao_$FILEOUT 
if [ $? -ne 0 ] ; then echo "error when running cdfmean (EROSS)"; echo "E R R O R in : ./mk_deepTS.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_deepTS_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi

elif [[ "$area" == "WWED" ]]
then
# Weddell Avg (bottom water)
# k = [38,75] => everything deeper than 390m
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -65.130  -53.020  -75.950  -72.340 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILE -v '|so|so_abs|vosaline|'     -p T -var -w ${ijbox} 38 75 -minmax -o WED_so_$FILEOUT 
if [ $? -ne 0 ] ; then echo "error when running cdfmean (WWED)"; echo "E R R O R in : ./mk_deepTS.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_deepTS_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi

fi
done

