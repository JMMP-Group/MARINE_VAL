#!/bin/bash
#SBATCH --mem=1G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 4 ]]; then echo 'mk_moc.bash [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

CONFIG=$1
RUNID=$2
TAG=$3
FREQ=$4

echo "CONFIG: $CONFIG; TAG: $TAG; RUNID: $RUNID; FREQ: $FREQ"

# load path and mask
. param.bash
. ${SCRPATH}/common.bash

echo "DATPATH : $DATPATH"
cd $DATPATH/

# name
RUN_NAME=${RUNID#*-}

# download data if needed
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-V
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-U

# check presence of input file
FILEV=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
FILEU=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILET=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
FILES=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILES ] ; then echo "$FILES is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# make moc
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_moc.nc
$CDFPATH/cdfmoc -v $FILEV -u $FILEU -t $FILET -s $FILES -rapid -vvl -o tmp_$FILEOUT

# mv output file
if [[ $? -eq 0 ]]; then 
   mv rapid_tmp_$FILEOUT rapid_$FILEOUT
else 
   echo "error when running cdfmoc; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

