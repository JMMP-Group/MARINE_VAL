#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 4 ]]; then echo 'mk_psi.bash [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

CONFIG=$1
RUNID=$2
TAG=$3
FREQ=$4

# load path and mask
. param.bash
. ${SCRPATH}/common.bash

cd $DATPATH/

# name
RUN_NAME=${RUNID#*-}

# download data if needed
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-V
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-U

# check presence of input file
FILEU=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make psi
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_psi.nc
$CDFPATH/cdfpsi -u $FILEU -v $FILEV -vvl -nc4 -ref 1 1 -o tmp_$FILEOUT

# mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfpsi; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

# WG max
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -31.250 37.500 -66.500 -60.400 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILEOUT -v sobarstf -p T -w ${ijbox} 0 0 -minmax -o WG_$FILEOUT
if [ $? -ne 0 ] ; then echo "error when running cdfmean (WG)"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi
# this step needed because cdfmean sets a strange value for valid max and that messes up the plotting routines.
ncatted -a valid_min,max_sobarstf,d,, -a valid_max,max_sobarstf,d,, WG_$FILEOUT

# RG max
ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -168.500 -135.750 -72.650 -61.600 | tail -2 | head -1)
$CDFPATH/cdfmean -f $FILEOUT -v sobarstf -p T -w ${ijbox} 0 0 -minmax -o RG_$FILEOUT
if [ $? -ne 0 ] ; then echo "error when running cdfmean (RG)"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi
# this step needed because cdfmean sets a strange value for valid max and that messes up the plotting routines.
ncatted -a valid_min,max_sobarstf,d,, -a valid_max,max_sobarstf,d,, RG_$FILEOUT
