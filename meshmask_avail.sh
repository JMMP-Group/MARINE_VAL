#!/bin/bash
#
# List available mesh_mask files based on the setting of MSKPATH in param.bash
#

MSKPATH=$(grep "^export.*MSKPATH" param.bash | cut -d"=" -f2)
echo "MSKPATH : $MSKPATH"
echo "Available mesh_mask files:"
mesh_files=$(ls $MSKPATH | grep "mesh")
for file in $mesh_files
do
    echo $file
done

exit 0


