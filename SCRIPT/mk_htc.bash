#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_htc.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi 

RUNID=$1
TAG=$2
FREQ=$3

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_htc.bash $@ (see ${JOBOUT_PATH}/mk_htc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# calculate heat content of NA subpolar gyre in Joules --> area of heat content for each layer
FILEOUT=HEATC_NA_${RUN_NAME}o_${FREQ}_${TAG}_heatc.nc
ijbox=$($CDFPATH/cdffindij -w -60.000 -20.000 48.000 72.000 -c mesh.nc -p T | tail -2 | head -1 )
echo "ijbox : $ijbox"

# calculate volume of NA subpolar gyre in m3
if [ ! -f ${DATPATH}/${RUNID}/masked_tmask_NA_gyre.nc ] ; then
   python ${SCRPATH}/tmask_zoom.py -w -60.000 -20.000 48.000 72.000 -depth ${DEPTH} -dir ${DATPATH} -runid ${RUNID} -c mesh.nc 
   if [[ $? -ne 0 ]]; then exit 42; fi 
fi

# assumes 75 levels in ocean:
$CDFPATH/cdfheatc -f $FILET -zoom ${ijbox} 1 75 -M ${DATPATH}/${RUNID}/masked_tmask_NA_gyre.nc tmask -o tmp_$FILEOUT #

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
