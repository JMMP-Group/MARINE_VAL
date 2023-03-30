#!/bin/bash

ulimit -s unlimited

# where mask are stored (name of mesh mask in SCRIPT/common.bash)
MSKPATH=${HOME}/Documents/MESH_MASK/
#MSKPATH=/data/users/frsy/MESH_MASK/
MSKPATH=/data/users/hadom/MESH_MASK/
BASINPATH=/data/users/frsy/MESH_MASK/

# main VALNA directory
EXEPATH=/data/users/hadom/branches/git/MARINE_VAL/VALNA/

# where cdftools are stored
CDFPATH=${EXEPATH}/../CDFTOOLS_4.0/bin/

# SCRIPT location
SCRPATH=${EXEPATH}/SCRIPT/

# OBS directory (including from nordic_seas-validation generated sections)
OBSPATH=${EXEPATH}/OBS/

# DATA path (CONFIG and RUNID are fill by script)
#DATPATH=${DATADIR}/VALNA/DATA/${RUNID}
#DATPATH=/scratch/hadom/VALNA/DATA/
DATPATH=/scratch/hadom/MARINE_VAL/VALNA/

# evaluation diagnostics:

#   * Subpolar gyre strength
#   * Subpolar gyre heat content
#   * AMOC at 26.5N at max. depth
#   * OHT at 26.5N
#   * Mixed layer depth in Labrador Sea in March
#   * Mean SSS anomaly in Labrador Sea
#   * Mean SST anomaly off Newfoundland
#   * Mean overflow bottom temperature and salinity (below 27.8 isopycnal) at various locations. Currently, VALNA isolates
#     and averages the Irminger and Icelandic basins at the osnap observational cross-section.
#   * GS separation latitude
#   * NA current latitude

RUNVALNA=1

# custom
runBSF=0
runHTC=0
runMOC=0
runMHT=0

runMLD=0
runSSS=0
runSST=0

runOVF=0
runGSL_NAC=0

if [[ $RUNVALNA == 1 ]]; then
  runBSF=1
  runHTC=1
  runMOC=1
  runMHT=1

  runMLD=1
  runSSS=1
  runSST=1

  runOVF=1
  runGSL_NAC=1
fi

module load gcc/8.1.0 mpi/mpich/3.2.1/gnu/8.1.0 hdf5/1.8.20/gnu/8.1.0 netcdf/4.6.1/gnu/8.1.0
