#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_hfds.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

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
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_hfds.bash $@ (see SLURM/${RUNID}/hfds_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make global heat flux
# The main diagnostic here is the "hfds" field from NEMO but this omits one or two contributions,
# notably the heat input from river runoff. This field is not usually included in older integrations,
# so the approach here is to integrate the hfds field, and integrate the other terms separately if
# they are available. The terms can easily be added as a postprocessing step. Doing things this way
# ensures transparency - you always know what you've got. 
FILEOUT=GLO_hfds_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
varlist="hfds"
if [[ "$(ncdump -h $FILE | grep 'float.*hflx_icb_cea' | wc -l)" != "0" ]];then
    varlist="$varlist hflx_icb_cea"
fi
$SCRPATH/reduce_fields.py -i $FILE -v $varlist -c longitude latitude -A mean -G mesh.nc mesh.nc -g e1t e2t -m tmask_GLOBAL.nc -S -o $FILEOUT 
    
#
