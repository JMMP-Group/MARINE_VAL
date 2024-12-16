#!/bin/bash -l
#SBATCH --mem=100G
#SBATCH --time=120
#SBATCH --ntasks=1

sleep 30

RUNID=$1
FREQ=$2
GRID=$3
TAGLIST=${@:4}

FILTER=${EXEPATH}/FILTERS/filter_${GRID}

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
   else FILE_LST="$FILE_LST $(moo ls moose:/crum/$RUNID/${CRUM_FREQ}.nc.file/*_${FREQ}_${TAG}*_${GRID}.nc)"; 
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
      Tvarname=$(ncdump -h $FILE | grep float | grep thetao[_\ ] | cut -d' ' -f2 | cut -d'(' -f1 )
      Svarname=$(ncdump -h $FILE | grep float | grep so[_\ ] | cut -d' ' -f2 | cut -d'(' -f1 )
      if [[ "$Tvarname" == "thetao_con" && "$Svarname" == "so_abs" ]]; then 
         CONVERT_EOS_LIST="$CONVERT_EOS_LIST $FILE"
      elif [[ "$Tvarname" == "thetao_con" || "$Svarname" == "so_abs" ]]; then
         # If file has only one of thetao_con or so_abs, something has gone wrong
         # delete and restore from MASS again. 
         echo " $FILE is corrupted "; rm $FILE
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
   Tvarname=$(ncdump -h $FILE | grep float | grep thetao[_\ ] | cut -d' ' -f2 | cut -d'(' -f1 )
   Svarname=$(ncdump -h $FILE | grep float | grep so[_\ ] | cut -d' ' -f2 | cut -d'(' -f1 )
   echo "$FILE : $Tvarname $Svarname"
   if [[ "$Tvarname" == "thetao_con" && "$Svarname" == "so_abs" ]]; then 
      echo "hello!"
      CONVERT_EOS_LIST="$CONVERT_EOS_LIST $FILE"
   fi
done

for FILE in $CONVERT_EOS_LIST;do
   python3 ${EXEPATH}/SCRIPT/convert_nemo_eos80.py $FILE
   ncks -x -v thetao_con,so_abs $FILE -o ${FILE%.nc}_noTEOS10var.nc
   mv -f ${FILE%.nc}_noTEOS10var.nc $FILE
done
