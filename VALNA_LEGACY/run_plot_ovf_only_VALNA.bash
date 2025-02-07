#!/bin/bash

if [ $# -eq 0 ] ; then echo 'need a [KEYWORD] (will be inserted inside the figure title and output name) and a list of id [RUNIDS RUNID ...] (definition of line style need to be done in RUNID.db)'; exit; fi

# module load scitools #used within Met Office only

#same as run_plot_VALNA.bash but only plots the overflow NA metrics in each location

KEY=${1}
FREQ=${2}
RUNIDS=${@:3}

#existing data stored in:
DATPATH=${DATADIR}/VALNA/DATA

echo '  '

OBS_NAME=osnap
# Irminger basin only
# salinity
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection_Irmin_basin_only.nc -var S_av_27_8_rho -title "Mean S>27.8 kg/m3 (Irmin b, osnap)" -dir ${DATPATH} -o ${KEY}_OSN_IRM_S -obs OBS/OVF_S_${OBS_NAME}_irminger_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# temp
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection_Irmin_basin_only.nc -var T_av_27_8_rho -title "Mean T>27.8 kg/m3 (Irmin b, osnap)" -dir ${DATPATH} -o ${KEY}_OSN_IRM_T -obs OBS/OVF_T_${OBS_NAME}_irminger_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi

OBS_NAME=osnap
# Icelandic basin only
# salinity
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection_Icel_basin_only.nc -var S_av_27_8_rho -title "Mean S>27.8 kg/m3 (Icel b, ${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_OSN_ICE_S -obs OBS/OVF_S_${OBS_NAME}_icel_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# temp
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection_Icel_basin_only.nc -var T_av_27_8_rho -title "Mean T>27.8 kg/m3 (Icel b, ${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_OSN_ICE_T -obs OBS/OVF_T_${OBS_NAME}_icel_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi


OBS_NAME=eel
# salinity
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var S_av_27_8_rho -title "Mean S>27.8 kg/m3 (${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_EEL_S -obs OBS/OVF_S_${OBS_NAME}_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# temp
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var T_av_27_8_rho -title "Mean T>27.8 kg/m3 (${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_EEL_T -obs OBS/OVF_T_${OBS_NAME}_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi


OBS_NAME=ovide
# Icelandic basin only
# salinity
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var S_av_27_8_rho -title "Mean S>27.8 kg/m3 (Icel b, ${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_OVI_S -obs OBS/OVF_S_${OBS_NAME}_icel_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# temp
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var T_av_27_8_rho -title "Mean T>27.8 kg/m3 (Icel b, ${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_OVI_T -obs OBS/OVF_T_${OBS_NAME}_icel_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi



OBS_NAME=latrabjarg_clim
# salinity
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var S_av_27_8_rho -title "Mean S>27.8 kg/m3 (${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_LAT_S -obs OBS/OVF_S_${OBS_NAME}_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# temp
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var T_av_27_8_rho -title "Mean T>27.8 kg/m3 (${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_LAT_T -obs OBS/OVF_T_${OBS_NAME}_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi


OBS_NAME=kogur
# salinity
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var S_av_27_8_rho -title "Mean S>27.8 kg/m3 (${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_KOG_S -obs OBS/OVF_S_${OBS_NAME}_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# temp
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var T_av_27_8_rho -title "Mean T>27.8 kg/m3 (${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_KOG_T -obs OBS/OVF_T_${OBS_NAME}_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi


OBS_NAME=hansen
# salinity
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var S_av_27_8_rho -title "Mean S>27.8 kg/m3 (${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_HAN_S -obs OBS/OVF_S_${OBS_NAME}_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# temp
python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var T_av_27_8_rho -title "Mean T>27.8 kg/m3 (${OBS_NAME})" -dir ${DATPATH} -o ${KEY}_HAN_T -obs OBS/OVF_T_${OBS_NAME}_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi


# crop figure (to rm legend)
convert ${KEY}_OSN_IRM_S.png                 -crop 1240x1040+0+0 tmp01.png
convert ${KEY}_OSN_IRM_T.png                 -crop 1240x1040+0+0 tmp02.png
convert ${KEY}_OSN_ICE_S.png                 -crop 1240x1040+0+0 tmp03.png
convert ${KEY}_OSN_ICE_T.png                 -crop 1240x1040+0+0 tmp04.png

convert ${KEY}_EEL_S.png                     -crop 1240x1040+0+0 tmp05.png
convert ${KEY}_EEL_T.png                     -crop 1240x1040+0+0 tmp06.png
convert ${KEY}_OVI_S.png                     -crop 1240x1040+0+0 tmp07.png
convert ${KEY}_OVI_T.png                     -crop 1240x1040+0+0 tmp08.png

convert ${KEY}_LAT_S.png                     -crop 1240x1040+0+0 tmp09.png
convert ${KEY}_LAT_T.png                     -crop 1240x1040+0+0 tmp10.png
convert ${KEY}_KOG_S.png                     -crop 1240x1040+0+0 tmp11.png
convert ${KEY}_KOG_T.png                     -crop 1240x1040+0+0 tmp12.png

convert ${KEY}_HAN_S.png                     -crop 1240x1040+0+0 tmp13.png
convert ${KEY}_HAN_T.png                     -crop 1240x1040+0+0 tmp14.png

convert FIGURES/box_NA_overflows.png -trim -bordercolor White -border 30 tmp15.png

# trim figure (remove white area)
convert legend.png      -trim    -bordercolor White -border 20 tmp16.png
convert runidname.png   -trim    -bordercolor White -border 20 tmp17.png

# compose the image
convert \( tmp01.png tmp02.png tmp03.png tmp04.png +append \) \
        \( tmp05.png tmp06.png tmp07.png tmp08.png +append \) \
        \( tmp09.png tmp10.png tmp11.png tmp12.png +append \) \
        \( tmp13.png tmp14.png tmp15.png +append \) \
           tmp16.png tmp17.png -append -trim -bordercolor White -border 50 $KEY.png


# save figure
mv ${KEY}_*.png FIGURES/.
mv ${KEY}_*.txt FIGURES/.
mv tmp13.png FIGURES/${KEY}_legend.png
mv tmp14.png FIGURES/${KEY}_runidname.png

# clean
rm tmp??.png
rm runidname.png
rm legend.png

#display
display -resize 30% $KEY.png
