#!/bin/bash

# DEFINE RUNS TO KEEP UP TO DATE IN MONITORING
runs="u-dw498 u-dx297 u-dx606" # this is the piControl of UKESM1.3 (u-dx) and its predecessor (u-dw)


# When to run the processing (starting point)
ystrt=1950
yend=1952


for suiteId in $runs ; do
  rm -f param.bash
  ln -s param_picontrol.bash param.bash

  BATHYFILE="UKESM1-3/bathy_remove-000_match_wrap-eORCA1.nc"
  MASKFILE="UKESM1-3/mesh_mask_copy.nc"

  # load DATPATH from the parameter file
  DATPATH_LINE=$(grep -E '^export DATPATH=' param.bash | head -n1)
  eval "$DATPATH_LINE"

  # determine last year already processed in ${DATPATH}/${suiteId}
  last_proc_year=""
  if [[ -d "${DATPATH}/${suiteId}" ]]; then
    last_proc_year=$(ls ${DATPATH}/${suiteId}/ACC*.nc | tail -1 | grep -oE '[0-9]{4}' | head -1)  
  fi

  # determine last year available on MASS (best-effort using `moo ls`); fall back to configured $yend
  last_mass_year=""
  if command -v moo >/dev/null 2>&1 ; then
    MASS_END=$(moo ls moose:/crum/${suiteId}/ony.nc.file/nemo*grid-T.nc | tail -1)
    last_mass_year=$(echo "$MASS_END" | grep -oE '[0-9]{4}' | head -1)
  fi

  # compute the new processing window
  new_ystrt=$(( last_proc_year + 1 ))
  if (( new_ystrt > last_mass_year )); then
    echo "No new years to process for ${suiteId} (processed up to ${last_proc_year}, MASS up to ${last_mass_year})"
    continue
  fi
  new_yend=$last_mass_year

  echo "Processing ${suiteId}: years ${new_ystrt}-${new_yend} (previously processed up to ${last_proc_year}; MASS up to ${last_mass_year})"

  
  ./run_proc.bash -B ${BATHYFILE} ${MASKFILE} ${new_ystrt} ${new_yend} 1y ${suiteId}

done

## SELECT WHICH DATA TO PLOT
timestamp=$(date +%Y-%m-%d)
echo Plot produced on ${timestamp}
./run_plot_VALNA.bash UKESM_VALNA_${timestamp} 1y ${runs} 
./run_plot_VALSO.bash UKESM_VALSO_${timestamp} 1y ${runs} 

## DEFINE WHERE TO SAVE THE FIGURE AND ITS NAME
mv /home/users/andrea.rochner/public_html/CMIP7_piControl/*.png /home/users/andrea.rochner/PROJECTS/CMIP7/MONITORING/Marine_Val_CMIP7/CMIP_piC_plots/.
cp UKESM_VAL*_${timestamp}*.png /home/users/andrea.rochner/public_html/CMIP7_piControl/.