#!/bin/bash
#
# Submit VALDRIFT plotting to Spice to generate the
# different pages for different areas in parallel.
#
# DS. Aug 2026
#

. ./param.bash

WINDOW_FLAG=""
YLIMITS_OHCFLUX=""
YLIMITS_MEANT=""
YLIMITS_MEANS=""
while getopts W:X:Y:Z: opt ; do
  case $opt in
     # window (integer > 1) for rolling mean
     W) WINDOW_FLAG=" -window ${OPTARG}" ;;
     X) YLIMITS_OHCFLUX=" -ylim ${OPTARG}" ;;
     Y) YLIMITS_MEANT=" -ylim ${OPTARG}" ;;
     Z) YLIMITS_MEANS=" -ylim ${OPTARG}" ;;
  esac   
done
shift `expr $OPTIND - 1`  
KEY=${1}
FREQ=${2}
RUNIDS=${@:3}
runid0=$(echo $RUNIDS | cut -d" " -f1)

for AREA in GLOBAL ARC NATL SATL NPAC SPAC IND SO
do
    ${SCRPATH}/sbrun -d$PWD -m50G ./run_plot_VALDRIFT.bash -A ${AREA} ${WINDOW_FLAG} \
	   ${YLIMITS_OHCFLUX} ${YLIMITS_MEANT} ${YLIMITS_MEANS} ${KEY} ${FREQ} ${RUNIDS}
done

exit 0
