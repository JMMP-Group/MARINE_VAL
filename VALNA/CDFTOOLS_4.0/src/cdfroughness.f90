PROGRAM cdfroughness
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
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: ztopos, planec, slpc

  REAL(KIND=8), DIMENSION(:),    ALLOCATABLE :: dtim                 ! time counter
  REAL(KIND=8), DIMENSION(:,:),  ALLOCATABLE :: dwku , dwkv          ! working arrays
  REAL(KIND=8), DIMENSION(:,:),  ALLOCATABLE :: dtrpu, dtrpv         ! barotropic transport 
  REAL(KIND=8), DIMENSION(:,:),  ALLOCATABLE :: d2zdx2, d2zdy2, d2zdxdy, d2zdydx, dzdx, dzdy
  REAL(KIND=8), DIMENSION(:,:),  ALLOCATABLE :: meanc, mean2c, stdc, kernel, roughness
  REAL(KIND=8) :: D, E, F, G, H, rsmooth2z, rsmoothz

  TYPE (variable), DIMENSION(:), ALLOCATABLE :: stypvar              ! structure for attribute

  CHARACTER(LEN=256)                         :: cf_ufil              ! input U- file
  CHARACTER(LEN=256)                         :: cf_vfil              ! input V- file
  CHARACTER(LEN=256)                         :: cf_out='topos.nc'    ! output file
  CHARACTER(LEN=256)                         :: cv_sotopos='sotopos' ! Along Slope TRansPort
  CHARACTER(LEN=256)                         :: cmethod='stdc' !'residual'
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
  ALLOCATE ( e1v(npiglo,npjglo), e2v(npiglo,npjglo), e3v(npiglo,npjglo)  )
  ALLOCATE ( e1u(npiglo,npjglo), e2u(npiglo,npjglo), e3u(npiglo,npjglo)  )
  ALLOCATE ( zdh  (npiglo,npjglo), slpc(npiglo,npjglo), planec(npiglo,npjglo), meanc(npiglo,npjglo), mean2c(npiglo,npjglo), stdc(npiglo,npjglo) )
  ALLOCATE ( d2zdx2(npiglo,npjglo), d2zdy2(npiglo,npjglo), d2zdxdy(npiglo,npjglo), d2zdydx(npiglo,npjglo), dzdx(npiglo,npjglo), dzdy(npiglo,npjglo) )
  ALLOCATE ( hdepw(npiglo, npjglo), roughness(npiglo,npjglo) )
  ALLOCATE ( e31d(npk), dtim(npt)  )

  CALL CreateOutput

  e1v(:,:) = getvar(cn_fhgr, cn_ve1v, 1, npiglo, npjglo)
  e1u(:,:) = getvar(cn_fhgr, cn_ve1u, 1, npiglo, npjglo)
  e2u(:,:) = getvar(cn_fhgr, cn_ve2u, 1, npiglo, npjglo)
  e2v(:,:) = getvar(cn_fhgr, cn_ve2v, 1, npiglo, npjglo)

  hdepw(:,:) = getvar(cn_fbathymet, cn_bathymet, 1, npiglo, npjglo)

  ! DEBUG
!  DO jj=1,npjglo
!     DO ji=1, npiglo
        !hdepw(ji,jj)=SQRT((ji-npiglo/2.)**2+(jj-npjglo/2.)**2)
        !hdepw(ji,jj)=((ji-npiglo/2.)**2+(jj-npjglo/2.)**2)
        !hdepw(ji,jj)=(ji-npiglo/2.)**2
!        hdepw(ji,jj)=(jj-npjglo/2.)
!        e1u(ji,jj)=1.0
!        e2v(ji,jj)=1.0
!     END DO
!  END DO

!  CALL Get_fitted_plane(zdh,e1u,e2v,hdepw)
!  ierr = putvar(ncout, id_varout(1) ,zdh(:,:), 1, npiglo, npjglo)

