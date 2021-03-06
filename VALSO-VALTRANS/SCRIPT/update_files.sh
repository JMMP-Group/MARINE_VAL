#!/bin/bash
#
# Append VALSO files from one run onto the end of another run. 
#
# DS. June 2022
#

job1=$(echo $1 | sed "s/u-//g")
job2=$(echo $2 | sed "s/u-//g")
years_offset=$3

# assume 360-day calendar (coupled runs)
let seconds_offset=$((86400*360*${years_offset}))
echo "seconds_offset is $seconds_offset"
for file in *${job2}*nc
do 
  echo $file
  ncap2 -s "time_centered=time_centered+${seconds_offset}" $file -o ${file%.nc}_ncap2.nc
  mv -f ${file%.nc}_ncap2.nc $file
done

let date_offset=$((10000*${years_offset}))
datelist=$(ls -r WMXL*${job2}* | cut -c 21-28)
for date1 in $datelist
do 
  let date2=${date1}+${date_offset}
  echo ${date1} ${date2}
  for file in $(ls *${job2}*${date1}*nc)
  do 
    mv $file $(echo $file | sed "s/${date1}/${date2}/g")_NEWDATE
  done
done
datelist=$(ls -r vnemo*${job2}* | cut -c 17-24)
for date1 in $datelist
do 
  let date2=${date1}+${date_offset}
  echo ${date1} ${date2}
  for file in $(ls *${job2}*${date1}*nc)
  do 
    mv $file $(echo $file | sed "s/${date1}/${date2}/g")_NEWDATE
  done
done

for file in *_NEWDATE
do 
  mv -f $file $(echo $file | sed 's/_NEWDATE//g')
done

if [[ "${job1}" != "${job2}" ]]
then
  for file in *${job2}*
  do 
    mv $file $(echo $file | sed "s/${job2}/${job1}/g")
  done
fi

exit 0
