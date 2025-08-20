#!/bin/bash

set -ex

# Source the common setup script
source ./tests/run_test_setup.bash

echo "Running all integration tests..."

# Test 1: A valid, simple run
echo ""
echo "-------------------------------------"
echo "Running test_valid_run.bash"
source ./tests/test_valid_run.bash

# Test 2: Test with missing dependencies
echo ""
echo "-------------------------------------"
echo "Running test_missing_deps.bash"
source ./tests/test_missing_deps.bash

# Test 3: Test with user choices for Southern Ocean
echo ""
echo "-------------------------------------"
echo "Running test_user_choices.bash"
source ./tests/test_user_choices.bash

# Test 4: Test with missing arguments
echo ""
echo "-------------------------------------"
echo "Running test_missing_args.bash"
source ./tests/test_missing_args.bash

# Test 5: Test with missing or invalid file paths
echo ""
echo "-------------------------------------"
echo "Running test_invalid_paths.bash"
source ./tests/test_invalid_paths.bash

echo ""
echo "-------------------------------------"
echo "All tests passed successfully!"