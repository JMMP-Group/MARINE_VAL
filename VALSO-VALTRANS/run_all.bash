
#!/bin/bash

#=============================================================================================================================
#                         FUNCTIONS 
#=============================================================================================================================
moo_wait() {
# Limit the number of MASS retrievals that we submit in parallel. The recommendation is to keep
# this to around 30 max. 
let njobs=$(sacct -s pd,r | grep "moo" | wc -l)
while (( ${njobs} > 25 ))
do
  let njobs=$(sacct -s pd,r | grep "moo" | wc -l)
  echo "Number of MASS retrievals : $njobs. Sleeping."
  sleep 10s
done
}

slurm_wait() {
# Check that we aren't going to exceed user limit of number of jobs before we submit another one.
# limit for pending and running jobs is 1000, limit for running jobs is 500. Aim for under 500 in
# total to be on the safe side. Note some latency in the system (jobs take a while to show up in 
# queue) so set the limit a bit below 500. 
# Now that we have chunking of MASS restores, a lot of processing jobs can be submitted all at once
# after a chunk of files have been restored and might not all show up in the queue. So put in a short
# sleep between each job submission as well.  
sleep 0.1s
let njobs=$(sacct | grep "PENDING" | wc -l)+$(sacct | grep "RUNNING" | wc -l)
while (( $njobs > 480 ))
do
  let njobs=$(sacct | grep "PENDING" | wc -l)+$(sacct | grep "RUNNING" | wc -l)
  echo "Number of slurm jobs : $njobs. Sleeping."
  sleep 1m
done
}

retrieve_data() {
   # $1 = $CONFIG ; $2 = $RUNID ; $3 = $FREQ ; $4 = $GRID ; $5+ = $TAGLIST
   exit_code=1
   let count=0
   while [[ "$exit_code" != "0" ]];do
      (( count += 1 ))
      slurm_wait
      sbatch --job-name=moo_${4}_${5} --output=${JOBOUT_PATH}/moo_${3}_${4}_${5}.out ${SCRPATH}/get_data.bash $1 $2 $3 $4 ${@:5} | awk '{print $4}'
      exit_code=$?
      echo "Retrieval attempt $count. Exit code $exit_code." >> ${JOBOUT_PATH}/sbatch_moo_${3}_${4}_${5}.out
   done
}
run_tool() {
   # $1 = TOOL ; [possible flags]; $2 = $CONFIG ; $3 = $TAG ; $4 = $RUNID ; $5 = $FREQ ; $6+ = ID
   # global var njob
   local OPTARG OPTIND opt
   TOOL=$1;shift
   flags=""
   jobtag=""
   while getopts S:s:A:B opt ; do
     if [ "$opt" == "B" ];then  
        jobtag="${jobtag}_B" 
        flags="$flags -${opt}"
     else
        jobtag="${jobtag}_${OPTARG}" 
        flags="$flags -${opt} $OPTARG"
     fi     
   done
   shift `expr $OPTIND - 1`  
   # echo "run_tool running $TOOL $flags $1 $2 $3 $4"
   sbatchschopt='--wait ' #--qos=long '  
   sbatchrunopt="--dependency=afterany:${@:5} --job-name=P$$_${TOOL}_${1}_${2}_${3} --output=${JOBOUT_PATH}/${TOOL}${jobtag}_${4}_${2}.out"
   exit_code=1
   while [[ "$exit_code" != "0" ]];do
      slurm_wait
      sbatch ${sbatchschopt} ${sbatchrunopt} ${SCRPATH}/${TOOL}.bash ${flags} $1 $3 $2 $4 > /dev/null 2>&1 &
      exit_code=$?
   done
   njob=$((njob+1))
}
progress_bar() {
   sleep 4
   echo''
   ijob=$njob
   eval "printf '|' ; printf '%0.s ' {0..100} ; printf '|\r' ;"
   while [[ $ijob -ne 0 ]] ; do
     ijob=$(squeue -u ${USER} | grep "P$$" | wc -l)
     icar=$(( ( (njob - ijob) * 100 ) / njob ))
     eval "printf '|' ; printf '%0.s=' {0..$icar} ; printf '\r' ; "
     sleep 1
   done
   eval "printf '|' ; printf '%0.s=' {0..100} ; printf '|\n' ;"
   echo ''
}
#=============================================================================================================================

while getopts C: opt ; do
  chunksize=${OPTARG} 
done
shift `expr $OPTIND - 1`  

