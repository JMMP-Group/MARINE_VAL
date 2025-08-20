#!/bin/bash
set -e

echo "--- Test 2: Missing Dependencies ---"

source ./tests/run_test_setup.bash
source ../run_proc.bash

setup_test_env

rm -rf "$TMP_DIR/CDFTOOLS_DIR"

cd "$TMP_DIR"
../run_proc.bash -B bathy.nc mesh_mask.nc 2020 2020 1m RUNID_TEST > output.txt 2> error_output.txt || true

if ! grep -q "E R R O R : CDFTOOLS/bin directory does not exist or is empty" error_output.txt; then
  echo "Test failed: Expected error message for missing CDFTOOLS not found."
  cleanup_test_env
  exit 1
fi

cleanup_test_env
echo "Test passed."