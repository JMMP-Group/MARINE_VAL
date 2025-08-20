#!/bin/bash
set -e

echo "--- Test 5: Missing or Invalid File Paths ---"

source ./tests/run_test_setup.bash
source ../run_proc.bash

setup_test_env

if [ -f "$TMP_DIR/MESH_MASK_DIR/mesh_mask.nc" ]; then
  rm "$TMP_DIR/MESH_MASK_DIR/mesh_mask.nc"
fi

cd "$TMP_DIR"
../run_proc.bash -B bathy.nc mesh_mask.nc 2020 2020 1m RUNID_TEST > output.txt 2> error_output.txt || true

if ! grep -q "E R R O R : Input meshmask .* does not exist or is not a file" error_output.txt; then
  echo "Test failed: Expected error message for missing mesh_mask file not found."
  cleanup_test_env
  exit 1
fi

cleanup_test_env
echo "Test passed."