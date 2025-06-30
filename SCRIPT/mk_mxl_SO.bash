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
PROC='runMLD_Weddell'
GENERATED_TMASKS=($(jq -r ".${PROC}[]" "${SCRPATH}/tmasks_generated.json"))

# name
RUN_NAME=${RUNID#*-}

# download data if needed
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-${GRID}

# check presence of input file
FILE=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]${GRID}.nc`
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_mxl.bash $@ (see SLURM/${RUNID}/mk_mxl_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# Extract tmask filename
PATTERN="WG"
for GEN_TMASK in "${GENERATED_TMASKS[@]}"; do
   if [[ "$GEN_TMASK" == *"$PATTERN"* ]]; then
      PARAMS=$(jq -c --arg tmask "$GEN_TMASK" '.[$tmask]' ${SCRPATH}/tmasks_all_params.json)
      TMASK=$(echo "$PARAMS" | jq -r '.o')
   fi
done
echo TMASK: $TMASK

# make mxl
FILEOUT=WMXL_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v somxzint1 -c longitude latitude -A max -o $FILEOUT -m $TMASK

