
#!/bin/bash
#
# List available mesh_mask files based on the setting of MSKPATH in param.bash
#

MSKPATH=$(grep "^export.*MSKPATH" param.bash | cut -d"=" -f2)
echo "MSKPATH : $MSKPATH"
echo ""
echo "Available mesh_mask (*mesh*) files:"
mesh_files=$(ls $MSKPATH | grep "mesh")
for file in $mesh_files
do
    echo $file
done
echo ""
echo "Available bathymetry (*bathy*) files:"
bathy_files=$(ls $MSKPATH | grep "bathy")
for file in $bathy_files
do
    echo $file
done

exit 0


