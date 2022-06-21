#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 4 ]]; then echo 'mk_trp.bash [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

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

# download data if needed (useless if data already there)
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-V
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-U

# check presence of input file
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
FILEU=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make trp
$CDFPATH/cdftransport -u $FILEU -v $FILEV -lonlat -noheat -vvl -pm  -sfx nemo_${RUN_NAME}o_${FREQ}_${TAG} < ${EXEPATH}/SECTIONS/section_LONLAT.dat

# mv output file
if [[ $? -eq 0 ]]; then 
else 
   echo "error when running cdftransport; exit" ; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi
