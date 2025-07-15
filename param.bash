#!/bin/bash -l

ulimit -s unlimited

##### USER CHOICES START ######

# top level directory
export MARINE_VAL=/YOUR/LOCAL/PATH/MARINE_VAL_DIR

# Path of the folder where mesh_mask bathy and are locally stored 
# (names of mesh mask and bathy are arguments to this script)
export MSKPATH=/YOUR/LOCAL/PATH/MESH_MASK_DIR

# Path where cdftools executables are locally stored
export CDFPATH=/YOUR/LOCAL/PATH/CDFTOOLS_DIR/bin

# Local path of the nam_cdf_names namelist.
# You can use as a template the "nam_cdf_names_template"
# file - you probably need to adapt to your need the following
# namelists: namvars, nammeshmask, nammask  
export NMLPATH=/YOUR/LOCAL/PATH/nam_cdf_names

# toolbox location
export EXEPATH=${MARINE_VAL}/

# SCRIPT location
export SCRPATH=${MARINE_VAL}/SCRIPT/

# Top-level working directory
# (working dir for $RUNID = $DATPATH/$RUNID)
export DATPATH=${DATADIR}/MARINE_VAL/

# Observations
export OBSPATH=YOUR/LOCAL/PATH/OBS_PATH_DIR
export runOBS=1      # run observations for HTC, STC and MEDOVF

RUNALL=0       # run all possible metrics

# diagnostics bundles
RUNVALSO=1     # Southern Ocean metrics
RUNVALNA=1     # North Atlantic metrics
RUNVALTRANS=1  # Transports/exchanges in straits

# DISABLED, SINCE IT IS NOT WORKING YET
#RUNVALGLO=0    # Global metrics

# custom:

# VALSO (Southern Ocean)
runACC=0            # Drake Passage net eastward transport
runMLD_Weddell=0    # Max wintertime mixed layer depth in Weddell Sea
runBSF_SO=0         # Max streamfunction in Weddell gyre and Ross gyre
runDEEPTS=0         # Deep salinity in West Weddell and West Ross Seas
                    # and deep temperature in Amundsen and East Ross Seas
runSST_SO=0         # Mean Southern Ocean SST between ?? and ??
runAABW=0           # Volume of water for a given sigma4 threshold

# VALNA (North Atlantic)
runBSF_NA=0         # North Atlantic subpolar gyre strength
runHTC=0            # North Atlantic subpolar gyre heat content
                    # NB: MHT metric only works if relevant diagnostic 
                    #     in model output. Therefore, the user needs to 
                    #     explicitly activate this diagnostic.
runSTC=0            # North Atlantic subpolar gyre salt content
runAMOC=0           # AMOC at 26.5N at max. depth
runMLD_LabSea=0     # Mixed layer depth in Labrador Sea in March
runSSS_LabSea=0     # Mean SSS anomaly in Labrador Sea
runSST_NWCorner=0   # Mean SST anomaly off Newfoundland

# DISABLED, SINCE IT IS NOT WORKING YET
# runOVF=0            # Mean overflow bottom temperature and salinity (below 27.8 isopycnal) 
#                     # at various locations. Currently, VALNA isolates and averages the 
#                     # Irminger and Icelandic basins at the osnap observational cross-section.

runGSL_NAC=0        # GS separation latitude and NA current latitude
runMedOVF=0         # Mediterranean overflow water max salinity and corresponding depth
runOSNAP=0          # Overturning streamfunction profile in density space accros OSNAP 
                    # East and West arrays.
                    # NB: Because of the observations, OSNAP metrics should be computed only 
                    #     using monthly outputs and for the 2014-2016 period. Therefore,
                    #     the user needs to explicitly activate this diagnostic.

# VALTRANS (Transports and exchanges in straits)
runMargSea=0        # Marginal Seas exchanges: Gibraltar, Bab el Mandeb, Strait of Hormuz
runITF=0            # Indonesian Throughflow: Lombok Strait, Ombai Strait, Timor Passage
runNAtlOverflows=0  # North Atlantic deep overflows: Denmark Strait, Faroe Bank Channel
runArcTrans=0       # Arctic transports: Fram Strait, Bering Strait, Davis Strait, Barents Sea

# DISABLED, SINCE IT IS NOT WORKING YET
# VALGLO (Global metrics)
# The VALGLO package also includes a number of metrics in other packages above.
#runMHT=0            # Atlantic(?) meridional heat transport
#runSIE=0            # Arctic sea ice extent
#runQHF=0            #

##### USER CHOICES END ######

if [[ $RUNVALSO == 1 || $RUNALL == 1 ]]; then
   runACC=1 
   runMLD_Weddell=1 
   runBSF_SO=1 
   runDEEPTS=1 
   runSST_SO=1
   runAABW=1
fi
if [[ $RUNVALNA == 1 || $RUNALL == 1 ]]; then
   runBSF_NA=1
   #runHTC=1
   runSTC=1
   runAMOC=1
   #runMHT=1 # if you want to use this, you need to explicitely activate it!
   runMLD_LabSea=1
   runSSS_LabSea=1
   runSST_NWCorner=1
#  Disabled since not yet working
#  runOVF=1
   runGSL_NAC=1
   runMedOVF=1
   #runOSNAP=1 # if you want to use this, you need to explicitely activate it!
fi
if [[ $RUNVALTRANS == 1 || $RUNALL == 1 ]]; then
   runITF=1
   runMargSea=1
   runNAtlOverflows=1
   runArcTrans=1
fi

# Disabled since it is not ready yet 
# if [[ $RUNVALGLO == 1 || $RUNALL == 1 ]]; then
#    runACC=1 
#    runAMOC=1
#    runMHT=1
#    runSIE=1
#    runQHF=1
#    runSST_NWCorner=1
#    runSST_SO=1
# fi
   
if [[ -z "$(conda env list | grep ^marval)" ]]
then
    echo "ERROR: marval conda environment not found."
    echo "You need to create it using 'conda env create -f marval.yml'"
    exit 11
fi

source /opt/conda/etc/profile.d/conda.sh # Ensure conda commands are available in this shell session
#conda init
conda activate marval
echo `which python`
