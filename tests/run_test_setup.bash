#!/bin/bash
# run_test_setup.bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Mock functions from run_proc.bash
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
  touch "$TMP_DIR/param.bash"
  echo "export MARINE_VAL=$TMP_DIR" >> "$TMP_DIR/param.bash"
  echo "export MSKPATH=$TMP_DIR/MESH_MASK_DIR" >> "$TMP_DIR/param.bash"
  echo "export CDFPATH=$TMP_DIR/CDFTOOLS_DIR/bin" >> "$TMP_DIR/param.bash"
  echo "export NMLPATH=$TMP_DIR/nam_cdf_names" >> "$TMP_DIR/param.bash"
  echo "export OBSPATH=$TMP_DIR/OBS_PATH_DIR" >> "$TMP_DIR/param.bash"
  
  # Create the necessary directories and files
  mkdir -p "$TMP_DIR/CDFTOOLS_DIR/bin"
  mkdir -p "$TMP_DIR/MESH_MASK_DIR"
  mkdir -p "$TMP_DIR/OBS_PATH_DIR"
  touch "$TMP_DIR/CDFTOOLS_DIR/bin/cdf_tool"
  touch "$TMP_DIR/MESH_MASK_DIR/mesh_mask.nc"
  touch "$TMP_DIR/MESH_MASK_DIR/bathy.nc"
  touch "$TMP_DIR/nam_cdf_names"
  touch "$TMP_DIR/OBS_PATH_DIR/your_obs_abs_sal_file.nc"
  touch "$TMP_DIR/OBS_PATH_DIR/your_obs_con_tem_file.nc"
}

# Function to clean up the temporary environment after a test
function cleanup_test_env() {
  rm -rf "$TMP_DIR"
}