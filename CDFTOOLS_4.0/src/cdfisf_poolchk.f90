PROGRAM cdfisf_poolchk
  !!======================================================================
  !!                     ***  PROGRAM  cdfisf_poolchk  ***
  !!=====================================================================
  !!  ** Purpose : Build a mask-like file that marks the un-connected point
  !!              in a 3D mask files. Un-connected points are points which
  !!              do not communicate with the open ocean. This case is
  !!              frequent for the ocean cavity below the ice shelves.
  !!
  !!  ** Method  : Use a fillpool3D algorithm. This program use 3D arrays
  !!               and may be very memory consuming for big domains.
  !!
  !! History :   3.0  : 11/2016  : J.M. Molines. P. Mathiot (original code)
  !!         :   4.0  : 03/2017  : J.M. Molines  
  !!----------------------------------------------------------------------
  !!   routines                                         : description
  !!----------------------------------------------------------------------
  !!----------------------------------------------------------------------
  USE cdfio
  USE modcdfnames
  USE modutils
  !!----------------------------------------------------------------------
  !! CDFTOOLS_4.0 , MEOM 2017 
  !! $Id$
  !! Copyright (c) 2017, J.-M. Molines 
  !! Software governed by the CeCILL licence (Licence/CDFTOOLSCeCILL.txt)
  !! @class ice_shelf_processing
  !!----------------------------------------------------------------------
  IMPLICIT NONE

  INTEGER(KIND=4)                               :: ji, jj, jk        ! dummy loop index
  INTEGER(KIND=4)                               :: narg, ijarg       ! command line
  INTEGER(KIND=4)                               :: npiglo, npjglo    ! domain dimension
  INTEGER(KIND=4)                               :: npk               ! domain dimension
  INTEGER(KIND=4)                               :: iiseed, ijseed    ! working seeds
  INTEGER(KIND=4)                               :: ikseed, ijmax     ! working seeds
  INTEGER(KIND=4)                               :: ifill = 2
  INTEGER(KIND=4)                               :: ncid, id          ! netcdf stuff
  INTEGER(KIND=4)                               :: ierr, ncout       ! netcdf stuff
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: ipk               ! arrays of vertical level for each var
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: id_varout         ! varid's of average vars

  INTEGER(KIND=2), DIMENSION(:,:),   ALLOCATABLE :: itab             ! 2D working array
  INTEGER(KIND=2), DIMENSION(:,:,:), ALLOCATABLE :: itab3d, itmask   ! 3D working array

  REAL(KIND=4), DIMENSION(:),        ALLOCATABLE :: rsum             ! iceshelf draft
  REAL(KIND=4), DIMENSION(:,:),      ALLOCATABLE :: rdraft           ! iceshelf draft

  CHARACTER(LEN=255)                             :: cf_in            ! input filename
  CHARACTER(LEN=255)                             :: cf_out='poolmask.nc' !default output filename
  CHARACTER(LEN=255)                             :: cf_isfdr='isf_draft.nc' ! filename for isf_draft
  CHARACTER(LEN=255)                             :: cv_isfdr='isf_draft' ! name of isf_draft variable
  CHARACTER(LEN=255)                             :: cldum            ! working char variable

  TYPE (variable), DIMENSION(:),    ALLOCATABLE  :: stypvar          ! attributes for average values

  LOGICAL                                        :: lchk=.FALSE.     ! missing files flag
  LOGICAL                                        :: lnc4=.FALSE.     ! netcdf4 flag
  !!----------------------------------------------------------------------
  CALL ReadCdfNames()

  narg = iargc()

  IF ( narg == 0 ) THEN
     PRINT *,' usage : cdfisf_poolchk -m MASK-file -d ISFDRAFT-file [-v ISFDRAFT-variable]'
     PRINT *,'            [-nc4] [-o OUT-file]'
     PRINT *,'      '
     PRINT *,'     PURPOSE :'
     PRINT *,'       Produces a netcdf mask file with 1 everywhere, except for points not '
     PRINT *,'       connected to the open ocean (frequent for cavities below ice-shelves),'
     PRINT *,'       which have 0 value. Both 3D and 2D variables are created, the 2D '
     PRINT *,'       variables being used for cdfisf_forcing.'
     PRINT *,'      '
     PRINT *,'     ARGUMENTS :'
     PRINT *,'       -m MASK-file : name of the input NEMO mask file, with tmask variable.'
     PRINT *,'       -d ISFDRAFT-file : name of the file with ice shelf draft.'
     PRINT *,'      '
     PRINT *,'     OPTIONS :'
     PRINT *,'       -v ISFDRAFT-variable: name of the variable for ice shelf draft.'
     PRINT *,'       -nc4 : use netcdf4 with chunking and deflation for the output.'
     PRINT *,'       -o OUT-file : name of the output file. [Default : ',TRIM(cf_out),' ]' 
     PRINT *,'      '
     PRINT *,'     REQUIRED FILES :'
     PRINT *,'       Only the mask file given as argument' 
     PRINT *,'      '
     PRINT *,'     OUTPUT : '
     PRINT *,'       netcdf file : ', TRIM(cf_out),' unless -o option is used.'
     PRINT *,'         variables : tmask_pool3d, tmask_pool2d'
     PRINT *,'      '
     PRINT *,'     SEE ALSO :'
     PRINT *,'      cdfisf_fill, cdfisf_forcing, cdfisf_rnf' 
     PRINT *,'      '
     STOP 
  ENDIF

  ijarg=1
  DO WHILE ( ijarg <= narg )
     CALL getarg(ijarg, cldum) ; ijarg = ijarg+1
     SELECT CASE ( cldum )
     CASE ( '-m'  ) ; CALL getarg(ijarg, cf_in   ) ; ijarg = ijarg+1
     CASE ( '-o'  ) ; CALL getarg(ijarg, cf_out  ) ; ijarg = ijarg+1
     CASE ( '-d'  ) ; CALL getarg(ijarg, cf_isfdr) ; ijarg = ijarg+1
     CASE ( '-v'  ) ; CALL getarg(ijarg, cv_isfdr) ; ijarg = ijarg+1
     CASE ( '-nc4') ; lnc4 = .TRUE.
     CASE DEFAULT   ; PRINT *,' ERROR : ', TRIM(cldum),' : unknown option.' ; STOP 99
     END SELECT
  ENDDO

  lchk = lchk .OR. chkfile(cf_in    )
  lchk = lchk .OR. chkfile(cf_isfdr)
  IF ( lchk ) STOP 99 ! missing files

  npiglo = getdim (cf_in,cn_x )
  npjglo = getdim (cf_in,cn_y )
  npk    = getdim (cf_in,cn_z )

  PRINT *, ' NPIGLO = ', npiglo
  PRINT *, ' NPJGLO = ', npjglo
  PRINT *, ' NPK    = ', npk

  ALLOCATE ( itab(npiglo, npjglo), itab3d( npiglo, npjglo, npk), itmask(npiglo, npjglo,npk) )
  ALLOCATE ( rdraft(npiglo, npjglo), rsum(npjglo) )
  ALLOCATE ( ipk(2), id_varout(2), stypvar(2))

  CALL CreateOutput

  ! Read ice shelf draft in order to find the northern limit of the cavities
  rdraft(:,:) = getvar(cf_isfdr, cv_isfdr, 1, npiglo, npjglo )
  rsum(:)     = SUM(rdraft, DIM=1 )
  ijmax=2
  DO jj=1, npjglo-1
     IF ( rsum(jj) /= 0. ) THEN
        ijmax=jj
     ENDIF
  ENDDO
  ijmax = MIN ( npjglo, ijmax+10 )

  ! JMM :note the use of 3D array ( very unusual in CDFTOOLS )
  itmask(:,:,:) = getvar3d (cf_in, cn_tmask, npiglo, npjglo, npk)
  itab3d(:,:,:) = itmask(:,:,:)

  ! set limits  for fillpool algo
  itab3d(:,ijmax  ,1:npk-1) = 0
  itab3d(:,ijmax-1,:) = 1  ! open a connection for sure at ijmax -1 (out of iceshelf cavities)
  itab3d(:,:,    1)   = 0  ! to set an upper limit !, assuming to cavities at this level
  iiseed= npiglo/2  ; ijseed = ijmax -1 ; ikseed = 2
  PRINT *,' SEED position',iiseed, ijseed, ikseed, itab3d(iiseed, ijseed, ikseed)

  CALL FillPool3D( iiseed, ijseed,ikseed, itab3d, -ifill )
  PRINT *, '  Number of disconected points : ', COUNT(  (itab3d(:,1:ijmax-2,:) == 1) )
  ! at this point itab3d (:,1:ijmax,:) can have 3 different values :
  !              0 where there where already 0
  !              -ifill where the ocean points are connected
  !              1 where ocean points in tmask are not connected
  itab(:,:) = itmask(:,:,1)  ! restore original tmask at surface
  itab(:,1:ijmax-2) = SUM(itab3d(:,1:ijmax-2,:), dim=3) 
  WHERE (itab(:,1:ijmax-2) > 0 ) itab(:,1:ijmax-2)=0
  WHERE (itab(:,1:ijmax-2) < 0 ) itab(:,1:ijmax-2)=1

  ierr = putvar( ncout, id_varout(1), itab(:,:), 1, npiglo, npjglo)

  DO jk = 1, npk 
     ierr = putvar( ncout, id_varout(2), itab3d(:,:,jk), jk, npiglo, npjglo)
  ENDDO

  ierr = closeout(ncout)

