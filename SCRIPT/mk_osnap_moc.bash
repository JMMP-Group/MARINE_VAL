#!/bin/bash -l
#SBATCH --mem=30G
#SBATCH --time=30
#SBATCH --ntasks=1

RUNID=$1
TAG=$2
FREQ=$3

#conda activate pyogcm

echo "RUNID, TAG, FREQ : $RUNID $TAG $FREQ"

# Create working directories if needed
if [ ! -d osnap   ]; then mkdir -p osnap ; fi
cd osnap

# sigma-theta bins
minsig=23.30
maxsig=28.10
stpsig=0.01

# name
RUN_NAME=${RUNID#*-}

# Check presence of input file
FILEV=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
FILEU=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILET=`ls $DATPATH/$RUNID/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILEV ] ; then 
   echo "$FILEV is missing; exit"
   echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/osnmoc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
   exit 1
fi
if [ ! -f $FILEU ] ; then 
   echo "$FILEU is missing; exit"
   echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/osnmoc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
   exit 1
fi
if [ ! -f $FILET ] ; then 
   echo "$FILET is missing; exit"
   echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/osnmoc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
   exit 1
fi

# Link the needed ancil files
if [[ ! -L mesh.nc   ]] ; then ln -s $DATPATH/$RUNID/mesh.nc . ; fi
if [[ ! -L mask.nc   ]] ; then ln -s $DATPATH/$RUNID/mask.nc . ; fi
if [[ ! -L bathy.nc   ]] ; then ln -s $DATPATH/$RUNID/bathy.nc . ; fi

# Modifying the namelist accordingly
f90nml -g namvars \
       -v cn_votemper='thetao_con' \
       -v cn_vosaline='so_abs' \
       -p $DATPATH/$RUNID/nam_cdf_names nam_cdf_names

# Taking care of the observations
for sec in "east" "west"; do
    section="OSNAP"${sec}
    OBS_OSNAP="moc_sigma0_"${section}"_obs.nc"
    if [ ! -f $OBS_OSNAP ]; then 
       echo "Computing OSNAP observations"
       python3 ${SCRPATH}/calc_moc_sigma0_osnap.py "obs_osnap_"$sec $section"_obs" $minsig $maxsig $stpsig
       if [[ $? -ne 0 ]]; then
          echo "error when running calc_moc_sigma0_osnap.py; exit"
          echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/mk_osnap_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
          exit 1
       fi
    fi

   ${SCRPATH}/mk_compute_obs_stats.bash max_osnap_moc_sig t $OBS_OSNAP OSNAP OSNAP_mocsig_${sec}.txt
done

# Looping over east and west legs of the array
for sec in "east" "west"; do

    # 1. Extract cross sections
    section="OSNAP"${sec}
    echo "section is ${section}"
    if [ -f ${EXEPATH}/SECTIONS/section_XTRAC_${section}.dat ];then
       secdef_file=${EXEPATH}/SECTIONS/section_XTRAC_${section}.dat
    else
       echo "Can't find section definition file; exit"
       echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/mk_osnap_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
       exit 2 
    fi  
    echo "XTRAC section definition file is $secdef_file"
    $CDFPATH/cdf_xtrac_brokenline -t $FILET -u $FILEU -v $FILEV -l ${secdef_file} -b bathy.nc -vecrot -o nemoXsec_${RUN_NAME}o_${FREQ}_${TAG}_
    if [[ $? -ne 0 ]]; then 
       echo "error when running cdf_xtrac_brokenline; exit" 
       echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/mk_osnap_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
       exit 1
    fi

    # 2. Compute MOC in density space
    xsec_file=$(ls nemoXsec_${RUN_NAME}o_${FREQ}_${TAG}_${section}.nc)
    echo "xsec_file = $xsec_file"
    label=${section}_${RUN_NAME}o_${FREQ}_${TAG}
    python3 ${SCRPATH}/calc_moc_sigma0_osnap.py $xsec_file $label $minsig $maxsig $stpsig
    if [[ $? -ne 0 ]]; then
       echo "error when running calc_moc_sigma0_osnap.py; exit"
       echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/mk_osnap_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
       exit 1
    fi
    
done

cd ../
