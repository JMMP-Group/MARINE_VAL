#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH --mem=100000
#SBATCH --output=/scratch/hadom/tmp/NAVAL_valid_new_%A.out
#SBATCH --error=/scratch/hadom/tmp/NAVAL_valid_new_%A.err
#SBATCH --job-name=NAALL_valid.sh
#SBATCH --time=6:00:00
#SBATCH --qos=normal
#SBATCH --ntasks=1

# Run on SPICE with "sbatch test_complete.sh"
###SBATCH --mem=100000

conda activate valna
ulimit -s unlimited

VALID_NA_DIR=/data/users/hadom/branches/git/MARINE_VAL/VALNA
# call with pairs of suite-name, config

while getopts 'n:s:c:' opt; do
    case "$opt" in
    n) nsuites="$OPTARG";;
    s) suites="$OPTARG";;
    c) configs="$OPTARG";;
    ?) exit 2;; # User passed in an invalid flag; `getopts` already     printed an error message
    esac
done

echo "$suites"
suitelist=($(echo $suites | tr ' ' ' '))
echo "${suitelist[0]}"
configlist=($(echo $configs | tr ' ' ' '))
echo "${configlist[0]}"
for ((i=0;i<${nsuites};i++)); do
  echo "$i ${suitelist[i]} ${configlist[i]}"
done 

start_year=1978
for ((i=0;i<${nsuites};i++)); do
  YEARST_1=`moo ls moose:/crum/${suitelist[i]}/ony.nc.file/*grid[_-]T*.nc  | head -1 | cut -d _ -f 4 | cut -c 1-4`
  YEARE_1=`moo ls moose:/crum/${suitelist[i]}/ony.nc.file/*grid[_-]T*.nc  | tail -1 | cut -d _ -f 4 | cut -c 1-4`
  echo "$YEARE_1"
  cd $VALID_NA_DIR
  #if (( $((YEARST_1 )) < $((start_year)) )); then
  #  start_year=$YEARST_1
  #fi
  start_year=$YEARST_1
  start_year=$((YEARST_1+1))
  echo "$VALID_NA_DIR/run_all_annual.bash ${configlist[i]} $start_year $start_year 1y ${suitelist[i]}"
  for ((iyr=$start_year;iyr<=${YEARE_1};iyr++)); do
    echo "run_all for year $iyr"
    $VALID_NA_DIR/run_all_annual.bash ${configlist[i]} $iyr $iyr 1y ${suitelist[i]}
  done
done

outdir=$(printf "_%s" "${suitelist[@]}")
outdir=${outdir:1}
echo "$VALID_NA_DIR/run_plot_VALNA.bash ${outdir}_new 1y ${suites} > NA_valid.out 2>&1"
$VALID_NA_DIR/run_plot_VALNA.bash ${outdir}_new 1y ${suites} > NA_valid.out 2>&1
mv ${outdir}_new.png /home/h06/hadom/public_html/valid_ocean/VALNA/
