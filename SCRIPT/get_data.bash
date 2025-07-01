#!/bin/bash -l
#SBATCH --mem=100G
#SBATCH --time=360
#SBATCH --ntasks=1

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
   else FILE_LST="$FILE_LST $(moo ls moose:/crum/$RUNID/${CRUM_FREQ}.nc.file/*_${RUNID:2}o_${FREQ}_${TAG}*_${GRID}.nc)"; 
   fi
done

MOO_GET_LIST=""
MOO_RESTORED_LIST=""
CONVERT_EOS_LIST=""
TEOS10=0
EOS80=0

for MFILE in ${FILE_LST}; do
   FILE=${MFILE#*${CRUM_FREQ}.nc.file/}
   if [ -f $FILE ]; then 
      TIME=$(ncdump -h $FILE | grep UNLIMITED | sed -e 's/(//' | awk '{print $6}')
#      SIZEMASS=`moo ls -l $MFILE | awk '{ print $5}'`
#      SIZESYST=`    ls -l $FILE  | awk '{ print $5}'`
#      if [[ $SIZEMASS -ne $SIZESYST ]]; then echo " $FILE is corrupted "; rm $FILE; fi
      if [[ $TIME -eq 0 ]]; then echo " $FILE is corrupted "; rm $FILE; fi

      if [[ "${GRID_CAT}" == "T" ]]; then
         Tv10=$(ncdump -h $FILE | grep float | grep thetao[_\ ]con | cut -d' ' -f2 | cut -d'(' -f1 )
         Sv10=$(ncdump -h $FILE | grep float | grep so[_\ ]abs | cut -d' ' -f2 | cut -d'(' -f1 )
         Tv80=$(ncdump -h $FILE | grep float | grep thetao[_\ ]pot | cut -d' ' -f2 | cut -d'(' -f1 )
         Sv80=$(ncdump -h $FILE | grep float | grep so[_\ ]pra | cut -d' ' -f2 | cut -d'(' -f1 )
         #echo "Tv10= " $Tv10 ", Sv10= " $Sv10
         #echo "Tv80= " $Tv80 ", Sv80= " $Sv80
         if [[ "$Tv10" == "thetao_con" && "$Sv10" == "so_abs" ]]; then TEOS10=1; fi
         if [[ "$Tv80" == "thetao_pot" && "$Sv80" == "so_pra" ]]; then EOS80=1; fi
         echo "TEOS10= " $TEOS10 ", EOS80= " $EOS80

         if [[ "$TEOS10" == 0 ]]; then
            # If file has only one of thetao_con or so_abs, something has gone wrong
            # delete and restore from MASS again. 
            echo " $FILE is corrupted "; rm $FILE
         elif [[ "$TEOS10" == 1 && "$EOS80" == 0 ]]; then
            # If file has only TEOS10 variables, we need to compute the EOS80 ones. 
            CONVERT_EOS_LIST="$CONVERT_EOS_LIST $FILE"
         else
            echo 'nothing to do ... '
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
      Tv10=$(ncdump -h $FILE | grep float | grep thetao[_\ ]c | cut -d' ' -f2 | cut -d'(' -f1 )
      Sv10=$(ncdump -h $FILE | grep float | grep so[_\ ]a | cut -d' ' -f2 | cut -d'(' -f1 )
      echo "$FILE : $Tv10 $Sv10"
      if [[ "$Tv10" == "thetao_con" && "$Sv10" == "so_abs" ]]; then 
         echo "hello!"
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
   python3 ${EXEPATH}/SCRIPT/convert_nemo_eos80.py $FILE
   #ncks -x -v thetao_con,so_abs $FILE -o ${FILE%.nc}_noTEOS10var.nc
   #mv -f ${FILE%.nc}_noTEOS10var.nc $FILE
done
