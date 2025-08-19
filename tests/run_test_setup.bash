#!/bin/bash
# run_test_setup.bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Mock the 'sbatch' command to write to stdout
sbatch() {
  echo "MOCK SBATCH: $@"
}
export -f sbatch

# Mock other commands used in the run_proc.bash
slurm_wait() { :; }
moo_wait() { :; }
sacct() { echo ""; }
squeue() { echo "P$$"; } # Add this new mock function
export -f slurm_wait moo_wait sacct squeue

# Function to set up the temporary environment for a test
function setup_test_env() {
  export TMP_DIR=$(mktemp -d)
  cp param.bash "$TMP_DIR/param.bash"
  mkdir -p "$TMP_DIR/CDFTOOLS_DIR/bin"
  mkdir -p "$TMP_DIR/MESH_MASK_DIR"
  touch "$TMP_DIR/CDFTOOLS_DIR/bin/cdf_tool"
  touch "$TMP_DIR/MESH_MASK_DIR/mesh_mask.nc"
  touch "$TMP_DIR/MESH_MASK_DIR/bathy.nc"
  touch "$TMP_DIR/nam_cdf_names"
}

# Function to clean up the temporary environment after a test
function cleanup_test_env() {
  rm -rf "$TMP_DIR"
}