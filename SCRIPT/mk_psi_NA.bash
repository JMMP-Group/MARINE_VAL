#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

if [[ $# -ne 3 ]]; then echo 'mk_psi.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3

# name
RUN_NAME=${RUNID#*-}

# check presence of input file
FILEU=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

# calculate barotropic streamfunction (psi) in m3/s (global)
FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_psi_NA.nc
$CDFPATH/cdfpsi -u $FILEU -v $FILEV -V -vvl -nc4 -ref 1 1 -o tmp_$FILEOUT

# V is given to integrate from West to East ==> dpsiv for North Atlantic
#https://github.com/meom-group/CDFTOOLS/blob/master/src/cdfpsi.f90
#
#FILEU = zonal velocity
#FILEV = meridional velocity
#
#-vvl, variable is max_sobarstf from run_plot_VALNA.bash
#
#-nc4 - netcdf output file with chunking
#
#-ref 1 1 - sets the reference point from default of zero
#
#-o - output filename


# mv output file
#if the previous command =! 0, save it otherwise return an error
if [[ $? -eq 0 ]]; then 
   mv tmp_$FILEOUT $FILEOUT
else 
   echo "error when running cdfpsi; exit"; echo "E R R O R in : ./mk_psi.bash $@ (see ${JOBOUT_PATH}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
fi

# NA subpolar min

ijbox=$($CDFPATH/cdffindij -c mesh.nc -p T -w -60.000 -20.000 48.000 72.000 | tail -2 | head -1)
#Return the model limit (i,j space) of the geographical window
#        given on the input line.
#
#-c - coordinate file (mesh.nc)
#-p - specify the point on a C-grid (T,U,V,F)
# min/max lat/lon --> changed to -60.000 -20.000 48.000 72.000
#xmin xmax ymin ymax or  (longmin longmax latmin latmax)


$CDFPATH/cdfmean -f $FILEOUT -v sobarstf -p T -w ${ijbox} 0 0 -minmax -o BSF_NA_$FILEOUT
# Computes the mean value of the field (3D, weighted). For 3D fields,
#         a horizontal mean for each level is also given. If a 2D spatial window
#         is specified, the mean value is computed only in this window.
if [ $? -ne 0 ] ; then echo "error when running cdfmean (WG)"; echo "E R R O R in : ./mk_psi.bash $@ (see ${JOBOUT_PATH}/mk_psi_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; fi
# this step needed because cdfmean sets a strange value for valid max and that messes up the plotting routines.
ncatted -a valid_min,min_sobarstf,d,, -a valid_max,min_sobarstf,d,, BSF_NA_$FILEOUT
