#!/bin/bash

if [ $# -eq 0 ] ; then echo 'need a [KEYWORD] (will be inserted inside the figure title and output name) and a list of id [RUNIDS RUNID ...] (definition of line style need to be done in RUNID.db)'; exit; fi

. ./param.bash

KEY=${1}
FREQ=${2}
RUNIDS=${@:3}

FREQs="1s"

# ACC
# Drake
echo 'plot ACC time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *ACC_nemo_*${FREQ}*1.nc -var vtrp -sf -1 -title "ACC transport (Sv)" -dir ${DATPATH} -o "${KEY}_ACC" -obs OBS/ACC_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
#echo 'plot ACC barotropic time series'
#python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *ACC_bottom_nemo*${FREQ}*1.nc -var vtrp -sf -1 -title "ACC barotropic transport (Sv)" -dir ${DATPATH} -o "${KEY}_ACC_bottom" -obs OBS/ACC_bottom_obs.txt
#if [[ $? -ne 0 ]]; then exit 42; fi
#echo 'plot ACC shelf break time series'
#python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *ACC_*${FREQ}*1.nc -var vtrp -sf -1 -title "ACC transport (Sv)" -dir ${DATPATH} -o "${KEY}_ACC_shelfbreak" -obs OBS/ACC_shelfbreak_obs.txt
#if [[ $? -ne 0 ]]; then exit 42; fi

# GYRE
# ROSS GYRE
echo 'plot Ross Gyre time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *RG*${FREQ}*psi_SO.nc -var '(max_sobarstf|sobarstf)' -title "Ross Gyre (Sv)" -dir ${DATPATH} -o ${KEY}_RG -sf 0.000001 -obs OBS/RG_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# WED GYRE
echo 'plot Weddell Gyre time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *WG*${FREQ}*psi_SO.nc -var '(max_sobarstf|sobarstf)' -title "Weddell Gyre (Sv)" -dir ${DATPATH} -o ${KEY}_WG -sf 0.000001 -obs OBS/WG_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi

# HSSW
# mean S WROSS
echo 'plot mean bot S (WROSS) time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *WROSS*so*${FREQ}*deepTS.nc -var '(mean_3D_so_pra|so_pra)' -title "Mean deep sal. WROSS (PSU)" -dir ${DATPATH} -o ${KEY}_WROSS_mean_deep_so -obs OBS/WROSS_deepS_mean_obs.txt
# mean S WWED
if [[ $? -ne 0 ]]; then exit 42; fi
echo 'plot mean bot S (WWED) time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *WED*so*${FREQs}*deepTS.nc   -var '(mean_3D_so_pra|so_pra)' -title "Mean deep sal. WWED  (PSU)" -dir ${DATPATH} -o ${KEY}_WWED_mean_deep_so  -obs OBS/WWED_deepS_mean_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi

# CDW
# mean T AMU
echo 'plot mean bot T (AMU) time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *AMU*thetao*${FREQ}*deepTS.nc   -var '(mean_3D_thetao_pot|thetao_pot)' -title "Mean deep temp. AMU (C)"   -dir ${DATPATH} -o ${KEY}_AMU_mean_deep_thetao   -obs OBS/AMU_deepT_mean_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi
# mean T EROSS
echo 'plot mean bot T (EROSS) time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *EROSS*thetao*${FREQs}*deepTS.nc -var '(mean_3D_thetao_pot|thetao_pot)' -title "Mean deep temp. EROSS (C)" -dir ${DATPATH} -o ${KEY}_EROSS_mean_deep_thetao -obs OBS/EROSS_deepT_mean_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi

# MLD
# max mld in WEDDELL GYRE
echo 'plot max mld in Weddell Gyre time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *WMXL*1m*0901*T.nc -var '(max_somxzint1|somxzint1)' -title "Max Kara mld WG (m)" -dir ${DATPATH} -o ${KEY}_WG_max_karamld -obs OBS/WG_karamld_max_obs.txt
if [[ $? -ne 0 ]]; then exit 42; fi

# crop figure (rm legend)
convert ${KEY}_ACC.png                   -crop 1240x1040+0+0 tmp01.png
#convert ${KEY}_ACC_bottom.png            -crop 1240x1040+0+0 tmp02.png
#convert ${KEY}_ACC_shelfbreak.png        -crop 1240x1040+0+0 tmp03.png
convert ${KEY}_WG.png                    -crop 1240x1040+0+0 tmp02.png
convert ${KEY}_RG.png                    -crop 1240x1040+0+0 tmp03.png
convert ${KEY}_WWED_mean_deep_so.png      -crop 1240x1040+0+0 tmp04.png
convert ${KEY}_WROSS_mean_deep_so.png     -crop 1240x1040+0+0 tmp05.png
convert ${KEY}_AMU_mean_deep_thetao.png   -crop 1240x1040+0+0 tmp06.png
convert ${KEY}_EROSS_mean_deep_thetao.png  -crop 1240x1040+0+0 tmp07.png
convert ${KEY}_WG_max_karamld.png        -crop 1240x1040+0+0 tmp08.png

# trim figure (remove white area)
convert FIGURES/box_VALSO.png -trim -bordercolor White -border 40 tmp09.png
convert legend.png      -trim -bordercolor White -border 20 tmp10.png
convert runidname.png   -trim -bordercolor White -border 20 tmp11.png

# compose the image
convert \( tmp01.png tmp02.png tmp03.png +append \) \
        \( tmp04.png tmp05.png tmp09.png +append \) \
        \( tmp06.png tmp07.png tmp08.png +append \) \
           tmp10.png tmp11.png -append -trim -bordercolor White -border 40 $KEY.png

# save figure
mv ${KEY}_*.png FIGURES/.
mv ${KEY}_*.txt FIGURES/.
mv tmp10.png FIGURES/${KEY}_legend.png
mv tmp11.png FIGURES/${KEY}_runidname.png

# clean
rm tmp??.png

#display
display -resize 30% $KEY.png
