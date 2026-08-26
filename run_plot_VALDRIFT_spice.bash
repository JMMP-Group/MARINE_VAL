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
     W) WINDOW="-W ${OPTARG}" ;;
     X) YLIMITS_OHCFLUX="-X ${OPTARG}" ;;
     Y) YLIMITS_MEANT="-Y ${OPTARG}" ;;
     Z) YLIMITS_MEANS="-Z ${OPTARG}" ;;
  esac   
done
shift `expr $OPTIND - 1`  
KEY=${1}
FREQ=${2}
RUNIDS=${@:3}
echo "KEY FREQ RUNIDS : $KEY $FREQ $RUNIDS"

# need to put some inverted commas in where we have multiple arguments to a flag
if [[ -n "$YLIMITS_OHCFLUX" ]]
then
    YLIMITS_OHCFLUX=$(echo $YLIMITS_OHCFLUX | sed 's/X /X \"/g')\"
fi
if [[ -n "$YLIMITS_MEANT" ]]
then
    YLIMITS_MEANT=$(echo $YLIMITS_MEANT | sed 's/Y /Y \"/g')\"
fi
if [[ -n "$YLIMITS_MEANS" ]]
then
    YLIMITS_MEANS=$(echo $YLIMITS_MEANS | sed 's/Z /Z \"/g')\"
fi
    
for AREA in GLOBAL ARC NATL SATL NPAC SPAC IND SO
do
    ${SCRPATH}/sbrun -d$PWD -m50G ./run_plot_VALDRIFT.bash -A ${AREA} ${WINDOW} \
	   ${YLIMITS_OHCFLUX} ${YLIMITS_MEANT} ${YLIMITS_MEANS} ${KEY} ${FREQ} ${RUNIDS}
done

exit 0