CONTAINS

  SUBROUTINE CreateOutput
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE CreateOutput  ***
    !!
    !! ** Purpose :  Create the output file. This is done outside the main
    !!               in order to increase readability of the code. 
    !!
    !! ** Method  :  Use global variables, defined in main 
    !!----------------------------------------------------------------------
    REAL(KIND=8), DIMENSION(1) :: dl_tim
    !!----------------------------------------------------------------------
    ! define new variables for output
    ipk(1) = 1  !  2D
    stypvar(1)%ichunk            = (/npiglo,MAX(1,npjglo/30),1,1 /)
    stypvar(1)%cname             = 'tmask_pool2d'
    stypvar(1)%rmissing_value    =  -99.
    stypvar(1)%valid_min         =  0.
    stypvar(1)%valid_max         =  1.
    stypvar(1)%clong_name        = '2d isf pool mask'
    stypvar(1)%cshort_name       = 'tmask_pool2d'
    stypvar(1)%conline_operation = 'N/A'
    stypvar(1)%caxis             = 'TYX'
    stypvar(1)%cprecision        = 'by'
    ! define new variables for output
    ipk(2) = npk  !  3D
    stypvar(2)%ichunk            = (/npiglo,MAX(1,npjglo/30),1,1 /)
    stypvar(2)%cname             = 'tmask_pool3d'
    stypvar(2)%rmissing_value    =  -99.
    stypvar(2)%valid_min         =  0.
    stypvar(2)%valid_max         =  1
    stypvar(2)%clong_name        = '3d isf pool mask'
    stypvar(2)%cshort_name       = 'tmask_pool3d'
    stypvar(2)%conline_operation = 'N/A'
    stypvar(2)%caxis             = 'TZYX'
    stypvar(2)%cprecision        = 'by'

    ! create output file taking the sizes in cf_fill
    ncout  = create      (cf_out, cf_in,   npiglo, npjglo, npk, ld_nc4=lnc4 )
    ierr   = createvar   (ncout,  stypvar, 2,   ipk, id_varout, ld_nc4=lnc4 )
    ierr   = putheadervar(ncout,  cf_in,   npiglo, npjglo, npk)

    dl_tim(1) = 0.d0
    ierr = putvar1d(ncout, dl_tim, 1, 'T')

  END SUBROUTINE CreateOutput

END PROGRAM cdfisf_poolchk
