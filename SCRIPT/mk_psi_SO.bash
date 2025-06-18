#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_psi.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
FILEU=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make psi
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_psi_SO.nc
$CDFPATH/cdfpsi -u $FILEU -v $FILEV -vvl -nc4 -ref 1 1 -o tmp_$FILEOUT

# mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfpsi; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

# Update the meta data in the psi file so that Iris can read it:
ncatted -a coordinates,sobarstf,c,c,"time_centered nav_lat nav_lon" $FILEOUT

# generate tmask of WG
TMASK1=${DATPATH}/${RUNID}/tmask_WG.nc
if [ ! -f $TMASK1 ] ; then
   python ${SCRPATH}/tmask_zoom.py -W -31.250 -E 37.500 -S -66.500 -N -60.400 -j 3 -i -63.5 -m ${DATPATH}/${RUNID}/mesh.nc -o $TMASK1
   if [[ $? -ne 0 ]]; then exit 42; fi 
fi

# generate tmask of RG
TMASK2=${DATPATH}/${RUNID}/tmask_RG.nc
if [ ! -f $TMASK2 ] ; then
   python ${SCRPATH}/tmask_zoom.py -W -168.500 -E -135.750 -S -72.650 -N -61.600 -j -152 -i -67 -m ${DATPATH}/${RUNID}/mesh.nc -o $TMASK2
   if [[ $? -ne 0 ]]; then exit 42; fi 
fi

# WG max
$SCRPATH/reduce_fields.py -i $FILEOUT -v sobarstf -c longitude latitude -A max -o WG_$FILEOUT -m $TMASK1

# RG max
$SCRPATH/reduce_fields.py -i $FILEOUT -v sobarstf -c longitude latitude -A max -o RG_$FILEOUT -m $TMASK2

