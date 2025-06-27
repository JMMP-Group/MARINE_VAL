#!/bin/bash
#SBATCH --mem=30G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 1 ]]; then echo 'mk_msk_and_obs.bash [RUNID (mi-aa000)]'; exit 1 ; fi 

RUNID=$1

python ${SCRPATH}/gen_tmasks.py -r $RUNID 
