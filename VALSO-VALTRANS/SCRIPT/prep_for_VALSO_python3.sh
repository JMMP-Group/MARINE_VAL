#!/bin/bash
#

for file in ?G*psi.nc
do
  echo $file
  ncatted -a valid_min,max_sobarstf,d,, -a valid_max,max_sobarstf,d,, $file
done

for file in WMXL*nc
do 
  echo $file
  ncatted -a valid_max,max_somxzint1,d,, $file
done

exit 0
