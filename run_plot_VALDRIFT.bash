#!/bin/bash -l

if [ $# -eq 0 ] ; then echo 'need a [KEYWORD] (will be inserted inside the figure title and output name) and a list of id [RUNIDS RUNID ...] (definition of line style need to be done in RUNID.db)'; exit; fi

. ./param.bash

ZERO_ORIGIN_FLAG=""
WINDOW_FLAG=""
while getopts ZW:X:Y:Z: opt ; do
  case $opt in
     Z) ZERO_ORIGIN_FLAG=" -force_zero_origin" ;;
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

# Work out the base scale factor once for all.
# This doesn't include the surface area scaling.
period_yrs=$(echo $FREQ | rev | cut -c2- | rev)
period_secs=$(echo "scale=8; ${period_yrs}*360*86400" | bc)
# Include the 0.7 factor here to get equivalent TOA flux
# rather than global atmos-ocean flux. 
base_factor=$(echo "scale=12; 0.7/${period_secs}" | bc)
# reset FREQ because filenames are always labelled "1y"
FREQ="1y"

if [[ $runTSdrift == 1 ]]
then
    AREAS="GLOBAL"
fi
if [[ $runTSdriftBasin == 1 ]]
then
    AREAS="GLOBAL ARC NATL SATL NPAC SPAC IND SO"
fi
if [[ $runTSdrift != 1 && $runTSdriftBasin != 1 ]]
then
    echo "Nothing to do: runTSdrift=0 and runTSdriftBasin=0."
    exit 11
fi

