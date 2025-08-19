#!/bin/bash
set -e

echo "--- Test 1: A valid run ---"

source ./tests/run_test_setup.bash

setup_test_env

cd "$TMP_DIR"
../run_proc.bash -B bathy.nc -C 1 mesh_mask.nc 2020 2020 1m RUNID_TEST > output.txt 2>&1

if ! grep -q "MOCK SBATCH: --output=.*mk_msks.out /.*/mk_msks.bash" output.txt; then
  echo "Test failed: Expected 'mk_msks.bash' job was not submitted."
  cleanup_test_env
  exit 1
fi

if ! grep -q "MOCK SBATCH: --job-name=moo_1m_grid-._20200101 --output=.*moo_1m_grid-._20200101.out /.*/get_data.bash" output.txt; then
  echo "Test failed: Expected a data retrieval job to be submitted."
  cleanup_test_env
  exit 1
fi

if ! grep -q "data processing is done for RUNID_TEST between 2020 and 2020" output.txt; then
  echo "Test failed: Expected success message not found."
  cleanup_test_env
  exit 1
fi

cleanup_test_env
echo "Test passed."