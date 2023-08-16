#!/bin/bash
#SBATCH --mem=30G
#SBATCH --time=10
#SBATCH --ntasks=1

xtrac=false
bottom=false
while getopts BS:s: opt 
   do
   case $opt in
      B) bottom=true ;;
      s) section=$OPTARG ;;
      S) section=$OPTARG 
         xtrac=true      ;;
   esac
done
shift `expr $OPTIND - 1`

if [[ -z "$section" || $# -ne 4 ]]; then echo 'mk_trp.bash [-B] -s/S [name of section] [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

if [[ ${section} == "DenmarkStrait" ]]; then 
  xtrac=true ; 
  bottom=false ;
#  dens_cutoff=1029.0  seemed appropriate for forced runs
  dens_cutoff=27.8
elif [[ ${section} == "FaroeBankChannel" ]]; then 
  xtrac=true
  bottom=false
  dens_cutoff=27.8
fi

CONFIG=$1
RUNID=$2
TAG=$3
FREQ=$4

echo "TAG, section, xtrac, bottom : $TAG $section $xtrac $bottom"

# load path and mask
. param.bash
. ${SCRPATH}/common.bash

cd $DATPATH/

# name
RUN_NAME=${RUNID#*-}

# download data if needed (useless if data already there)
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-V
#${SCRPATH}/get_data.bash $RUNID $FREQ $TAG grid-U

# check presence of input file
FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
FILEU=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_trp2.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

BTM=""
ln -s ${MSKPATH}/bathymetry_${CONFIG}-GO6.nc bathy.nc
if [[ "$bottom" == "true" ]]; then
  # calculate "barotropic" component of transport as U_bottom * channel width * channel height
  # create 3D masked projection of bottom field with call to bottom_field.py, then call cdftransport as usual
  # cut out small area first to save on memory in the bottom field calculation.
  # create separate subdirectory to stop parallel jobs getting confused about the mesh and bathy files. 
  if [[ ! -d bottom_${section} ]];then mkdir bottom_${section};fi
  cd bottom_${section}
  lonlatbox=$(cat ${EXEPATH}/SECTIONS/clip_LONLAT_${section}.dat)
  ijbox=($($CDFPATH/cdffindij -c ../mesh.nc -p T -w ${lonlatbox} | tail -2 | head -1))
  FILET_ORIG=$FILET
  FILEU_ORIG=$FILEU
  FILEV_ORIG=$FILEV
  echo "pwd: $PWD"
  echo "FILET : $FILET : $(ls -l ../$FILET)"
  ncks ../$FILET -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},${ijbox[3]} -o ${FILET_ORIG%.nc}_clip${section}.nc
  if [[ $? != 0 ]];then 
     # this just for u-ai758!!!
     ncks ../$FILET -O -d x_grid_T,${ijbox[0]},${ijbox[1]} -d y_grid_T,${ijbox[2]},${ijbox[3]} -o ${FILET_ORIG%.nc}_clip${section}.nc
  fi
  ncks ../$FILEU -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},${ijbox[3]} -o ${FILEU_ORIG%.nc}_clip${section}.nc
  if [[ $? != 0 ]];then 
     # this just for u-ai758!!!
     ncks ../$FILEU -O -d x_grid_U,${ijbox[0]},${ijbox[1]} -d y_grid_U,${ijbox[2]},${ijbox[3]} -o ${FILEU_ORIG%.nc}_clip${section}.nc
  fi
  ncks ../$FILEV -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},${ijbox[3]} -o ${FILEV_ORIG%.nc}_clip${section}.nc
  if [[ $? != 0 ]];then 
     # this just for u-ai758!!!
     ncks ../$FILEV -O -d x_grid_V,${ijbox[0]},${ijbox[1]} -d y_grid_V,${ijbox[2]},${ijbox[3]} -o ${FILEV_ORIG%.nc}_clip${section}.nc
  fi
  echo "ls : $(ls -l)"
  if [[ ! -f mesh_clip${section}.nc ]];then
     echo "clipping mesh file with command:"
     echo "ncks ../mesh.nc -O -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},${ijbox[3]} -o mesh_clip${section}.nc"
     ncks ../mesh.nc -O -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},${ijbox[3]} -o mesh_clip${section}.nc
  fi
  if [[ ! -f bathy_clip${section}.nc ]];then
     ncks ../bathy.nc -O -d x,${ijbox[0]},${ijbox[1]} -d y,${ijbox[2]},${ijbox[3]} -o bathy_clip${section}.nc
  fi
  bottom_field.py ${FILEU_ORIG%.nc}_clip${section}.nc uo -G U -M mesh_clip${section}.nc --3D
  bottom_field.py ${FILEV_ORIG%.nc}_clip${section}.nc vo -G V -M mesh_clip${section}.nc --3D
  FILET="${FILET_ORIG%.nc}_clip${section}.nc"
  FILEU="${FILEU_ORIG%.nc}_clip${section}_bottom3D.nc" 
  FILEV="${FILEV_ORIG%.nc}_clip${section}_bottom3D.nc"
  ln -s mesh_clip${section}.nc mesh.nc
  ln -s mesh_clip${section}.nc mask.nc
  ln -s bathy_clip${section}.nc bathy.nc
  BTM="bottom_"
fi

if [[ "$xtrac" == "true" ]]; then
  # extract cross section if required
  echo "section is $section"
  $CDFPATH/cdf_xtrac_brokenline -t $FILET -u $FILEU -v $FILEV -l ${EXEPATH}/SECTIONS/section_XTRAC_${section}.dat -b bathy.nc -vecrot -o nemoXsec_${RUN_NAME}o_${FREQ}_${TAG}_${BTM}
  if [[ $? -ne 0 ]]; then 
     echo "error when running cdf_xtrac_brokenline; exit" ; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_trp_${section}_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
  fi
fi

if [[ -n "$dens_cutoff" ]]; then

  # overflow transport defined by a cutoff density
  xsec_file=$(ls nemoXsec_${RUN_NAME}o_${FREQ}_${TAG}_${section}.nc)
  #xsec_file="$(echo $xsec | rev | cut -d"_" -f2- | rev).nc"
  echo "xsec_file = $xsec_file"
  $CDFPATH/cdfsigtrp -brk $xsec_file -smin ${dens_cutoff} -smax 40.0 -nbins 1 -o ${xsec_file%.nc}_
  if [[ $? -ne 0 ]]; then 
    echo "error when running cdfsigtrp for section file ${xsec}; exit" ; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_trp_${section}_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
  fi

else

  # total and positive/negative transports in channel
  $CDFPATH/cdftransport -u $FILEU -v $FILEV -lonlat -noheat -vvl -pm -sfx ${BTM}nemo_${RUN_NAME}o_${FREQ}_${TAG} < ${EXEPATH}/SECTIONS/section_LONLAT_${section}.dat
  if [[ $? -ne 0 ]]; then 
    echo "error when running cdftransport; exit" ; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_trp_${section}_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
  fi

fi

if [[ "$bottom" == "true" ]];then
   # move output back to main directory
   mv ${section}* nemoXsec* ..
   cd ..
fi
