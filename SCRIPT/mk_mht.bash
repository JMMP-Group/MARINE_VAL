#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_mht.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_mht.bash $@ (see SLURM/${RUNID}/mht_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make mht
set -x
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_mht.nc
$CDFPATH/cdfmhst -vt $FILEV -vvl -o tmp_$FILEOUT

# mv output file
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfmht; exit"; echo "E R R O R in : ./mk_mht.bash $@ (see SLURM/${RUNID}/mht_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

# Find which CONFIG (eORCA1, eORCA025 etc) we are using from dimensions of mesh file: 
xdim=$(ncdump -h mesh.nc | grep "\sx =" | cut -d"=" -f2 | sed 's/;//g')
case xdim in 
  360|362)
    CONFIG="eORCA1"
    ;;
  1440|1442)
    CONFIG="eORCA025"
    ;;
  4320|4322)
    CONFIG="eORCA12"
    ;;
  *)
    echo "Unknown configuration"
    echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
    exit 1 
    ;;
esac

# extract only 26.5
case $CONFIG in
  eORCA1)
    jj=227
    ;;
  eORCA025)
    jj=793
    ;;
  eORCA12)
    jj=2364
    ;;
  *)
    echo "Unrecognised configuration."
    echo "error when running cdfmht; exit"; echo "E R R O R in : ./mk_mht.bash $@ (see SLURM/${CONFIG}/${RUNID}/mht_${TAG}.out)" >> ${EXEPATH}/ERROR.txt; exit 1
    ;;
esac
ncks -O -d y,$jj,$jj $FILEOUT nemo_${RUN_NAME}o_${FREQ}_${TAG}_mht_265.nc
