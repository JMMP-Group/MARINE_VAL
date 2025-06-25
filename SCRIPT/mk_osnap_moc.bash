#!/bin/bash -l
#SBATCH --mem=30G
#SBATCH --time=30
#SBATCH --ntasks=1

RUNID=$1
TAG=$2
FREQ=$3

conda activate pyogcm

echo "RUNID, TAG, FREQ : $RUNID $TAG $FREQ"

# sigma-theta bins
minsig=23.30
maxsig=28.10
stpsig=0.01

# name
RUN_NAME=${RUNID#*-}

# Check presence of input file
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
FILEU=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
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

# Taking care of the observations
for sec in "east" "west"; do
    OBS_OSNAP="osnap_moc_sigma0_obs_"${sec}".nc"
    if [ ! -f $OBS_OSNAP ]; then 
       python3 ${SCRPATH}/calc_moc_sigma0.py "obs_osnap_"$sec "obs_"$sec $minsig $maxsig $stpsig
       if [[ $? -ne 0 ]]; then
          echo "error when running calc_moc_sigma0.py; exit"
          echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/mk_osnap_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
          exit 1
       fi
    fi
    # compute
    # 1) the mean
    ncwa -O -v max_osnap_moc_sig -a t ${OBS_OSNAP} mean_${OBS_OSNAP}
    mean_obs=`ncdump -v max_osnap_moc_sig mean_${OBS_OSNAP} | sed -e "1,/data:/d" -e '$d' -e "s/max_osnap_moc_sig =//g" -e "s/;//g"`
    mean_obs="${mean_obs//$'\n'/}"
    # 2) the deviations with respect to the mean
    ncbo -O -v max_osnap_moc_sig ${OBS_OSNAP} mean_${OBS_OSNAP} dev_${OBS_OSNAP}
    # 3) the sum of the square of the deviations, then divide by (N-1) and take the square root
    ncra -O -y rmssdn dev_${OBS_OSNAP} std_dev_${OBS_OSNAP}
    std_obs=`ncdump -v max_osnap_moc_sig std_dev_${OBS_OSNAP} | sed -e "1,/data:/d" -e '$d' -e "s/max_osnap_moc_sig =//g" -e "s/;//g"`
    std_obs="${std_obs//$'\n'/}"
    cat > "${MARINE_VAL}/OBS/OSNAP_mocsig_${sec}.txt" << EOF
ref = OSNAP
mean = ${mean_obs}
std = ${std_obs}
EOF
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
    label=${RUN_NAME}o_${FREQ}_${TAG}_${section}
    python3 ${SCRPATH}/calc_moc_sigma0.py $xsec_file $label $minsig $maxsig $stpsig
    if [[ $? -ne 0 ]]; then
       echo "error when running calc_moc_sigma0.py; exit"
       echo "E R R O R in : ./mk_osnap_moc.bash $@ (see SLURM/${RUNID}/mk_osnap_moc_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
       exit 1
    fi
    
done
