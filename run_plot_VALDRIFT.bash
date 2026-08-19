#!/bin/bash -l

if [ $# -eq 0 ] ; then echo 'need a [KEYWORD] (will be inserted inside the figure title and output name) and a list of id [RUNIDS RUNID ...] (definition of line style need to be done in RUNID.db)'; exit; fi

. ./param.bash

ZERO_ORIGIN_FLAG=""
WINDOW_FLAG=""
while getopts ZW:Y: opt ; do
  case $opt in
     Z) ZERO_ORIGIN_FLAG=" -force_zero_origin" ;;
     # window (integer > 1) for rolling mean
     W) WINDOW_FLAG=" -window ${OPTARG}" ;;
     Y) YLIMITS=" -ylim ${OPTARG}" ;;
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
# Include the 0.7 factor here to get equivalent TOA flux
# rather than global atmos-ocean flux. 
base_factor=$(echo "scale=12; 0.7/${period_secs}" | bc)
# reset FREQ because filenames are always labelled "1y"
FREQ="1y"

# Global heat content as equivalent TOA heat flux.
factor=$base_factor
if [[ $runTSdrift == 1 ]]; then
   echo 'plot global heat content as equivalent flux'
   python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanTS-GLOBAL_nemo_*${FREQ}*grid-T.nc -var heat_content_per_unit_area \
	  -diff -sf ${factor} -title "Global implied TOA (W/m2)" -dir ${DATPATH} -o "${KEY}_heatc_eqflx-global" \
	  $ZERO_ORIGIN_FLAG $WINDOW_FLAG $YLIMITS
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# Global heat content top 1000m as equivalent TOA heat flux.
factor=$base_factor
if [[ $runTSdrift == 1 ]]; then
   echo 'plot global heat content top 1000m as equivalent flux'
   python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanTS-GLOBAL_maxdepth-1000_nemo_*${FREQ}*grid-T.nc -var heat_content_per_unit_area \
	  -diff -sf ${factor} -title "Global top 1000m implied TOA (W/m2)" -dir ${DATPATH} -o "${KEY}_heatc_eqflx-global-top-1000m" \
	  $ZERO_ORIGIN_FLAG $WINDOW_FLAG $YLIMITS
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# Global heat content below 1000m as equivalent TOA heat flux.
#   Add scaling to account for difference in:
#   top area of sub-1000m volume (in "meanTS" file) and
#   area of global ocean (in "meanTS_GLOBAL" file)
runid0=$(echo $RUNIDS | cut -d" " -f1)
file_meanTS=$(ls ${DATPATH}/${runid0}/*meanTS-GLOBAL_mindepth-1000_nemo_*${FREQ}*grid-T.nc | head -n1)
if [[ -f $file_meanTS ]];then
    surf_area=$(ncdump $file_meanTS | grep "surface_area =" | cut -d" " -f4)
else
    echo "Error: could not find any files matching *meanTS-GLOBAL_mindepth-1000_nemo_*${FREQ}*grid-T.nc"
    exit 15
fi
file_meanTS_GLOBAL=$(ls ${DATPATH}/${runid0}/*meanTS-GLOBAL_nemo_*${FREQ}*grid-T.nc | head -n1)
if [[ -f $file_meanTS ]];then
    surf_area_glob=$(ncdump $file_meanTS_GLOBAL | grep "surface_area =" | cut -d" " -f4)
else
    echo "Error: could not find any files matching *meanTS-GLOBAL_nemo_*${FREQ}*grid-T.nc"
    exit 15
fi
factor=$(echo "scale=12;${base_factor}*${surf_area}/${surf_area_glob}" | bc)
if [[ $runTSdrift == 1 ]]; then
   echo 'plot global heat content below 1000m as equivalent flux'
   python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanTS-GLOBAL_mindepth-1000_nemo_*${FREQ}*grid-T.nc -var heat_content_per_unit_area \
	  -diff -sf ${factor} -title "Global below 1000m implied TOA (W/m2)" -dir ${DATPATH} -o "${KEY}_heatc_eqflx-global-below-1000m" \
	  $ZERO_ORIGIN_FLAG $WINDOW_FLAG $YLIMITS
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
