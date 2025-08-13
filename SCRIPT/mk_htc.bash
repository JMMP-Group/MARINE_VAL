#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_htc.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi 

RUNID=$1
TAG=$2
FREQ=$3

PROC='runHTC' 
OBS_DONE_FLAG="${SCRPATH}/.obs_done_HTC"
GENERATED_TMASKS=($(jq -r ".${PROC}[]" "${SCRPATH}/tmasks_generated.json"))

# Only run obs section if runOBS is set
if [[ "$runOBS" != "1" ]]; then touch $OBS_DONE_FLAG; fi

# Only run obs section if not already completed once
if [[ ! -f $OBS_DONE_FLAG ]]; then
   touch $OBS_DONE_FLAG

   # Spatial filtering parameters
   PATTERN="NA_GYRE_obs-woa13v2"
   for GEN_TMASK in "${GENERATED_TMASKS[@]}"; do
      if [[ "$GEN_TMASK" == *"$PATTERN"* ]]; then
         PARAMS=$(jq -c --arg tmask "$GEN_TMASK" '.[$tmask]' ${SCRPATH}/tmasks_all_params.json)
         MIN_LON=$(echo "$PARAMS" | jq -r '.W')
         MAX_LON=$(echo "$PARAMS" | jq -r '.E')
         MIN_LAT=$(echo "$PARAMS" | jq -r '.S')
         MAX_LAT=$(echo "$PARAMS" | jq -r '.N')
         TAR_LON=$(echo "$PARAMS" | jq -r '.tlon')
         TAR_LAT=$(echo "$PARAMS" | jq -r '.tlat')
         TMASK=$(echo "$PARAMS" | jq -r '.o')
         MESHF=$(echo "$PARAMS" | jq -r '.m')
         MIN_DEP=$(echo "$PARAMS" | jq -r '.mindepth // empty')
         MAX_DEP=$(echo "$PARAMS" | jq -r '.maxdepth // empty')

         echo "Unpacking $GEN_TMASK parameters"
         echo -e "MIN_LON=$MIN_LON \nMAX_LON=$MAX_LON \nMIN_LAT=$MIN_LAT \nMAX_LAT=$MAX_LAT \nTAR_LON=$TAR_LON \nTAR_LAT=$TAR_LAT \nMIN_DEP=$MIN_DEP \nMAX_DEP=$MAX_DEP \nTMASK=$TMASK \nMESHF=$MESHF"
      fi
   done

   ### Obs ###
   # We compute this everytime, to allow the possibility 
   # of changing the parameters for the spatial filtering
   # while having always consistent observational values

   echo 'mk_htc.bash: Calculate Obs Heat content SPG NA metrics.'

   # calculate heat content of NA subpolar gyre --> area of heat content for each layer
   FILEOUT=HEATC_NA_WOA13v2_heatc.nc
   ijbox=$($CDFPATH/cdffindij -w ${MIN_LON} ${MAX_LON} ${MIN_LAT} ${MAX_LAT} -c $MESHF -p T | tail -2 | head -1 )
   echo "ijbox : $ijbox"
   # assumes 75 levels in ocean:
   $CDFPATH/cdfheatc -f $OBS_CON_TEM -zoom ${ijbox} 1 75 -M ${TMASK} tmask -o $FILEOUT
   # compute subp_obs
   ${SCRPATH}/mk_compute_obs_stats.bash heatc3d time_counter $FILEOUT WOA13v2 HTC_subp_obs.txt
fi

### Models ### 
RUN_NAME=${RUNID#*-}

# Spatial filtering parameters
PATTERN="NA_GYRE"
for GEN_TMASK in "${GENERATED_TMASKS[@]}"; do
   if [[ "$GEN_TMASK" == *"$PATTERN"* && "$GEN_TMASK" != *obs* ]]; then
      PARAMS=$(jq -c --arg tmask "$GEN_TMASK" '.[$tmask]' ${SCRPATH}/tmasks_all_params.json)
      MIN_LON=$(echo "$PARAMS" | jq -r '.W')
      MAX_LON=$(echo "$PARAMS" | jq -r '.E')
      MIN_LAT=$(echo "$PARAMS" | jq -r '.S')
      MAX_LAT=$(echo "$PARAMS" | jq -r '.N')
      TAR_LON=$(echo "$PARAMS" | jq -r '.tlon')
      TAR_LAT=$(echo "$PARAMS" | jq -r '.tlat')
      TMASK=$(echo "$PARAMS" | jq -r '.o')
      MESHF=$(echo "$PARAMS" | jq -r '.m')
      MIN_DEP=$(echo "$PARAMS" | jq -r '.mindepth // empty')
      MAX_DEP=$(echo "$PARAMS" | jq -r '.maxdepth // empty')

      echo "Unpacking $GEN_TMASK parameters"
      echo -e "MIN_LON=$MIN_LON \nMAX_LON=$MAX_LON \nMIN_LAT=$MIN_LAT \nMAX_LAT=$MAX_LAT \nTAR_LON=$TAR_LON \nTAR_LAT=$TAR_LAT \nMIN_DEP=$MIN_DEP \nMAX_DEP=$MAX_DEP \nTMASK=$TMASK \nMESHF=$MESHF"
   fi
done

# check presence of input file
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_htc.bash $@ (see ${JOBOUT_PATH}/mk_htc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# Calculate heat content of NA subpolar gyre in Joules --> area of heat content for each layer
FILEOUT=HEATC_NA_${RUN_NAME}o_${FREQ}_${TAG}_heatc.nc

ijbox=$($CDFPATH/cdffindij -w ${MIN_LON} ${MAX_LON} ${MIN_LAT} ${MAX_LAT} -c ${MESHF} -p T | tail -2 | head -1 )
echo "ijbox : $ijbox"

# assumes 75 levels in ocean:
$CDFPATH/cdfheatc -f $FILET -zoom ${ijbox} 1 75 -M $TMASK tmask -o tmp_$FILEOUT #

#Computes the heat content in the specified area (Joules). Using all depth.
#cdfheatc  -f T-file [-mxloption option] [-mxlf MXL-file] ...'
#             [-zoom imin imax jmin jmax kmin kmax] [-full] [-o OUT-file]'
#             [-M MSK-file VAR-mask ] [-vvl ]

#outputs: heatc3d (Joules)

# mv output file
#if the previous command =! 0, save it otherwise return an error
if [[ $? -eq 0 ]]; then
   mv tmp_$FILEOUT $FILEOUT
else
   echo "error when running cdfheatc; exit"; echo "E R R O R in : ./mk_htc.bash $@ (see ${JOBOUT_PATH}/mk_htc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi 

#needed due to problem reading masked heatc3d variable:
ncatted -a valid_min,heatc3d,d,, -a valid_max,heatc3d,d,, $FILEOUT
