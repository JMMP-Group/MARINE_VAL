#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 5 ]]; then echo "mk_compute_obs_stats.bash [VAR] [TIME] [REF] [FILE_IN] [FILEOUT]"; exit 1 ; fi

VAR=$1
TIME=$2
FILEIN=$3 
REF=$4    
FILEOUT=$5

# compute
# 1) the mean
ncwa -O -v $VAR -a $TIME ${FILEIN} mean_${FILEIN}
mean_obs=`ncdump -v $VAR mean_${FILEIN} | sed -e "1,/data:/d" -e '$d' -e "s/$VAR =//g" -e "s/;//g"`
mean_obs="${mean_obs//$'\n'/}"
# 2) the deviations with respect to the mean
ncbo -O -v $VAR ${FILEIN} mean_${FILEIN} dev_${FILEIN}
# 3) the sum of the square of the deviations, then divide by (N-1) and take the square root
ncra -O -y rmssdn dev_${FILEIN} std_dev_${FILEIN}
std_obs=`ncdump -v $VAR std_dev_${FILEIN} | sed -e "1,/data:/d" -e '$d' -e "s/$VAR =//g" -e "s/;//g"`
std_obs="${std_obs//$'\n'/}"

# trim whitespace
mean_obs="$(echo "$mean_obs" | xargs)" 
std_obs="$(echo "$std_obs" | xargs)"

# create output file
cat > "${MARINE_VAL}/OBS/${FILEOUT}" << EOF
ref = ${REF}
mean = ${mean_obs}
std = ${std_obs}
EOF



