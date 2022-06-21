#!/bin/bash

#=============================================================================================================================
#                         FUNCTIONS 
#=============================================================================================================================
retreive_data() {
   # $1 = $CONFIG ; $2 = $RUNID ; $3 = $FREQ ; $4 = $TAG ; $5 = $GRID
   sbatch --job-name=moo_${4}_${5} --output=${JOBOUT_PATH}/moo_${3}_${4}_${5} ${SCRPATH}/get_data.bash $1 $2 $3 $4 $5 | awk '{print $4}'
}
run_tool() {
   # $1 = TOOL ; [possible flags]; $2 = $CONFIG ; $3 = $TAG ; $4 = $RUNID ; $5 = $FREQ ; $6+ = ID
   # global var njob
   local OPTARG OPTIND opt
   TOOL=$1;shift
   flags=""
   jobtag=""
   while getopts S:s: opt ; do
     flags="$flags -${opt} $OPTARG"
     jobtag=$OPTARG 
   done
   shift `expr $OPTIND - 1`  
   # echo "run_tool running $TOOL $flags $1 $2 $3 $4"
   sbatchschopt='--wait ' #--qos=long '  
   sbatchrunopt="--dependency=afterany:${@:5} --job-name=SO_${TOOL}_${1}_${2}_${3} --output=${JOBOUT_PATH}/${TOOL}_${jobtag}_${4}_${2}.out"
   sbatch ${sbatchschopt} ${sbatchrunopt} ${SCRPATH}/${TOOL}.bash ${flags} $1 $3 $2 $4 > /dev/null 2>&1 &
   njob=$((njob+1))
}
progress_bar() {
   sleep 4
   echo''
   ijob=$njob
   eval "printf '|' ; printf '%0.s ' {0..100} ; printf '|\r' ;"
   while [[ $ijob -ne 0 ]] ; do
     ijob=`squeue -u ${USER} | grep 'SO_' | wc -l`
     icar=$(( ( (njob - ijob) * 100 ) / njob ))
     eval "printf '|' ; printf '%0.s=' {0..$icar} ; printf '\r' ; "
     sleep 1
   done
   eval "printf '|' ; printf '%0.s=' {0..100} ; printf '|\n' ;"
   echo ''
}
#=============================================================================================================================

