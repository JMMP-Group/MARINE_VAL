PROGRAM cdftopos
  !!======================================================================
  !!                     ***  PROGRAM  cdftopos  ***
  !!=====================================================================
  !!  ** Purpose : compute barotropic velocity topostrophy
  !!
  !!  ** Method  : compute topostrophy as in Merryfield and scott 2007 using the
  !                barotropic velocity (un . (-f x grad(H)))/(|f|.|grad(H)|)
  !!               
  !!
  !! History : 4.0  : 04/2018  : P. Mathiot original code
  !!----------------------------------------------------------------------
  USE cdfio
  USE modcdfnames
  !!----------------------------------------------------------------------
  !! CDFTOOLS_4.0 , MEOM 2017 
  !! $Id$
  !! Copyright (c) 2017, J.-M. Molines 
  !! Software governed by the CeCILL licence (Licence/CDFTOOLSCeCILL.txt)
  !! @class transport
  !!----------------------------------------------------------------------
  IMPLICIT NONE

  INTEGER(KIND=4)                            :: ji, jj, jk, jt       ! dummy loop index
  INTEGER(KIND=4)                            :: it                   ! time index
  INTEGER(KIND=4)                            :: kmin=0, kmax=0
  INTEGER(KIND=4)                            :: ierr                 ! working integer
  INTEGER(KIND=4)                            :: narg, iargc, ijarg   ! command line 
  INTEGER(KIND=4)                            :: npiglo, npjglo       ! size of the domain
  INTEGER(KIND=4)                            :: npk, npt             ! size of the domain
  INTEGER(KIND=4)                            :: ncout                ! ncid of output file
  INTEGER(KIND=4)                            :: nvarout = 1          ! number of output variables
  INTEGER(KIND=4), DIMENSION(:), ALLOCATABLE :: ipk, id_varout       ! for variable output

  REAL(KIND=4), DIMENSION(:),    ALLOCATABLE :: e31d                      ! e3t metrics (full step)
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: e1u, e1v                  ! horizontal metrics
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: e2u, e2v                  !  "            "
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: e3u, e3v                  ! vertical metrics
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: tmask, hdepw              ! tmask and bathymetry
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: zdhdx, zdhdy, zdh         ! bottom slope
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: zwghtu, zwghtv
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: zu, zv, zu_T, zv_T, zUn_T  ! velocity components
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: zff, ff                   ! coriolis parameter
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: ztopos

  REAL(KIND=8), DIMENSION(:),    ALLOCATABLE :: dtim                 ! time counter
  REAL(KIND=8), DIMENSION(:,:),  ALLOCATABLE :: dwku , dwkv          ! working arrays
  REAL(KIND=8), DIMENSION(:,:),  ALLOCATABLE :: dtrpu, dtrpv         ! barotropic transport 

  TYPE (variable), DIMENSION(:), ALLOCATABLE :: stypvar              ! structure for attribute

  CHARACTER(LEN=256)                         :: cf_ufil              ! input U- file
  CHARACTER(LEN=256)                         :: cf_vfil              ! input V- file
  CHARACTER(LEN=256)                         :: cf_out='topos.nc'    ! output file
  CHARACTER(LEN=256)                         :: cv_sotopos='sotopos' ! Along Slope TRansPort
  CHARACTER(LEN=256)                         :: cldum                ! dummy character variable

  LOGICAL                                    :: lchk   = .FALSE.     ! flag for missing files
  LOGICAL                                    :: lnc4   = .FALSE.     ! Use nc4 with chunking and deflation
  LOGICAL                                    :: lfull  = .FALSE.
  !!----------------------------------------------------------------------
  CALL ReadCdfNames()

  narg= iargc()
  IF ( narg == 0 ) THEN
     PRINT *,' usage : cdfvtrp -u U-file -v V-file [-vvl] ...'
     PRINT *,'               ... [-o OUT-file] [-nc4]'
     PRINT *,'      '
     PRINT *,'     PURPOSE :'
     PRINT *,'       Compute the vertically integrated transports at each grid cell.' 
     PRINT *,'      '
     PRINT *,'     ARGUMENTS :'
     PRINT *,'       -u U-file : netcdf gridU file' 
     PRINT *,'       -v V-file : netcdf gridV file' 
     PRINT *,'      '
     PRINT *,'     OPTIONS :'
     PRINT *,'       [-jk kmin kmax  ] : use mean velocity between level jk0 and jk1 instead of barotropic velocity'
     PRINT *,'       [-vvl  ] : Use time-varying vertical metrics'
     PRINT *,'       [-o OUT-file  ] : specify output file name instead of ',TRIM(cf_out)
     PRINT *,'       [-nc4 ]     : Use netcdf4 output with chunking and deflation level 1.'
     PRINT *,'                This option is effective only if cdftools are compiled with'
     PRINT *,'                a netcdf library supporting chunking and deflation.'
     PRINT *,'      '
     PRINT *,'     REQUIRED FILES :'
     PRINT *,'        ',TRIM(cn_fhgr),' and ',TRIM(cn_fzgr)
     PRINT *,'      '
     PRINT *,'     OUTPUT : '
     PRINT *,'       netcdf file : ', TRIM(cf_out) 
     PRINT *,'       variables : ' 
     PRINT *,'           sotopos : barotropic velocity topostrophy'
     PRINT *,'      '
     STOP 
  ENDIF

  ! scan command line and set flags
  ijarg = 1 
  DO WHILE ( ijarg <= narg ) 
     CALL getarg(ijarg, cldum) ; ijarg=ijarg+1
     SELECT CASE ( cldum ) 
     CASE ('-u'     ) ; CALL getarg(ijarg, cf_ufil) ; ijarg=ijarg+1
     CASE ('-v'     ) ; CALL getarg(ijarg, cf_vfil) ; ijarg=ijarg+1
        ! options
     CASE ('-jk'    ) ; CALL getarg(ijarg, cldum) ; ijarg = ijarg + 1 ; READ(cldum,*) kmin
          ;             CALL getarg(ijarg, cldum) ; ijarg = ijarg + 1 ; READ(cldum,*) kmax
     CASE ('-full'  ) ; lfull  = .TRUE.
     CASE ('-vvl'   ) ; lg_vvl = .TRUE.
     CASE ('-o'     ) ; CALL getarg(ijarg, cf_out) ; ijarg=ijarg+1
     CASE ('-nc4'   ) ; lnc4   = .TRUE.
     CASE DEFAULT     ; PRINT *,' ERROR : ',TRIM(cldum),' : unknown option.' ; STOP 99
     END SELECT
  ENDDO
  
  ! file existence check
  lchk = lchk .OR. chkfile ( cn_fzgr )
  lchk = lchk .OR. chkfile ( cn_fhgr )
  lchk = lchk .OR. chkfile ( cf_ufil )
  lchk = lchk .OR. chkfile ( cf_vfil )
  IF ( lchk ) STOP 99   ! missing files

  IF ( lg_vvl) THEN
     cn_fe3u = cf_ufil
     cn_fe3v = cf_vfil
     cn_ve3u = cn_ve3uvvl
     cn_ve3v = cn_ve3vvvl
  ENDIF

  ALLOCATE ( ipk(nvarout), id_varout(nvarout), stypvar(nvarout) )

  npiglo = getdim (cf_ufil, cn_x)
  npjglo = getdim (cf_ufil, cn_y)
  npk    = getdim (cf_ufil, cn_z)
  npt    = getdim (cf_ufil, cn_t)

  PRINT *, 'npiglo = ', npiglo
  PRINT *, 'npjglo = ', npjglo
  PRINT *, 'npk    = ', npk
  PRINT *, 'npt    = ', npt

  IF (kmin==0 .AND. kmax==0) THEN
     kmin=1 ; kmax=npk
  END IF
  ! Allocate arrays
  ALLOCATE ( e1v(npiglo,npjglo)  , e2v(npiglo,npjglo)  , e3v(npiglo,npjglo)  )
  ALLOCATE ( e1u(npiglo,npjglo)  , e2u(npiglo,npjglo)  , e3u(npiglo,npjglo)  )
  ALLOCATE ( zu(npiglo,npjglo)   , zv(npiglo,npjglo)   )
  ALLOCATE ( zff(npiglo,npjglo)  , ff(npiglo,npjglo)   )
  ALLOCATE ( dwku(npiglo,npjglo) , dwkv(npiglo,npjglo) )
  ALLOCATE ( dtrpu(npiglo,npjglo), dtrpv(npiglo,npjglo))
  ALLOCATE ( zwghtu(npiglo,npjglo), zwghtv(npiglo,npjglo))
  ALLOCATE ( zu_T(npiglo,npjglo) , zv_T(npiglo,npjglo) , zUn_T(npiglo, npjglo) )
  ALLOCATE ( zdhdx(npiglo,npjglo), zdhdy(npiglo,npjglo), zdh  (npiglo, npjglo) )
  ALLOCATE ( ztopos(npiglo, npjglo), hdepw(npiglo, npjglo), tmask(npiglo, npjglo) )
  ALLOCATE ( e31d(npk), dtim(npt)                      )

  CALL CreateOutput

  e1v(:,:) = getvar(cn_fhgr, cn_ve1v, 1, npiglo, npjglo)
  e1u(:,:) = getvar(cn_fhgr, cn_ve1u, 1, npiglo, npjglo)
  e2u(:,:) = getvar(cn_fhgr, cn_ve2u, 1, npiglo, npjglo)
  e2v(:,:) = getvar(cn_fhgr, cn_ve2v, 1, npiglo, npjglo)
  ff (:,:) = getvar(cn_fhgr, cn_vff , 1, npiglo, npjglo)

  tmask(:,:) = getvar(cn_fmsk  , cn_tmask   , 1, npiglo, npjglo)
  hdepw(:,:) = getvar(cn_fbathymet, cn_bathymet, 1, npiglo, npjglo)

  DO jt = 1, npt
     dtrpu(:,:)= 0.d0
     dtrpv(:,:)= 0.d0
     IF ( lg_vvl ) THEN ; it = jt
     ELSE ;               it = 1
     ENDIF

     DO jk = kmin, kmax
        PRINT *,'level ',jk
        ! Get velocities at jk
        zu(:,:)= getvar(cf_ufil, cn_vozocrtx, jk, npiglo, npjglo, ktime=jt)
        zv(:,:)= getvar(cf_vfil, cn_vomecrty, jk, npiglo, npjglo, ktime=jt)

        ! get e3v at level jk
        IF ( lfull ) THEN
           e3v(:,:) = e31d(jk)
           e3u(:,:) = e31d(jk)
        ELSE
           e3v(:,:) = getvar(cn_fe3v, cn_ve3v, jk, npiglo, npjglo, ktime=it, ldiom=.NOT.lg_vvl)
           e3u(:,:) = getvar(cn_fe3u, cn_ve3u, jk, npiglo, npjglo, ktime=it, ldiom=.NOT.lg_vvl)
        ENDIF
        dwku(:,:) = zu(:,:)*e2u(:,:)*e3u(:,:)
        dwkv(:,:) = zv(:,:)*e1v(:,:)*e3v(:,:)

        ! integrates vertically 
        dtrpu(:,:) = dtrpu(:,:) + dwku(:,:)
        dtrpv(:,:) = dtrpv(:,:) + dwkv(:,:)

        ! compute total weight
        zwghtu(:,:)=zwghtu(:,:)+e2u(:,:)*e3u(:,:)
        zwghtv(:,:)=zwghtv(:,:)+e1v(:,:)*e3v(:,:)
     END DO  ! loop to next level

     ! compute mean velocity
     zu(:,:)=0.0
     WHERE (zwghtu(:,:) .NE. 0.0)
        zu(:,:)=dtrpu(:,:)/zwghtu(:,:)
     END WHERE   

     zv(:,:)=0.0
     WHERE (zwghtv(:,:) .NE. 0.0)
        zv(:,:)=dtrpv(:,:)/zwghtv(:,:)
     END WHERE
     !zu=2.0 ; zv=1.0
     ! compute normalised velocity component at T point 
     zu_T(:,:) = 0.d0        ! U direction
     DO jj=1, npjglo
        DO ji= 2,npiglo
           zu_T(ji,jj) = 0.5 * ( zu(ji,jj) + zu(ji-1,jj) )
        ENDDO
        ! E-W periodicity :
        zu_T(1,jj) = zu_T(npiglo-1, jj)
     ENDDO

     zv_T(:,:) = 0.d0     ! V direction
     DO jj=2, npjglo
        DO ji= 1,npiglo
           zv_T(ji,jj) = 0.5 * ( zv(ji,jj) + zv(ji,jj-1) )
        ENDDO
     ENDDO

     zUn_T(:,:)=SQRT(zu_T(:,:)*zu_T(:,:) + zv_T(:,:)*zv_T(:,:))
     WHERE (zu_T(:,:) .NE. 0.0)
        zu_T(:,:)=zu_T(:,:)/zUn_T(:,:)
        zv_T(:,:)=zv_T(:,:)/zUn_T(:,:)
     ELSEWHERE
        zu_T(:,:)=0.0
        zv_T(:,:)=0.0
     END WHERE

     ! compute normalised bathymetric slope at T point (centered scheme)
     zdhdx = 0.e0            ! U direction
     DO jj=1,npjglo          
        DO ji=2, npiglo-1
           zdhdx(ji,jj) = ( hdepw(ji+1,jj) - hdepw(ji-1,jj)) / ( e1u(ji,jj) + e1u(ji-1,jj) ) * tmask(ji,jj)
        END DO
     END DO

     zdhdy = 0.e0            ! V direction
     DO jj=2,npjglo-1        
        DO ji=1, npiglo
           zdhdy(ji,jj) = ( hdepw(ji,jj+1) - hdepw(ji,jj-1)) / ( e2v(ji,jj) + e2v(ji,jj-1) ) * tmask(ji,jj)
        END DO
     END DO
     
     zdh(:,:)=SQRT(zdhdx(:,:)*zdhdx(:,:) + zdhdy(:,:)*zdhdy(:,:))    
     WHERE (zdh(:,:) .NE. 0.0)
        zdhdx(:,:)=zdhdx(:,:)/zdh(:,:)
        zdhdy(:,:)=zdhdy(:,:)/zdh(:,:)
     END WHERE
     
     ! compute normalised ff
     zff(:,:)=ff(:,:)/ABS(ff(:,:))

     ! compute un(i,j).(-f.k x grad(H))/(|f|.|grad(H)|)    
     ztopos(:,:)=zu_T(:,:) * ( zff(:,:)*zdhdy(:,:) ) + zv_T(:,:) * ( -zff(:,:)*zdhdx(:,:) )

     ! save data
     ierr = putvar(ncout, id_varout(1) ,ztopos(:,:), 1, npiglo, npjglo, ktime=jt)
  END DO

  ierr = closeout (ncout)
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
    ! define  variables for output 
    ipk(:) = 1   ! all 2D variables
    stypvar%rmissing_value    = 0.
    stypvar%valid_min         = -100.
    stypvar%valid_max         = 100.
    stypvar%cunits            = 'm3/s'
    stypvar%conline_operation = 'N/A'
    stypvar%caxis             = 'TYX'

    stypvar(1)%ichunk         = (/npiglo,npjglo,1,1 /) 
    stypvar(1)%cname       = 'sotopos'                  
    stypvar(1)%clong_name  = 'topostrophy'  
    stypvar(1)%cshort_name = 'sotopos'

    stypvar(1)%ichunk         = (/npiglo,npjglo,1,1 /) 
    stypvar(1)%cname       = 'sotopobeta'                  
    stypvar(1)%clong_name  = 'topographic beta (Shi and Chao 1994)'  
    stypvar(1)%cshort_name = 'sotopobeta'

    ! create output fileset
    ncout = create      (cf_out, cf_ufil, npiglo , npjglo, 1         , ld_nc4=lnc4 )
    ierr  = createvar   (ncout,  stypvar, nvarout, ipk,    id_varout , ld_nc4=lnc4 )
    ierr  = putheadervar(ncout,  cf_ufil, npiglo , npjglo, 1                       )
  
    dtim  = getvar1d(cf_ufil, cn_vtimec, npt     )
    ierr  = putvar1d(ncout,   dtim,      npt, 'T')
  END SUBROUTINE CreateOutput

END PROGRAM cdftopos
