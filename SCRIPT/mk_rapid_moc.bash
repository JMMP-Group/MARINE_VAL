#!/bin/bash
#SBATCH --mem=100G
#SBATCH --time=360
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_rapid_moc.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3

echo "TAG: $TAG; RUNID: $RUNID; FREQ: $FREQ"

# Create working directory if needed
if [ ! -d rapid_z   ]; then mkdir -p rapid_z   ; fi

# name
RUN_NAME=${RUNID#*-}

# -----------------------------------------------------------------
# Compute MOC in depth space at RAPID array

cd rapid_z

# a) check presence of input file and link the needed ancil files

cp $DATPATH/$RUNID/nam_cdf_names .
FILEU=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILEV=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
FILET=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
FILES=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [[ ! -L mesh.nc   ]] ; then ln -s $DATPATH/$RUNID/mesh.nc  . ; fi
if [[ ! -L mask.nc   ]] ; then ln -s $DATPATH/$RUNID/mask.nc  . ; fi
if [[ ! -L bathy.nc  ]] ; then ln -s $DATPATH/$RUNID/bathy.nc . ; fi
if [[ ! -L subbasinmask_amoc.nc ]] ; then ln -s $DATPATH/$RUNID/subbasinmask_amoc.nc . ; fi

if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_rapid_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_rapid_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_rapid_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILES ] ; then echo "$FILES is missing; exit"; echo "E R R O R in : ./mk_rapid_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

### Obs ###
# We compute this everytime, to allow the
# possibility of easily updating the RAPID timeseries
if [[ ! -L obs_rpd_moc.nc ]] ; then ln -s $OBS_RPD_MOC obs_rpd_moc.nc ; fi
${SCRPATH}/mk_compute_obs_stats.bash moc_mar_hc10 time obs_rpd_moc.nc RAPID AMOC_max_obs.txt

# 1. Extract cross sections
section="RAPID"
echo "section is ${section}"
if [ -f ${EXEPATH}/SECTIONS/section_XTRAC_${section}.dat ];then
   secdef_file=${EXEPATH}/SECTIONS/section_XTRAC_${section}.dat
else
   echo "Can't find section definition file; exit"
   echo "E R R O R in : ./mk_amoc.bash $@ (see SLURM/${RUNID}/mk_amoc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
   exit 2
fi
echo "XTRAC section definition file is $secdef_file"
echo "$FILET"
echo "$FILEU"
echo "$FILEV"
$CDFPATH/cdf_xtrac_brokenline -t $FILET -u $FILEU -v $FILEV -l ${secdef_file} -b bathy.nc -vecrot -o nemoXsec_${RUN_NAME}o_${FREQ}_${TAG}_
if [[ $? -ne 0 ]]; then
   echo "error when running cdf_xtrac_brokenline; exit" 
   echo "E R R O R in : ./mk_amoc.bash $@ (see SLURM/${RUNID}/mk_amoc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
   exit 1
fi

#2.Compute MOC in depth space
xsec_file=$(ls nemoXsec_${RUN_NAME}o_${FREQ}_${TAG}_${section}.nc)
echo "xsec_file = $xsec_file"
label=${section}_${RUN_NAME}o_${FREQ}_${TAG}
ncks -Av gdepw_1d mesh.nc $xsec_file
python3 ${SCRPATH}/calc_moc_depth_rapid.py $xsec_file $label "top2bot"
if [[ $? -ne 0 ]]; then
   echo "error when running calc_moc_depth_rapid.py; exit"
   echo "E R R O R in : ./mk_rapid_moc.bash $@ (see SLURM/${RUNID}/mk_rapid_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
   exit 1
fi

#FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_moc.nc
#$CDFPATH/cdfmoc -v $FILEV -u $FILEU -t $FILET -s $FILES -rapid -o tmp_$FILEOUT
#if [[ $? -eq 99 || $? -eq 0 ]]; then
#   mv "rapid_tmp_$FILEOUT" "moc_z_RAPID_${RUN_NAME}o_${FREQ}_${TAG}.nc"
#else
#   echo "error when running cdfmoc; exit"; echo "E R R O R in : ./mk_moc.bash $@ (see SLURM/${RUNID}/mk_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
#fi

echo "RAPID overturning streamfunction in depth space done!"

cd ../
