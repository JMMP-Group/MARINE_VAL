#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_mxl.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3
GRID='T'

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
FILE=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]${GRID}.nc`
if [ ! -f $FILE ] ; then echo "$FILE is missing; exit"; echo "E R R O R in : ./mk_mxl.bash $@ (see S${JOBOUT_PATH}/mk_mxl_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# calculate MXL in Labrador Sea in March using density criteria (0.03 kg/m3 difference between rho at surface and MLD)
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${GRID}_mxl_rho_003_criteria.nc
$CDFPATH/cdfmxl -t $FILE -s $FILE -nc4 -o tmp_$FILEOUT

#Compute 7 estimates of the mixed layer depth from temperature
#        and salinity given in the input file, based on 3 different criteria:
#        1- Density criterium (0.01 kg/m3 difference between surface and MLD)
#        2- Density criterium (0.03 kg/m3 difference between surface and MLD)
#        3- Temperature criterium (0.2 C absolute difference between surface
#           and MLD)
#        4- Temperature criterium (0.2 C absolute difference between T at 10m
#           and MLD)
#        5- Temperature criterium (0.5 C absolute difference between T at 10m
#           and MLD)
#        6- Density criterium (0.03 kg/m3 difference between rho at 10m and MLD)
#        7- Density criterium (0.125 kg/m3 difference between rho at 10m and MLD)

#          variables : somxl010    = mld on density criterium 0.01 ref. surf.
#                      somxl030    = mld on density criterium 0.03 ref. surf.
#                      somxlt02    = mld on temperature criterium -0.2 ref. surf.
#                      somxlt02z10 = mld on temperature criterium -0.2 ref. 10m
#                      somxlt05z10 = mld on temperature criterium -0.5 ref. 10m
#                      somxl030z10 = mld on density criterium 0.03 ref. 10m
#                      somxl125z10 = mld on density criterium 0.125 ref. 10m
# mv output file
if [[ $? -eq 0 ]]; then
   mv tmp_$FILEOUT $FILEOUT
else
   echo "error when running cdfmxl; exit"; echo "E R R O R in : ./mk_mxl.bash $@ (see ${JOBOUT_PATH}/mxl_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

# averaging MXL depth in Lab Sea: 60° W–50° W, 55° N–62° N
ijbox=$($CDFPATH/cdffindij -c mesh.nc -w -60.000 -50.000  55.000  62.000 | tail -2 | head -1)
echo ijbox
$CDFPATH/cdfmean -f $FILEOUT -v 'somxl030' -p T -w ${ijbox} 0 0 -minmax -o tmp_LAB_MXL_$FILEOUT
# this step needed because cdfmean sets a strange value for valid_max and that messes up the plotting routines.
ncatted -a valid_max,mean_somxl030,d,, tmp_LAB_MXL_$FILEOUT

# mv output file
if [[ $? -eq 0 ]]; then
   mv tmp_LAB_MXL_$FILEOUT LAB_MXL_$FILEOUT
else
   echo "error when running cdfmean; exit"; echo "E R R O R in : ./mk_mxl.bash $@ (see ${JOBOUT_PATH}/mxl_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi



