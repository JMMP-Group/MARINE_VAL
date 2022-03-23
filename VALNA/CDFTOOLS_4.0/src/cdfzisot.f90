PROGRAM cdfzisot
  !!======================================================================
  !!                     ***  PROGRAM  cdfzisot  ***
  !!=====================================================================
  !!  ** Purpose : Compute isothermal depth
  !!
  !!  ** Method  : - compute surface properties
  !!               - initialize depths and model levels number
  !!
  !! History : 3.0  : 07/2012  : F.Hernandez: Original code
  !!         : 4.0  : 03/2017  : J.M. Molines  
  !!           
  !!----------------------------------------------------------------------
  USE cdfio
  USE modcdfnames
  !!----------------------------------------------------------------------
  !! CDFTOOLS_4.0 , MEOM 2017 
  !! $Id$
  !! Copyright (c) 2017, J.-M. Molines 
  !! Software governed by the CeCILL licence (Licence/CDFTOOLSCeCILL.txt)
  !! @class derived_fields
  !!----------------------------------------------------------------------
  IMPLICIT NONE

  INTEGER(KIND=4),PARAMETER                    :: pnvarout = 2   ! number of output variables
  INTEGER(KIND=4)                              :: ji, jj, jk, jt ! dummy loop index
  INTEGER(KIND=4)                              :: jref           ! dummy loop index
  INTEGER(KIND=4)                              :: narg, iargc, ii ! browse line
  INTEGER(KIND=4)                              :: ijarg          ! line parser
  INTEGER(KIND=4)                              :: npiglo, npjglo ! domain size
  INTEGER(KIND=4)                              :: npk, npt       ! domain size
  INTEGER(KIND=4)                              :: ncout, ierr    ! ncid of output file, error status
  INTEGER(KIND=4), DIMENSION(pnvarout)         :: ipk, id_varout ! levels and varid's of output vars
  INTEGER(KIND=4), DIMENSION(:,:), ALLOCATABLE :: mbathy         ! mbathy metric

  REAL(KIND=4)                                 :: rtref          ! reference temperature
  REAL(KIND=4)                                 :: rmisval        ! Missing value of temperature
  REAL(KIND=4), DIMENSION(:),      ALLOCATABLE :: gdept          ! depth of T levels
  REAL(KIND=4), DIMENSION(:),      ALLOCATABLE :: gdepw          ! depth of W levels
  REAL(KIND=4), DIMENSION(1)                   :: rdep           ! dummy depth for output
  REAL(KIND=4), DIMENSION(:,:),    ALLOCATABLE :: rtem, rtemxz   ! temperature
  REAL(KIND=4), DIMENSION(:,:),    ALLOCATABLE :: tmask          ! temperature mask
  REAL(KIND=4), DIMENSION(:,:),    ALLOCATABLE :: glam,gphi      ! lon/lat
  REAL(KIND=4), DIMENSION(:,:),    ALLOCATABLE :: rzisot         ! depth of the isotherm
  REAL(KIND=4), DIMENSION(:,:),    ALLOCATABLE :: rzisotup       ! depth of the isotherm above
  !                                                              ! in case of inversion
  REAL(KIND=4), DIMENSION(:,:,:),  ALLOCATABLE :: rtem3d        ! 3d temperature

  REAL(KIND=8), DIMENSION(:),      ALLOCATABLE :: dtim           ! time counter

  CHARACTER(LEN=256)                           :: cf_tfil        ! input T file
  CHARACTER(LEN=256)                           :: cf_out='zisot.nc'! defaults output file name
  CHARACTER(LEN=256)                           :: cldum           ! dummy value

  TYPE(variable), DIMENSION(pnvarout)          :: stypvar        ! structure for output var. attributes

  LOGICAL                                      :: lnc4 = .FALSE.  ! Use nc4 with chunking and deflation
  LOGICAL                                      :: l3d  = .FALSE.  ! load full 3d variable in memory
  !!----------------------------------------------------------------------
  CALL ReadCdfNames()

  narg = iargc()
  IF ( narg == 0 ) THEN
     PRINT *,' usage : cdfzisot -t T-file -iso ISO-temp [-o OUT-file] [-nc4] [-3d]'
     PRINT *,'      '
     PRINT *,'     PURPOSE :'
     PRINT *,'       Compute the depth of an isotherm surface from the temperature file'
     PRINT *,'       and value of the isotherm given on the command line.'
     PRINT *,'      '
     PRINT *,'     ARGUMENTS :'
     PRINT *,'       -t T-file  : input netcdf file with the ocean temperature.' 
     PRINT *,'       -iso ISO-temp : Indicates the temperature (Celsius) of the chosen'
     PRINT *,'            isotherm.'
     PRINT *,'      '
     PRINT *,'     OPTIONS :'
     PRINT *,'        [-o OUT-file] : specify the output file name instead of ',TRIM(cf_out)
     PRINT *,'        [-nc4]  : Use netcdf4 output with chunking and deflation level 1.'
     PRINT *,'             This option is effective only if cdftools are compiled with'
     PRINT *,'             a netcdf library supporting chunking and deflation.'
     PRINT *,'        [-l3d]  : Read temperature variable as 3d ionstead of xz slice '
     PRINT *,'                  ( depending of the chunking pattern of the file '
     PRINT *,'                  it could speed up a lot the tool if your machine memory is big enough)'
     PRINT *,'      '
     PRINT *,'     REQUIRED FILES :'
     PRINT *,'        ',TRIM(cn_fzgr)
     PRINT *,'         In case of FULL STEP configuration, ',TRIM(cn_fbathylev),' is also required.'
     PRINT *,'      '
     PRINT *,'     OUTPUT : '
     PRINT *,'       netcdf file : ', TRIM(cf_out) ,' unless option -o is used.'
     PRINT *,'      '
     STOP 
  ENDIF

  ijarg=1
  DO WHILE ( ijarg <= narg ) 
     CALL getarg (ijarg, cldum ) ; ijarg=ijarg+1
     SELECT CASE ( cldum )
     CASE ( '-t'  ) ; CALL getarg (ijarg, cf_tfil) ; ijarg=ijarg+1
     CASE ( '-iso') ; CALL getarg (ijarg, cldum  ) ; ijarg=ijarg+1 ; READ(cldum,*) rtref
        ! options
     CASE ( '-o'  ) ; CALL getarg (ijarg, cf_out ) ; ijarg=ijarg+1
     CASE ( '-nc4') ; lnc4 = .TRUE. 
     CASE ( '-l3d') ; l3d  = .TRUE. 
     CASE DEFAULT   ; PRINT *,' ERROR : ',TRIM(cldum),' : unknown option.' ; STOP 99
     END SELECT
  ENDDO

  IF ( chkfile(cf_tfil) .OR. chkfile(cn_fzgr) ) STOP 99 ! missing file

  ! read dimensions 
  npiglo = getdim (cf_tfil,cn_x)
  npjglo = getdim (cf_tfil,cn_y)
  npk    = getdim (cf_tfil,cn_z)
  npt    = getdim (cf_tfil,cn_t)

  ALLOCATE (gdept(npk), gdepw(npk), dtim(npt) )
  ALLOCATE (rtem(npiglo,npjglo), rtemxz(npiglo,npk) )
  ALLOCATE (tmask(npiglo,npjglo), glam(npiglo,npjglo), gphi(npiglo,npjglo) )
  ALLOCATE (rzisot(npiglo,npjglo) , rzisotup(npiglo,npjglo) )
  ALLOCATE (mbathy(npiglo,npjglo) )
  ALLOCATE (rtem3d(npiglo,npjglo,npk))

  ! read metrics gdept and gdepw
  gdept(:)    = getvare3(cn_fzgr, cn_gdept, npk )
  gdepw(:)    = getvare3(cn_fzgr, cn_gdepw, npk)

  ! read "mbathy"
  mbathy(:,:) = getvar(cn_fzgr, cn_mbathy,    1, npiglo, npjglo)

  ! get missing value of votemper
  rmisval = getatt(cf_tfil, cn_votemper, cn_missing_value )

  ! get longitude and latitude
  glam(:,:) = getvar(cf_tfil, cn_vlon2d, 1, npiglo, npjglo)
  gphi(:,:) = getvar(cf_tfil, cn_vlat2d, 1, npiglo, npjglo)

  ! initialize tmask: 1=valid / 0= no valid of SST
  tmask(:,:) = 1.
  rtem( :,:) = getvar(cf_tfil, cn_votemper, 1, npiglo, npjglo, ktime=1 )  
  WHERE ( rtem == rmisval ) tmask = 0.
  ! initialise matrix of results
  rzisot   = 0. ; WHERE ( rtem == rmisval ) rzisot   = rmisval
  rzisotup = 0. ; WHERE ( rtem == rmisval ) rzisotup = rmisval

  CALL CreateOutput
  
  IF (l3d) THEN
     rtem3d=getvar3d(cf_tfil, cn_votemper, npiglo, npjglo, npk)
  END IF

  DO jt=1,npt
     DO jj = 1 , npjglo
        IF (MOD(jj,100) == 0) PRINT *, jj,'/',npjglo

        ! read temperature on x-z slab
        rtemxz(:,:) = rtem3d(:,jj,:) !getvarxz(cf_tfil, cn_votemper, jj, npiglo, npk, kimin=1, kkmin=1, ktime=jt )
        IF (l3d) THEN
           rtemxz(:,:) = rtem3d(:,jj,:) !getvarxz(cf_tfil, cn_votemper, jj, npiglo, npk, kimin=1, kkmin=1, ktime=jt )
        ELSE
           rtemxz(:,:) = getvarxz(cf_tfil, cn_votemper, jj, npiglo, npk, kimin=1, kkmin=1, ktime=jt )
        END IF

        DO ji = 1, npiglo
           IF ( tmask(ji,jj) == 1 ) THEN
              IF ( COUNT( rtemxz(ji,:)>=rtref .AND. rtemxz(ji,:) .NE.rmisval ) > 0 ) THEN

                 jk = 1 ! count level down

                 ! take into account temperature inversion from the surface
                 IF ( rtemxz(ji,1)<rtref .AND. rtemxz(ji,1) /= rmisval ) THEN

                    ! search first level with T >= rtref
                    DO WHILE ( jk < npk .AND. rtemxz(ji,jk) < rtref .AND. rtemxz(ji,jk) /=  rmisval )
                       jref = jk
                       jk = jk + 1
                    ENDDO

                    ! compute depth of the above isotherm
                    rzisotup(ji,jj) = ( gdept(jk-1)*( rtemxz(ji,jk)-rtref ) + &
                         & gdept(jk)*( rtref-rtemxz(ji,jk-1) ) ) / &
                         & ( rtemxz(ji,jk)-rtemxz(ji,jk-1) )

                    !write(12,*)ji,jj,glam(ji,jj),gphi(ji,jj),rzisotup(ji,jj)

                 ENDIF

                 ! then start from the first level with T >= rtref
                 ! and search first value below rtref
                 jref = 0
                 DO WHILE ( jk < npk .AND. rtemxz(ji,jk) >= rtref .AND. rtemxz(ji,jk) /=  rmisval )
                    jref = jk
                    jk = jk + 1
                 ENDDO

                 ! test if the level is the last "wet level" in model metrics
                 ! OR if next temperature value is missing
                 ! Or at the bottom
                 ! --> give value of the bottom of the layer: gdepw(k+1)
                 IF ( jref == mbathy(ji,jj) .OR. rtemxz(ji,jref+1) == rmisval .OR. jref == npk-1 ) THEN
                    rzisot(ji,jj) = gdepw(jref+1)
                 ELSE
                    rzisot(ji,jj) = ( gdept(jref)*( rtemxz(ji,jref+1)-rtref ) + &
                         & gdept(jref+1)*( rtref-rtemxz(ji,jref) ) ) / &
                         & ( rtemxz(ji,jref+1)-rtemxz(ji,jref) )
                 ENDIF

              ENDIF  ! COUNT( rtemxz(ji,:)>=rtref
           ENDIF  ! tmask(ji,jj) == 1

        ENDDO ! ji = 1, npiglo
     ENDDO ! jj = 1 , npjglo

     ! Store the zisot variable in output file
     ierr = putvar(ncout, id_varout(1), rzisot, 1, npiglo, npjglo, ktime=jt)
     ierr = putvar(ncout, id_varout(2), rzisotup, 1, npiglo, npjglo, ktime=jt)

  END DO ! time loop

  ierr = closeout(ncout)

CONTAINS

  SUBROUTINE CreateOutput
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE CreateOutput  ***
    !!
    !! ** Purpose :  Create netcdf output file(s) 
    !!
    !! ** Method  :  Use stypvar global description of variables
    !!
    !!----------------------------------------------------------------------
    WRITE(cldum,'(f6.2)') rtref
    ! define structure to write the computed isotherm depth
    rdep(1) = 0.
    ipk(:)                    = 1
    stypvar(1)%ichunk         = (/npiglo,MAX(1,npjglo/30),1,1 /)
    stypvar(1)%cname          = 'zisot'
    stypvar(2)%ichunk         = (/npiglo,MAX(1,npjglo/30),1,1 /)
    stypvar(2)%cname          = 'zisotup'
    stypvar%cunits            = 'm'
    stypvar%rmissing_value    = 32767.
    stypvar%valid_min         = 0.
    stypvar%valid_max         = 7000.
    stypvar(1)%clong_name     = 'Depth_of_'//TRIM(cldum)//'C_isotherm' 
    stypvar(2)%clong_name     = 'Depth_of_'//TRIM(cldum)//'C_upper_isotherm' 
    stypvar(1)%cshort_name    = 'D'//TRIM(cldum)
    stypvar(2)%cshort_name    = 'D'//TRIM(cldum)//'up'
    stypvar%conline_operation = 'N/A'
    stypvar%caxis             = 'TYX'

    ! Create output file, based on existing input gridT file
    ncout = create      (cf_out, cf_tfil, npiglo, npjglo, 1               , ld_nc4=lnc4)
    ierr  = createvar   (ncout,  stypvar, pnvarout,      ipk,    id_varout, ld_nc4=lnc4)
    ierr  = putheadervar(ncout,  cf_tfil, npiglo, npjglo, 1, pdep=rdep)

    dtim = getvar1d(cf_tfil, cn_vtimec, npt     )
    ierr = putvar1d(ncout,   dtim,      npt, 'T')

  END SUBROUTINE CreateOutput

END PROGRAM cdfzisot
