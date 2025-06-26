#!/bin/bash
#SBATCH --mem=20G
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

if [[ $# -ne 3 ]]; then echo 'mk_deepTS.bash -A [list of areas] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3

GRID=T

# name
RUN_NAME=${RUNID#*-}

# download data if needed
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-${GRID}

# check presence of input file
FILE=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]${GRID}.nc`
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_deepTS.bash $@ (see SLURM/${RUNID}/mk_deepTS_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# mean over relevant boxes
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_deepTS.nc

for area in $areas
do

if [[ "$area" == "AMU" ]]
then

echo mk_deepTS.bash: calculating AMU thetao
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A mean -G self measures -g cell_thickness cell_area \
	       -o AMU_thetao_$FILEOUT -m ${DATPATH}/${RUNID}/tmask_AMU_mindepth-390.nc
    
elif [[ "$area" == "WROSS" ]]
then

echo mk_deepTS.bash: calculating WROSS so_pra
$SCRPATH/reduce_fields.py -i $FILE -v so_pra -c longitude latitude depth -A mean -G self measures -g cell_thickness cell_area \
	      -o WROSS_so_$FILEOUT -m ${DATPATH}/${RUNID}/tmask_WROSS_mindepth-390.nc

elif [[ "$area" == "EROSS" ]]
then

echo mk_deepTS.bash: calculating EROSS thetao
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A mean -G self measures -g cell_thickness cell_area \
	       -o EROSS_thetao_$FILEOUT -m ${DATPATH}/${RUNID}/tmask_EROSS_mindepth-390.nc 

elif [[ "$area" == "WWED" ]]
then

echo mk_deepTS.bash: calculating WED so_pra 
$SCRPATH/reduce_fields.py -i $FILE -v so_pra -c longitude latitude depth -A mean -G self measures -g cell_thickness cell_area \
	      -o WED_so_$FILEOUT -m ${DATPATH}/${RUNID}/tmask_WWED_mindepth-390.nc

fi
done

