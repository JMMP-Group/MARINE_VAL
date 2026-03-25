# MARINE_VAL for monitoring CMIP7 simulations
See guidance to set up marine_val in (main) 

## Purpose of this branch
marine_val is adjusted here to work with a larger variety of model outputs including UKESM1.3, UKESM2, and UKCM2 for CMIP7, and NEMO-MEDUSA runs with DA for CMUG (ORCA025). To be able to run all set-ups from the same directory, some changes to the logic of the toolbox are made to keep the experiments separated and keep the code tidy. Those changes may affect the capability to run e.g. GOSI10 simulations with this branch, though I tested most changes in u-dw515 (a GOSI10 beta version) to ensure it's still working. 

## Use 
* In main directory, `run_experiment.sh` is used for running `marine_val`. In it, you need to set `RUNEXP` and define with bash script is run (e.g. `sh "run_monitoring.sh"  `). 
* `EXP/` contains directories with experiment set-ups for different ways to run `marine_val`. Each subdirectory should contain 
  * a sh script that's defines suite id's, years, mesh mask, bathymetry file, the `./run_proc.bash` command, and plotting 
  * one or multiple `param.bash` that define paths and metrics to be produced, one file for the "type" of suite that's supposed to be evaluated.
  * one or multiple `nam_cdf_names` that defines e.g. variable names. 
  * Optional (and to be added): `run_plot_XXX.bash` to produce specific summary plots. 

## Notes 
The advantage of having this structure with definitions in `EXP/` is that it's reproducable how `marine_val` was run, e.g. which mesh mask was used. 

**The mesh file**
Can be produced while running the model: `namelist_ref ` > `&namdom` > `nn_msh=1` > produces per-processor mesh files > rebuild 

It may need manual modification to change variable names, i.e. rename time (`time_counter`), bathymetry (`bathy_metry`), depth (`nav_lev`).

In the respective `nam_cdf_names`, `cn_bathymet` needs to be the variable name from the mesh file, not bathymetry file. 

## Issues 

`runSST_SO`: `mk_sst_so` only produces output file for GOSI10 (u-dw515), error for UKESM1.3 and UKCM2. No plots produced - no plotting in VALSO?

`runACC`: Plotting the barootropic timeseries and shelfbreak timeseries is switched off - why? 



