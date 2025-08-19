#!/bin/bash
set -e

echo "--- Test 4: Missing arguments ---"

source ./tests/run_test_setup.bash

setup_test_env

cd "$TMP_DIR"
../run_proc.bash -B bathy.nc -C 1 mesh_mask.nc 2020 2020 2> error_output.txt || true

if ! grep -q "run_proc.sh \[-C chunksize\] \[-B BATHY\] \[MESHMASK\] \[YEARB\] \[YEARE\] \[FREQ\] \[RUNID list\]" error_output.txt; then
  echo "Test failed: Expected usage message was not found."
  cleanup_test_env
  exit 1
fi

cleanup_test_env
echo "Test passed."