for AREA in $AREAS
do
   # Global mean SST.
   if [[ "${AREA}" == "GLOBAL" ]]; then
      echo 'plot global mean SST'
      python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *Tprof-GLOBAL_nemo_*${FREQ}*grid-T.nc \
	     -var thetao_pot -lev 0 -title "Global mean SST (deg C)" -dir ${DATPATH} \
	     -o "${KEY}_SST-global" -yfmt "%.3f" $ZERO_ORIGIN_FLAG $WINDOW_FLAG $YLIMITS_MEANT
      if [[ $? -ne 0 ]]; then exit 42; fi
   fi

   for LAYER in "full_depth" "0-1000m" "1000m+"
   do
      case $LAYER in
         "full_depth")
	    layer_suffix=""
	    layer_label=""
	    ;;
	 "0-1000m")
	    layer_suffix="_maxdepth-1000"
	    layer_label="0-1000m" 
            ;;
	 "1000m+")
	    layer_suffix="_mindepth-1000"
	    layer_label="1000m+" 
            ;;
      esac	 

      # Area heat content as equivalent TOA heat flux.
      if [[ "$AREA" != "GLOBAL" || "$LAYER" == "1000m+" ]]
      then
	 # We need to scale the top area of this volume by the surface area of the ocean.
         # surf_area_glob should have already been calculated at this point.
         file_meanTS=$(ls ${DATPATH}/${runid0}/*meanTS-${AREA}${layer_suffix}_nemo_*${FREQ}*grid-T.nc | head -n1)
         if [[ -e $file_meanTS ]];then
            surf_area=$(ncdump $file_meanTS | grep "surface_area =" | cut -d" " -f4)
         else
            echo "Error: could not find any files matching *meanTS-GLOBAL_mindepth-1000_nemo_*${FREQ}*grid-T.nc" 
            exit 15
         fi
         factor=$(echo "scale=12;${base_factor}*${surf_area}/${surf_area_glob}" | bc)
      else
         factor=$base_factor
      fi
      echo "plot $AREA $LAYER heat content as equivalent flux"
      python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanTS-${AREA}${layer_suffix}_nemo_*${FREQ}*grid-T.nc \
   	     -var heat_content_per_unit_area -diff -sf ${factor} -title "$AREA ${layer_label} implied TOA (W/m2)" -dir ${DATPATH} \
	     -o "${KEY}_heatc_eqflx-${AREA}${layer_suffix}" $ZERO_ORIGIN_FLAG $WINDOW_FLAG $YLIMITS_OHCFLUX
      if [[ $? -ne 0 ]]; then exit 42; fi
      if [[ "$AREA" == "GLOBAL" && "$LAYER" == "full_depth" ]]
      then
         # Calculate surface area of global ocean to use to scale other regions. 
         file_meanTS_GLOBAL=$(ls ${DATPATH}/${runid0}/*meanTS-GLOBAL_nemo_*${FREQ}*grid-T.nc | head -n1)
         if [[ -e $file_meanTS_GLOBAL ]];then
            surf_area_glob=$(ncdump $file_meanTS_GLOBAL | grep "surface_area =" | cut -d" " -f4)
         else
            echo "Error: could not find any files matching ${DATPATH}/${runid0}/*meanTS-GLOBAL_nemo_*${FREQ}*grid-T.nc"
            exit 15
         fi
      fi
	 
      # Volume mean temperature.
      echo "plot ${AREA} ${LAYER} volume mean temperature"
      python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanTS-${AREA}${layer_suffix}_nemo_*${FREQ}*grid-T.nc \
   	     -var thetao_pot -title "$AREA $layer_label mean temperature (deg C)" -dir ${DATPATH} \
	     -o "${KEY}_meanT-${AREA}${layer_suffix}" -yfmt "%.3f" $ZERO_ORIGIN_FLAG $WINDOW_FLAG $YLIMITS_MEANT
      if [[ $? -ne 0 ]]; then exit 42; fi

      # Volume mean salinity.
      echo "plot ${AREA} ${LAYER} volume mean salinity"
      python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *meanTS-${AREA}${layer_suffix}_nemo_*${FREQ}*grid-T.nc \
   	     -var so_pra -title "$AREA $layer_label mean salinity (psu)" -dir ${DATPATH} \
	     -o "${KEY}_meanS-${AREA}${layer_suffix}" -yfmt "%.3f" $ZERO_ORIGIN_FLAG $WINDOW_FLAG $ZLIMITS_MEANT
      if [[ $? -ne 0 ]]; then exit 42; fi

   # end of loop on layers
   done

   # crop figure (rm legend)
   convert ${KEY}_heatc_eqflx-${AREA}.png                  -crop 1240x1040+0+0 tmp01.png
   convert ${KEY}_heatc_eqflx-${AREA}_maxdepth-1000.png    -crop 1240x1040+0+0 tmp02.png
   convert ${KEY}_heatc_eqflx-${AREA}_mindepth-1000.png    -crop 1240x1040+0+0 tmp03.png
   convert ${KEY}_meanT-${AREA}.png                        -crop 1240x1040+0+0 tmp04.png
   convert ${KEY}_meanT-${AREA}_maxdepth-1000.png          -crop 1240x1040+0+0 tmp05.png
   convert ${KEY}_meanT-${AREA}_mindepth-1000.png          -crop 1240x1040+0+0 tmp06.png
   convert ${KEY}_meanS-${AREA}.png                        -crop 1240x1040+0+0 tmp07.png
   convert ${KEY}_meanS-${AREA}_maxdepth-1000.png          -crop 1240x1040+0+0 tmp08.png
   convert ${KEY}_meanS-${AREA}_mindepth-1000.png          -crop 1240x1040+0+0 tmp09.png
   if [[ "$AREA" == "GLOBAL" ]]
   then
      convert ${KEY}_SST-global.png                           -crop 1240x1040+0+0 tmp10.png
   fi
      
   # trim figure (remove white area)
   #convert FIGURES/box_VALSO.png -trim -bordercolor White -border 40 tmp09.png
   convert legend.png      -trim -bordercolor White -border 20 tmp11.png
   convert runidname.png   -trim -bordercolor White -border 20 tmp12.png

   # compose the image
   if [[ "$AREA" == "GLOBAL" ]]
   then
      convert \( tmp01.png tmp02.png tmp03.png +append \) \
              \( tmp10.png +append \) \
              \( tmp04.png tmp05.png tmp06.png +append \) \
              \( tmp07.png tmp08.png tmp09.png +append \) \
                 tmp11.png tmp12.png -append -trim -bordercolor White -border 40 ${KEY}_${AREA}.png
   else
      convert \( tmp01.png tmp02.png tmp03.png +append \) \
              \( tmp04.png tmp05.png tmp06.png +append \) \
              \( tmp07.png tmp08.png tmp09.png +append \) \
                 tmp11.png tmp12.png -append -trim -bordercolor White -border 40 ${KEY}_${AREA}.png
   fi
      
   # save figure
   mv ${KEY}_heat*.png ${KEY}_mean*.png ${KEY}_SST*.png FIGURES/.
   mv ${KEY}_*.txt FIGURES/.
   mv tmp11.png FIGURES/${KEY}_legend.png
   mv tmp12.png FIGURES/${KEY}_runidname.png

   # clean
   rm tmp??.png

   # display
   display -resize 30% ${KEY}_${AREA}.png

# end of loop on areas    
done
            


