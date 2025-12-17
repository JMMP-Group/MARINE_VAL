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
heat_capacity=3991.86 # J/K
density=1026. # kg/m3
# need to use bc for floating point arithmetic (bash only does integer arithmetic)
factor=$(bc <<<$heat_capacity*$density)

# make globally averaged T profile
FILEOUT=Tprof_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude -A mean -G mesh.nc mesh.nc -g e1t e2t -m tmask_GLOBAL.nc -o $FILEOUT 

# make globally averaged full-depth heat content
FILEOUT=heatc-global_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A sum -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL.nc -o $FILEOUT 
ncap2 -v -s "heatc=thetao_pot*$factor" $FILEOUT -o heat_content.nc
ncatted -a units,heatc,m,c,"J" heat_content.nc
ncks -v heatc heat_content.nc -A $FILEOUT
#ncrename -v unknown_0,norm $FILEOUT

# make globally averaged 0-1000m heat content
FILEOUT=heatc-global-top-1000m_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A sum -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL_maxdepth-1000.nc -o $FILEOUT 
ncap2 -v -s "heatc=thetao_pot*$factor" $FILEOUT -o heat_content.nc
ncatted -a units,heatc,m,c,"J" heat_content.nc
ncks -v heatc heat_content.nc -A $FILEOUT
#ncrename -v unknown_0,norm $FILEOUT

# make globally averaged 1000m+ heat content
FILEOUT=heatc-global-below-1000m_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v thetao_pot -c longitude latitude depth -A sum -G mesh.nc mesh.nc self -g e1t e2t cell_thickness -m tmask_GLOBAL_mindepth-1000.nc -o $FILEOUT 
ncap2 -v -s "heatc=thetao_pot*$factor" $FILEOUT -o heat_content.nc
ncatted -a units,heatc,m,c,"J" heat_content.nc
ncks -v heatc heat_content.nc -A $FILEOUT
#ncrename -v unknown_0,norm $FILEOUT