if [[ -z "$chunksize" ]];then chunksize=1;fi
echo "chunksize is $chunksize"
if [[ $chunksize == 5 ]];then echo "chunksize is 5";fi

if [ $# -le 4 ]; then echo 'run_all.sh [-C chunksize] [CONFIG] [YEARB] [YEARE] [FREQ] [RUNID list]'; exit 42; fi

CONFIG=$1
YEARB=$2
YEARE=$3
FREQ=$4
RUNIDS=${@:5}

. param.bash

# clean ERROR.txt file
if [ -f ERROR.txt ]; then rm ERROR.txt ; fi

[[ $runACC == 1 || $runMargSea == 1 || $runITF == 1 || $runNAtlOverflows == 1  ]] && runTRP=1

# loop over years
echo ''
for RUNID in `echo $RUNIDS`; do

   # set up jobout directory file
   JOBOUT_PATH=${EXEPATH}/SLURM/${CONFIG}/${RUNID}
   if [ ! -d ${JOBOUT_PATH} ]; then mkdir -p ${JOBOUT_PATH} ; fi

   echo "$RUNID ..."

   njob=0
   LSTY=$(eval echo {${YEARB}..${YEARE}})
   if   [[ $FREQ == 1m ]]; then MONTHB=1  ; MONTHE=12 ; LSTM=$(eval echo {$MONTHB..$MONTHE}) ;
   elif [[ $FREQ == 1y ]]; then MONTHB=12 ; MONTHE=12 ; LSTM=$(eval echo {$MONTHB..$MONTHE}) ;
   else 
        echo "E R R O R : $FREQ not supported; exit 42"
        exit 42
   fi

   let tagcount=0
   let tag2count=0
   TAG_LIST=""
   TAGDJF_LIST=""
   TAG09_LIST=""
   TAG02_LIST=""
   TAG03_LIST=""
   for YEAR in $(printf "%04d " $LSTY); do

      for MONTH in $(printf "%02d " $LSTM); do
         # define tags
         (( tagcount+=1 ))
         TAG_LIST="$TAG_LIST ${YEAR}${MONTH}01"

         if [[ $tagcount == $chunksize || ( $YEAR == $YEARE && $MONTH == $MONTHE ) ]]
         then

         echo "TAG_LIST : $TAG_LIST"
         # get data (retrieve_data function is defined in this script)
         moo_wait
         [[ $runTRP == 1 || $runBSF == 1 || $runMOC == 1 || $runMHT == 1  ]] && mooVyid=$(retrieve_data $CONFIG $RUNID $FREQ grid-V $TAG_LIST)
         moo_wait
         [[ $runTRP == 1 || $runBSF == 1 || $runMOC == 1 ]] && mooUyid=$(retrieve_data $CONFIG $RUNID $FREQ grid-U $TAG_LIST)
         moo_wait
         [[ $runTRP == 1 || $runDEEPTS == 1 || $runQHF == 1 || $runSST == 1 || $runMOC == 1 ]] && mooTyid=$(retrieve_data $CONFIG $RUNID $FREQ grid-T $TAG_LIST)
          
         echo "mooTyid : $mooTyid"
         echo "mooUyid : $mooUyid"
         echo "mooVyid : $mooVyid"

         for TAG in $TAG_LIST; do
            # run cdftools
            [[ $runACC == 1 ]]     && run_tool mk_trp  -S ACC            $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runACC == 1 ]]     && run_tool mk_trp  -S ACC -B         $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runACC == 1 ]]     && run_tool mk_trp  -s ACC-shelfbreak $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runNAtlOverflows == 1 ]] && run_tool mk_trp  -S DenmarkStrait      $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runNAtlOverflows == 1 ]] && run_tool mk_trp  -S FaroeBankChannel   $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S FramStrait         $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S BeringStrait       $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S DavisStrait        $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S BarentsSea         $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S WSC                $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runMargSea == 1 ]] && run_tool mk_trp  -S GibraltarStrait          $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runMargSea == 1 ]] && run_tool mk_trp  -S BabElMandeb    $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runMargSea == 1 ]] && run_tool mk_trp  -S StraitOfHormuz $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid 
            [[ $runITF == 1 ]]     && run_tool mk_trp  -S LombokStrait   $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runITF == 1 ]]     && run_tool mk_trp  -S OmbaiStrait    $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runITF == 1 ]]     && run_tool mk_trp  -S TimorPassage   $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid 
            [[ $runBSF == 1 ]]     && run_tool mk_psi  $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid
            [[ $runDEEPTS == 1 ]]  && run_tool mk_deepTS -A AMU $CONFIG $TAG $RUNID $FREQ $mooTyid
            [[ $runDEEPTS == 1 ]]  && run_tool mk_deepTS -A WROSS $CONFIG $TAG $RUNID $FREQ $mooTyid
            [[ $runMOC == 1 ]]     && run_tool mk_moc  $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runMHT == 1 ]]     && run_tool mk_mht  $CONFIG $TAG $RUNID $FREQ $mooVyid:$mooVyid
            [[ $runQHF == 1 ]]     && run_tool mk_hfds $CONFIG $TAG $RUNID $FREQ $mooTyid 
            [[ $runSST == 1 ]]     && run_tool mk_sst  $CONFIG $TAG $RUNID $FREQ $mooTyid
         done
         let tagcount=0
         TAG_LIST=""
         fi
      done

      # define tags      
      (( tag2count+=1 ))
      TAGDJF_LIST="$TAGDJF_LIST ${YEAR}1201"
      TAG09_LIST="$TAG09_LIST ${YEAR}0901"
      TAG02_LIST="$TAG02_LIST ${YEAR}0201"
      TAG03_LIST="$TAG03_LIST ${YEAR}0301"

      if [[ (( $tag2count = $chunksize || $YEAR = $YEARE )) ]]
      then

      echo "TAGDJF_LIST : $TAGDJF_LIST"
      echo "TAG09_LIST : $TAG09_LIST"
      # get data (retrieve_data function are defined in this script)
      moo_wait
      [[ $runDEEPTS == 1 ]]                                              && mooDJFsid=$(retrieve_data $CONFIG $RUNID 1s grid-T $TAGDJF_LIST)
      moo_wait
      [[ $runSIE == 1 || $runMLD == 1 ]]                                 && mooT09mid=$(retrieve_data $CONFIG $RUNID 1m grid-T $TAG09_LIST)
      moo_wait
      [[ $runSIE == 1 ]]                                                 && mooT02mid=$(retrieve_data $CONFIG $RUNID 1m grid-T $TAG02_LIST)
      moo_wait
      [[ $runSIE == 1 ]]                                                 && mooT03mid=$(retrieve_data $CONFIG $RUNID 1m grid-T $TAG03_LIST)

      echo "mooDJFsid : $mooDJFsid"
      echo "mooT09mid : $mooT09mid"

      # run cdftools
      for TAG in $TAGDJF_LIST;do
         [[ $runDEEPTS == 1 ]]  && run_tool mk_deepTS -A WWED $CONFIG $TAG $RUNID 1s $mooDJFsid
         [[ $runDEEPTS == 1 ]]  && run_tool mk_deepTS -A EROSS $CONFIG $TAG $RUNID 1s $mooDJFsid
      done
      for TAG in $TAG09_LIST;do
         [[ $runMLD == 1 ]] && run_tool mk_mxl  $CONFIG $TAG $RUNID 1m    $mooT09mid
         [[ $runSIE == 1 ]] && run_tool mk_sie  $CONFIG $TAG $RUNID 1m    $mooT09mid 
      done
      for TAG in $TAG02_LIST;do
         [[ $runSIE == 1 ]] && run_tool mk_sie  $CONFIG $TAG $RUNID 1m    $mooT02mid
      done
      for TAG in $TAG03_LIST;do
         [[ $runSIE == 1 ]] && run_tool mk_sie  $CONFIG $TAG $RUNID 1m    $mooT03mid
      done
      let tag2count=0
      TAGDJF_LIST=""
      TAG09_LIST=""
      TAG02_LIST=""
      TAG03_LIST=""

      fi
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
   echo ""
   echo "ERRORS are present :"
   cat ERROR.txt
   echo ""
   echo "if error expected (as missing data because data coverage larger than run coverage), diagnostics will be missing for these cases."
else
   echo ""
   echo "data processing for Southern Ocean validation toolbox is done for ${RUNIDS} between ${YEARB} and ${YEARE}"
fi
echo ""
echo "You can now run < ./run_plot.bash [KEY] [RUNIDS] > if no more files to process (other resolution, other periods ...)"
echo ""
echo "by default ./run_plot.bash will process all the file in the data directory, if you want some specific period, you need to tune the glob.glob pattern in the script"
echo ""

