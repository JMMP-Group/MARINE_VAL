#!/bin/bash
# run_test_setup.bash

# Exit immediately if a command exits with a non-zero status.
set -ex

# Mock slurm and mass commands for testing
sbatch() { echo "MOCK SBATCH: $@"; }
slurm_wait() { :; }
moo_wait() { :; }
sacct() { echo ""; }
squeue() { echo "P$$"; }
export -f sbatch slurm_wait moo_wait sacct squeue

# Function to set up the temporary environment for a test
function setup_test_env() {
  export TMP_DIR=$(mktemp -d)
  
  # Create an empty param.bash and add the mock paths to it
  > "param.bash"
  # cp run_proc.bash "$TMP_DIR/run_proc.bash"
  echo "export MARINE_VAL=." >> "param.bash"
  echo "export MSKPATH=$TMP_DIR/MESH_MASK_DIR" >> "param.bash"
  echo "export CDFPATH=$TMP_DIR/CDFTOOLS_DIR/bin" >> "param.bash"
  echo "export NMLPATH=$TMP_DIR/nam_cdf_names" >> "param.bash"
  echo "export EXEPATH=\${MARINE_VAL}" >> "param.bash"
  echo "export SCRPATH=\${MARINE_VAL}/SCRIPT" >> "param.bash"
  echo "export DATPATH=$TMP_DIR/DATA" >> "param.bash"
  echo "export OBSPATH=$TMP_DIR/OBS_PATH_DIR" >> "param.bash"
  echo "export OBS_MESH=\${OBSPATH}/obs_mesh.nc" >> "param.bash"
  echo "export OBS_ABS_SAL=\${OBSPATH}/obs_abs_sal.nc" >> "param.bash"
  echo "export OBS_CON_TEM=\${OBSPATH}/obs_con_tem.nc" >> "param.bash"
  # echo "export runOBS=1" >> "param.bash"

  echo "Contents of param.bash:"
  cat param.bash

  # Source the param.bash file to set environment variables
  source "param.bash"

  # Create the necessary directories and files
  mkdir -p "$MSKPATH"
  mkdir -p "$CDFPATH"
  mkdir -p "$DATPATH"
  mkdir -p "$OBSPATH"

  touch "$NMLPATH"
  touch "$CDFPATH/cdf_tool"
  touch "$MSKPATH/mesh_mask.nc"
  touch "$MSKPATH/bathy.nc"
  touch "$OBS_MESH"
  touch "$OBS_ABS_SAL"
  touch "$OBS_CON_TEM"
}

# Function to clean up the temporary environment after a test
function cleanup_test_env() {
  rm -rf "$TMP_DIR"
}