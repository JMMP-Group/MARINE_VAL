#!/bin/bash
#SBATCH --mem=30G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_aabw.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi 

RUNID=$1
TAG=$2
FREQ=$3

RUN_NAME=${RUNID#*-}
PROC='runAABW'
GENERATED_TMASKS=($(jq -r ".${PROC}[]" "${SCRPATH}/tmasks_generated.json"))
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_aabw.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_aabw_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

TIME_VAR='time_counter'
SALVAR='so_pra'
TEMPVAR='thetao_pot'
DENSITY_THRESHOLD=45.88

### Weddell sea ###
echo 'mk_aabw.bash: Calculate Model Antarctic bottom Water metrics - Weddell sea.'
# Spatial filtering parameters
PATTERN="WEDATL"
for GEN_TMASK in "${GENERATED_TMASKS[@]}"; do
   if [[ "$GEN_TMASK" == *"$PATTERN"* && "$GEN_TMASK" != *obs* ]]; then
      PARAMS=$(jq -c --arg tmask "$GEN_TMASK" '.[$tmask]' ${SCRPATH}/tmasks_all_params.json)
      TMASK=$(echo "$PARAMS" | jq -r '.o')
      MESHF=$(echo "$PARAMS" | jq -r '.m')

      echo "Unpacking $GEN_TMASK parameters"
      echo -e "TMASK=$TMASK \nMESHF=$MESHF"
   fi
done

FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_${PATTERN}

python ${SCRPATH}/cal_deep_tracers_metrics.py -datadir $DATPATH/$RUNID -datf $FILET -meshf $MESHF \
    -outf ${FILEOUT}_weddell -marvaldir $MARINE_VAL -timevar $TIME_VAR -salvar $SALVAR \
    -tempvar $TEMPVAR -freq $FREQ -densthresh $DENSITY_THRESHOLD -t $TMASK -obsout AABW_$PATTERN -obsref "Dummy $PATTERN obs"
if [[ $? -ne 0 ]]; then exit 42; fi 

### Southern ocean ###
echo 'mk_aabw.bash: Calculate Model Antarctic bottom Water metrics - Southern ocean.'
# Spatial filtering parameters
PATTERN="SOUTHERN_OCEAN"
for GEN_TMASK in "${GENERATED_TMASKS[@]}"; do
   if [[ "$GEN_TMASK" == *"$PATTERN"* && "$GEN_TMASK" != *obs* ]]; then
      PARAMS=$(jq -c --arg tmask "$GEN_TMASK" '.[$tmask]' ${SCRPATH}/tmasks_all_params.json)
      TMASK=$(echo "$PARAMS" | jq -r '.o')
      MESHF=$(echo "$PARAMS" | jq -r '.m')

      echo "Unpacking $GEN_TMASK parameters"
      echo -e "TMASK=$TMASK \nMESHF=$MESHF"
   fi
done

FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_${PATTERN}

python ${SCRPATH}/cal_deep_tracers_metrics.py -datadir $DATPATH/$RUNID -datf $FILET -meshf $MESHF \
    -outf ${FILEOUT}_so -marvaldir $MARINE_VAL -timevar $TIME_VAR -salvar $SALVAR \
    -tempvar $TEMPVAR -freq $FREQ -densthresh $DENSITY_THRESHOLD -t $TMASK -obsout AABW_$PATTERN -obsref "Dummy $PATTERN obs"
if [[ $? -ne 0 ]]; then exit 42; fi 
