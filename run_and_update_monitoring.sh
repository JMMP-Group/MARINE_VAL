#!/bin/bash

## Get data or update data

# DEFINE RUNS TO KEEP UP TO DATE IN MONITORING
runs="u-dw515 u-dw498 u-dx297 u-dv341 "
#runs="u-dw515"
#runs="u-dv341"
# WHERE THE DATA WILL BE STORED
DATAPATH=/data/scratch/andrea.rochner/MARINE_VAL




# If no directory for the suiteID exists, create it
for suiteId in $runs ; do
  rm param.bash
  if [ ${suiteId} == "u-dv341" ]; then 
    echo "A UKCM2 run : "  $suiteId
    ln -s param_UKCM2.bash param.bash    
    #ln -s nam_cdf_names_UKCM2 nam_cdf_names
    BATHYFILE="UKCM2/bathymetry_eORCA1-GOSI9.nc"
    MASKFILE="UKCM2/mesh_mask_eORCA1-GOSI9_MARINEVAL.nc"
  elif [ ${suiteId} == "u-dw515" ]; then 
    echo "A GOSI10 run : " $suiteId
    ln -s param_GOSI10.bash param.bash
    #ln -s nam_cdf_names_UKESM1-3 nam_cdf_names
    BATHYFILE="GOSI10/bathy_eORCA025_noclosea_from_GEBCO2021_FillZero_S21TT_CloseaCopy_edits-20220404-20241213_r42.nc"
    MASKFILE="GOSI10/mesh_mask_MEs_novf_4env_2930_r12_r16-r075-r040-r035_it2-r030.nc"
  else
    echo "A UKESM1.3 run : " $suiteId
    ln -s param_UKESM1-3.bash param.bash
    #ln -s nam_cdf_names_UKESM1-3 nam_cdf_names
    BATHYFILE="UKESM1-3/bathy_remove-000_match_wrap-eORCA1.nc"
    MASKFILE="UKESM1-3/mesh_mask_copy.nc"
  fi
  ./run_proc.bash -B ${BATHYFILE} ${MASKFILE} 1960 1964 1y ${suiteId}



#  echo ${DATAPATH}/${suiteId}
#  RUNPATH=${DATAPATH}/${suiteId}
#  if [ ! -d ${RUNPATH} ]; then
#    echo "Directory for ${suiteId} does not exist. Creating it."
#    mkdir ${RUNPATH}
#  else
#    echo "Directory for ${suiteId} exists."
#  fi


  ## Update data
  # CHECK IF THE PROCESSING IN submit_convert_marineval.batch IS WHAT YOU WANT TO DO
  #./submit_convert_marineval.batch "${suiteId}" ${RUNPATH}

  ## Run processing data
  # start point: either first file or most recent when updating
  #processed=$(ls ${RUNPATH}/ACC_nemo* | wc -l)
  #echo " Processed up to ${processed}"

  #if [ ${processed} == 0 ]; then # No file has been processed yet
  #  firstfile=$(ls ${RUNPATH}/nemo*1y*grid-T.nc | head -1)
  #  firstfile=${firstfile##*1y_}
  #  startyear="${firstfile%1201-*}" # select start
  #else # files had been processed, find the latest one
  #  firstfile=$(ls ${RUNPATH}/ACC_nemo* | tail -1)
  #  firstfile=${firstfile##*1y_}
  #  startyear="${firstfile%1201.*}" # select start
  #fi


  # Last year added
  #lastfile=$(ls ${RUNPATH}/nemo*grid-T.nc | tail -1)
  #lastfile=${lastfile##*1y_}
  #endyear=${lastfile%1201-*}

  # PROCESSING: PICK CORRECT MASKING
  #echo "Processing files from ${startyear} to ${endyear}"
  #BATHYFILE="UKESM1-3/bathy_remove-000_match_wrap-eORCA1.nc"
  #MASKFILE="UKESM1-3/mesh_mask.nc"
  #./run_proc.bash -B ${BATHYFILE} ${MASKFILE} ${startyear} ${endyear} 1y ${suiteId}
done

## SELECT WHICH DATA TO PLOT
timestamp=$(date +%Y-%m-%d)
echo Plot produced on ${timestamp}
#./run_plot_VALGLO.bash UKESM_VALGLO_${timestamp} ${runs} 
./run_plot_VALNA.bash UKESM_VALNA_${timestamp} 1y ${runs} 
./run_plot_VALSO.bash UKESM_VALSO_${timestamp} 1y ${runs} 

## DEFINE WHERE TO SAVE THE FIGURE AND ITS NAME
#mv /home/users/andrea.rochner/public_html/CMIP7_piControl/*.png /home/users/andrea.rochner/PROJECTS/CMIP7/MONITORING/Marine_Val_CMIP7/CMIP_piC_plots/.
#cp UKESM_VAL*_${timestamp}.png /home/users/andrea.rochner/public_html/CMIP7_piControl/.
