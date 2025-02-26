#!/bin/bash

ulimit -s unlimited

##### USER CHOICES START ######

# top level directory
export MARINE_VAL=/YOUR/LOCAL/PATH/MARINE_VAL_DIR

# Path of the folder where mesh_mask bathy and are locally stored 
# (names of mesh mask and bathy are arguments to this script)
export MSKPATH=/YOUR/LOCAL/PATH/MESH_MASK_DIR

# Path where cdftools executables are locally stored
export CDFPATH=/YOUR/LOCAL/PATH/CDFTOOLS_DIR/bin

# Local path of the nam_cdf_names namelist
export NMLPATH=/YOUR/LOCAL/PATH/nam_cdf_names

# toolbox location
export EXEPATH=${MARINE_VAL}/

# SCRIPT location
export SCRPATH=${MARINE_VAL}/SCRIPT/

# Top-level working directory
# (working dir for $RUNID = $DATPATH/$RUNID)
export DATPATH=${DATADIR}/MARINE_VAL/

RUNALL=0       # run all possible metrics

# diagnostics bundles
RUNVALSO=1     # Southern Ocean metrics
RUNVALNA=1     # North Atlantic metrics
RUNVALTRANS=1  # Transports/exchanges in straits
RUNVALGLO=0    # Global metrics (UNTESTED IN MERGED VERSION OF MARINE_VAL)

# custom:

# VALSO (Southern Ocean)
runACC=0            # Drake Passage net eastward transport
runMLD_Weddell=0    # Max wintertime mixed layer depth in Weddell Sea
runBSF_SO=0         # Max streamfunction in Weddell gyre and Ross gyre
runDEEPTS=0         # Deep salinity in West Weddell and West Ross Seas
                    # and deep temperature in Amundsen and East Ross Seas
runSST_SO=0         # Mean Southern Ocean SST between ?? and ??

# VALNA (North Atlantic)
runBSF_NA=0         # North Atlantic subpolar gyre strength
runHTC=0            # North Atlantic subpolar gyre heat content
runAMOC=0           # AMOC at 26.5N at max. depth
runMLD_LabSea=0     # Mixed layer depth in Labrador Sea in March
runSSS_LabSea=0     # Mean SSS anomaly in Labrador Sea
runSST_NWCorner=0   # Mean SST anomaly off Newfoundland
runOVF=0            # Mean overflow bottom temperature and salinity (below 27.8 isopycnal) 
                    # at various locations. Currently, VALNA isolates and averages the 
                    # Irminger and Icelandic basins at the osnap observational cross-section.
runGSL_NAC=0        # GS separation latitude and NA current latitude

# VALTRANS (Transports and exchanges in straits)
runMargSea=0        # Marginal Seas exchanges: Gibraltar, Bab el Mandeb, Strait of Hormuz
runITF=0            # Indonesian Throughflow: Lombok Strait, Ombai Strait, Timor Passage
runNAtlOverflows=0  # North Atlantic deep overflows: Denmark Strait, Faroe Bank Channel
runArcTrans=0       # Arctic transports: Fram Strait, Bering Strait, Davis Strait, Barents Sea

# VALGLO (Global metrics) NB. THESE ARE UNTESTED AND MIGHT BE BUGGY
# The VALGLO package also includes a number of metrics in other packages above.
runMHT=0            # Atlantic(?) meridional heat transport
runSIE=0            # Arctic sea ice extent
runQHF=0            #

##### USER CHOICES END ######

if [[ $RUNVALSO == 1 || $RUNALL == 1 ]]; then
   runACC=1 
   runMLD_Weddell=1 
   runBSF_SO=1 
   runDEEPTS=1 
   runSST_SO=1
fi
if [[ $RUNVALNA == 1 || $RUNALL == 1 ]]; then
   runBSF_NA=1
   runHTC=1
   runAMOC=1
#   MHT metric only works if relevant diagnostic in model output
#   runMHT=1
   runMLD_LabSea=1
   runSSS_LabSea=1
   runSST_NWCorner=1
#   OVF metrics not yet working in merged version of Marine_Val
#   runOVF=1
   runGSL_NAC=1
fi
if [[ $RUNVALTRANS == 1 || $RUNALL == 1 ]]; then
   runITF=1
   runMargSea=1
   runNAtlOverflows=1
   runArcTrans=1
fi
if [[ $RUNVALGLO == 1 || $RUNALL == 1 ]]; then
   runACC=1 
   runAMOC=1
   runMHT=1
   runSIE=1
   runQHF=1
   runSST_NWCorner=1
   runSST_SO=1
fi
   
# Load scitools and modules required to run CDFTOOLS:
module load scitools
check_vdi="${HOSTNAME:0:3}"
if [ $check_vdi == "vld" ]; then
   module load gcc/8.1.0 mpi/mpich/3.2.1/gnu/8.1.0 hdf5/1.8.20/gnu/8.1.0 netcdf/4.6.1/gnu/8.1.0
elif [ $check_vdi == "caz" ]; then
   module load netcdf-fortran/4.6.1-gcc-12.2.0-43finqs gcc/13.2.0-gcc-12.2.0-lx4jx7u
fi
