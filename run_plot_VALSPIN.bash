#!/bin/bash -l

if [ $# -eq 0 ] ; then echo 'need a [KEYWORD] (will be inserted inside the figure title and output name) and a list of id [RUNIDS RUNID ...] (definition of line style need to be done in RUNID.db)'; exit; fi

. ./param.bash

ZERO_ORIGIN_FLAG=""
WINDOW_FLAG=""
while getopts ZW: opt ; do
  case $opt in
     Z) ZERO_ORIGIN_FLAG=" -force_zero_origin" ;;
     # window (integer > 1) for rolling mean
     W) WINDOW_FLAG=" -window ${OPTARG}" ;;
  esac   
done
shift `expr $OPTIND - 1`  
KEY=${1}
FREQ=${2}
RUNIDS=${@:3}

FREQs="1s"

# Work out the scale factor once for all.
period_yrs=$(echo $FREQ | rev | cut -c2- | rev)
period_secs=$(echo "scale=8; ${period_yrs}*360*86400" | bc)
# reset FREQ because filenames are always labelled "1y"
FREQ="1y"
# heat capacity and density constants from NEMO:
heat_cap=3991.0
density=1026.0
factor=$(echo "scale=12;${heat_cap}*${density}/${period_secs}" | bc)
echo "factor is $factor"

# Global heat content as equivalent heat flux through surface.
if [[ $runTprof == 1 ]]; then
   echo 'plot global heat content as equivalent flux'
   python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanT-global_nemo_*${FREQ}*grid-T.nc -var thetao_pot_depth_integral -diff -sf ${factor} -title "Global implied heat flux (W/m2)" -dir ${DATPATH} -o "${KEY}_heatc_eqflx-global" $ZERO_ORIGIN_FLAG $WINDOW_FLAG
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# Global heat content top 1000m as equivalent heat flux through surface.
if [[ $runTprof == 1 ]]; then
   echo 'plot global heat content top 1000m as equivalent flux'
   python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanT-global-top-1000m_nemo_*${FREQ}*grid-T.nc -var thetao_pot_depth_integral -diff -sf ${factor} -title "Global top 1000m implied heat flux (W/m2)" -dir ${DATPATH} -o "${KEY}_heatc_eqflx-global-top-1000m" $ZERO_ORIGIN_FLAG $WINDOW_FLAG
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# Global heat content below 1000m as equivalent heat flux through surface.
if [[ $runTprof == 1 ]]; then
   echo 'plot global heat content below 1000m as equivalent flux'
   python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanT-global-below-1000m_nemo_*${FREQ}*grid-T.nc -var thetao_pot_depth_integral -diff -sf ${factor} -title "Global below 1000m implied heat flux (W/m2)" -dir ${DATPATH} -o "${KEY}_heatc_eqflx-global-below-1000m" $ZERO_ORIGIN_FLAG $WINDOW_FLAG
   if [[ $? -ne 0 ]]; then exit 42; fi
fi


# crop figure (rm legend)
convert ${KEY}_heatc_eqflx-global.png                   -crop 1240x1040+0+0 tmp01.png
convert ${KEY}_heatc_eqflx-global-top-1000m.png         -crop 1240x1040+0+0 tmp02.png
convert ${KEY}_heatc_eqflx-global-below-1000m.png       -crop 1240x1040+0+0 tmp03.png

# trim figure (remove white area)
#convert FIGURES/box_VALSO.png -trim -bordercolor White -border 40 tmp09.png
convert legend.png      -trim -bordercolor White -border 20 tmp10.png
convert runidname.png   -trim -bordercolor White -border 20 tmp11.png

# compose the image
convert \( tmp01.png tmp02.png tmp03.png +append \) \
           tmp10.png tmp11.png -append -trim -bordercolor White -border 40 $KEY.png

# save figure
mv ${KEY}_*.png FIGURES/.
mv ${KEY}_*.txt FIGURES/.
mv tmp10.png FIGURES/${KEY}_legend.png
mv tmp11.png FIGURES/${KEY}_runidname.png

# clean
rm tmp??.png

# display
display -resize 30% $KEY.png
