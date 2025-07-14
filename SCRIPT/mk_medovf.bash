#!/bin/bash
#SBATCH --mem=30G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_medovf.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi 

RUNID=$1
TAG=$2
FREQ=$3

RUN_NAME=${RUNID#*-}
PROC='runMedOVF'
OBS_DONE_FLAG="${SCRPATH}/.obs_done_MEDOVF"
GENERATED_TMASKS=($(jq -r ".${PROC}[]" "${SCRPATH}/tmasks_generated.json"))

# Only run obs section if not already completed once
if [[ ! -f $OBS_DONE_FLAG ]]; then
   touch $OBS_DONE_FLAG

   # Spatial filtering parameters
   PATTERN="MEDOVF_obs-woa13v2"
   for GEN_TMASK in "${GENERATED_TMASKS[@]}"; do
      if [[ "$GEN_TMASK" == *"$PATTERN"* ]]; then
         PARAMS=$(jq -c --arg tmask "$GEN_TMASK" '.[$tmask]' ${SCRPATH}/tmasks_all_params.json)
         TMASK=$(echo "$PARAMS" | jq -r '.o')
         MESHF=$(echo "$PARAMS" | jq -r '.m')

         echo "Unpacking $GEN_TMASK parameters"
         echo -e "TMASK=$TMASK \nMESHF=$MESHF"
      fi
   done

    ### Obs ###
    FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_${PATTERN}
    FILET="/data/users/nemo/obs_data/NOAA_WOA13v2/1955-2012/025/orca025/woa13v2.omip-clim.abs_sal_gosi10p1-025_flooded.nc" 
    echo 'mk_medovf.bash: Calculate Obs Med Overflow salinity metrics.'
    python ${SCRPATH}/cal_deep_tracers_metrics.py -obs -datadir $DATPATH/$RUNID -datf $FILET -meshf $MESHF \
        -outf $FILEOUT -marvaldir $MARINE_VAL -timevar time_counter -salvar so_abs \
        -freq $FREQ -t $TMASK -obsout MEDOVF -obsref "NOAA_WOA13v2: 1955-2012"
    if [[ $? -ne 0 ]]; then exit 42; fi

fi

# Spatial filtering parameters
PATTERN="MEDOVF"
for GEN_TMASK in "${GENERATED_TMASKS[@]}"; do
   if [[ "$GEN_TMASK" == *"$PATTERN"* && "$GEN_TMASK" != *obs* ]]; then
      PARAMS=$(jq -c --arg tmask "$GEN_TMASK" '.[$tmask]' ${SCRPATH}/tmasks_all_params.json)
      TMASK=$(echo "$PARAMS" | jq -r '.o')
      MESHF=$(echo "$PARAMS" | jq -r '.m')

      echo "Unpacking $GEN_TMASK parameters"
      echo -e "TMASK=$TMASK \nMESHF=$MESHF"
   fi
done

### Model ###
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_${PATTERN}
FILET=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_medovf.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_medovf_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
echo 'mk_medovf.bash: Calculate Model Med Overflow salinity metrics.'
python ${SCRPATH}/cal_deep_tracers_metrics.py -datadir $DATPATH/$RUNID -datf $FILET -meshf $MESHF \
    -outf $FILEOUT -marvaldir $MARINE_VAL -timevar time_counter -salvar so_pra \
    -freq $FREQ -t $TMASK
if [[ $? -ne 0 ]]; then exit 42; fi 

