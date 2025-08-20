#!/bin/bash
set -e

echo "--- Test 3: User Choices from param.bash ---"

source ./tests/run_test_setup.bash
source ../run_proc.bash

setup_test_env

sed -i 's/RUNALL=0/RUNALL=0/' "$TMP_DIR/param.bash"
sed -i 's/RUNVALSO=1/RUNVALSO=1/' "$TMP_DIR/param.bash"
sed -i 's/runACC=0/runACC=0/' "$TMP_DIR/param.bash"

cd "$TMP_DIR"
../run_proc.bash -B bathy.nc mesh_mask.nc 2020 2020 1m RUNID_TEST > output.txt 2>&1

if ! grep -q "MOCK SBATCH: --job-name=P.._mk_psi_SO_20200101" output.txt; then
  echo "Test failed: Expected 'mk_psi_SO' job was not submitted, indicating user choices were not respected."
  cleanup_test_env
  exit 1
fi

cleanup_test_env
echo "Test passed."