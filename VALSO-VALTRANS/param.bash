#!/bin/bash

ulimit -s unlimited

# top level directory
MARINE_VAL=${HOME}/Git_Repos/MARINE_VAL

# where mask are stored (name of mesh mask in SCRIPT/common.bash)
MSKPATH=/data/users/frsy/MESH_MASK/

# where cdftools are stored
CDFPATH=${MARINE_VAL}/CDFTOOLS_4.0/bin

# toolbox location
EXEPATH=${MARINE_VAL}/VALSO-VALTRANS/

# SCRIPT location
SCRPATH=${MARINE_VAL}/VALSO-VALTRANS/SCRIPT/

# diagnostics bundle
RUNVALSO=1     # Southern Ocean metrics
RUNVALGLO=0    # Global metrics (bit flakey)
RUNVALTRANS=0  # Transports/exchanges
RUNALL=0       # All of the above
# custom
runACC=0            # Drake Passage net eastward transport
runMargSea=0        # Marginal Seas exchanges: Gibraltar, Bab el Mandeb, Strait of Hormuz
runITF=0            # Indonesian Throughflow: Lombok Strait, Ombai Strait, Timor Passage
runNAtlOverflows=0  # North Atlantic deep overflows: Denmark Strait, Faroe Bank Channel
runMLD=0            # Max wintertime mixed layer depth in Weddell Sea
runBSF=0            # Max streamfunction in Weddell gyre and Ross gyre
runDEEPTS=0         # Deep salinity in West Weddell and West Ross Seas
                    # and deep temperature in Amundsen and East Ross Seas
runMOC=0            # Atlantic meridional overturning
runMHT=0            # Atlantic meridional heat transport
runSIE=0            # Southern Ocean sea ice extent
runSST=0            #
runQHF=0            #
#
if [[ $RUNALL == 1 || $RUNTEST == 1 ]]; then
   runACC=1 #acc  ts
   runMLD=1 #mld  ts
   runBSF=1 #gyre ts
   runDEEPTS=1 #deep TS ts
   runMOC=1
   runMHT=1
   runSIE=1
   runSST=1
   runQHF=1
   runITF=1
   runMargSea=1
   runNAtlOverflows=1
fi
if [[ $RUNVALSO == 1 ]]; then
   runACC=1 #acc  ts
   runMLD=1 #mld  ts
   runBSF=1 #gyre ts
   runDEEPTS=1 #deep TS ts
fi
if [[ $RUNVALGLO == 1 ]]; then
   runMOC=1
   runMHT=1
   runSIE=1
   runSST=1
   runQHF=1
fi
if [[ $RUNVALTRANS == 1 ]]; then
   runITF=1
   runMargSea=1
   runNAtlOverflows=1
#else
#   echo 'need to define what you want in param.bash; exit 42'
#   exit 42
fi
   
# Load scitools and modules required to run CDFTOOLS:
module load scitools
module load gcc/8.1.0 mpi/mpich/3.2.1/gnu/8.1.0 hdf5/1.8.20/gnu/8.1.0 netcdf/4.6.1/gnu/8.1.0
