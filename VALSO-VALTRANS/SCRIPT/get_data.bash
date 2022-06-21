#!/bin/bash -l
#SBATCH --mem=500
#SBATCH --time=60
#SBATCH --ntasks=1

CONFIG=$1
RUNID=$2
FREQ=$3
TAG=$4
GRID=$5

. param.bash
. ${SCRPATH}/common.bash

cd ${DATPATH}

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

if   [ $FREQ == '5d'  ]; then FILE_LST=`moo ls moose:/crum/$RUNID/${CRUM_FREQ}.nc.file/*_${FREQ}_${GRID}_${TAG}.nc`
elif [ $FREQ == 'i1m' ]; then FILE_LST=`moo ls moose:/crum/$RUNID/${CRUM_FREQ}.nc.file/*_1m_${TAG}.nc`
else FILE_LST=`moo ls moose:/crum/$RUNID/${CRUM_FREQ}.nc.file/*_${FREQ}_${TAG}*_${GRID}.nc`;
fi

for MFILE in `echo ${FILE_LST}`; do
   FILE=${MFILE#*${CRUM_FREQ}.nc.file/}
   if [ -f $FILE ]; then 
      TIME=`ncdump -h $FILE | grep UNLIMITED | sed -e 's/(//' | awk '{print $6}'`
#      SIZEMASS=`moo ls -l $MFILE | awk '{ print $5}'`
#      SIZESYST=`    ls -l $FILE  | awk '{ print $5}'`
#      if [[ $SIZEMASS -ne $SIZESYST ]]; then echo " $FILE is corrupted "; rm $FILE; fi
      if [[ $TIME -eq 0 ]]; then echo " $FILE is corrupted "; rm $FILE; fi
   fi
   if [ ! -f $FILE ]; then
      echo "downloading file ${FILE}"
      moo filter $FILTER $MFILE .
   fi
done
