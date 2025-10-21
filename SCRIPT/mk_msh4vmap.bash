#!/bin/bash
#SBATCH --mem=200G
#SBATCH --time=60
#SBATCH --ntasks=1

if [[ $# -ne 1 ]]; then echo 'mk_msh4vmap.bash [RUNID (mi-aa000)]'; exit 1 ; fi

RUNID=$1

echo RUNID: $RUNID

# name
RUN_NAME=${RUNID#*-}

# Vertical coordinates used in the zco mesh_mask.nc
zco=`ncdump -v ln_zco zco_mesh.nc | sed -e "1,/data:/d" -e '$d' -e "s/ln_zco =//g" -e "s/;//g"`
zco=$(($zco + 0))
zps=`ncdump -v ln_zps zco_mesh.nc | sed -e "1,/data:/d" -e '$d' -e "s/ln_zps =//g" -e "s/;//g"`
zps=$(($zps + 0))
if [[ $zco == 1 && $zps == 1 ]]; then
   echo "E R R O R:"
   exit 1
elif [[ $zco == 1 ]]; then
   vco="z"
else
   vco="zps"
fi

echo "vco: "${vco}

$CDFPATH/cdf_mshmsk_update_e3 -i zco_mesh.nc -lev ${vco} -t mesh.nc -m bathy.nc

