#!/bin/bash -l

if [ $# -eq 0 ] ; then echo 'need a [KEYWORD] (will be inserted inside the figure title and output name) and a list of id [RUNIDS RUNID ...] (definition of line style need to be done in RUNID.db)'; exit; fi

. ./param.bash

KEY=${1}
FREQ=${2}
RUNIDS=${@:3}

## ACC
## Drake
#echo 'plot ACC time series'
#python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *ACC*${FREQ}*1.nc -var vtrp -sf -1 -title "ACC transport (Sv)" -dir ${DATPATH} -o "${KEY}_ACC" -obs OBS/ACC_obs.txt
#if [[ $? -ne 0 ]]; then exit 42; fi

## Denmark Strait overflow (southward flow sigma0 > 27.8 kg/m3)
echo 'plot Denmark Strait overflow time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f nemoXsec*${FREQ}*DenmarkStrait_trpsig.nc -var sigtrp_DenmarkStrait -title "Denmark Strait overflow (Sv)" -dir ${DATPATH} -o "${KEY}_DenmarkStrait" -obs OBS/DenmarkStrait_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Faroe Bank Channel overflow (southward flow sigma0 > 27.8 kg/m3)
echo 'plot Faroe Bank Channel overflow time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f nemoXsec*${FREQ}*FaroeBankChannel_trpsig.nc -var sigtrp_FaroeBankChannel -sf -1 -title "Faroe Bank Channel overflow (Sv)" -dir ${DATPATH} -o "${KEY}_FaroeBankChannel" -obs OBS/FaroeBankChannel_obs.txt  -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Gibraltar exchange
echo 'plot Gibraltar time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *Gibraltar*${FREQ}*1.nc -var ptrp -title "Gibraltar outflow (Sv)" -dir ${DATPATH} -o "${KEY}_Gibraltar" -obs OBS/Gibraltar_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Bab el Mandeb exchange
echo 'plot Bab el Mandeb time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *BabElMandeb*${FREQ}*1.nc -var ptrp -title "Bab el Mandeb outflow (Sv)" -dir ${DATPATH} -o "${KEY}_BabElMandeb" -obs OBS/BabElMandeb_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Strait of Hormuz exchange
echo 'plot Strait of Hormuz time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *StraitOfHormuz*${FREQ}*1.nc -var mtrp -sf -1 -title "Strait of Hormuz inflow (Sv)" -dir ${DATPATH} -o "${KEY}_StraitOfHormuz" -obs OBS/StraitOfHormuz_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Lombok Strait
echo 'plot Lombok Strait time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *LombokStrait*${FREQ}*1.nc -var ptrp  -title "Lombok Strait inflow (Sv)" -dir ${DATPATH} -o "${KEY}_LombokStrait" -obs OBS/LombokStrait_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Ombai Strait
echo 'plot Ombai Strait time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *OmbaiStrait*${FREQ}*1.nc -var mtrp -sf -1 -title "Ombai Strait inflow (Sv)" -dir ${DATPATH} -o "${KEY}_OmbaiStrait" -obs OBS/OmbaiStrait_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Timor Passage
echo 'plot Timor Passage time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *TimorPassage*${FREQ}*1.nc -var mtrp -sf -1 -title "Timor Passage inflow (Sv)" -dir ${DATPATH} -o "${KEY}_TimorPassage" -obs OBS/TimorPassage_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Bering Strait - mtrp, ptrp, or something else?
echo 'plot Bering Strait time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *BeringStrait*${FREQ}*1.nc -var ptrp  -title "Bering Strait inflow (Sv)" -dir ${DATPATH} -o "${KEY}_BeringStrait" -obs OBS/BeringStrait_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

## Fram Strait - northward transport = ptrp
echo 'plot Fram Strait time series'
python ${SCRPATH}/plot_time_series.py -noshow -runid $RUNIDS -f *FramStrait*${FREQ}*1.nc -var ptrp  -title "Fram Strait inflow (Sv)" -dir ${DATPATH} -o "${KEY}_FramStrait" -obs OBS/FramStrait_obs.txt -force_zero_origin
if [[ $? -ne 0 ]]; then exit 42; fi

# crop figure (rm legend)
#convert ${KEY}_ACC.png                   -crop 1240x1040+0+0 tmp01.png
convert ${KEY}_DenmarkStrait.png          -crop 1240x1040+0+0 tmp01.png
convert ${KEY}_FaroeBankChannel.png       -crop 1240x1040+0+0 tmp02.png
convert ${KEY}_Gibraltar.png              -crop 1240x1040+0+0 tmp04.png
convert ${KEY}_BabElMandeb.png            -crop 1240x1040+0+0 tmp05.png
convert ${KEY}_StraitOfHormuz.png         -crop 1240x1040+0+0 tmp06.png
convert ${KEY}_LombokStrait.png           -crop 1240x1040+0+0 tmp07.png
convert ${KEY}_OmbaiStrait.png            -crop 1240x1040+0+0 tmp08.png
convert ${KEY}_TimorPassage.png           -crop 1240x1040+0+0 tmp09.png
convert ${KEY}_BeringStrait.png           -crop 1240x1040+0+0 tmp10.png
convert ${KEY}_FramStrait.png             -crop 1240x1040+0+0 tmp11.png
# trim figure (remove white area)
#convert FIGURES/box.png -trim -bordercolor White -border 40 tmp09.png
convert legend.png      -trim -bordercolor White -border 20 tmp12.png
convert runidname.png   -trim -bordercolor White -border 20 tmp13.png

# compose the image
convert \( tmp01.png tmp02.png +append \) \
        \( tmp04.png tmp05.png tmp06.png +append \) \
        \( tmp07.png tmp08.png tmp09.png +append \) \
        \( tmp10.png tmp11.png +append \) \
           tmp12.png tmp13.png -append -trim -bordercolor White -border 40 $KEY.png

# save figure
mv ${KEY}_*.png FIGURES/.
mv ${KEY}_*.txt FIGURES/.
mv tmp12.png FIGURES/${KEY}_legend.png
mv tmp13.png FIGURES/${KEY}_runidname.png

# clean
rm tmp??.png

# display
display -resize 30% $KEY.png
