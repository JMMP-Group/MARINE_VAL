#!/bin/bash

# DEFINE RUNS TO KEEP UP TO DATE IN MONITORING
runs="u-dx606 u-dv341 u-dw515" # this is the piControl of UKESM1.3 (u-dx) and its predecessor (u-dw)


# When to run the processing
ystrt=1960
yend=1961


# If no directory for the suiteID exists, create it
for suiteId in $runs ; do
  rm param.bash
  if [ ${suiteId} == "u-dv341" ]; then 
    echo "A UKCM2 run : "  $suiteId
    ln -s param_UKCM2.bash param.bash    
    BATHYFILE="UKCM2/bathymetry_eORCA1-GOSI9.nc"
    MASKFILE="UKCM2/mesh_mask_eORCA1-GOSI9_MARINEVAL.nc"
    ./run_proc.bash -B ${BATHYFILE} ${MASKFILE} $ystrt $yend 1y ${suiteId}
  elif [ ${suiteId} == "u-dw515" ]; then 
    echo "A GOSI10 run : " $suiteId
    ln -s param_GOSI10.bash param.bash
    # bathy and mesh from
    BATHYFILE="GOSI10/bathymetry.loc_area-nord_ovf_025.dep2930_sig1_stn9_itr1.MEs_novf_gosi10_025_4env_2930_r12_r16-r075-r040-r035_it2-r030.nc"
    MASKFILE="GOSI10/mesh_mask_MEs_novf_4env_2930_r12_r16-r075-r040-r035_it2-r030.nc"
    VERTINTERPFILE="/data/users/diego.bruciaferri/Model_Config/GOSI/GOSI10_input_files/p1.0/mesh_mask_eORCA025_v3.2_r42.nc"
    ./run_proc.bash -B ${BATHYFILE} -V ${VERTINTERPFILE} ${MASKFILE} $ystrt $yend 1y ${suiteId}
  else
    echo "A UKESM1.3 run : " $suiteId
    ln -s param_UKESM1-3.bash param.bash
    BATHYFILE="UKESM1-3/bathy_remove-000_match_wrap-eORCA1.nc"
    MASKFILE="UKESM1-3/mesh_mask_copy.nc"
    ./run_proc.bash -B ${BATHYFILE} ${MASKFILE} $ystrt $yend 1y ${suiteId}
  fi
done

## SELECT WHICH DATA TO PLOT
timestamp=$(date +%Y-%m-%d)
echo Plot produced on ${timestamp}
./run_plot_VALNA.bash TESTING_VALNA_${timestamp} 1y ${runs} 
./run_plot_VALSO.bash TESTING_VALSO_${timestamp} 1y ${runs} 

