#!/bin/bash
#SBATCH --mem=30G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_aabw.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi 

RUNID=$1
TAG=$2
FREQ=$3

MIN_DEPTH=500
MAX_DEPTH=1500
DENSITY_THRESHOLD=45.8 

RUN_NAME=${RUNID#*-}
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_aabw
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_aabw.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_aabw_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
MESHF="${DATPATH}/${RUNID}/mesh.nc"
TIME_VAR='time_counter'
SALVAR='so_pra'
TEMPVAR='thetao_pot'
VARTYPE='density'
echo 'mk_aabw.bash: Calculate Model Antarctic bottom Water metrics.'

### Weddell sea ###
LONMIN=-65.500
LONMAX=-20.000
LATMIN=-90.000
LATMAX=-24.000
python ${SCRPATH}/cal_deep_tracers_metrics.py -lonmin $LONMIN -lonmax $LONMAX -latmin $LATMIN -latmax $LATMAX \
    -mindepth $MIN_DEPTH -maxdepth $MAX_DEPTH -datadir $DATPATH/$RUNID -datf $FILET -meshf $MESHF \
    -outf ${FILEOUT}_weddell -marvaldir $MARINE_VAL -vartype $VARTYPE -timevar $TIME_VAR -salvar $SALVAR \
    -tempvar $TEMPVAR -freq $FREQ -densthresh $DENSITY_THRESHOLD
if [[ $? -ne 0 ]]; then exit 42; fi 

### Southern ocean ###
LONMIN=-180
LONMAX=180
LATMIN=-90.000
LATMAX=-24.000
python ${SCRPATH}/cal_deep_tracers_metrics.py -lonmin $LONMIN -lonmax $LONMAX -latmin $LATMIN -latmax $LATMAX \
    -mindepth $MIN_DEPTH -maxdepth $MAX_DEPTH -datadir $DATPATH/$RUNID -datf $FILET -meshf $MESHF \
    -outf ${FILEOUT}_so -marvaldir $MARINE_VAL -vartype $VARTYPE -timevar $TIME_VAR -salvar $SALVAR \
    -tempvar $TEMPVAR -freq $FREQ -densthresh $DENSITY_THRESHOLD
if [[ $? -ne 0 ]]; then exit 42; fi 
