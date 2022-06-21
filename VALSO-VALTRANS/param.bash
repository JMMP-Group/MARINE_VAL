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
RUNVALSO=1
RUNVALGLO=0
RUNVALTRANS=0
RUNALL=0
# custom
runACC=0
runMargSea=0
runITF=0
runNAtlOverflows=0
runMLD=0
runBSF=0
runBOT=0
runMOC=0
runMHT=0
runSIE=0
runSST=0
runQHF=0
runTRP2=0
#
if [[ $RUNALL == 1 || $RUNTEST == 1 ]]; then
   runACC=1 #acc  ts
   runMLD=1 #mld  ts
   runBSF=1 #gyre ts
   runBOT=1 #bottom TS ts
   runMOC=1
   runMHT=1
   runSIE=1
   runSST=1
   runQHF=1
   runTRP2=1
fi
if [[ $RUNVALSO == 1 ]]; then
   runACC=1 #acc  ts
   runMLD=1 #mld  ts
   runBSF=1 #gyre ts
   runBOT=1 #bottom TS ts
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
   
# Load modules required to run CDFTOOLS:
module load gcc/8.1.0 mpi/mpich/3.2.1/gnu/8.1.0 hdf5/1.8.20/gnu/8.1.0 netcdf/4.6.1/gnu/8.1.0
