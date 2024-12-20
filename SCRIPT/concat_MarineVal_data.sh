#!/bin/bash
#
# Append VALSO files from one run onto the end of another run. 
#
# Gather all the files from the two jobs in one directory first,
# then run this script in the directory, specifying the names of
# the two model runs as the first two arguments and the date offset
# in years as the third argument. The files from the second model
# run specified will have the date in their filenames and in the 
# netcdf meta data incremented by the specified amount, then those
# files are relabelled with the name of the first model run specified.
#
# DS. June 2022
#

job1=$(echo $1 | sed "s/u-//g")
job2=$(echo $2 | sed "s/u-//g")
years_offset=$3
sample_filestem=$4 # filestem of files to get datelist from
if [[ -z "$sample_filestem" ]];then sample_filestem="WG_nemo";fi

# assume 360-day calendar (coupled runs)
let seconds_offset=$((86400*360*${years_offset}))
for file in *${job2}*nc
do 
  echo $file
  ncap2 -s "time_centered=time_centered+${seconds_offset}" $file -o ${file%.nc}_ncap2.nc
  mv -f ${file%.nc}_ncap2.nc $file
done

let date_offset=$((10000*${years_offset}))
echo "" > datelist.txt
for file in *${job2}*
do 
  if [[ $file =~ .*([0-9]{8}).* ]]
    then echo ${BASH_REMATCH[1]} >> datelist.txt
  fi
done
datelist=$(cat datelist.txt | sort -r | uniq)

for date1 in $datelist
do 
  let date2=${date1}+${date_offset}
  echo ${date1} ${date2}
  for file in $(ls *${job2}*${date1}*)
  do 
    mv $file $(echo $file | sed "s/${date1}/${date2}/g")
  done
done

for file in *${job2}*
do 
  mv $file $(echo $file | sed "s/${job2}/${job1}/g")
done

exit 0
