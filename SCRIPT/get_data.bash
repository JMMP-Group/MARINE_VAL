#!/bin/bash -l
#SBATCH --mem=100G
#SBATCH --time=360
#SBATCH --ntasks=1

check_TS_var(){
    # check standard_name attributes and extract relevant variable name from grep command
    FILE=$1
    TEOS10=0; EOS80=0
    Tv10="";Sv10="";Tv80="";Sv80=""
    Tv10=$(ncdump -h $FILE | grep "sea_water_conservative_temperature" | cut -d":" -f1)
    Sv10=$(ncdump -h $FILE | grep "sea_water_absolute_salinity" | cut -d":" -f1)
    Tv80=$(ncdump -h $FILE | grep "sea_water_potential_temperature" | cut -d":" -f1)
    Sv80=$(ncdump -h $FILE | grep "sea_water_practical_salinity" | cut -d":" -f1)
    if [[ -n "$Tv10" && -n "$Sv10" ]]; then TEOS10=1; fi
    if [[ -n "$Tv80" && -n "$Sv80" ]]; then EOS80=1; fi
    echo "TEOS10= " $TEOS10 ", EOS80= " $EOS80
}    

sleep 30

RUNID=$1
FREQ=$2
GRID=$3
TAGLIST=${@:4}

FILTER=${EXEPATH}/FILTERS/filter_${GRID}
GRID_CAT=$(echo $GRID | awk -F'[-_]' '{print $NF}')

# get data
if   [ $FREQ == '5d' ]; then CRUM_FREQ=ond;
elif [ $FREQ == '1m' ]; then CRUM_FREQ=onm;
elif [ $FREQ == '1s' ]; then CRUM_FREQ=ons;
elif [ $FREQ == '1y' ]; then CRUM_FREQ=ony;
elif [ $FREQ == 'i1m' ]; then CRUM_FREQ=inm;
else echo '$FREQ frequency is not supported'; exit 1
fi

# flexibility for old-style filenames:
GRID=$(echo $GRID | sed 's/-/[-_]/g')

FILE_LST=""
for TAG in $TAGLIST;do
   if   [ $FREQ == '5d'  ]; then FILE_LST="$FILE_LST $(moo ls moose:/crum/$RUNID/${CRUM_FREQ}.nc.file/*_${FREQ}_${GRID}_${TAG}.nc)"
   elif [ $FREQ == 'i1m' ]; then FILE_LST="$FILE_LST $(moo ls moose:/crum/$RUNID/${CRUM_FREQ}.nc.file/*_1m_${TAG}.nc)"
   else FILE_LST="$FILE_LST $(moo ls moose:/crum/$RUNID/${CRUM_FREQ}.nc.file/*${RUNID:2}o_${FREQ}_${TAG}*_${GRID}.nc)"; 
   fi
done

MOO_GET_LIST=""
MOO_RESTORED_LIST=""
CONVERT_EOS_LIST=""

for MFILE in ${FILE_LST}; do
   FILE=${MFILE#*${CRUM_FREQ}.nc.file/}
   if [ -f $FILE ]; then 
      TIME=$(ncdump -h $FILE | grep UNLIMITED | sed -e 's/(//' | awk '{print $6}')
#      SIZEMASS=`moo ls -l $MFILE | awk '{ print $5}'`
#      SIZESYST=`    ls -l $FILE  | awk '{ print $5}'`
#      if [[ $SIZEMASS -ne $SIZESYST ]]; then echo " $FILE is corrupted "; rm $FILE; fi
      if [[ $TIME -eq 0 ]]; then echo " $FILE is corrupted "; rm $FILE; fi

      if [[ "${GRID_CAT}" == "T" ]]; then
         check_TS_var $FILE
         if [[ "$TEOS10" == 1 && "$EOS80" == 0 ]]; then
            # If file has only TEOS10 variables, we need to compute the EOS80 ones. 
            CONVERT_EOS_LIST="$CONVERT_EOS_LIST $FILE"
         elif [[ "$TEOS10" == 0 && "$EOS80" == 0 ]]; then
            # We don't have a consistent set of T and S variables. 
            # Try restoring the file again.
            echo " $FILE may be corrupted "; rm $FILE
         else
            echo 'EOS80 fields in file: no conversion required.'
         fi
      fi
   fi

   if [ ! -f $FILE ]; then
      echo "downloading file ${FILE}"
      MOO_GET_LIST="$MOO_GET_LIST $MFILE"
      MOO_RESTORED_LIST="$MOO_RESTORED_LIST $FILE"
   fi

done

if [[ -n "$MOO_GET_LIST" ]];then 
  echo "Executing command : moo filter $FILTER $MOO_GET_LIST ."
  moo filter $FILTER $MOO_GET_LIST .
fi

for FILE in $MOO_RESTORED_LIST;do
   if [[ "${GRID_CAT}" == "T" ]]; then   
      check_TS_var $FILE
      if [[ "$TEOS10" == 1 && "EOS80" == 0 ]]; then 
         CONVERT_EOS_LIST="$CONVERT_EOS_LIST $FILE"
      fi
   fi 
   # Set standard_name for depth coordinate so Iris will recognise it:
   [[ "$FILE" =~ *grid-T\.nc ]] && depvar="deptht"
   [[ "$FILE" =~ *grid-U\.nc ]] && depvar="depthu"
   [[ "$FILE" =~ *grid-V\.nc ]] && depvar="depthv"
   ncatted -a standard_name,${depvar},c,c,"depth" $FILE
   #
done

for FILE in $CONVERT_EOS_LIST;do
   echo "Converting $Tv10 and $Sv10 to EOS80 variables in $FILE" 
   ${EXEPATH}/SCRIPT/convert_nemo_eos80.py -i $FILE -T $Tv10 -S $Sv10
done
