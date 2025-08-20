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
  cp run_proc.bash "$TMP_DIR/run_proc.bash"
  echo "export MARINE_VAL=$TMP_DIR" >> "param.bash"
  echo "export MSKPATH=$TMP_DIR/MESH_MASK_DIR" >> "param.bash"
  echo "export CDFPATH=$TMP_DIR/CDFTOOLS_DIR/bin" >> "param.bash"
  echo "export NMLPATH=$TMP_DIR/nam_cdf_names" >> "param.bash"
  echo "export OBSPATH=$TMP_DIR/OBS_PATH_DIR" >> "param.bash"

  # Create the necessary directories and files
  mkdir -p "$TMP_DIR/CDFTOOLS_DIR/bin"
  mkdir -p "$TMP_DIR/MESH_MASK_DIR"
  mkdir -p "$TMP_DIR/OBS_PATH_DIR"
  touch "$TMP_DIR/CDFTOOLS_DIR/bin/cdf_tool"
  touch "$TMP_DIR/MESH_MASK_DIR/mesh_mask.nc"
  touch "$TMP_DIR/MESH_MASK_DIR/bathy.nc"
  touch "$TMP_DIR/nam_cdf_names"
  touch "$TMP_DIR/OBS_PATH_DIR/obs_abs_sal.nc"
  touch "$TMP_DIR/OBS_PATH_DIR/obs_con_tem.nc"
}

# Function to clean up the temporary environment after a test
function cleanup_test_env() {
  rm -rf "$TMP_DIR"
}