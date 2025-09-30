#!/bin/bash
#SBATCH --mem=200G
#SBATCH --time=360
#SBATCH --ntasks=4

if [[ $# -ne 3 ]]; then echo 'mk_moc.bash [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

RUNID=$1
TAG=$2
FREQ=$3

echo "TAG: $TAG; RUNID: $RUNID; FREQ: $FREQ"

# Create working directory if needed
if [ ! -d vrmp   ]; then mkdir -p vrmp ; fi

cd vrmp

# Carrying out conservative vertical remapping (vrmp) on the global grid is quite expensive 
# (CDFTOOLS is not parallelised).
# However, since GOSI10 uses local ME s-coordinates only in the Nordic OVF region, only the 
# zonally integrated overturning streamfunction in depth space diagnostic needs conservative 
# vertical remapping (vrmp). Therefore, to speed up the computation, we crop out here the files 
# to include only the Atlantic.
# Note that when local-MEs will be applied in other regions of the model domain (e.g., the Southern 
# Ocean) we will need to do this step outside this script and in a more geneal way.

MIN_LON=-114.5
MAX_LON=70
MIN_LAT=-50
MAX_LAT=60
ijbox=$($CDFPATH/cdffindij -w ${MIN_LON} ${MAX_LON} ${MIN_LAT} ${MAX_LAT} -c ../zco_mesh.nc -p T | tail -2 | head -1 )
echo "ijbox : $ijbox"
ijbox=($ijbox)
if [ ! -f zgr_amoc.nc ] ; then
   ncks -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},-1 ../zgr.nc               -O zgr_amoc.nc
fi
if [ ! -f mesh_amoc.nc ] ; then
   ncks -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},-1 ../mesh.nc              -O mesh_amoc.nc
fi
if [ ! -f bathy_amoc.nc ] ; then
   ncks -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},-1 ../bathy.nc             -O bathy_amoc.nc
fi
if [ ! -f subbasinmask_amoc.nc ] ; then
   ncks -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},-1 ../subbasinmask_amoc.nc -O subbasinmask_amoc.nc
fi
if [[ ! -L mesh_h.nc     ]] ; then ln -s mesh_amoc.nc mesh_h.nc ; fi
if [[ ! -L mesh_z.nc     ]] ; then ln -s mesh_amoc.nc mesh_z.nc ; fi
if [[ ! -L mask.nc       ]] ; then ln -s mesh_amoc.nc mask.nc   ; fi
if [[ ! -L nam_cdf_names ]] ; then 
   cp $DATPATH/$RUNID/nam_cdf_names nam_cdf_names_ori
   f90nml -g nammeshmask \
          -v cn_fzgr='mesh_z.nc' \
          -v cn_fhgr='mesh_h.nc' \
          -p nam_cdf_names_ori nam_cdf_names
   rm nam_cdf_names_ori
fi

# name
RUN_NAME=${RUNID#*-}
scheme="ppm"

for var in T S V U; do

    echo $var

    case $var in

      T)
        grd=T
        vname=thetao_pot
        ;;
      S)
        grd=T
        vname=so_pra
        ;;
      V)
        grd=V
        vname=vo
        ;;
      U)
        grd=U
        vname=uo
        ;;
    esac 

    # check presence of input file
    FILE=`ls ../[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]${grd}.nc`
    if [ ! -f $FILE ] ; then 
       echo "$FILE is missing; exit"
       echo "E R R O R in : ./mk_vrmp.bash $@ (see SLURM/${RUNID}/mk_vrmp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt
       exit 1
    fi

    FILEOUT=nemo_${RUN_NAME}o_${FREQ}_${TAG}_grid-${grd}.nc

    if [[ "${var}" == S ]]; then
       oname=vrmp_${FILEOUT}
    else
       oname=vrmp.amoc_${FILEOUT}
    fi
    
    if [ ! -f amoc_$FILEOUT ] ; then
       ncks -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},-1 $FILE -O amoc_$FILEOUT
    fi

    $CDFPATH/cdfvrmp -m zgr_amoc.nc -f amoc_${FILEOUT} -v ${vname} -p ${grd} -s ${scheme} -o ${oname} -verbose

    if [[ "${var}" == S ]]; then
       ncks -A -v so_pra vrmp_${FILEOUT} vrmp.amoc_${FILEOUT}
       rm vrmp_${FILEOUT}
    fi 

    # For the rapid profile we need to add the wind to the file U
    if [[ "${var}" == U ]]; then
       ncks -A -v tauuo amoc_${FILEOUT} vrmp.amoc_${FILEOUT}
    fi

done
