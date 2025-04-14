#!/bin/bash -l

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
   # $1 = $RUNID ; $2 = $FREQ ; $3 = $GRID ; $4+ = $TAGLIST
   exit_code=1
   let count=0
   while [[ "$exit_code" != "0" ]];do
      (( count += 1 ))
      slurm_wait
      sbatch --job-name=moo_${3}_${4} --output=${JOBOUT_PATH}/moo_${2}_${3}_${4}.out ${SCRPATH}/get_data.bash $1 $2 $3 ${@:4} | awk '{print $4}'
      exit_code=$?
      echo "Retrieval attempt $count. Exit code $exit_code." >> ${JOBOUT_PATH}/sbatch_moo_${2}_${3}_${4}.out
   done
}
run_tool() {
   # $1 = TOOL ; [possible flags]; $2 = $TAG ; $3 = $RUNID ; $4 = $FREQ ; $5+ = retrieval job IDs
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
   # echo "run_tool running $TOOL $flags $1 $2 $3"
   sbatchschopt='--wait ' #--qos=long '  
   sbatchrunopt="--dependency=afterany:${@:4} --job-name=P$$_${TOOL}_${1}_${2} --output=${JOBOUT_PATH}/${TOOL}${jobtag}_${3}_${1}.out"
   exit_code=1
   
   while [[ "$exit_code" != "0" ]];do
      if [[ $TOOL == "mk_htc" && -z "$FIRST_MK_HTC_JOB_ID" ]]; then
         declare -g FIRST_MK_HTC_JOB_ID
         FIRST_MK_HTC_JOB_ID=$(sbatch ${sbatchschopt} ${sbatchrunopt} ${SCRPATH}/${TOOL}.bash ${flags} $2 $1 $3 | awk '{print $4}')
         while squeue -j $FIRST_MK_HTC_JOB_ID > /dev/null 2>&1; do
            sleep 2
         done
      else
         slurm_wait
         sbatch ${sbatchschopt} ${sbatchrunopt} ${SCRPATH}/${TOOL}.bash ${flags} $2 $1 $3 > /dev/null 2>&1 &
         exit_code=$?
      fi
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

while getopts B:C: opt ; do
  case $opt in
     B) BATHY=${OPTARG} ;;
     C) chunksize=${OPTARG} ;;
  esac   
done
shift `expr $OPTIND - 1`  

if [[ -z "$chunksize" ]];then chunksize=1;fi
echo "chunksize is $chunksize"
echo "BATHY is $BATHY"

