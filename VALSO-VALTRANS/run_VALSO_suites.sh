#!/bin/bash -l
#SBATCH --export=NONE
#SBATCH --mem=100000
#SBATCH --output=/scratch/hadom/tmp/SOVAL_valid_%A.out
#SBATCH --error=/scratch/hadom/tmp/SOVAL_valid_%A.err
#SBATCH --job-name=SOVAL_valid.sh
#SBATCH --time=6:00:00
#SBATCH --qos=normal
#SBATCH --ntasks=1

# Run on SPICE with "sbatch test_complete.sh"
###SBATCH --mem=100000

ulimit -s unlimited

VALID_SO_DIR=/data/users/hadom/branches/git/MARINE_VAL/VALSO-VALTRANS
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
#start_year=1850
for ((i=0;i<${nsuites};i++)); do
  YEARST_1=`moo ls moose:/crum/${suitelist[i]}/ony.nc.file/*grid[_-]T*.nc  | head -1 | cut -d _ -f 4 | cut -c 1-4`
  YEARE_1=`moo ls moose:/crum/${suitelist[i]}/ony.nc.file/*grid[_-]T*.nc  | tail -1 | cut -d _ -f 4 | cut -c 1-4`
  echo "YEARE_1 $YEARE_1"
  echo "YEARST_1 $YEARST_1"
  cd $VALID_SO_DIR
  #if (( $((YEARST_1)) < $((start_year)) )); then
  #  start_year=$YEARST_1
  #fi
  start_year=$YEARST_1
  start_year=$((YEARST_1+1))
  echo "start year $start_year"
  echo "$VALID_SO_DIR/run_all_annual.bash ${configlist[i]} $start_year $start_year 1y ${suitelist[i]}"
  for ((iyr=$start_year;iyr<=${YEARE_1};iyr++)); do
    echo "run_all for year $iyr"
    $VALID_SO_DIR/run_all_annual.bash ${configlist[i]} $iyr $iyr 1y ${suitelist[i]}
  done
done

outdir=$(printf "_%s" "${suitelist[@]}")
outdir=${outdir:1}
echo "$VALID_SO_DIR/run_plot_VALSO.bash ${outdir}_new ${suites} > SO_valid.out 2>&1"
$VALID_SO_DIR/run_plot_VALSO.bash ${outdir}_new 1y ${suites} > SO_valid.out 2>&1
cp ${outdir}_new.png /home/h06/hadom/public_html/valid_ocean/SO_VAL/
