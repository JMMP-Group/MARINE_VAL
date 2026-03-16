#!/bin/bash

# DEFINE RUNS TO KEEP UP TO DATE IN MONITORING
runs="u-dw498 u-dx297" # this is the piControl of UKESM1.3 (u-dx) and its predecessor (u-dw)


# When to run the processing
ystrt=1960
yend=1961


# If no directory for the suiteID exists, create it
for suiteId in $runs ; do
  rm param.bash

  ln -s param_example.bash param.bash
  BATHYFILE="UKESM1-3/bathy_remove-000_match_wrap-eORCA1.nc"
  MASKFILE="UKESM1-3/mesh_mask_copy.nc"
  ./run_proc.bash -B ${BATHYFILE} ${MASKFILE} $ystrt $yend 1y ${suiteId}

done

## SELECT WHICH DATA TO PLOT
timestamp=$(date +%Y-%m-%d)
echo Plot produced on ${timestamp}
./run_plot_VALNA.bash UKESM_VALNA_${timestamp} 1y ${runs} 
./run_plot_VALSO.bash UKESM_VALSO_${timestamp} 1y ${runs} 

