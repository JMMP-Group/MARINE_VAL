#!/bin/bash
#
# Script to reset NEMO time_counter values for integrations
# starting before 1900.
#
# Dave S.
# July 2026
#

start_year=$1
shift
infiles=$*

let secs_per_year=31554000
let secs_per_6mon=15777000

# Starting value is 6 months in seconds,
# ie. halfway through first year, then
# we increment by years.
let timevalue=$secs_per_6mon
for file in $infiles
do
    echo "Working on $file"
    # the "-o $file" seems to be necessary to avoid HDF5 errors...
    ncatted -O -a units,time_counter,m,c,"seconds since ${start_year}-01-01 00:00:00" $file -o $file
    ncatted -O -a time_origin,time_counter,m,c,"${start_year}-01-01 00:00:00" $file -o $file
    ncatted -O -a units,time_centered,m,c,"seconds since ${start_year}-01-01 00:00:00" $file -o $file
    ncatted -O -a time_origin,time_centered,m,c,"${start_year}-01-01 00:00:00" $file -o $file
    # the trailing dot after ${timevalue} forces it to NC_DOUBLE type
    ncap2 -O -s "time_counter(:)=${timevalue}.;" $file $file
    ncap2 -O -s "time_centered(:)=${timevalue}.;" $file $file
    # not sure using bc is strictly necessary here but probably a bit safer in case the numbers get huge.
    timevalue="$( bc <<<"$timevalue + $secs_per_year" )"
done

exit 0


