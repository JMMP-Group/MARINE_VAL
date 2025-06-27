#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

VAR=$1
TOOL=$2
FILEOUT=$3

# compute
# 1) the mean
ncwa -O -v $VAR -a time_counter ${FILEOUT} mean_${FILEOUT}
mean_obs=`ncdump -v $VAR mean_${FILEOUT} | sed -e "1,/data:/d" -e '$d' -e "s/$VAR =//g" -e "s/;//g"`
mean_obs="${mean_obs//$'\n'/}"
# 2) the deviations with respect to the mean
ncbo -O -v $VAR ${FILEOUT} mean_${FILEOUT} dev_${FILEOUT}
# 3) the sum of the square of the deviations, then divide by (N-1) and take the square root
ncra -O -y rmssdn dev_${FILEOUT} std_dev_${FILEOUT}
std_obs=`ncdump -v $VAR std_dev_${FILEOUT} | sed -e "1,/data:/d" -e '$d' -e "s/$VAR =//g" -e "s/;//g"`
std_obs="${std_obs//$'\n'/}"

cat > "${MARINE_VAL}/OBS/${TOOL}_subp_obs.txt" << EOF
ref = WOA13v2
mean = ${mean_obs}
std = ${std_obs}
EOF