if [ $# -le 4 ]; then echo 'run_all.sh [CONFIG] [YEARB] [YEARE] [FREQ] [RUNID list]'; exit 42; fi

CONFIG=$1
YEARB=$2
YEARE=$3
FREQ=$4
RUNIDS=${@:5}

. param.bash

# clean ERROR.txt file
if [ -f ERROR.txt ]; then rm ERROR.txt ; fi

# loop over years
echo ''
for RUNID in `echo $RUNIDS`; do

   # set up jobout directory file
   JOBOUT_PATH=${EXEPATH}/SLURM/${CONFIG}/${RUNID}
   if [ ! -d ${JOBOUT_PATH} ]; then mkdir -p ${JOBOUT_PATH} ; fi

   echo "$RUNID ..."

   njob=0
   LSTY=`eval echo {${YEARB}..${YEARE}}`
   if   [[ $FREQ == 1m ]]; then MONTHB=1  ; MONTHE=12 ; LSTM=`eval echo {$MONTHB..$MONTHE}` ;
   elif [[ $FREQ == 1y ]]; then MONTHB=12 ; MONTHE=12 ; LSTM=`eval echo {$MONTHB..$MONTHE}` ;
   else 
        echo "E R R O R : $FREQ not supported; exit 42"
        exit 42
   fi

   for YEAR in `printf "%04d " $LSTY`; do

      for MONTH in `printf "%02d " $LSTM`; do
         # define tags
         TAG=${YEAR}${MONTH}01

         [[ $runACC == 1 || $runMargSea == 1 || $runITF == 1 || $runNAtlOverflows == 1  ]] && runTRP=1

         # get data (retreive_data function are defined in this script)
         [[ $runTRP == 1 || $runBSF == 1 || $runMOC == 1 || $runMHT == 1  ]] && mooVyid=$(retreive_data $CONFIG $RUNID $FREQ $TAG grid-V)
         [[ $runTRP == 1 || $runBSF == 1 || $runTRP2 == 1 || $runMOC == 1 ]] && mooUyid=$(retreive_data $CONFIG $RUNID $FREQ $TAG grid-U)
         [[ $runTRP == 1 || $runBOT == 1 || $runQHF == 1 || $runSST == 1 || $runMOC == 1 ]] && mooTyid=$(retreive_data $CONFIG $RUNID $FREQ $TAG grid-T)
          
         # run cdftools
         [[ $runACC == 1 ]]     && run_tool mk_trp  -S ACC            $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runNAtlOverflows == 1 ]] && run_tool mk_trp  -S DenmarkStrait      $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runNAtlOverflows == 1 ]] && run_tool mk_trp  -S FaroeBankChannel   $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runMargSea == 1 ]] && run_tool mk_trp  -S Gibraltar      $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runMargSea == 1 ]] && run_tool mk_trp  -S BabElMandeb    $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runMargSea == 1 ]] && run_tool mk_trp  -S StraitOfHormuz $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid 
         [[ $runITF == 1 ]]     && run_tool mk_trp  -S LombokStrait   $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runITF == 1 ]]     && run_tool mk_trp  -S OmbaiStrait    $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runITF == 1 ]]     && run_tool mk_trp  -S TimorPassage   $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid 
         [[ $runBSF == 1 ]]     && run_tool mk_psi  $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid
         [[ $runBOT == 1 ]]     && run_tool mk_bot  $CONFIG $TAG $RUNID $FREQ $mooTyid
         [[ $runMOC == 1 ]]     && run_tool mk_moc  $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
         [[ $runMHT == 1 ]]     && run_tool mk_mht  $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooVyid
         [[ $runQHF == 1 ]]     && run_tool mk_hfds $CONFIG $TAG $RUNID $FREQ $mooTyid 
         [[ $runSST == 1 ]]     && run_tool mk_sst  $CONFIG $TAG $RUNID $FREQ $mooTyid
      done

      # define tag      
      TAG09=${YEAR}0901
      TAG02=${YEAR}0201
      TAG03=${YEAR}0301

      # get data (retreive_data function are defined in this script)
      [[ $runSIE == 1 || $runMLD == 1 ]]                                 && mooT09mid=$(retreive_data $CONFIG $RUNID 1m $TAG09 grid-T)
      [[ $runSIE == 1 ]]                                                 && mooT02mid=$(retreive_data $CONFIG $RUNID 1m $TAG02 grid-T)
      [[ $runSIE == 1 ]]                                                 && mooT03mid=$(retreive_data $CONFIG $RUNID 1m $TAG03 grid-T)

      # run cdftools
      [[ $runMLD == 1 ]] && run_tool mk_mxl  $CONFIG $TAG09 $RUNID 1m    $mooT09mid
      [[ $runSIE == 1 ]] && run_tool mk_sie  $CONFIG $TAG09 $RUNID 1m    $mooT09mid 
      [[ $runSIE == 1 ]] && run_tool mk_sie  $CONFIG $TAG02 $RUNID 1m    $mooT02mid
      [[ $runSIE == 1 ]] && run_tool mk_sie  $CONFIG $TAG03 $RUNID 1m    $mooT03mid
   done

   # print task bar
   progress_bar  
 
   # wait it is all done (probably useless because of the progress bar loop)
   wait

done # end runids

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
   echo "data processing for Southern Ocean validation toolbox is done for ${RUNIDS} between ${YEARB} and ${YEARE}"
fi
echo ''
echo "You can now run < ./run_plot.bash [KEY] [RUNIDS] > if no more files to process (other resolution, other periods ...)"
echo ''
echo "by default ./run_plot.bash will process all the file in the data directory, if you want some specific period, you need to tune the glob.glob pattern in the script"
echo ''

