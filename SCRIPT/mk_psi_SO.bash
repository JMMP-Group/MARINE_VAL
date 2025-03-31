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

# WG max
$SCRPATH/reduce_fields.py -i $FILEOUT -v sobarstf -c longitude latitude -A max -W-31.250 -E37.500 -S-66.500 -N-60.400 -o WG_$FILEOUT 

# RG max
$SCRPATH/reduce_fields.py -i $FILEOUT -v sobarstf -c longitude latitude -A max -W-168.500 -E-135.750 -S-72.650 -N-61.600 -o RG_$FILEOUT 

