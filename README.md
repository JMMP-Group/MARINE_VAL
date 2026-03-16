# MARINE_VAL for monitoring CMIP7 simulations 

See guidance to set up marine_val in (main) 

## Purpose
marine_val is adjusted here to work with outputs of UKESM1.3 and UKCM2, while trying to maintain the capability to runs with newer configurations and NEMO versions. 

We want to use marine_val to monitor currently running simulations, therefore some changes are made e.g. to only process years that have not been processed before. 

## Use 
`run_and_update_monitoring.sh` is the file that combined processing and plotting. 

Each model "type" gets its own `param_XXX.bash` and `nam_cdf_names_XXX` to be able to process and plot output from different sources together, e.g. the piControl runs of UKESM1.3 and UKCM2. `nam_cdf_names_XXX` is set in `param_XXX.bash`, while `param_XXX.bash` is linked in `run_and_update_monitoring.sh`.