#!/bin/bash -l
#
# This script currently only plots the minimal set of VALNA metrics, excluding:
#     1. Meridional heat transport (MHT) which metric only works if relevant diagnostic in model output. 
#     2. Overflow metrics (OVF) for which the calculation needs to be corrected.

if [ $# -eq 0 ] ; then echo 'need a [KEYWORD] (will be inserted inside the figure title and output name) and a list of id [RUNIDS RUNID ...] (definition of line style need to be done in RUNID.db)'; exit; fi

. ./param.bash

KEY=${1}
FREQ=${2}
RUNIDS=${@:3}

echo '  '

# NA subpolar gyre max strength
if [[ $runBSF_NA == 1 ]]; then
   echo 'plot NA subpolar gyre strength time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *BSF_NA*${FREQ}*psi_NA.nc -var '(min_sobarstf|sobarstf)' -title "SPG max strength (Sv)" -dir ${DATPATH} -o ${KEY}_BSF -sf -0.000001 #-obs OBS/SUBP_PSI_obs.txt
   #-sf is scale factor i.e. m3/s to Sv
   #using min and negative scale factor because streamf is negative in subpolar gyre
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# Heat content of subpolar gyre
if [[ $runHTC == 1 ]]; then
   echo 'plot heat content of subpolar gyre time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *HEATC_NA_*${FREQ}*heatc.nc -var heatc3d -title "Heat content in SPG (*10^23 J)" -dir ${DATPATH} -o ${KEY}_HTC -obs OBS/HTC_subp_obs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# Salt content of subpolar gyre
if [[ $runSTC == 1 ]]; then
   echo 'plot salt content of subpolar gyre time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *SALTC_NA_*${FREQ}*saltc.nc -var saltc3d -title "Salt content in SPG" -dir ${DATPATH} -o ${KEY}_STC -obs OBS/STC_subp_obs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# AMOC
if [[ $runAMOC == 1 ]]; then 

   # 1) timeseries of AMOC at 26.5N (maximum in z)
   echo 'plot max(AMOC_z) at 26.5N time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f rapid_z/*moc_z_RAPID*${FREQ}*.nc -var Total_max_amoc_rapid -title "AMOC @26.5N (Sv)" -dir ${DATPATH} -o ${KEY}_AMOC -obs OBS/AMOC_max_obs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi

   # 2) AMOC profiles (in z space) at 26.5N
   echo 'plot RAPID mocz'
   python SCRIPT/plot_rapid_mocz.py -runid $RUNIDS -dir ${DATPATH} -o ${KEY}_rapid_mocz -st ${FREQ} -p moc_z_RAPID -obs ${OBS_RPD_PRF}
   
   # 3) Zonally integrated mean AMOC in depth space
   echo 'plot zonally integrated mean AMOC in depth space'
   python SCRIPT/plot_zonint_amoc_z.py -runid $RUNIDS -dir ${DATPATH} -o ${KEY}_amoc_z -p AMOC_depth
   if [[ $? -ne 0 ]]; then exit 42; fi

   # 4) Zonally integrated mean AMOC in sigma_2000 space
   echo 'plot zonally integrated mean AMOC in sigma_2000 space'
   python SCRIPT/plot_zonint_amoc_rho.py -runid $RUNIDS -dir ${DATPATH} -o ${KEY}_amoc_rho -p AMOC_sigma2
   if [[ $? -ne 0 ]]; then exit 42; fi

fi

### OHT at 26.5N
## TEMPORARILY COMMENTED OUT
##echo 'plot OHT time series'
##python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *OHT*${FREQ}*mht_26_5N.nc -var zomht_glo -title "MHT @26.5N (PW)" -dir ${DATPATH} -o ${KEY}_OHT -obs OBS/AMHT_obs.txt
##if [[ $? -ne 0 ]]; then exit 42; fi

# mean MXL depth in Lab Sea in March (averaged in small region)
if [[ $runMLD_LabSea == 1 ]]; then 
   echo 'plot mean MXL depth in Lab Sea time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *LAB_MXL*1m*0301*T*003*.nc -var '(mean_somxl030|somxl030)' -title "Mean MXL in Lab Sea in March (m)" -dir ${DATPATH} -o ${KEY}_MXL_LAB_MEAN -sf -1 -obs OBS/MXL_lab_mean_obs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# mean SSS in Labrador Sea
if [[ $runSSS_LabSea == 1 ]]; then
   echo 'plot mean SSS in Labrador Sea time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f SSSav_LabSea_*${FREQ}*T.nc -var '(mean_so_pra|so_pra)' -title "Mean SSS in Labrador Sea (PSU)" -dir ${DATPATH} -o ${KEY}_SSS_LabSea -obs OBS/SSS_LabSea_obs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

# mean SST off Newfoundland
if [[ $runSST_NWCorner == 1 ]]; then
   echo 'plot mean SST off Newfoundland time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f SSTav_Newfound_*${FREQ}*T.nc -var '(mean_thetao_pot|thetao_pot)' -title "Mean SST off Newfoundland (degC)" -dir ${DATPATH} -o ${KEY}_SST_newf -obs OBS/SST_newf_obs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi
fi

## OVF METRICS TEMPORARILY COMMENTED OUT
## #################
## # choose overflow NA observations
## OBS_NAME=osnap
## #options: latrabjarg_clim, ovide, eel, kogur, hansen & osnap (Irminger and Icelandic basin)
## #################
## echo 'plot T and S overflow time series'
## # salinity
## python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var S_av_27_8_rho -title "Mean S>27.8 kg/m3 @ ${OBS_NAME}" -dir ${DATPATH} -o ${KEY}_OVF_S -obs OBS/OVF_S_${OBS_NAME}_obs.txt
## if [[ $? -ne 0 ]]; then exit 42; fi
## # temp
## python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*${OBS_NAME}_Xsection.nc -var T_av_27_8_rho -title "Mean T>27.8 kg/m3 @ ${OBS_NAME}" -dir ${DATPATH} -o ${KEY}_OVF_T -obs OBS/OVF_T_${OBS_NAME}_obs.txt
## if [[ $? -ne 0 ]]; then exit 42; fi

if [[ $runGSL_NAC == 1 ]]; then 

   # GS separation latitude
   echo 'plot GS separation latitude time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*NA_crop_T.nc -var GS_sep_lat -title "GS separation latitude @72degW" -dir ${DATPATH} -o ${KEY}_GSL -obs OBS/GS_sep_lat_obs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi

   # NAC latitude
   echo 'plot NAC latitude time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*NA_crop_T.nc -var NAC_lat -title "NAC latitude @41degW" -dir ${DATPATH} -o ${KEY}_NAC -obs OBS/NAC_lat_obs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi

fi

if [[ $runMedOVF == 1 ]]; then

   # max practical salinity in med overflow   
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*_medovf_mean.nc -var so_pra -title "Med Outflow Max Salinity" -dir ${DATPATH} -o ${KEY}_medovf_salinity -obs OBS/MEDOVF_so_abs.txt
   if [[ $? -ne 0 ]]; then exit 42; fi

   # depth of max practical salinity in med overflow
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f *${FREQ}*_medovf_mean_depth.nc -var deptht -title "Med Outflow Depth of Max Salinity (m)" -dir ${DATPATH} -o ${KEY}_medovf_depth -obs OBS/MEDOVF_so_abs_depth.txt
   if [[ $? -ne 0 ]]; then exit 42; fi

fi

if [[ $runOSNAP == 1 ]]; then

   # OSNAP West
   echo 'plot OSNAP west mocsig'
   python SCRIPT/plot_osnap_mocsig.py -runid $RUNIDS -dir ${DATPATH} -o ${KEY}_osnap_mocsig_west -st OSNAPwest -p moc_sigma0
   echo 'plot OSNAP west mocsig max time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f osnap*${FREQ}*OSNAPwest.nc -var 'max_osnap_moc_sig' -title "OSNAP west mocsig" -dir ${DATPATH} -o ${KEY}_OSNAP_west -obs OBS/OSNAP_mocsig_west.txt

   # OSNAP East
   echo 'plot OSNAP east mocsig'
   python SCRIPT/plot_osnap_mocsig.py -runid $RUNIDS -dir ${DATPATH} -o ${KEY}_osnap_mocsig_east -st OSNAPeast -p moc_sigma0
   echo 'plot OSNAP east mocsig max time series'
   python SCRIPT/plot_time_series.py -noshow -runid $RUNIDS -f osnap*${FREQ}*OSNAPeast.nc -var 'max_osnap_moc_sig' -title "OSNAP east mocsig" -dir ${DATPATH} -o ${KEY}_OSNAP_east -obs OBS/OSNAP_mocsig_east.txt

fi

# crop figure (rm legend)
convert ${KEY}_BSF.png                     -crop 1240x1040+0+0 tmp01.png
convert ${KEY}_HTC.png                     -crop 1240x1040+0+0 tmp02.png
convert ${KEY}_AMOC.png                    -crop 1240x1040+0+0 tmp03.png
## convert ${KEY}_OHT.png                     -crop 1240x1040+0+0 tmp04.png

convert ${KEY}_MXL_LAB_MEAN.png            -crop 1240x1040+0+0 tmp05.png
convert ${KEY}_SSS_LabSea.png              -crop 1240x1040+0+0 tmp06.png
convert ${KEY}_SST_newf.png                -crop 1240x1040+0+0 tmp07.png
convert FIGURES/box_NA.png  -trim -bordercolor White -border 2 tmp08.png

## convert ${KEY}_OVF_S.png                   -crop 1240x1040+0+0 tmp09.png
## convert ${KEY}_OVF_T.png                   -crop 1240x1040+0+0 tmp10.png
convert ${KEY}_GSL.png                     -crop 1240x1040+0+0 tmp11.png
convert ${KEY}_NAC.png                     -crop 1240x1040+0+0 tmp12.png

convert ${KEY}_medovf_salinity.png        -crop 1240x1040+0+0 tmp11.png
convert ${KEY}_medovf_depth.png            -crop 1240x1040+0+0 tmp12.png

# trim figure (remove white area)
convert legend.png      -trim    -bordercolor White -border 20 tmp13.png
convert runidname.png   -trim    -bordercolor White -border 20 tmp14.png

## ORIGINAL SET OF VALNA METRICS:
## # compose the image
## convert \( tmp01.png tmp02.png tmp03.png tmp04.png +append \) \
##         \( tmp05.png tmp06.png tmp07.png tmp08.png +append \) \
##         \( tmp09.png tmp10.png tmp11.png tmp12.png +append \) \
##            tmp13.png tmp14.png -append -trim -bordercolor White -border 50 $KEY.png

## REDUCED SET OF METRICS:
# compose the image
convert \( tmp01.png tmp02.png tmp03.png +append \) \
        \( tmp05.png tmp06.png tmp08.png +append \) \
        \( tmp07.png tmp11.png tmp12.png +append \) \
           tmp13.png tmp14.png -append -trim -bordercolor White -border 50 $KEY.png

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
