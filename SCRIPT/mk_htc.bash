#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_htc.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi 

RUNID=$1
TAG=$2
FREQ=$3

# Spatial filtering parameters
MIN_LON=-60.000
MAX_LON=-20.000
MIN_LAT=48.000
MAX_LAT=72.000
MIN_DEP=1000
TAR_LON=-40
TAR_LAT=50

### Obs ###
# We compute this everytime, to allow the possibility 
# of changing the parameters for the spatial filtering
# while having always consistent observational values

echo 'mk_htc.bash: Calculate Obs Heat content SPG NA metrics.'

OBSPATH="/data/users/nemo/obs_data/NOAA_WOA13v2/1955-2012/025/orca025"
FILET="${OBSPATH}/woa13v2.omip-clim.con_tem_gosi10p1-025_flooded.nc"
MESHF="${OBSPATH}/mesh_mask_eORCA025_v3.2_r42.nc"
TMASK="${DATPATH}/${RUNID}/tmask_NA_gyre_mindepth-1000.nc"
OMSKS="${DATPATH}/${RUNID}/tmask_NA_gyre_obs-woa13v2_mindepth-1000.nc"

# calculate heat content of NA subpolar gyre --> area of heat content for each layer
FILEOUT=HEATC_NA_WOA13v2_heatc.nc
ijbox=$($CDFPATH/cdffindij -w ${MIN_LON} ${MAX_LON} ${MIN_LAT} ${MAX_LAT} -c $MESHF -p T | tail -2 | head -1 )
echo "ijbox : $ijbox"
# assumes 75 levels in ocean:
$CDFPATH/cdfheatc -f $FILET -zoom ${ijbox} 1 75 -M ${OMSKS} tmask -o $FILEOUT

# compute
# 1) the mean
ncwa -O -v heatc3d -a time_counter ${FILEOUT} mean_${FILEOUT}
mean_obs=`ncdump -v heatc3d mean_${FILEOUT} | sed -e "1,/data:/d" -e '$d' -e "s/heatc3d =//g" -e "s/;//g"`
mean_obs="${mean_obs//$'\n'/}"
# 2) the deviations with respect to the mean
ncbo -O -v heatc3d ${FILEOUT} mean_${FILEOUT} dev_${FILEOUT}
# 3) the sum of the square of the deviations, then divide by (N-1) and take the square root
ncra -O -y rmssdn dev_${FILEOUT} std_dev_${FILEOUT}
std_obs=`ncdump -v heatc3d std_dev_${FILEOUT} | sed -e "1,/data:/d" -e '$d' -e "s/heatc3d =//g" -e "s/;//g"`
std_obs="${std_obs//$'\n'/}"

cat > "${MARINE_VAL}/OBS/HTC_subp_obs.txt" << EOF
ref = WOA13v2
mean = ${mean_obs}
std = ${std_obs}
EOF


### Models ### 
RUN_NAME=${RUNID#*-}

# check presence of input file
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_htc.bash $@ (see ${JOBOUT_PATH}/mk_htc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# Calculate heat content of NA subpolar gyre in Joules --> area of heat content for each layer
FILEOUT=HEATC_NA_${RUN_NAME}o_${FREQ}_${TAG}_heatc.nc

ijbox=$($CDFPATH/cdffindij -w ${MIN_LON} ${MAX_LON} ${MIN_LAT} ${MAX_LAT} -c mesh.nc -p T | tail -2 | head -1 )
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
