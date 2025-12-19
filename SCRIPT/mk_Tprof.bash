#!/bin/bash
#SBATCH --mem=20G
#SBATCH --time=10
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_sst.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3
GRID='T'

# name
RUN_NAME=${RUNID#*-}

# download data if needed
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-${GRID}

# check presence of input file
FILE=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]${GRID}.nc`
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_sst.bash $@ (see SLURM/${RUNID}/mk_sst_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# values from NEMO
#heat_capacity=3991.86 # J/K/kg
#density=1026. # kg/m3
# need to use bc for floating point arithmetic (bash only does integer arithmetic)
#factor=$(echo "scale=12;$heat_capacity*$density" | bc)

# make globally averaged T profile
FILEOUT=Tprof_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude -A mean -G mesh.nc mesh.nc -g e1t e2t -m tmask_GLOBAL.nc -o $FILEOUT 

# make global mean temperature and also global mean ocean depth to facilitate conversion
# of changes in global mean temperature to equivalent heat fluxes.
FILEOUT=meanT-global_nemo_${RUN_NAME}o_${FREQ}_${TAG}
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A mean -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL.nc -o ${FILEOUT}_grid-${GRID}.nc
# First calculate the depth field from the 3D thickness field,
# then take the area mean to get a mean depth.
$SCRPATH/reduce_fields.py -i $FILE -v thkcello -c depth -A sum -m tmask_GLOBAL.nc -o ${FILEOUT}_depths.nc
ncatted -a coordinates,thkcello,m,c,"nav_lat nav_lon time_centered" ${FILEOUT}_depths.nc
$SCRPATH/reduce_fields.py -i ${FILEOUT}_depths.nc -v thkcello -G mesh.nc mesh.nc -g e1t e2t -c latitude longitude -A mean -m tmask_GLOBAL.nc -S -o ${FILEOUT}_mean_depth.nc
ncrename -v thkcello,mean_depth ${FILEOUT}_mean_depth.nc
ncks -v mean_depth ${FILEOUT}_mean_depth.nc -A ${FILEOUT}_grid-${GRID}.nc
ncap2 -v -s "thetao_pot_depth_integral=thetao_pot*mean_depth" ${FILEOUT}_grid-${GRID}.nc -o ${FILEOUT}_thetao_pot_depth_int.nc
ncks -v thetao_pot_depth_integral ${FILEOUT}_thetao_pot_depth_int.nc -A ${FILEOUT}_grid-${GRID}.nc
rm ${FILEOUT}_thetao_pot_depth_int.nc

# make globally averaged 0-1000m heat content
FILEOUT=meanT-global-top-1000m_nemo_${RUN_NAME}o_${FREQ}_${TAG}
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A mean -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL_maxdepth-1000.nc -o ${FILEOUT}_grid-${GRID}.nc
# First calculate the depth field from the 3D thickness field,
# then take the area mean to get a mean depth.
$SCRPATH/reduce_fields.py -i $FILE -v thkcello -c depth -A sum -m tmask_GLOBAL_maxdepth-1000.nc -o ${FILEOUT}_depths.nc
ncatted -a coordinates,thkcello,m,c,"nav_lat nav_lon time_centered" ${FILEOUT}_depths.nc
# use tmask_GLOBAL.nc here because we are using the -S flag to indicate surface fields
$SCRPATH/reduce_fields.py -i ${FILEOUT}_depths.nc -v thkcello -G mesh.nc mesh.nc -g e1t e2t -c latitude longitude -A mean -m tmask_GLOBAL.nc -S -o ${FILEOUT}_mean_depth.nc
ncrename -v thkcello,mean_depth ${FILEOUT}_mean_depth.nc
ncks -v mean_depth ${FILEOUT}_mean_depth.nc -A ${FILEOUT}_grid-${GRID}.nc
ncap2 -v -s "thetao_pot_depth_integral=thetao_pot*mean_depth" ${FILEOUT}_grid-${GRID}.nc -o ${FILEOUT}_thetao_pot_depth_int.nc
ncks -v thetao_pot_depth_integral ${FILEOUT}_thetao_pot_depth_int.nc -A ${FILEOUT}_grid-${GRID}.nc
rm ${FILEOUT}_thetao_pot_depth_int.nc

# make globally averaged 1000m+ heat content
FILEOUT=meanT-global-below-1000m_nemo_${RUN_NAME}o_${FREQ}_${TAG}
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A mean -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL_mindepth-1000.nc -o ${FILEOUT}_grid-${GRID}.nc
# First calculate the depth field from the 3D thickness field,
# then take the area mean to get a mean depth.
$SCRPATH/reduce_fields.py -i $FILE -v thkcello -c depth -A sum -m tmask_GLOBAL_mindepth-1000.nc -o ${FILEOUT}_depths.nc
ncatted -a coordinates,thkcello,m,c,"nav_lat nav_lon time_centered" ${FILEOUT}_depths.nc
# use tmask_GLOBAL.nc here because we are using the -S flag to indicate surface fields
$SCRPATH/reduce_fields.py -i ${FILEOUT}_depths.nc -v thkcello -G mesh.nc mesh.nc -g e1t e2t -c latitude longitude -A mean -m tmask_GLOBAL.nc -S -o ${FILEOUT}_mean_depth.nc
ncrename -v thkcello,mean_depth ${FILEOUT}_mean_depth.nc
ncks -v mean_depth ${FILEOUT}_mean_depth.nc -A ${FILEOUT}_grid-${GRID}.nc
ncap2 -v -s "thetao_pot_depth_integral=thetao_pot*mean_depth" ${FILEOUT}_grid-${GRID}.nc -o ${FILEOUT}_thetao_pot_depth_int.nc
ncks -v thetao_pot_depth_integral ${FILEOUT}_thetao_pot_depth_int.nc -A ${FILEOUT}_grid-${GRID}.nc
rm ${FILEOUT}_thetao_pot_depth_int.nc

rm *${RUN_NAME}o_${FREQ}_${TAG}_depths.nc *${RUN_NAME}o_${FREQ}_${TAG}_mean_depth.nc


