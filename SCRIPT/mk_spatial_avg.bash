#!/bin/bash
#SBATCH --mem=20G
#SBATCH --time=10
#SBATCH --ntasks=1

while getopts f: opt 
   do
   case $opt in
      f) field=$OPTARG ;;
   esac
done
shift `expr $OPTIND - 1`

if [[ -z "$field" || $# -ne 3 ]]; then echo 'mk_spatial_avg.bash [RUNID (u-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

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

# calculate globally averaged value
echo "mk_spatial_avg.bash : making global average"
echo "$SCRPATH/reduce_fields.py -i $FILE -v $field -c longitude latitude -A mean -G measures self -g cell_area depth -o $FILEOUT"
FILEOUT=GlobalMean_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v $field -c longitude latitude depth -A mean -G measures self -g cell_area cell_thickness -o $FILEOUT 

# calculate averaged value 0-1000m
FILEOUT=GlobalMean_upper_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v $field -c longitude latitude depth -A mean -G measures self -g cell_area cell_thickness -B 1000.0 -o $FILEOUT 

# calculate averaged value 1000+m
FILEOUT=GlobalMean_lower_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v $field -c longitude latitude depth -A mean -G measures self -g cell_area cell_thickness -T 1000.0 -o $FILEOUT 

# make globally averaged T profile
FILEOUT=GlobalProfile_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
$SCRPATH/reduce_fields.py -i $FILE -v $field -c longitude latitude -A mean -G measures -g cell_area -o $FILEOUT 

# Gather all the spatial means into one file
ncrename -v ${field},${field}_mean GlobalMean_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
ncks -v ${field}_mean  GlobalMean_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc \
     -O -o Spatial_Means_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
rm GlobalMean_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc

ncrename -v ${field},${field}_mean_upper GlobalMean_upper_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
ncks GlobalMean_upper_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc -v ${field}_mean_upper \
     -A Spatial_Means_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
rm GlobalMean_upper_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc

ncrename -v ${field},${field}_mean_lower GlobalMean_lower_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
ncks GlobalMean_lower_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc -v ${field}_mean_lower \
     -A Spatial_Means_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc
rm GlobalMean_lower_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc

# Keep the spatially meaned profiles as a separate file. 
ncrename -v ${field},${field}_mean_prof GlobalProfile_nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}.nc

