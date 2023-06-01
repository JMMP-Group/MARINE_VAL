#!/bin/bash
shopt -s nullglob

#=============================================================================================================================
#                         FUNCTIONS 
#=============================================================================================================================
retrieve_data() {
   # $1 = $CONFIG ; $2 = $RUNID ; $3 = $FREQ ; $4 = $TAG ; $5 = $GRID
   sbatch --job-name=moo_${4}_${5} --output=${JOBOUT_PATH}/moo_${3}_${4}_${5} ${SCRPATH}/get_data.bash $1 $2 $3 $4 $5 | awk '{print $4}'
}
run_tool() {
   # $1 = TOOL ; $2 = $CONFIG ; $3 = $TAG ; $4 = $RUNID ; $5 = $FREQ ; $6+ = ID
   # global var njob
   sbatchschopt='--wait ' #--qos=long '  
   sbatchrunopt="--dependency=afterany:${@:6} --job-name=NA_${1}_${2}_${3}_${4} --output=${JOBOUT_PATH}/${1}_${5}_${3}.out"
   sbatch ${sbatchschopt} ${sbatchrunopt} ${SCRPATH}/${1}.bash $2 $4 $3 $5 > /dev/null 2>&1 &
   njob=$((njob+1))
}
progress_bar() {
   sleep 4
   echo''
   ijob=$njob
   #eval "printf '|' ; printf '%0.s ' {0..100} ; printf '|\r' ;"
   while [[ $ijob -ne 0 ]] ; do
     ijob=`squeue -u ${USER} | grep 'NA_' | wc -l`
     icar=$(( ( (njob - ijob) * 100 ) / njob ))
     #eval "printf '|' ; printf '%0.s=' {0..$icar} ; printf '\r' ; "
     sleep 1
   done
   #eval "printf '|' ; printf '%0.s=' {0..100} ; printf '|\n' ;"
   #echo ''
}
check_files() {
   # look at the files already produced and derive the first year to calculate
   # find minimum number of files, return value to caller
   files=( ${DATPATH}/${RUNID}/*OHT*${YEARB}*.nc )
   files1=( ${DATPATH}/${RUNID}/*BSF_NA*${YEARB}*.nc )
   files2=( ${DATPATH}/${RUNID}/*HEATC_NA*${YEARB}*.nc )
   files3=( ${DATPATH}/${RUNID}/*AMOC*${YEARB}*.nc )
   files4=( ${DATPATH}/${RUNID}/*LAB_MXL*${YEARB}*.nc )
   files5=( ${DATPATH}/${RUNID}/*SSSav_Lab*${YEARB}*.nc )
   files6=( ${DATPATH}/${RUNID}/*SSTav_New*${YEARB}*.nc )
   files7=( ${DATPATH}/${RUNID}/*${YEARB}*osnap_Xsection.nc )
   files8=( ${DATPATH}/${RUNID}/nemo_*${YEARB}*NA_crop_T.nc )

   # there were files
   nf=${#files[@]}
   nf1=${#files1[@]}
   nf2=${#files2[@]}
   nf3=${#files3[@]}
   nf4=${#files4[@]}
   nf5=${#files5[@]}
   nf6=${#files6[@]}
   nf7=${#files7[@]}
   nf8=${#files8[@]}
   #echo "nfiles $nf $nf1 $nf2 $nf3 $nf4 $nf5 $nf6 $nf7 $nf8"
   numbers=($nf $nf1 $nf2 $nf3 $nf4 $nf5 $nf6 $nf7 $nf8)
   minval=`printf "%d\n" "${numbers[@]}" | sort -rn | tail -1`
   echo "$minval nfiles $nf $nf1 $nf2 $nf3 $nf4 $nf5 $nf6 $nf7 $nf8"
}

#=============================================================================================================================

if [ $# -le 4 ]; then echo 'run_all.sh [CONFIG] [YEARB] [YEARE] [FREQ] [RUNID list]'; exit 42; fi

CONFIG=$1
YEARB=$2
YEARE=$3
FREQ=$4
RUNIDS=${@:5}

. param.bash

# indicate which metrics are being run:
echo "runMOC : $runMOC"
echo "runMHT : $runMHT"
echo "runBSF : $runBSF"

echo "runMLD : $runMLD"
echo "runSST : $runSST"
echo "runSSS : $runSSS"

echo "runHTC : $runHTC"
echo "runGSL_NAC : $runGSL_NAC"
echo "runOVF : $runOVF"

# clean ERROR.txt file
if [ -f ERROR.txt ]; then rm ERROR.txt ; fi

# loop over years
echo ''
for RUNID in `echo $RUNIDS`; do

   # set up jobout directory file
#   JOBOUT_PATH=${DATADIR}/VALNA/DATA/${RUNID}/JOBOUT
   JOBOUT_PATH=${DATPATH}/${RUNID}/JOBOUT
   if [ ! -d ${JOBOUT_PATH} ]; then mkdir -p ${JOBOUT_PATH} ; fi

   echo "$RUNID ..."
   start=$YEARB
   YEARE=$(($start+1))
   # look at the files already produced and derive the first year to calculate
   filecheck=$(check_files $DATPATH $RUNID $YEARB)
   minval=${filecheck:0:1}
   echo "filecheck $filecheck"
   echo "minval $minval"
   echo "do years $start"
   if [[ $minval -ne '0' ]]; then
      echo "This year already done $YEARB"
      exit 0
   fi

   njob=0
   LSTY=`eval echo {${start}..${YEARE}}`
   # option to calculate annually or monthly
   if   [[ $FREQ == 1m ]]; then MONTHB=1  ; MONTHE=12 ; LSTM=`eval echo {$MONTHB..$MONTHE}` ;
   elif [[ $FREQ == 1y ]]; then MONTHB=12 ; MONTHE=12 ; LSTM=`eval echo {$MONTHB..$MONTHE}` ;
   else 
        echo "E R R O R : $FREQ not supported; exit 42"
        exit 42
   fi

   #for YEAR in `printf "%04d " $LSTY`; do
   YEAR=$start
      echo "doing $YEAR"
      for MONTH in `printf "%02d " $LSTM`; do
         # define tags
         TAG=${YEAR}${MONTH}01

         # retrieve raw data
         [[ $runMOC == 1 || $runMHT == 1 || $runBSF == 1 ]]                                                      && mooVyid=$(retrieve_data $CONFIG $RUNID $FREQ $TAG grid-V)
         [[ $runMOC == 1 || $runBSF == 1 ]]                                                                      && mooUyid=$(retrieve_data $CONFIG $RUNID $FREQ $TAG grid-U)
         [[ $runMOC == 1 || $runSST == 1 || $runSSS == 1  || $runHTC == 1 || $runGSL_NAC == 1 || $runOVF == 1 ]] && mooTyid=$(retrieve_data $CONFIG $RUNID $FREQ $TAG grid-T)

         # run cdftools to calculate metrics
         [[ $runBSF == 1 ]] && run_tool mk_psi          $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid
         [[ $runMOC == 1 ]] && run_tool mk_moc          $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runMHT == 1 ]] && run_tool mk_mht          $CONFIG $TAG $RUNID $FREQ $mooTyid:$mooVyid
         [[ $runSST == 1 ]] && run_tool mk_sst          $CONFIG $TAG $RUNID $FREQ $mooTyid
         [[ $runSSS == 1 ]] && run_tool mk_sss          $CONFIG $TAG $RUNID $FREQ $mooTyid
         [[ $runHTC == 1 ]] && run_tool mk_htc          $CONFIG $TAG $RUNID $FREQ $mooTyid
         [[ $runGSL_NAC == 1 ]] && run_tool mk_gsl_nac  $CONFIG $TAG $RUNID $FREQ $mooTyid
         [[ $runOVF == 1 ]] && run_tool mk_ovf          $CONFIG $TAG $RUNID $FREQ $mooTyid
      done

      # define tag - choosing March for max MXL depth (month with the strongest convection):
      TAG09=${YEAR}0301

      # retrieve data
      [[ $runMLD == 1 ]]                                    && mooT09mid=$(retrieve_data $CONFIG $RUNID 1m $TAG09 grid-T)

      # run cdftools
      [[ $runMLD == 1 ]] && run_tool mk_mxl  $CONFIG $TAG09 $RUNID 1m    $mooT09mid

    #done

   # print task bar
   progress_bar

   # wait it is all done (probably useless because of the progress bar loop)
   wait

done # end runids
#rm /scratch/hadom/VALNA/DATA/${RUNID}/nemo*${YEAR}*_grid-?.nc
rm ${DATPATH}/${RUNID}/nemo*${YEAR}*_grid-T_mxl*.nc
rm ${DATPATH}/${RUNID}/nemo*${YEAR}*_psi.nc


# print out
sleep 1
ls > /dev/null 2>&1 # without this the following command sometimes failed (maybe it force to flush all the file on disk)
if [ -f ERROR.txt ]; then
   echo ''
   echo 'ERRORS are present :'
   cat ERROR.txt
   echo ''
   echo 'if error expected (as missing data because data coverage larger than run coverage), diagnostics will be missing for these cases.'
else
   echo ''
   echo "data processing for North Atlantic validation toolbox is done for ${RUNIDS} between ${YEARB} and ${YEARE}"
fi
echo ''
echo "You can now run < ./run_plot.bash [KEY] [FREQ] [RUNIDS] > if no more files to process (other resolution, other periods ...)"
echo ''
echo "by default ./run_plot.bash will process all the file in the data directory, if you want some specific period, you need to tune the glob.glob pattern in the script"
echo ''