if [ $# -le 4 ]; then echo 'run_proc.sh [-C chunksize] [-B BATHY] [MESHMASK] [YEARB] [YEARE] [FREQ] [RUNID list]'; exit 42; fi

MESHMASK=$1
YEARB=$2
YEARE=$3
FREQ=$4
RUNIDS=${@:5}

. param.bash

# clean ERROR.txt file
if [[ -f ERROR.txt ]]; then rm ERROR.txt ; fi

[[ $runACC == 1 || $runMargSea == 1 || $runITF == 1 || $runNAtlOverflows == 1  || $runArcTrans == 1 ]] && runTRP=1
[[ $runBSF_SO == 1 || $runBSF_NA == 1 ]] && runBSF=1
[[ $runDEEPTS == 1 || $runSSS_LabSea == 1 || $runSST_SO == 1 || $runSST_NWCorner == 1 ]] && runTS=1

# Check that everything is in place
if [[ ! -d ${CDFPATH} || ! -n "$(ls -A "$CDFPATH")" ]] ; then  
   echo "E R R O R : CDFTOOLS/bin directory does not exist or is empty: ${CDFPATH}"
   exit 41
fi

if [[ ! -f ${NMLPATH} ]] ; then 
   echo "E R R O R : nam_cdf_names namelist file does not exist : ${NMLPATH}"
   exit 41
fi

if [[ ! -f ${MSKPATH}/${MESHMASK} ]] ; then 
   echo "E R R O R : mesh_mask file does not exist : ${MSKPATH}/${MESHMASK}"
   exit 41
fi

if [[ $runTRP == 1 && ! -f ${MSKPATH}/${BATHY} ]] ; then
   echo "E R R O R : bathymetry file does not exist : ${MSKPATH}/${BATHY}"
   echo "Bathymetry file can be created from mesh_mask file using SCRIPT/bathy_from_dommesh.py"
   exit 41
fi

# loop over years
echo ''
for RUNID in `echo $RUNIDS`; do

   # set up jobout directory file
   JOBOUT_PATH=${EXEPATH}/JOBOUT/${RUNID}
   if [ ! -d ${JOBOUT_PATH} ]; then mkdir -p ${JOBOUT_PATH} ; fi

   # create working directory
   if [ ! -d ${DATPATH}/${RUNID} ]; then mkdir -p ${DATPATH}/${RUNID} ; fi
   cd ${DATPATH}/${RUNID}

   # check nam_cdf_names namelist
   if [[ ! -L nam_cdf_names ]] ; then ln -s ${NMLPATH} nam_cdf_names ; fi

   # check mesh mask
   if [[ ! -L mesh.nc     ]] ; then ln -s ${MSKPATH}/${MESHMASK} mesh.nc ; fi
   if [[ ! -L mask.nc     ]] ; then ln -s ${MSKPATH}/${MESHMASK} mask.nc ; fi
   if [[ $runTRP == 1 && ! -L bathy.nc    ]] ; then ln -s ${MSKPATH}/${BATHY} bathy.nc ; fi
   # subbasins file not currently used by any metrics
   #if [ ! -L subbasin.nc ] ; then ln -s ${MSKPATH}/subbasins_${CONFIG}-GO6.nc subbasin.nc ; fi

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
         [[ $runTRP == 1 || $runBSF == 1 || $runAMOC == 1 || $runMHT == 1  ]] && mooVyid=$(retrieve_data $RUNID $FREQ grid-V $TAG_LIST)
         moo_wait
         [[ $runTRP == 1 || $runBSF == 1 || $runAMOC == 1 ]] && mooUyid=$(retrieve_data $RUNID $FREQ grid-U $TAG_LIST)
         moo_wait
         [[ $runTRP == 1 || $runQHF == 1 || $runTS == 1 || $runAMOC == 1 || $runHTC == 1 || $runGSL_NAC || $runMHT == 1 ]] && mooTyid=$(retrieve_data $RUNID $FREQ grid-T $TAG_LIST)
          
         echo "mooTyid : $mooTyid"
         echo "mooUyid : $mooUyid"
         echo "mooVyid : $mooVyid"

         for TAG in $TAG_LIST; do
            # run cdftools
            [[ $runBSF_SO == 1 ]]  && run_tool mk_psi_SO                 $TAG $RUNID $FREQ $mooVyid:$mooUyid
            [[ $runDEEPTS == 1 ]]  && run_tool mk_deepTS -A AMU          $TAG $RUNID $FREQ $mooTyid
            [[ $runDEEPTS == 1 ]]  && run_tool mk_deepTS -A WROSS        $TAG $RUNID $FREQ $mooTyid
            [[ $runSST_SO == 1 ]]  && run_tool mk_sst_SO                 $TAG $RUNID $FREQ $mooTyid
            [[ $runACC == 1 ]]     && run_tool mk_trp  -S ACC            $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runACC == 1 ]]     && run_tool mk_trp  -S ACC -B         $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runACC == 1 ]]     && run_tool mk_trp  -s ACC-shelfbreak $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runNAtlOverflows == 1 ]] && run_tool mk_trp  -S DenmarkStrait      $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runNAtlOverflows == 1 ]] && run_tool mk_trp  -S FaroeBankChannel   $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S FramStrait         $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S BeringStrait       $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S DavisStrait        $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S BarentsSea         $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runArcTrans == 1 ]]      && run_tool mk_trp  -S WSC                $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runMargSea == 1 ]]       && run_tool mk_trp  -S GibraltarStrait    $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runMargSea == 1 ]]       && run_tool mk_trp  -S BabElMandeb        $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runMargSea == 1 ]]       && run_tool mk_trp  -S StraitOfHormuz     $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid 
            [[ $runITF == 1 ]]           && run_tool mk_trp  -S LombokStrait       $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runITF == 1 ]]           && run_tool mk_trp  -S OmbaiStrait        $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runITF == 1 ]]           && run_tool mk_trp  -S TimorPassage       $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid 
            [[ $runBSF_NA == 1 ]]        && run_tool mk_psi_NA   $TAG $RUNID $FREQ $mooVyid:$mooUyid
            [[ $runAMOC == 1 ]]          && run_tool mk_amoc     $TAG $RUNID $FREQ $mooVyid:$mooUyid:$mooTyid
            [[ $runSST_NWCorner == 1 ]]  && run_tool mk_sst_NA   $TAG $RUNID $FREQ $mooTyid
            [[ $runSSS_LabSea == 1 ]]    && run_tool mk_sss      $TAG $RUNID $FREQ $mooTyid
            [[ $runHTC == 1 ]]           && run_tool mk_htc      $TAG $RUNID $FREQ $mooTyid
            [[ $runGSL_NAC == 1 ]]       && run_tool mk_gsl_nac  $TAG $RUNID $FREQ $mooTyid
            [[ $runOVF == 1 ]]           && run_tool mk_ovf      $TAG $RUNID $FREQ $mooTyid
            [[ $runMHT == 1 ]]     && run_tool mk_mht  $TAG $RUNID $FREQ $mooVyid:$mooVyid
            [[ $runQHF == 1 ]]     && run_tool mk_hfds $TAG $RUNID $FREQ $mooTyid 
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
      echo "TAG03_LIST : $TAG03_LIST"

      # get data (retrieve_data function are defined in this script)
      moo_wait
      [[ $runDEEPTS == 1 ]]                                              && mooDJFsid=$(retrieve_data $RUNID 1s grid-T $TAGDJF_LIST)
      moo_wait
      [[ $runSIE == 1 || $runMLD_Weddell == 1 ]]                         && mooT09mid=$(retrieve_data $RUNID 1m grid-T $TAG09_LIST)
      moo_wait
      [[ $runSIE == 1 ]]                                                 && mooT02mid=$(retrieve_data $RUNID 1m grid-T $TAG02_LIST)
      moo_wait
      [[ $runSIE == 1 || $runMLD_LabSea == 1 ]]                          && mooT03mid=$(retrieve_data $RUNID 1m grid-T $TAG03_LIST)

      echo "mooDJFsid : $mooDJFsid"
      echo "mooT09mid : $mooT09mid"
      echo "mooT03mid : $mooT03mid"

      # run cdftools
      for TAG in $TAGDJF_LIST;do
         [[ $runDEEPTS == 1 ]]  && run_tool mk_deepTS -A WWED $TAG $RUNID 1s $mooDJFsid
         [[ $runDEEPTS == 1 ]]  && run_tool mk_deepTS -A EROSS $TAG $RUNID 1s $mooDJFsid
      done
      for TAG in $TAG09_LIST;do
         [[ $runMLD_Weddell == 1 ]] && run_tool mk_mxl_SO  $TAG $RUNID 1m    $mooT09mid
         [[ $runSIE == 1 ]]         && run_tool mk_sie  $TAG $RUNID 1m    $mooT09mid 
      done
      for TAG in $TAG02_LIST;do
         [[ $runSIE == 1 ]] && run_tool mk_sie  $TAG $RUNID 1m    $mooT02mid
      done
      for TAG in $TAG03_LIST;do
         [[ $runMLD_LabSea == 1 ]] && run_tool mk_mxl_NA  $TAG $RUNID 1m    $mooT03mid
         [[ $runSIE == 1 ]] && run_tool mk_sie  $TAG $RUNID 1m    $mooT03mid
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
   echo "data processing is done for ${RUNIDS} between ${YEARB} and ${YEARE}"
fi
echo ""
echo "You can now run < ./run_plot_{PACKAGE}.bash [KEY] [FREQ] [RUNIDS] > if no more files to process (other resolution, other periods ...)"
echo ""
echo "by default ./run_plot_{PACKAGE}.bash will process all the file in the data directory, if you want some specific period, you need to tune the glob.glob pattern in the script"
echo ""

