#!/bin/bash
#SBATCH --mem=10G
#SBATCH --time=20
#SBATCH --ntasks=1

xtrac=false
while getopts S:s: opt 
   do
   case $opt in
      s) section=$OPTARG ;;
      S) section=$OPTARG 
         xtrac=true      ;;
   esac
done
shift `expr $OPTIND - 1`

if [[ -z "$section" || $# -ne 4 ]]; then echo 'mk_trp.bash -s/S [name of section] [CONFIG (eORCA12, eORCA025 ...)] [RUNID (mi-aa000)] [TAG (19991201_20061201_ANN)] [FREQ (1y)]'; exit 1 ; fi

if [[ ${section} == "DenmarkStrait" ]]; then 
  xtrac=true ; 
#  dens_cutoff=1029.0  seemed appropriate for forced runs
  dens_cutoff=1027.8
elif [[ ${section} == "FaroeBankChannel" ]]; then 
  xtrac=true
  dens_cutoff=1027.8
fi

CONFIG=$1
RUNID=$2
TAG=$3
FREQ=$4

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
FILEV=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
FILEU=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
FILET=`ls ${DATINPATH}/[nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`
if [ ! -f $FILEV ] ; then echo "$FILEV is missing; exit"; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILEU ] ; then echo "$FILEU is missing; exit"; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi
if [ ! -f $FILET ] ; then echo "$FILET is missing; exit"; echo "E R R O R in : ./mk_trp2.bash $@ (see SLURM/${CONFIG}/${RUNID}/trp_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1 ; fi

#ln -s $FILET
#ln -s $FILEU
#ln -s $FILEV
#FILEV=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]V.nc`
#FILEU=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]U.nc`
#FILET=`ls [nu]*${RUN_NAME}o_${FREQ}_${TAG}*_grid[-_]T.nc`

if [[ "$xtrac" == "true" ]]; then
  # extract cross section if required
  echo "section is $section"
  $CDFPATH/cdf_xtrac_brokenline -t $FILET -u $FILEU -v $FILEV -l ${EXEPATH}/SECTIONS/section_XTRAC_${section}.dat -b ${DATPATH}/bathymetry.nc -vecrot -o nemoXsec_${RUN_NAME}o_${FREQ}_${TAG}_
  if [[ $? -ne 0 ]]; then 
     echo "error when running cdf_xtrac_brokenline; exit" ; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_trp_${section}_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
  fi
fi

if [[ -n "$dens_cutoff" ]]; then

  # overflow transport defined by a cutoff density
  xsec_file=$(ls nemoXsec_${RUN_NAME}o_${FREQ}_${TAG}_${section}.nc)
  #xsec_file="$(echo $xsec | rev | cut -d"_" -f2- | rev).nc"
  echo "xsec_file = $xsec_file"
  $CDFPATH/cdfsigtrp -brk $xsec_file -smin 27.8 -smax 30.0 -nbins 1 -o ${xsec_file%.nc}_
  if [[ $? -ne 0 ]]; then 
    echo "error when running cdfsigtrp for section file ${xsec}; exit" ; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_trp_${section}_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
  fi

else

  # total and positive/negative transports in channel
  $CDFPATH/cdftransport -u $FILEU -v $FILEV -lonlat -noheat -vvl -pm -sfx nemo_${RUN_NAME}o_${FREQ}_${TAG} < ${EXEPATH}/SECTIONS/section_LONLAT_${section}.dat
  if [[ $? -ne 0 ]]; then 
    echo "error when running cdftransport; exit" ; echo "E R R O R in : ./mk_trp.bash $@ (see SLURM/${CONFIG}/${RUNID}/mk_trp_${section}_${FREQ}_${TAG}.out)" >> ${EXEPATH}/ERROR.txt ; exit 1
  fi

fi
