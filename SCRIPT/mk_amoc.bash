#!/bin/bash
#SBATCH --mem=150G
#SBATCH --time=360
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_moc.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3

echo "TAG: $TAG; RUNID: $RUNID; FREQ: $FREQ"

# Create working directories if needed
if [ ! -d amoc_z   ]; then mkdir -p amoc_z   ; fi
if [ ! -d amoc_rho ]; then mkdir -p amoc_rho ; fi

# name
RUN_NAME=${RUNID#*-}

# -----------------------------------------------------------------
# 1) Compute AMOC in depth space

vvl="" # for now, TBC
cd amoc_z

# a) check presence of input file and link the needed ancil files

if [[ "$runVRMP" == 1 ]]; then
   cp $DATPATH/$RUNID/vrmp/nam_cdf_names .
   FILEU=`ls $DATPATH/$RUNID/vrmp/vrmp.amoc*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
   FILEV=`ls $DATPATH/$RUNID/vrmp/vrmp.amoc*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
   FILET=`ls $DATPATH/$RUNID/vrmp/vrmp.amoc*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
   FILES=`ls $DATPATH/$RUNID/vrmp/vrmp.amoc*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
   if [[ ! -L mesh_h.nc ]] ; then ln -s $DATPATH/$RUNID/vrmp/mesh_amoc.nc mesh_h.nc ; fi
   if [[ ! -L mesh_z.nc ]] ; then ln -s $DATPATH/$RUNID/vrmp/zgr_amoc.nc mesh_z.nc  ; fi
   if [[ ! -L mask.nc   ]] ; then ln -s $DATPATH/$RUNID/vrmp/zgr_amoc.nc mask.nc    ; fi
   if [[ ! -L bathy.nc  ]] ; then ln -s $DATPATH/$RUNID/vrmp/bathy_amoc.nc bathy.nc ; fi
   if [[ ! -L subbasinmask_amoc.nc ]] ; then ln -s ../vrmp/subbasinmask_amoc.nc . ; fi
else
   cp $DATPATH/$RUNID/nam_cdf_names .
   FILEU=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
   FILEV=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
   FILET=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
   FILES=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
   if [[ ! -L mesh.nc   ]] ; then ln -s $DATPATH/$RUNID/mesh.nc  . ; fi
   if [[ ! -L mask.nc   ]] ; then ln -s $DATPATH/$RUNID/mask.nc  . ; fi
   if [[ ! -L bathy.nc  ]] ; then ln -s $DATPATH/$RUNID/bathy.nc . ; fi
   if [[ ! -L subbasinmask_amoc.nc ]] ; then ln -s $DATPATH/$RUNID/subbasinmask_amoc.nc . ; fi
fi

if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILES ] ; then echo "$FILES is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# b) Compute AMOC streamfunction in depth space

FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}.nc
$CDFPATH/cdfmoc -v $FILEV -o tmp_$FILEOUT
if [[ $? -eq 99 || $? -eq 0 ]]; then 
   mv tmp_$FILEOUT AMOC_depth_$FILEOUT
else 
   echo "error when running cdfmoc; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

echo "AMOC streamfunction in depth space done!"
cd ../

# -----------------------------------------------------------------
# 2) Compute AMOC in sigma_2000 space

vvl="" # for now, TBC
cd amoc_rho

cp $DATPATH/$RUNID/nam_cdf_names .

# a) check presence of input file and link the needed ancil files

if [[ "$runVRMP" == 1 ]]; then
   # When using GVC, to comute the AMOC in density space we don't need to use 
   # the remapped files, we can use the original ones.
   FILEV=`ls $DATPATH/$RUNID/vrmp/amoc*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
   #FILEU=`ls $DATPATH/$RUNID/vrmp/amoc*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
   FILET=`ls $DATPATH/$RUNID/vrmp/amoc*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
   FILES=`ls $DATPATH/$RUNID/vrmp/amoc*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
   if [[ ! -L mesh.nc   ]] ; then ln -s $DATPATH/$RUNID/vrmp/mesh_amoc.nc mesh.nc ; fi
   if [[ ! -L mask.nc   ]] ; then ln -s $DATPATH/$RUNID/vrmp/mesh_amoc.nc mask.nc ; fi
   if [[ ! -L subbasinmask_amoc.nc ]] ; then ln -s $DATPATH/$RUNID/vrmp/subbasinmask_amoc.nc . ; fi
else
   FILEV=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
   #FILEU=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
   FILET=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
   FILES=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
   if [[ ! -L mesh.nc   ]] ; then ln -s $DATPATH/$RUNID/mesh.nc . ; fi
   if [[ ! -L mask.nc   ]] ; then ln -s $DATPATH/$RUNID/mask.nc . ; fi
   if [[ ! -L subbasinmask_amoc.nc ]] ; then ln -s $DATPATH/$RUNID/subbasinmask_amoc.nc . ; fi
fi

#if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILES ] ; then echo "$FILES is missing; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}.nc
$CDFPATH/cdfmocsig -v $FILEV -t $FILET -s $FILES -r 2000 $vvl -o tmp_$FILEOUT
if [[ $? -eq 99 || $? -eq 0 ]]; then
   mv tmp_$FILEOUT AMOC_sigma2_$FILEOUT
else
   echo "error when running cdfmocsig; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

echo "AMOC streamfunction in sigm_2000 space done!"

cd ../

