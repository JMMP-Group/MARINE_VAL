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
FILEOUT0=meanT-global_nemo_${RUN_NAME}o_${FREQ}_${TAG}
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A mean -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL.nc -o ${FILEOUT0}_grid-${GRID}.nc
# First calculate the depth field from the 3D thickness field,
# then take the area mean to get a mean depth.
$SCRPATH/reduce_fields.py -i $FILE -v thkcello -c depth -A sum -m tmask_GLOBAL.nc -o ${FILEOUT0}_depths.nc
ncatted -a coordinates,thkcello,m,c,"nav_lat nav_lon time_centered" ${FILEOUT0}_depths.nc
$SCRPATH/reduce_fields.py -i ${FILEOUT0}_depths.nc -v thkcello -G mesh.nc mesh.nc -g e1t e2t -c latitude longitude -A mean -m tmask_GLOBAL.nc -S -o ${FILEOUT0}_mean_depth.nc
ncrename -v thkcello,mean_depth ${FILEOUT0}_mean_depth.nc
ncks -v mean_depth ${FILEOUT0}_mean_depth.nc -A ${FILEOUT0}_grid-${GRID}.nc
ncap2 -v -s "thetao_pot_depth_integral=thetao_pot*mean_depth" ${FILEOUT0}_grid-${GRID}.nc -o ${FILEOUT0}_thetao_pot_depth_int.nc
ncks -v thetao_pot_depth_integral ${FILEOUT0}_thetao_pot_depth_int.nc -A ${FILEOUT0}_grid-${GRID}.nc
rm ${FILEOUT0}_thetao_pot_depth_int.nc

# make globally averaged 0-1000m heat content
FILEOUT1=meanT-global-top-1000m_nemo_${RUN_NAME}o_${FREQ}_${TAG}
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A mean -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL_maxdepth-1000.nc -o ${FILEOUT1}_grid-${GRID}.nc
# First calculate the depth field from the 3D thickness field,
# then take the area mean to get a mean depth.
$SCRPATH/reduce_fields.py -i $FILE -v thkcello -c depth -A sum -m tmask_GLOBAL_maxdepth-1000.nc -o ${FILEOUT1}_depths.nc
ncatted -a coordinates,thkcello,m,c,"nav_lat nav_lon time_centered" ${FILEOUT1}_depths.nc
# use tmask_GLOBAL.nc here because we are using the -S flag to indicate surface fields
$SCRPATH/reduce_fields.py -i ${FILEOUT1}_depths.nc -v thkcello -G mesh.nc mesh.nc -g e1t e2t -c latitude longitude -A mean -m tmask_GLOBAL.nc -S -o ${FILEOUT1}_mean_depth.nc
ncrename -v thkcello,mean_depth ${FILEOUT1}_mean_depth.nc
ncks -v mean_depth ${FILEOUT1}_mean_depth.nc -A ${FILEOUT1}_grid-${GRID}.nc
ncap2 -v -s "thetao_pot_depth_integral=thetao_pot*mean_depth" ${FILEOUT1}_grid-${GRID}.nc -o ${FILEOUT1}_thetao_pot_depth_int.nc
ncks -v thetao_pot_depth_integral ${FILEOUT1}_thetao_pot_depth_int.nc -A ${FILEOUT1}_grid-${GRID}.nc
rm ${FILEOUT1}_thetao_pot_depth_int.nc

# make globally averaged 1000m+ heat content
FILEOUT2=meanT-global-below-1000m_nemo_${RUN_NAME}o_${FREQ}_${TAG}
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A mean -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL_mindepth-1000.nc -o ${FILEOUT2}_grid-${GRID}.nc
# First calculate the depth field from the 3D thickness field,
# then take the area mean to get a mean depth.
$SCRPATH/reduce_fields.py -i $FILE -v thkcello -c depth -A sum -m tmask_GLOBAL_mindepth-1000.nc -o ${FILEOUT2}_depths.nc
ncatted -a coordinates,thkcello,m,c,"nav_lat nav_lon time_centered" ${FILEOUT2}_depths.nc
# use tmask_GLOBAL.nc here because we are using the -S flag to indicate surface fields
$SCRPATH/reduce_fields.py -i ${FILEOUT2}_depths.nc -v thkcello -G mesh.nc mesh.nc -g e1t e2t -c latitude longitude -A mean -m tmask_GLOBAL.nc -S -o ${FILEOUT2}_mean_depth.nc
ncrename -v thkcello,mean_depth ${FILEOUT2}_mean_depth.nc
# For layers below the surface we need to scale the depth-integral temperature by the ratio of the area of the top of this layer
# to the area of the top of the ocean, so this is depth-integral temperature per unit area of the surface of the ocean. We can
# get this ratio by manipulating the mean depths for the total volume (Dm0), for the upper layer (Dm1) and for the lower layer (Dm2)
# as follows: Area(top of lower layer)/Area(top of upper layer) = (Dm0 - Dm1)/Dm2
ncks -O -v mean_depth ${FILEOUT0}_mean_depth.nc -o ${FILEOUT2}_area_ratio_calc.nc
ncrename -v mean_depth,mean_depth0 ${FILEOUT2}_area_ratio_calc.nc
ncks -v mean_depth ${FILEOUT1}_mean_depth.nc -A ${FILEOUT2}_area_ratio_calc.nc
ncrename -v mean_depth,mean_depth1 ${FILEOUT2}_area_ratio_calc.nc
ncks -v mean_depth ${FILEOUT2}_mean_depth.nc -A ${FILEOUT2}_area_ratio_calc.nc
ncrename -v mean_depth,mean_depth2 ${FILEOUT2}_area_ratio_calc.nc
ncap2 -v -s "area_ratio=(mean_depth0-mean_depth1)/mean_depth2" ${FILEOUT2}_area_ratio_calc.nc -A ${FILEOUT2}_grid-${GRID}.nc
#
ncks -v mean_depth ${FILEOUT2}_mean_depth.nc -A ${FILEOUT2}_grid-${GRID}.nc
ncap2 -v -s "thetao_pot_depth_integral=thetao_pot*mean_depth*area_ratio" ${FILEOUT2}_grid-${GRID}.nc -o ${FILEOUT2}_thetao_pot_depth_int.nc
ncks -v thetao_pot_depth_integral ${FILEOUT2}_thetao_pot_depth_int.nc -A ${FILEOUT2}_grid-${GRID}.nc
rm ${FILEOUT2}_thetao_pot_depth_int.nc

rm *${RUN_NAME}o_${FREQ}_${TAG}_depths.nc *${RUN_NAME}o_${FREQ}_${TAG}_mean_depth.nc ${FILEOUT2}_area_ratio_calc.nc


