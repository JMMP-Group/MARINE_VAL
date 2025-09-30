#!/bin/bash
#SBATCH --mem=20G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 1 ]]; then echo 'mk_subbasin.bash [RUNID (mi-aa000)]'; exit 1 ; fi

RUNID=$1

echo RUNID: $RUNID

# name
RUN_NAME=${RUNID#*-}

# Vertical coordinates used in the zco mesh_mask.nc
python ${SCRPATH}/gen_subbasinmask.py -m mask.nc -o subbasinmask_amoc.nc

