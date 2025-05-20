#!/bin/bash
#SBATCH --mem=30G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_medovf.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi 

# . ./param.bash # dev mode

RUNID=$1
TAG=$2
FREQ=$3
MIN_DEPTH=500
MAX_DEPTH=1500
LONMIN=-16.000
LONMAX=-5.500
LATMIN=31.500
LATMAX=39.500

RUN_NAME=${RUNID#*-}

### Obs ###
FILEOUT=medovf
if [ ! -f "${MARINE_VAL}/OBS/${FILEOUT}_salinity.txt" ]; then
FILET="/data/users/nemo/obs_data/NOAA_WOA13v2/1955-2012/025/woa13v2.omip-clim.abs_sal.nc"
MESHF="/data/users/nemo/obs_data/NOAA_WOA13v2/1955-2012/025/mesh_mask_woa13v2.nc"
TIME_VAR='time'
SALVAR='so_abs'
VARTYPE='salinity'
DEPTH_VAR='depth'
echo 'mk_medovf.bash: Plot Obs Med Overflow salinity metrics.'
python ${SCRPATH}/cal_density_metrics.py -obs -lonmin $LONMIN -lonmax $LONMAX -latmin $LATMIN -latmax $LATMAX \
    -mindepth $MIN_DEPTH -maxdepth $MAX_DEPTH -datadir $DATPATH/$RUNID -datf $FILET -meshf $MESHF \
    -outf $FILEOUT -marvaldir $MARINE_VAL -timevar $TIME_VAR -salvar $SALVAR -vartype $VARTYPE \
    -depthvar $DEPTH_VAR -freq $FREQ
if [[ $? -ne 0 ]]; then exit 42; fi 
fi

### Model ###
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_medovf
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
# FILET=$DATPATH/u-dl879/nemo_dl879o_1y_19911201-19921201_grid-T.nc # dev mode
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_medovf.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_sal_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
MESHF="${DATPATH}/${RUNID}/mesh.nc"
TIME_VAR='time_counter'
SALVAR='so_pra'
VARTYPE='salinity'
DEPTH_VAR='deptht'
echo 'mk_medovf.bash: Plot Model Med Overflow salinity metrics.'
python ${SCRPATH}/cal_density_metrics.py -lonmin $LONMIN -lonmax $LONMAX -latmin $LATMIN -latmax $LATMAX \
    -mindepth $MIN_DEPTH -maxdepth $MAX_DEPTH -datadir $DATPATH/$RUNID -datf $FILET -meshf $MESHF \
    -outf $FILEOUT -marvaldir $MARINE_VAL -timevar $TIME_VAR -salvar $SALVAR -vartype $VARTYPE \
    -depthvar $DEPTH_VAR -freq $FREQ
if [[ $? -ne 0 ]]; then exit 42; fi 

