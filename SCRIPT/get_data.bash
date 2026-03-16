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

# Source `param.bash` and get the switches 
PARAM_FILE=${MARINE_VAL}/param.bash
source "$PARAM_FILE"
: ${useTEOS10:=1}  # Is this NEMO version using TEOS10 (default = yes/1) or EOS80 (0) 
: ${usePRENEMO4:=0} # Is the NEMO version pre-NEMO4 (default = no/0)

# Read variable names from the namelist (nam_cdf_names), if they exist replace the defaults
if [[ -n "${NMLPATH}" && -f "${NMLPATH}" ]]; then
   cn_votemper=$(sed -n "s/.*cn_votemper\s*=\s*'\([^']*\)'.*/\1/p" "${NMLPATH}")
   cn_vosaline=$(sed -n "s/.*cn_vosaline\s*=\s*'\([^']*\)'.*/\1/p" "${NMLPATH}")
   cn_somxl010=$(sed -n "s/.*cn_somxl010\s*=\s*'\([^']*\)'.*/\1/p" "${NMLPATH}")
fi
# fallback variable names as used in SCRIPT's
: ${cn_votemper:=thetao_pot}
: ${cn_vosaline:=so_pra}
: ${cn_somxl010:=somxzint1}


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

# Determine which files need to be downloaded 
for MFILE in ${FILE_LST}; do
   FILE=${MFILE#*${CRUM_FREQ}.nc.file/}
   if [ ! -f $FILE ]; then
      #echo "downloading file ${FILE}"
      MOO_GET_LIST="$MOO_GET_LIST $MFILE"
   fi
done


if [[ -n "$MOO_GET_LIST" ]];then 
   echo "Executing command : moo filter $FILTER $MOO_GET_LIST ."
   moo filter $FILTER $MOO_GET_LIST . 

   FILE=${FILE#*${CRUM_FREQ}.nc.file/}
   echo $FILE
   # Set standard_name for depth coordinate so Iris will recognise it:
   [[ "$FILE" =~ *grid-T\.nc ]] && depvar="deptht"
   [[ "$FILE" =~ *grid-U\.nc ]] && depvar="depthu"
   [[ "$FILE" =~ *grid-V\.nc ]] && depvar="depthv"
   # In NEMO3.6 the following causes an error later-on as it creates another "depth" variable
   if [[ "${usePRENEMO4:-0}" == "0" ]]; then
      ncatted -a standard_name,"${depvar}",c,c,"depth" "$FILE"
   fi

   # Renaming variables to match what's used in SCRIPT's
   if [[ "${useTEOS10:-1}" == "0" ]]; then 
      echo "Model used EOS80"
      if [[ $FILE == *grid-T.nc ]]; then         
         ncks -v ${cn_votemper} $FILE tmp.nc
         ncrename -v "${cn_votemper},thetao_pot" tmp.nc
         ncks -A tmp.nc $FILE
         rm -f tmp.nc

         ncks -v ${cn_vosaline} $FILE tmp.nc
         ncrename -v "${cn_vosaline},so_pra" tmp.nc
         ncks -A tmp.nc $FILE
         rm -f tmp.nc
      fi
   elif  [[ "${useTESO10:-1}" == "1" ]]; then 
      echo "Model used TEOS10"
      if [[ $FILE == *grid-T.nc ]]; then   
         echo ${cn_votemper}
         ncks -v ${cn_votemper} $FILE tmp.nc
         ncrename -v "${cn_votemper},thetao_con" tmp.nc
         ncks -A tmp.nc $FILE
         rm -f tmp.nc

         echo ${cn_vosaline}
         ncks -v ${cn_vosaline} $FILE tmp.nc
         ncrename -v "${cn_vosaline},so_abs" tmp.nc
         ncks -A tmp.nc $FILE
         rm -f tmp.nc
      fi
   fi
   ncks -v ${cn_somxl010} $FILE tmp.nc
   ncrename -v "${cn_somxl010},somxzint1" tmp.nc 
   ncks -A tmp.nc $FILE
   rm -f tmp.nc
fi



for MFILE in ${FILE_LST}; do
   FILE=${MFILE#*${CRUM_FREQ}.nc.file/}
   if [ -f $FILE ]; then 
      TIME=$(ncdump -h $FILE | grep UNLIMITED | sed -e 's/(//' | awk '{print $6}')
#      SIZEMASS=`moo ls -l $MFILE | awk '{ print $5}'`
#      SIZESYST=`    ls -l $FILE  | awk '{ print $5}'`
#      if [[ $SIZEMASS -ne $SIZESYST ]]; then echo " $FILE is corrupted "; rm $FILE; fi
      if [[ $TIME -eq 0 ]]; then echo " $FILE is corrupted "; rm $FILE; fi

      if [[ "${GRID_CAT}" == "T" ]]; then
         Tv=$(ncdump -h $FILE | grep float | grep thetao_pot | cut -d' ' -f2 | cut -d'(' -f1 )
         Sv=$(ncdump -h $FILE | grep float | grep so_pra | cut -d' ' -f2 | cut -d'(' -f1 )
         echo "Tv= " $Tv ", Sv= " $Sv
         
         if [[ "$Tv" == "thetao_pot" && "$Sv" == "so_pra" ]]; then
            echo 'EOS80: nothing to do ... '
            EOS80=1; 
         else 
            Tv=$(ncdump -h $FILE | grep float | grep thetao_con | cut -d' ' -f2 | cut -d'(' -f1 )
            Sv=$(ncdump -h $FILE | grep float | grep so_abs | cut -d' ' -f2 | cut -d'(' -f1 )
            if [[ "$Tv" == "thetao_con" && "$Sv" == "so_abs" ]]; then
               echo 'converting to EOS80'
               CONVERT_EOS_LIST="$CONVERT_EOS_LIST $FILE"
               TEOS10=1; 
            else 
               echo 'Check TS variables, removing file'
               Tv=$(ncdump -h $FILE | grep float | grep thet | cut -d' ' -f2 | cut -d'(' -f1 )
               Sv=$(ncdump -h $FILE | grep float | grep so | cut -d' ' -f2 | cut -d'(' -f1 )
               echo "Tv= " $Tv ", Sv= " $Sv
               rm $FILE
            fi
         
         fi

      fi
   fi

done


for FILE in $CONVERT_EOS_LIST;do
   python3 ${EXEPATH}/SCRIPT/convert_nemo_eos80.py $FILE
   #ncks -x -v thetao_con,so_abs $FILE -o ${FILE%.nc}_noTEOS10var.nc
   #mv -f ${FILE%.nc}_noTEOS10var.nc $FILE
done