!  hdepw=zdh ! hdepw used a temporary variable
  ! compute std of curvature
  IF (cmethod == 'stdc') THEN
     ! get slope
     CALL Get_fitted_plane(dzdx, dzdy, e1u, e2v, REAL(hdepw,8))
     ! get d2z/dx2
     CALL Get_fitted_plane(d2zdx2, d2zdydx, e1u, e2v,dzdx)
     ! get d2z/dy2
     CALL Get_fitted_plane(d2zdxdy, d2zdy2 , e1u, e2v,dzdy)

     DO jj=1,npjglo
        DO ji=1, npiglo
           ! gradient
           D=d2zdx2(ji,jj); E=d2zdy2(ji,jj); F=0.5*(d2zdydx(ji,jj)+d2zdxdy(ji,jj));
           G=dzdx(ji,jj); H=dzdy(ji,jj);
           zdh(ji,jj)=SQRT(G**2 + H**2);
           IF (zdh(ji,jj) /= 0.0) THEN
           ! plane curavture (contour curvature) (horizontal)
           !planec(ji,jj)=2.0*(D*H**2+E*G**2-F*G*H)/(G**2 + H**2)
           ! slope curvature (flow path curvature)
           !slpc(ji,jj)=-2.0*(D*G**2+E*H**2+F*G*H)/(G**2 + H**2)
           ELSE
              planec(ji,jj)=9999.99
              slpc(ji,jj)=9999.99
           END IF
           ! mean curvature as in ArcGIS => aproximation of Goldman 2006 in case G
           ! and H << 1 (genealy the case when looking at bathymetry but maybe not
           ! if looking at the 30" arc data
           !slpc(ji,jj)=-2.0*(D+E)*100
           ! mean curvature (wikipedia)
           ! https://en.wikipedia.org/wiki/Mean_curvature ; Goldman 2006
           slpc(ji,jj)=((1.0+G**2)*E-2*G*H*F+(1.0+H**2)*D)/(1.0+G**2+H**2)**1.5
        END DO
     END DO

     meanc=0.0
     mean2c=0.0
     stdc=0.0
     WHERE (e1u*e2u==0.0)
        e1u=1. ; e2v=1.
     ENDWHERE
     DO jj=2,npjglo-1
        DO ji=2,npiglo-1
           meanc(ji,jj) =SUM(slpc(ji-1:ji+1,jj-1:jj+1)*e1u(ji-1:ji+1,jj-1:jj+1)*e2v(ji-1:ji+1,jj-1:jj+1))/SUM(e1u(ji-1:ji+1,jj-1:jj+1)*e2v(ji-1:ji+1,jj-1:jj+1))
           mean2c(ji,jj)=SUM(slpc(ji-1:ji+1,jj-1:jj+1)**2 * e1u(ji-1:ji+1,jj-1:jj+1)*e2v(ji-1:ji+1,jj-1:jj+1))/SUM(e1u(ji-1:ji+1,jj-1:jj+1)*e2v(ji-1:ji+1,jj-1:jj+1))
           roughness(ji,jj)=SQRT(MAX((mean2c(ji,jj)-meanc(ji,jj)**2),1.e-20))
        END DO
     END DO
   ELSE IF (cmethod == 'residual') THEN
     WHERE (e1u*e2u==0.0)
        e1u=1. ; e2v=1.
     ENDWHERE
     ALLOCATE(kernel(5,5))
     DO jj=3,npjglo-2
        DO ji=2,npiglo-2
           kernel=hdepw(ji-2:ji+2,jj-2:jj+2)
           rsmoothz=SUM(kernel*e1u(ji-2:ji+2,jj-2:jj+2)*e2v(ji-2:ji+2,jj-2:jj+2))/SUM(e1u(ji-2:ji+2,jj-2:jj+2)*e2v(ji-2:ji+2,jj-2:jj+2))
           rsmooth2z=SUM(kernel**2*e1u(ji-2:ji+2,jj-2:jj+2)*e2v(ji-2:ji+2,jj-2:jj+2))/SUM(e1u(ji-2:ji+2,jj-2:jj+2)*e2v(ji-2:ji+2,jj-2:jj+2))
           roughness(ji,jj)=SQRT(MAX((rsmooth2z-rsmoothz**2),1.e-20))
        END DO
     END DO
     DEALLOCATE(kernel)
   END IF

!  CALL Get_slope_stat(zdh,planec,slpc,e1u,e2v,hdepw)  ! methode using 3x3 box 0 center of LEGO
!  planec=1./planec
  ierr = putvar(ncout, id_varout(1), roughness, 1, npiglo, npjglo)
!  ierr = putvar(ncout, id_varout(2) ,planec, 1, npiglo, npjglo)
!  ierr = putvar(ncout, id_varout(3) ,d2zdx2, 1, npiglo, npjglo)
!  ierr = putvar(ncout, id_varout(4) ,d2zdy2, 1, npiglo, npjglo)

  ierr = closeout (ncout)
CONTAINS
  SUBROUTINE Get_fitted_plane(dzdx, dzdy, e1u, e2v, rbathy)
    !! find the best plane to fit the data with 2d least square method
    !! http://www.ilikebigbits.com/blog/2015/3/2/plane-from-points
    !!
    INTEGER :: ji,jj
    REAL(KIND=4), DIMENSION(:,:), INTENT(in)  :: e1u, e2v
    REAL(KIND=8), DIMENSION(:,:), INTENT(in)  :: rbathy
    REAL(KIND=8), DIMENSION(:,:), INTENT(out) :: dzdx, dzdy
    REAL(KIND=4), DIMENSION(3,3) :: xcoord, ycoord, zval
    REAL(KIND=8) :: s1, s2, s3, s4, s5, D

     ! compute normalised bathymetric slope at T point (centered scheme)
     DO jj=2,npjglo-1
        DO ji=2, npiglo-1
           !
           ! coordinates compare to the middle of the 3x3 block; it is needed
           ! for this simple version of the algorithm
           xcoord(1,1)=-e1u(ji,jj) ; ycoord(1,1)=-e2v(ji,jj)
           xcoord(2,1)= 0.0        ; ycoord(2,1)=-e2v(ji,jj)  
           xcoord(3,1)= e1u(ji,jj) ; ycoord(3,1)=-e2v(ji,jj)
           !
           xcoord(1,2)=-e1u(ji,jj) ; ycoord(1,2)= 0.0
           xcoord(2,2)= 0.0        ; ycoord(2,2)= 0.0           
           xcoord(3,2)= e1u(ji,jj) ; ycoord(3,2)= 0.0
           !
           xcoord(1,3)=-e1u(ji,jj) ; ycoord(1,3)= e2v(ji,jj)  
           xcoord(2,3)= 0.0        ; ycoord(2,3)= e2v(ji,jj)  
           xcoord(3,3)= e1u(ji,jj) ; ycoord(3,3)= e2v(ji,jj)   
           !
           ! zval need to be relative to the mean (as it is a 3x3 and the grid
           ! variation weak, we divide by 9.0 by simplicity to compute the mean
           zval(1:3,1:3)=rbathy(ji-1:ji+1,jj-1:jj+1)-SUM(rbathy(ji-1:ji+1,jj-1:jj+1)/9.0)
           !
           ! moment needed for least square
           s1=SUM(xcoord*xcoord)
           s2=SUM(ycoord*ycoord)
           s3=SUM(xcoord*ycoord)
           s4=SUM(xcoord*zval  )
           s5=SUM(ycoord*zval  )
           !
           D=s1*s2-s3*s3
           !
           ! slope along x and y
           dzdx(ji,jj)=-(s5*s3-s4*s2)/D
           dzdy(ji,jj)=-(s4*s3-s5*s1)/D
           !
        END DO
     END DO
  END SUBROUTINE Get_fitted_plane

    SUBROUTINE Get_slope_stat(dzds, planec, slpc, e1u, e2v, rbathy)
    !! QUANTIFYING SOURCE AREAS THROUGH LAND SURFACE CURVATURE AND SHAPE RICHARD G. HEERDEGEN and MAX A. BERAN 
    !!
    INTEGER :: ji,jj
    REAL(KIND=4), DIMENSION(:,:), INTENT(in)  :: e1u, e2v, rbathy
    REAL(KIND=4), DIMENSION(:,:), INTENT(out) :: dzds, planec, slpc
    REAL(KIND=8), DIMENSION(3,3) :: zval
    REAL(KIND=8) :: z1, z2, z3, z4, z5, z6, z7, z8, z9
    REAL(KIND=8) :: A, B, C, D, E, F, G, H, I, L
     ! compute normalised bathymetric slope at T point (centered scheme)
     DO jj=2,npjglo-1
        DO ji=2, npiglo-1
           !
           ! coordinates compare to the middle of the 3x3 block; it is needed
           ! for this simple version of the algorithm
           zval(ji-1:ji+1,jj-1:jj+1)=rbathy(ji-1:ji+1,jj-1:jj+1)
           L=e1u(ji,jj)
           z1=zval(ji-1,jj+1) ; z2=zval(ji,jj+1) ; z3=zval(ji+1,jj+1)
           z4=zval(ji-1,jj  ) ; z5=zval(ji,jj  ) ; z6=zval(ji+1,jj  )
           z7=zval(ji-1,jj-1) ; z8=zval(ji,jj-1) ; z9=zval(ji+1,jj-1)
           !
           A=(( z1+z3+z7+z9)/4.0-(z2+z4+z6+z8)/2.0+z5)/L**4

           B=(( z1+z3-z7-z9)/4.0-(z2-z8)/2.0)/L**3
           C=((-z1+z3-z7+z9)/4.0+(z4-z6)/2.0)/L**3

           D=((z4+z6)/2.0-z5)/L**2
           E=((z2+z8)/2.0-z5)/L**2
           F=(-z1+z3+z7-z9)/(4.0*L**2)

           G=(-z4+z6)/(2.0*L)
           H=(z2-z8)/(2.0*L)

           I=z5
           !
           ! gradient
           dzds(ji,jj)=SQRT(G**2 + H**2)
           IF (dzds(ji,jj) /= 0.0) THEN
              ! plane curavture (contour curvature) (horizontal)
              planec(ji,jj)=2.0*(D*H**2+E*G**2-F*G*H)/(G**2 + H**2)
              ! slope curvature (flow path curvature)
              slpc(ji,jj)=-2.0*(D*G**2+E*H**2+F*G*H)/(G**2 + H**2)
           ELSE
              planec(ji,jj)=9999.99
              slpc(ji,jj)=9999.99
           END IF
!           IF (ABS(planec(ji,jj)) < 1e-20) planec(ji,jj)=9999.99
        END DO
     END DO
  END SUBROUTINE Get_slope_stat

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
    stypvar%rmissing_value    = 9999.99
    stypvar%conline_operation = 'N/A'
    stypvar%caxis             = 'TYX'

    IF (cmethod=='stdc') THEN
       stypvar(1)%ichunk         = (/npiglo,npjglo,1,1 /) 
       stypvar(1)%cname       = 'sostdc'                  
       stypvar(1)%clong_name  = 'roughness (std slope curvature)'  
       stypvar(1)%cshort_name = 'sostdc'
       stypvar(1)%cunits         = 'm-1'
    ELSE IF (cmethod=='residual') THEN
       stypvar(1)%ichunk         = (/npiglo,npjglo,1,1 /) 
       stypvar(1)%cname       = 'sostdres'                  
       stypvar(1)%clong_name  = 'roughness (std residual)'  
       stypvar(1)%cshort_name = 'sostdres'
       stypvar(1)%cunits         = 'm'
     END IF

!    stypvar(2)%ichunk         = (/npiglo,npjglo,1,1 /) 
!    stypvar(2)%cname       = 'someanc'                  
!    stypvar(2)%clong_name  = 'mean slope curvature'  
!    stypvar(2)%cshort_name = 'someanc'
!    stypvar(2)%cunits         = 'm-1'

!    stypvar(2)%ichunk         = (/npiglo,npjglo,1,1 /) 
!    stypvar(2)%cname       = 'soplanec'                  
!    stypvar(2)%clong_name  = 'planec'  
!    stypvar(2)%cshort_name = 'soplanec'
!    stypvar(2)%cunits      = 'm-1'

!    stypvar(3)%ichunk         = (/npiglo,npjglo,1,1 /) 
!    stypvar(3)%cname       = 'soslp'                  
!    stypvar(3)%clong_name  = 'slp'  
!    stypvar(3)%cshort_name = 'soslp'
!    stypvar(3)%cunits      = 'm-1'

!    stypvar(4)%ichunk         = (/npiglo,npjglo,1,1 /) 
!    stypvar(4)%cname       = 'sodepth'                  
!    stypvar(4)%clong_name  = 'depth'  
!    stypvar(4)%cshort_name = 'sodepth'
!    stypvar(4)%cunits      = 'm'
    ! create output fileset
    PRINT *, 'create'
    ncout = create      (cf_out, cf_ufil, npiglo , npjglo, 1         , ld_nc4=lnc4 )
    PRINT *, 'create var'
    ierr  = createvar   (ncout,  stypvar, nvarout, ipk,    id_varout , ld_nc4=lnc4 )
    PRINT *, 'header'
    ierr  = putheadervar(ncout,  cf_ufil, npiglo , npjglo, 1                       )
  
    PRINT *, 'get time'
    dtim  = getvar1d(cf_ufil, cn_vtimec, npt     )
    PRINT *, 'put itme'
    ierr  = putvar1d(ncout,   dtim,      npt, 'T')
  END SUBROUTINE CreateOutput

END PROGRAM cdfroughness
