TOOLS=$1
rm ${TOOLS}_mod

# add declaration
#awk '/CHARACTER\(LEN=256\)/ && !x {print "  CHARACTER(LEN=256)                         :: cd_x,cd_y,cd_t      ! dimension name"; x=1} 1' ${TOOLS} > ${TOOLS}_mod

# rm finddim
#sed -i "/.\+CALL finddimname.\+/d" ${TOOLS}_mod

# dimension
#DIMX=`grep getdim ${TOOLS}_mod | grep cn_x` ; DIMX_new=`echo $DIMX | sed s/\)/", cdtrue=cd_x)"/`;
#sed -i "s/$DIMX/\ \ $DIMX_new/" ${TOOLS}_mod
#DIMY=`grep getdim ${TOOLS}_mod | grep cn_y` ; DIMY_new=`echo $DIMY | sed s/\)/", cdtrue=cd_y)"/`;
#sed -i "s/$DIMY/\ \ $DIMY_new/" ${TOOLS}_mod
#DIMT=`grep getdim ${TOOLS}_mod | grep cn_t` ; DIMT_new=`echo $DIMT | sed s/\)/", cdtrue=cd_t)"/`;
#sed -i "s/$DIMT/\ \ $DIMT_new/" ${TOOLS}_mod
#
# variable
#sed -i '/ncout = create      (/i\ \ \ \ ! get varname needed'              ${TOOLS}_mod
#sed -i '/ncout = create      (/i\ \ \ \ CALL findvarname(cf_in,cn_vlon2d)' ${TOOLS}_mod
#sed -i '/ncout = create      (/i\ \ \ \ CALL findvarname(cf_in,cn_vlat2d)' ${TOOLS}_mod
#sed -i '/ncout = create      (/i\ \ \ \ CALL findvarname(cf_in,cn_vtimec)' ${TOOLS}_mod
#sed -i '/ncout = create      (/i\ \ \ \ !'                                 ${TOOLS}_mod

#vimdiff $TOOLS ${TOOLS}_mod
#vi $TOOLS
