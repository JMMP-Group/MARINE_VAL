#!/bin/bash
# run_test_setup.bash

# Exit immediately if a command exits with a non-zero status.
set -ex

echo "Current working directory: $(pwd)"

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
  export PARAMS="../param.bash"

  if [ ! -f ../run_proc_orig.bash ]; then
    mv ../run_proc.bash ../run_proc_orig.bash
  fi
  sed '/moo_wait() {/,/^}/d; /slurm_wait() {/,/^}/d; /retrieve_data() {/,/^}/d; /run_tool() {/,/^}/d' "../run_proc_orig.bash" > "../run_proc.bash"
  echo "Contents of run_proc.bash:"
  cat ../run_proc.bash
  
  # Create an empty param.bash and add the mock paths to it
  > "$PARAMS"
  # cp run_proc.bash "$TMP_DIR/run_proc.bash"
  echo "export MARINE_VAL=.." >> "$PARAMS"
  echo "export MSKPATH=$TMP_DIR/MESH_MASK_DIR" >> "$PARAMS"
  echo "export CDFPATH=$TMP_DIR/CDFTOOLS_DIR/bin" >> "$PARAMS"
  echo "export NMLPATH=$TMP_DIR/nam_cdf_names" >> "$PARAMS"
  echo "export EXEPATH=\${MARINE_VAL}" >> "$PARAMS"
  echo "export SCRPATH=\${MARINE_VAL}/SCRIPT" >> "$PARAMS"
  echo "export DATPATH=$TMP_DIR/DATA" >> "$PARAMS"
  echo "export OBSPATH=$TMP_DIR/OBS_PATH_DIR" >> "$PARAMS"
  echo "export OBS_MESH=\${OBSPATH}/obs_mesh.nc" >> "$PARAMS"
  echo "export OBS_ABS_SAL=\${OBSPATH}/obs_abs_sal.nc" >> "$PARAMS"
  echo "export OBS_CON_TEM=\${OBSPATH}/obs_con_tem.nc" >> "$PARAMS"
  # echo "export runOBS=1" >> "$PARAMS"

  echo "Contents of param.bash:"
  cat "$PARAMS"

  # Source the param.bash file to set environment variables
  source "$PARAMS"

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