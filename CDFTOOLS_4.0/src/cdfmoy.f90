PROGRAM cdfmoy
  !!======================================================================
  !!                     ***  PROGRAM  cdfmoy  ***
  !!=====================================================================
  !!  ** Purpose : Compute mean values for all the variables in a bunch
  !!               of cdf files given as argument
  !!               Store the results on a 'similar' cdf file.
  !!
  !!  ** Method  : Also store the mean squared values for the nn_sqdvar
  !!               variables belonging to cn_sqdvar(:), than can be changed 
  !!               in the nam_cdf_names namelist if wished.
  !!               Optionally order 3 moments for some variables can be
  !!               computed.
  !!
  !! History : 2.0  : 11/2004  : J.M. Molines : Original code
  !!         : 2.1  : 06/2007  : P. Mathiot   : Modif for forcing fields
  !!           3.0  : 12/2010  : J.M. Molines : Doctor norm + Lic.
  !!                  04/2015  : S. Leroux    : add nomissincl option
  !!         : 4.0  : 03/2017  : J.M. Molines  
  !!----------------------------------------------------------------------
  !!----------------------------------------------------------------------
  !!   routines      : description
  !!   varchk2       : check if variable is candidate for square mean
  !!   varchk3       : check if variable is candidate for cubic mean
  !!   zeromean      : substract mean value from input field
  !!----------------------------------------------------------------------
  USE cdfio 
  USE modcdfnames
  !!----------------------------------------------------------------------
  !! CDFTOOLS_4.0 , MEOM 2017 
  !! $Id$
  !! Copyright (c) 2017, J.-M. Molines 
  !! Software governed by the CeCILL licence (Licence/CDFTOOLSCeCILL.txt)
  !! @class time_averaging
  !!-----------------------------------------------------------------------------
  IMPLICIT NONE

  INTEGER(KIND=4)                               :: jk, jfil,jdep      ! dummy loop index
  INTEGER(KIND=4)                               :: jvar, jv, jt       ! dummy loop index
  INTEGER(KIND=4)                               :: ierr               ! working integer
  INTEGER(KIND=4)                               :: idep, idep_max     ! possible depth index, maximum
  INTEGER(KIND=4)                               :: narg, iargc, ijarg ! browsing command line
  INTEGER(KIND=4)                               :: nfiles             ! number of files to average
  INTEGER(KIND=4)                               :: npiglo, npjglo     ! size of the domain
  INTEGER(KIND=4)                               :: npk, npt           ! size of the domain
  INTEGER(KIND=4)                               :: nvars              ! number of variables in a file
  INTEGER(KIND=4)                               :: ntframe            ! cumul of time frame
  INTEGER(KIND=4)                               :: ncout              ! ncid of output files
  INTEGER(KIND=4)                               :: ncout2             ! ncid of output files
  INTEGER(KIND=4)                               :: ncout3             ! ncid of output files
  INTEGER(KIND=4)                               :: ncout4             ! ncid of output files
  INTEGER(KIND=4)                               :: nperio=4           ! periodic flag
  INTEGER(KIND=4)                               :: iwght              ! weight of variable
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: id_var             ! arrays of var id's
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: ipk                ! arrays of vertical level for each var
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: ipk4               ! arrays of vertical level for min/max
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: id_varout          ! varid's of average vars
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: id_varout2         ! varid's of sqd average vars
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: id_varout3         ! varid's of cub average vars
  INTEGER(KIND=4), DIMENSION(:),    ALLOCATABLE :: id_varout4         ! varid's of cub average vars

  REAL(KIND=4), DIMENSION(:,:),     ALLOCATABLE :: rmask2d            ![from SL]
  REAL(KIND=4), DIMENSION(:,:),     ALLOCATABLE :: v2d                ! array to read a layer of data
  REAL(KIND=4), DIMENSION(:,:),     ALLOCATABLE :: e3                 ! array to read vertical metrics
  REAL(KIND=4), DIMENSION(:,:),     ALLOCATABLE :: rmax               ! array for maximum value
  REAL(KIND=4), DIMENSION(:,:),     ALLOCATABLE :: rmin               ! array for minimum value
  REAL(KIND=4), DIMENSION(:,:),     ALLOCATABLE :: rmean              ! average
  REAL(KIND=4), DIMENSION(:,:),     ALLOCATABLE :: rmean2             ! squared average
  REAL(KIND=4), DIMENSION(:,:),     ALLOCATABLE :: rmean3             ! cubic average
  REAL(KIND=4), DIMENSION(:),       ALLOCATABLE :: zspval_in          ! time counter

  REAL(KIND=8), DIMENSION(1)                    :: dtimean            ! mean time
  REAL(KIND=8), DIMENSION(:),       ALLOCATABLE :: dtim               ! time counter
  REAL(KIND=8), DIMENSION(:,:),     ALLOCATABLE :: dtab, dtab2        ! arrays for cumulated values
  REAL(KIND=8), DIMENSION(:,:),     ALLOCATABLE :: dtab3              ! arrays for cumulated values
  REAL(KIND=8), DIMENSION(:,:),     ALLOCATABLE :: de3s               ! arrays for cumulated e3 (vvl)
  REAL(KIND=8)                                  :: dtotal_time        ! to compute mean time

  CHARACTER(LEN=256)                            :: cf_in              ! input file names
  CHARACTER(LEN=256)                            :: cf_root = 'cdfmoy'     ! optional root of output files 
  CHARACTER(LEN=256)                            :: cf_out  = 'cdfmoy.nc'  ! output file for average
  CHARACTER(LEN=256)                            :: cf_out2 = 'cdfmoy2.nc' ! output file for squared average
  CHARACTER(LEN=256)                            :: cf_out3 = 'cdfmoy3.nc' ! output file for squared average
  CHARACTER(LEN=256)                            :: cf_out4 = 'cdfmoy_minmax.nc'  ! output file for min/max
  CHARACTER(LEN=256)                            :: cf_e3              ! file name for reading vertical metrics (vvl)
  CHARACTER(LEN=256)                            :: cv_single          ! name of the single variable to process ( -var option)
  CHARACTER(LEN=256)                            :: cv_e3              ! name of e3t variable for vvl
  CHARACTER(LEN=256)                            :: cldum              ! dummy string argument
  CHARACTER(LEN=256), DIMENSION(:), ALLOCATABLE :: cf_lst             ! list of input files
  CHARACTER(LEN=256), DIMENSION(:), ALLOCATABLE :: cv_nam             ! array of var name
  CHARACTER(LEN=256), DIMENSION(:), ALLOCATABLE :: cv_nam2            ! array of var2 name for output
  CHARACTER(LEN=256), DIMENSION(:), ALLOCATABLE :: cv_nam3            ! array of var3 name for output
  CHARACTER(LEN=256), DIMENSION(:), ALLOCATABLE :: cv_nam4            ! array of var3 name for output

  TYPE (variable), DIMENSION(:),    ALLOCATABLE :: stypvar            ! attributes for average values
  TYPE (variable), DIMENSION(:),    ALLOCATABLE :: stypvar2           ! attributes for square averaged values
  TYPE (variable), DIMENSION(:),    ALLOCATABLE :: stypvar3           ! attributes for cubic averaged values
  TYPE (variable), DIMENSION(:),    ALLOCATABLE :: stypvar4           ! attributes for min/max

  LOGICAL                                       :: lcaltmean          ! mean time computation flag
  LOGICAL                                       :: lspval0 = .FALSE.  ! cdfmoy_chsp flag
  LOGICAL                                       :: lcubic  = .FALSE.  ! 3rd momment computation
  LOGICAL                                       :: lzermean= .FALSE.  ! flag for zero-mean process
  LOGICAL                                       :: lmax    = .FALSE.  ! flag for min/max computation
  LOGICAL                                       :: lvar    = .FALSE.  ! fkag for single variable processing
  LOGICAL                                       :: lchk    = .FALSE.  ! flag for missing files
  LOGICAL                                       :: lnc4    = .FALSE.  ! flag for netcdf4 output
  LOGICAL                                       :: ll_vvl             ! working flag: vvl AND ipk(jvar) > 1
  LOGICAL                                       :: lmskmiss= .FALSE.  ! from SL] flag for excluding gridpoints where some values are missing
  !!----------------------------------------------------------------------------
  CALL ReadCdfNames()

  narg= iargc()
  IF ( narg == 0 ) THEN
     PRINT *,' usage : cdfmoy -l LST-files [-spval0] [-cub] [-zeromean] [-max] [-mskmiss] ...'
     PRINT *,'            ... [-var VAR-name] [-vvl] [-o OUT-rootname] [-nc4]'
     PRINT *,'      '
     PRINT *,'     PURPOSE :'
     PRINT *,'       Compute the ''time average'' of a list of files given as arguments.' 
     PRINT *,'       The program assumes that all files in the list are of same type (shape,'
     PRINT *,'       variables,  etc...). Any file in the list may have many time frames,'
     PRINT *,'       they will be taken into account in the average.'
     PRINT *,'      '
     PRINT *,'       For some variables, the program also computes the time average of the'
     PRINT *,'       squared variables, which is used in other cdftools (cdfeke, cdfrmsssh,'
     PRINT *,'       cdfstdevw, cdfstddevts...). The actual variables selected for squared'
     PRINT *,'       average are :'
     PRINT '(10x,"- ",a)' , (TRIM(cn_sqdvar(jv)), jv=1, nn_sqdvar)
     PRINT *,'       This selection can be adapted with the nam_cdf_namelist process.'
     PRINT *,'       (See cdfnamelist -i for details).'
     PRINT *,'      '
     PRINT *,'       If you want to compute the average of already averaged files, consider'
     PRINT *,'       using cdfmoy_weighted instead, in order to take into account a '
     PRINT *,'       particular weight for each file in the list.'
     PRINT *,'      '
     PRINT *,'     ARGUMENTS :'
     PRINT *,'       -l LST-files : A list of similar model output files, whose time average'
     PRINT *,'                      will be computed.'
     PRINT *,'      '
     PRINT *,'     OPTIONS :'
     PRINT *,'       [-spval0 ] : set missing_value attribute to 0 for all variables and'
     PRINT *,'               take care of the input missing_value. This option is usefull'
     PRINT *,'               if missing_values differ from files to files.'
     PRINT *,'       [-cub ] : use this option if you want to compute third order moments'
     PRINT *,'               for the eligible variables, which are at present :'
     PRINT '(17x,"- ",a)' , (TRIM(cn_cubvar(jv)), jv=1, nn_cubvar)
     PRINT *,'              This selection can be adapted with the nam_cdf_namelist process.'
     PRINT *,'              (See cdfnamelist -i for details).'
     PRINT *,'       [-zeromean ] : with this option, the spatial mean value for each time'
     PRINT *,'              frame is substracted from the original field before averaging,'
     PRINT *,'              square averaging and eventually cubic averaging.'
     PRINT *,'       [-max ] : with this option, a file with the minimum and maximum values'
     PRINT *,'              of the variables (through the list of files) is created.'
     PRINT *,'       [-mskmiss ] : with this option, the output average is set to missing' 
     PRINT *,'              value at any gridpoint where the variable contains a  missing'
     PRINT *,'              value for at least one timestep. You should combine with option'
     PRINT *,'              -spval0 if missing values are not 0 in all the input files.'
     PRINT *,'       [-var VAR-name] : Only process VAR-name, instead of all variables.'
     PRINT *,'       [-vvl ] : take into account the time varying vertical scale factor.'
     PRINT *,'       [-o OUT-rootname] : Define output root-name instead of ', TRIM(cf_root) 
     PRINT *,'       [-nc4 ]: Use netcdf4 output with chunking and deflation level 1..'
     PRINT *,'              This option is effective only if cdftools are compiled with'
     PRINT *,'              a netcdf library supporting chunking and deflation.'
     PRINT *,'      '
     PRINT *,'     REQUIRED FILES :'
     PRINT *,'       If -zeromean option is used, need ', TRIM(cn_fhgr),' and ',TRIM(cn_fmsk)
     PRINT *,'      '
     PRINT *,'     OUTPUT : '
     PRINT *,'       netcdf file : ', TRIM(cf_out),' and ',TRIM(cf_out2)
     PRINT *,'       Variables name are the same than in the input files. '
     PRINT *,'       For squared averages ''_sqd'' is appended to the original variable name.'
     PRINT *,'       If -cub option is used, the file ', TRIM(cf_out3),' is also created with'
     PRINT *,'       ''_cub'' appended to the original variable name.'
     PRINT *,'       If -max option is used, the file ',TRIM(cf_out4),' is also created with '
     PRINT *,'       ''_max'' and ''_min'' appended to the original variable name.'
     PRINT *,'      '
     PRINT *,'     SEE ALSO :'
     PRINT *,'       cdfmoy_weighted, cdfstdev'
     PRINT *,'      '
     STOP 
  ENDIF

  ijarg = 1 
  DO WHILE ( ijarg <= narg )
     CALL getarg (ijarg, cldum) ; ijarg = ijarg + 1
     SELECT CASE ( cldum )
     CASE ( '-l'        ) ; CALL GetFileList
        ! options
     CASE ( '-spval0'   ) ; lspval0  = .TRUE.
     CASE ( '-cub'      ) ; lcubic   = .TRUE.
     CASE ( '-zeromean' ) ; lzermean = .TRUE.
     CASE ( '-max'      ) ; lmax     = .TRUE.
     CASE ( '-mskmiss'  ) ; lmskmiss = .TRUE.  
     CASE ( '-var'      ) ; lvar     = .TRUE.  
        ;                   CALL getarg (ijarg, cv_single) ; ijarg = ijarg + 1
     CASE ( '-vvl'      ) ; lg_vvl   = .TRUE.
     CASE ( '-o'        ) ; CALL getarg (ijarg, cf_root  ) ; ijarg = ijarg + 1
     CASE ( '-nc4'      ) ; lnc4     = .TRUE.
     CASE DEFAULT         ; PRINT *,' ERROR : ',TRIM(cldum),' : unknown option.' ; STOP 99
     END SELECT
  END DO

  cf_out=TRIM(cf_root )//'.nc'
  cf_out2=TRIM(cf_root)//'2.nc'
  cf_out3=TRIM(cf_root)//'3.nc'
  cf_out4=TRIM(cf_root)//'_minmax.nc'

  IF ( lzermean ) THEN
     lchk = lchk .OR. chkfile ( cn_fhgr )
     lchk = lchk .OR. chkfile ( cn_fmsk )
     IF ( lchk ) STOP 99 ! missing files
  ENDIF

  ! Initialisation from  1rst file (all file are assume to have the same geometry)
  ! time counter can be different for each file in the list. It is read in the
  ! loop for files

  cf_in = cf_lst(1)
  PRINT *, 'FILE list length is ',nfiles
  IF ( chkfile (cf_in) ) STOP 99 ! missing file
  !
  npiglo = getdim (cf_in, cn_x)
  npjglo = getdim (cf_in, cn_y)
  npk    = getdim (cf_in, cn_z)

  IF ( ierr /= 0 ) THEN  ! none of the dim name was found
     PRINT *,' assume file with no depth'
     npk=0
  ENDIF

  PRINT *, 'npiglo = ', npiglo
  PRINT *, 'npjglo = ', npjglo
  PRINT *, 'npk    = ', npk

  nvars = getnvar(cf_in)
  PRINT *,' nvars = ', nvars

  ALLOCATE(  dtab(npiglo,npjglo),   dtab2(npiglo,npjglo) )
  ALLOCATE(   v2d(npiglo,npjglo), rmask2d(npiglo,npjglo) )
  ALLOCATE( rmean(npiglo,npjglo),  rmean2(npiglo,npjglo) )
  IF ( lcubic ) ALLOCATE( dtab3(npiglo,npjglo), rmean3(npiglo,npjglo) )
  IF ( lg_vvl ) ALLOCATE(  de3s(npiglo,npjglo),     e3(npiglo,npjglo) )
  IF ( lmax   ) ALLOCATE (rmin(npiglo, npjglo),   rmax(npiglo,npjglo) )
  ALLOCATE (    cv_nam(nvars),    cv_nam2(nvars) )
  ALLOCATE (   stypvar(nvars),   stypvar2(nvars) )
  ALLOCATE (    id_var(nvars),        ipk(nvars) )
  ALLOCATE ( id_varout(nvars), id_varout2(nvars) )
  IF ( lcubic ) ALLOCATE (                cv_nam3(  nvars), stypvar3(  nvars), id_varout3(  nvars)  )
  IF ( lmax   ) ALLOCATE ( ipk4(2*nvars), cv_nam4(2*nvars), stypvar4(2*nvars), id_varout4(2*nvars)  )

  ! Prepare output files
  CALL CreateOutput

  ! for vvl, look for e3x variable in the file
  cv_e3 = 'none'
  IF ( lg_vvl ) THEN
     DO jvar = 1, nvars
        ! in case of CMIP6 names, cn_ve3tvvl is identical for U v W grid ... so far ! CAUTION if changed !
        IF ( INDEX(cv_nam(jvar), 'e3') /= 0  .OR. INDEX(cv_nam(jvar), cn_ve3tvvl) /= 0 ) THEN
           cv_e3=cv_nam(jvar)
           EXIT
        ENDIF
     ENDDO
  ENDIF

  lcaltmean=.TRUE.
  DO jvar = 1,nvars
     ! JMM vvl note : we suppose that 2D fields are not weighted averaged ( Questionable ? )
     ll_vvl = lg_vvl .AND.  (ipk(jvar) > 1)
     iwght=0
     IF ( cv_nam(jvar) == cn_vlon2d .OR. &     ! nav_lon
          cv_nam(jvar) == cn_vlat2d .OR. &     ! nav_lon
          cv_nam(jvar) == 'none'    ) THEN     ! nav_lat
        ! skip these variable
     ELSE
        PRINT *,' Working with ', TRIM(cv_nam(jvar)), ipk(jvar)
          DO jk = 1, ipk(jvar)
           PRINT *,'level ',jk
           dtab(:,:) = 0.d0 ; dtab2(:,:) = 0.d0 ; dtotal_time = 0.
           rmask2d(:,:) = 1.
           IF ( lcubic ) THEN  ; dtab3(:,:) = 0.d0                       ;
           ENDIF
           IF ( lmax   ) THEN  ; rmin (:,:) = 1.e20 ; rmax(:,:) = -1.e20 ;
           ENDIF
           IF ( ll_vvl ) THEN  ; de3s(:,:)  = 0.d0                       ;
           ENDIF
           ntframe = 0
           DO jfil = 1, nfiles
              cf_in = cf_lst(jfil)
              IF ( ll_vvl ) THEN ! work with weighted average in case of vvl
                 cf_e3=cf_in
              ENDIF
              IF ( jk == 1 ) THEN
                 IF ( chkfile (cf_in) ) STOP 99 ! missing file
                 iwght=iwght+MAX(1,INT(getatt( cf_in, cv_nam(jvar), 'iweight')))
              ENDIF

              npt = getdim (cf_in, cn_t)
              IF ( lcaltmean )  THEN
                 ALLOCATE ( dtim(npt) )
                 dtim        = getvar1d(cf_in, cn_vtimec, npt)
                 dtotal_time = dtotal_time + SUM(dtim(:))
                 DEALLOCATE (dtim )
              END IF
              DO jt=1,npt
                 ntframe = ntframe + 1
                 IF ( ll_vvl ) THEN
                    e3(:,:)   = getvar (cf_e3, cv_e3, jk ,npiglo, npjglo,ktime=jt )
                    de3s(:,:) = de3s(:,:) + e3(:,:)  ! cumulate e3
                 ENDIF
                 v2d(:,:)  = getvar(cf_in, cv_nam(jvar), jk ,npiglo, npjglo,ktime=jt )
                 IF ( lspval0  )  WHERE (v2d == zspval_in(jvar))  v2d = 0.  ! change missing values to 0

                 WHERE (v2d == 0.) rmask2d = 0.                              ! [from SL]
                 IF ( lzermean ) CALL zeromean (jk, v2d )

                 IF ( ll_vvl ) THEN ; dtab(:,:) = dtab(:,:) + e3(:,:) * v2d(:,:)*1.d0
                 ELSE               ; dtab(:,:) = dtab(:,:) + v2d(:,:)          *1.d0
                 ENDIF

                 IF (cv_nam2(jvar) /= 'none'    ) dtab2(:,:) = dtab2(:,:) + v2d(:,:)*v2d(:,: )         *1.d0
                 IF ( lcubic ) THEN
                    IF (cv_nam3(jvar) /= 'none' ) dtab3(:,:) = dtab3(:,:) + v2d(:,:)*v2d(:,:)*v2d(:,:) *1.d0
                 ENDIF
                 IF ( lmax ) THEN
                    rmax(:,:) = MAX(v2d(:,:),rmax(:,:))
                    rmin(:,:) = MIN(v2d(:,:),rmin(:,:))
                 ENDIF
              ENDDO
           END DO
           ! finish with level jk ; compute mean (assume spval is 0 )
           IF ( ll_vvl ) THEN ; rmean(:,:) = dtab(:,:)/de3s(:,:)
           ELSE               ; rmean(:,:) = dtab(:,:)/ntframe
           ENDIF

           IF ( lmskmiss ) rmean(:,:) = rmean(:,:)*(rmask2d(:,:)*1.d0)

           IF (cv_nam2(jvar) /= 'none' ) THEN
              rmean2(:,:) = dtab2(:,:)/ntframe
              IF ( lmskmiss ) rmean2(:,:) = rmean2(:,:)*(rmask2d(:,:)*1.d0)
           ENDIF

           IF ( lcubic ) THEN
              IF (cv_nam3(jvar) /= 'none' ) THEN 
                 rmean3(:,:) = dtab3(:,:)/ntframe
                 IF ( lmskmiss ) rmean3(:,:) = rmean3(:,:)*(rmask2d(:,:)*1.d0)
              ENDIF
           ENDIF

           ! store variable on outputfile
           ierr = putvar(ncout, id_varout(jvar), rmean, jk, npiglo, npjglo, kwght=iwght)
           IF (cv_nam2(jvar) /= 'none' ) THEN 
              ierr = putvar(ncout2, id_varout2(jvar), rmean2, jk, npiglo, npjglo, kwght=iwght)
           ENDIF

           IF ( lcubic) THEN
              IF (cv_nam3(jvar) /= 'none' ) THEN 
                 ierr = putvar(ncout3, id_varout3(jvar), rmean3, jk, npiglo, npjglo, kwght=iwght)
              ENDIF
           ENDIF

           IF ( lmax  ) THEN
              ierr = putvar(ncout4, id_varout4(      jvar), rmax, jk, npiglo, npjglo, kwght=iwght)
              ierr = putvar(ncout4, id_varout4(nvars+jvar), rmin, jk, npiglo, npjglo, kwght=iwght)
           ENDIF

           IF (lcaltmean )  THEN
              dtimean(1) = dtotal_time/ntframe
              ierr = putvar1d(ncout,  dtimean, 1, 'T')
              ierr = putvar1d(ncout2, dtimean, 1, 'T')
              IF (lcubic) ierr = putvar1d(ncout3, dtimean, 1, 'T')
              IF (lmax  ) ierr = putvar1d(ncout4, dtimean, 1, 'T')
           END IF

           lcaltmean=.FALSE. ! tmean already computed
        END DO  ! loop to next level
     END IF
  END DO ! loop to next var in file

  ierr = closeout(ncout )
  ierr = closeout(ncout2)
  IF ( lcubic ) ierr = closeout(ncout3) 
  IF ( lmax   ) ierr = closeout(ncout4) 

CONTAINS 

  LOGICAL FUNCTION varchk2 ( cd_var ) 
    !!---------------------------------------------------------------------
    !!                  ***  FUNCTION varchk2  ***
    !!
    !! ** Purpose : Return true if cd_var is candidate for mean squared value  
    !!
    !! ** Method  : List of candidate is established in modcdfnames, and
    !!              can be changed via the nam_cdf_names namelist   
    !!----------------------------------------------------------------------
    CHARACTER(LEN=*), INTENT(in) :: cd_var

    INTEGER(KIND=4)              :: jv
    !!----------------------------------------------------------------------
    varchk2 = .FALSE.
    DO jv = 1, nn_sqdvar 
       IF ( cd_var == cn_sqdvar(jv) ) THEN
          varchk2 = .TRUE.
          EXIT
       ENDIF
    ENDDO

  END FUNCTION varchk2

  LOGICAL FUNCTION varchk3 ( cd_var )
    !!---------------------------------------------------------------------
    !!                  ***  FUNCTION varchk3  ***
    !!
    !! ** Purpose : Return true if cd_var is candidate for cubic mean average
    !!
    !! ** Method  : List of candidate is established in modcdfnames, and
    !!              can be changed via the nam_cdf_names namelist
    !!----------------------------------------------------------------------
    CHARACTER(LEN=*), INTENT(in) :: cd_var

    INTEGER(KIND=4)              :: jv
    !!----------------------------------------------------------------------
    varchk3 = .FALSE.
    DO jv = 1, nn_cubvar
       IF ( cd_var == cn_cubvar(jv) ) THEN
          varchk3 = .TRUE.
          EXIT
       ENDIF
    ENDDO

  END FUNCTION varchk3

  SUBROUTINE zeromean(kk, ptab)
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE zeromean  ***
    !!
    !! ** Purpose :  Compute the spatial average of argument and
    !!               and substract it from the field 
    !!
    !! ** Method  :  requires the horizontal metrics 
    !!
    !!----------------------------------------------------------------------
    INTEGER(KIND=4),              INTENT(   in) :: kk
    REAL(KIND=4), DIMENSION(:,:), INTENT(inout) :: ptab

    REAL(KIND=4), DIMENSION(:,:), ALLOCATABLE, SAVE :: ze2, ze1, tmask, tmask0

    REAL(KIND=8), DIMENSION(:,:), ALLOCATABLE, SAVE :: dareas
    REAL(KIND=8),                              SAVE :: darea
    REAL(KIND=8)                                    :: dmean

    LOGICAL, SAVE                                   :: lfirst = .TRUE.
    !!----------------------------------------------------------------------

    IF (lfirst) THEN
       lfirst=.FALSE.
       ! read e1 e2 and tmask ( assuming this prog only deal with T-points)
       ALLOCATE ( ze1(npiglo, npjglo), ze2(npiglo,npjglo)       )
       ALLOCATE ( tmask(npiglo,npjglo), tmask0(npiglo,npjglo)   )
       ALLOCATE ( dareas(npiglo,npjglo)                         )

       ze1(:,:)     = getvar(cn_fhgr, cn_ve1t, 1, npiglo, npjglo)
       ze2(:,:)     = getvar(cn_fhgr, cn_ve2t, 1, npiglo, npjglo)
       dareas(:,:)  = ze1(:,:) * ze2(:,:) *1.d0
    ENDIF
    tmask0(:,:)  = getvar(cn_fmsk, cn_tmask, kk, npiglo, npjglo)
    tmask = tmask0
    tmask(1,:)=0 ; tmask(npiglo,:)=0 ; tmask(:,1) = 0.; tmask(:,npjglo) = 0 

    IF ( nperio == 3 .OR. nperio == 4 ) tmask(npiglo/2+1:npiglo,npjglo-1) = 0.

    darea = SUM( dareas * tmask )

    IF ( darea /= 0.d0 ) THEN ; dmean = SUM( ptab * dareas ) / darea
    ELSE                      ; dmean = 0.d0
    ENDIF

    WHERE ( ptab /= 0 )  ptab = ( ptab - dmean ) * tmask0

  END SUBROUTINE zeromean

  SUBROUTINE CreateOutput
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE CreateOutput  ***
    !!
    !! ** Purpose :  Create Netcdf output files
    !!
    !! ** Method  :  Create files and define variables etc...
    !!
    !!----------------------------------------------------------------------

    ! get list of variable names and collect attributes in stypvar (optional)
    cv_nam(:) = getvarname(cf_in,nvars,stypvar)
    IF ( lvar ) THEN
       DO jv=1,nvars
          IF ( cv_nam(jv) /= cv_single ) cv_nam(jv)='none'
       ENDDO
    ENDIF


    ! choose chunk size for output ... not easy not used if lnc4=.false. but anyway ..
    DO jv = 1, nvars
       stypvar(jv)%ichunk=(/npiglo,MAX(1,npjglo/30),1,1 /)
       stypvar2(jv)%ichunk=(/npiglo,MAX(1,npjglo/30),1,1 /)
    ENDDO

    IF ( lspval0 ) THEN 
       ALLOCATE ( zspval_in(nvars) )
       zspval_in(:) = stypvar(:)%rmissing_value
       stypvar(:)%rmissing_value = 0.
    ENDIF

    IF ( lcubic) THEN
       ! force votemper to be squared saved
       nn_sqdvar = nn_sqdvar + 1
       cn_sqdvar(nn_sqdvar) = TRIM(cn_votemper)  
    ENDIF

    DO jvar = 1, nvars
       ! variables that will not be computed or stored are named 'none'
       IF (cv_nam(jvar) /= 'none' ) THEN
          IF ( varchk2 ( cv_nam(jvar) ) ) THEN 
             cv_nam2(jvar)                    = TRIM(cv_nam(jvar))//'_sqd'
             stypvar2(jvar)%cname             = TRIM(stypvar(jvar)%cname)//'_sqd'         ! name
             stypvar2(jvar)%cunits            = '('//TRIM(stypvar(jvar)%cunits)//')^2'    ! unit
             stypvar2(jvar)%rmissing_value    = stypvar(jvar)%rmissing_value              ! missing_value
             stypvar2(jvar)%valid_min         = 0.                                        ! valid_min = zero
             stypvar2(jvar)%valid_max         = stypvar(jvar)%valid_max**2                ! valid_max *valid_max
             stypvar2(jvar)%scale_factor      = 1.
             stypvar2(jvar)%add_offset        = 0.
             stypvar2(jvar)%savelog10         = 0.
             stypvar2(jvar)%clong_name        = TRIM(stypvar(jvar)%clong_name)//'_Squared'  ! 
             stypvar2(jvar)%cshort_name       = TRIM(stypvar(jvar)%cshort_name)//'_sqd'     !
             stypvar2(jvar)%conline_operation = TRIM(stypvar(jvar)%conline_operation) 
             stypvar2(jvar)%caxis             = TRIM(stypvar(jvar)%caxis) 
          ELSE
             cv_nam2(jvar) = 'none'
          END IF

          ! check for cubic average
          IF ( lcubic ) THEN
             IF ( varchk3 ( cv_nam(jvar) ) ) THEN 
                cv_nam3(jvar)                    = TRIM(cv_nam(jvar))//'_cub'
                stypvar3(jvar)%cname             = TRIM(stypvar(jvar)%cname)//'_cub'         ! name
                stypvar3(jvar)%cunits            = '('//TRIM(stypvar(jvar)%cunits)//')^3'    ! unit
                stypvar3(jvar)%rmissing_value    = stypvar(jvar)%rmissing_value              ! missing_value
                stypvar3(jvar)%valid_min         = 0.                                        ! valid_min = zero
                stypvar3(jvar)%valid_max         = stypvar(jvar)%valid_max**3                ! valid_max *valid_max
                stypvar3(jvar)%scale_factor      = 1.
                stypvar3(jvar)%add_offset        = 0.
                stypvar3(jvar)%savelog10         = 0.
                stypvar3(jvar)%clong_name        = TRIM(stypvar(jvar)%clong_name)//'_Cubed'   ! 
                stypvar3(jvar)%cshort_name       = TRIM(stypvar(jvar)%cshort_name)//'_cub'    !
                stypvar3(jvar)%conline_operation = TRIM(stypvar(jvar)%conline_operation) 
                stypvar3(jvar)%caxis             = TRIM(stypvar(jvar)%caxis) 

                stypvar3(jvar)%ichunk=(/npiglo,MAX(1,npjglo/30),1,1 /)
             ELSE
                cv_nam3(jvar) = 'none'
             END IF
          ENDIF

          IF ( lmax ) THEN
             cv_nam4(jvar)                    = TRIM(cv_nam(jvar))//'_max'
             stypvar4(jvar)%cname             = TRIM(stypvar(jvar)%cname)//'_max'         ! name
             stypvar4(jvar)%cunits            = '('//TRIM(stypvar(jvar)%cunits)//')'      ! unit
             stypvar4(jvar)%rmissing_value    = stypvar(jvar)%rmissing_value              ! missing_value
             stypvar4(jvar)%valid_min         = 0.                                        ! valid_min = zero
             stypvar4(jvar)%valid_max         = stypvar(jvar)%valid_max                   ! valid_max *valid_max
             stypvar4(jvar)%scale_factor      = 1.
             stypvar4(jvar)%add_offset        = 0.
             stypvar4(jvar)%savelog10         = 0.
             stypvar4(jvar)%clong_name        = TRIM(stypvar(jvar)%clong_name)//'_max'   ! 
             stypvar4(jvar)%cshort_name       = TRIM(stypvar(jvar)%cshort_name)//'_max'  !
             stypvar4(jvar)%conline_operation = TRIM(stypvar(jvar)%conline_operation)
             stypvar4(jvar)%caxis             = TRIM(stypvar(jvar)%caxis)

             stypvar4(jvar)%ichunk=(/npiglo,MAX(1,npjglo/30),1,1 /)

             cv_nam4(nvars+jvar)                    = TRIM(cv_nam(jvar))//'_min'
             stypvar4(nvars+jvar)%cname             = TRIM(stypvar(jvar)%cname)//'_min'         ! name
             stypvar4(nvars+jvar)%cunits            = '('//TRIM(stypvar(jvar)%cunits)//')'      ! unit
             stypvar4(nvars+jvar)%rmissing_value    = stypvar(jvar)%rmissing_value              ! missing_value
             stypvar4(nvars+jvar)%valid_min         = 0.                                        ! valid_min = zero
             stypvar4(nvars+jvar)%valid_max         = stypvar(jvar)%valid_max                   ! valid_max *valid_max
             stypvar4(nvars+jvar)%scale_factor      = 1.
             stypvar4(nvars+jvar)%add_offset        = 0.
             stypvar4(nvars+jvar)%savelog10         = 0.
             stypvar4(nvars+jvar)%clong_name        = TRIM(stypvar(jvar)%clong_name)//'_min'   ! 
             stypvar4(nvars+jvar)%cshort_name       = TRIM(stypvar(jvar)%cshort_name)//'_min'  !
             stypvar4(nvars+jvar)%conline_operation = TRIM(stypvar(jvar)%conline_operation)
             stypvar4(nvars+jvar)%caxis             = TRIM(stypvar(jvar)%caxis)

             stypvar4(nvars+jvar)%ichunk=(/npiglo,MAX(1,npjglo/30),1,1 /)
          ENDIF

       ELSE
          cv_nam2(jvar)='none'
          IF (lcubic) cv_nam3(       jvar)='none'
          IF (lmax  ) cv_nam4(       jvar)='none'
          IF (lmax  ) cv_nam4(nvars+ jvar)='none'
       ENDIF
    END DO

    id_var(:)  = (/(jv, jv=1,nvars)/)
    ! ipk gives the number of level or 0 if not a T[Z]YX  variable
    ipk(:)     = getipk (cf_in,nvars)
    DO jvar = 1, nvars
       IF (ipk(jvar) == 0) THEN
          PRINT *, TRIM(cv_nam(jvar)),' is skip because of dimension issue'
          cv_nam(jvar)='none'
       END IF
    END DO

    IF ( lmax ) THEN 
       ipk4(1      :nvars  ) = ipk(1:nvars)
       ipk4(nvars+1:2*nvars) = ipk(1:nvars)
       WHERE( ipk4 == 0 ) cv_nam4='none'
    ENDIF
    stypvar (:)%cname = cv_nam
    stypvar2(:)%cname = cv_nam2
    IF ( lcubic ) stypvar3(:)%cname = cv_nam3
    IF ( lmax   ) stypvar4(:)%cname = cv_nam4

    ! create output file taking the sizes in cf_in

    ! get varname needed
    ncout  = create      (cf_out,  cf_in,    npiglo, npjglo, npk,              ld_nc4=lnc4)
    ierr   = createvar   (ncout ,  stypvar,  nvars,  ipk,    id_varout       , ld_nc4=lnc4)
    ierr   = putheadervar(ncout,   cf_in,    npiglo, npjglo, npk )

    ncout2 = create      (cf_out2, cf_in,    npiglo, npjglo, npk,              ld_nc4=lnc4)
    ierr   = createvar   (ncout2,  stypvar2, nvars,  ipk,    id_varout2      , ld_nc4=lnc4)
    ierr   = putheadervar(ncout2,  cf_in,    npiglo, npjglo, npk )

    IF ( lcubic) THEN
       ncout3 = create      (cf_out3, cf_in,    npiglo, npjglo, npk,              ld_nc4=lnc4)
       ierr   = createvar   (ncout3,  stypvar3, nvars,  ipk,    id_varout3      , ld_nc4=lnc4)
       ierr   = putheadervar(ncout3,  cf_in,    npiglo, npjglo, npk )
    ENDIF

    IF ( lmax ) THEN
       ncout4 = create      (cf_out4, cf_in,    npiglo, npjglo, npk,              ld_nc4=lnc4)
       ierr   = createvar   (ncout4,  stypvar4, 2*nvars,  ipk4,    id_varout4   , ld_nc4=lnc4)
       ierr   = putheadervar(ncout4,  cf_in,    npiglo, npjglo, npk )
    ENDIF

  END SUBROUTINE CreateOutput

  SUBROUTINE GetFileList
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE GetFileList  ***
    !!
    !! ** Purpose :  Set up a file list given on the command line as 
    !!               blank separated list
    !!
    !! ** Method  :  Scan the command line until a '-' is found
    !!----------------------------------------------------------------------
    INTEGER (KIND=4)  :: ji
    INTEGER (KIND=4)  :: icur
    !!----------------------------------------------------------------------
    !!
    nfiles=0
    ! need to read a list of file ( number unknow ) 
    ! loop on argument till a '-' is found as first char
    icur=ijarg                          ! save current position of argument number
    DO ji = icur, narg                  ! scan arguments till - found
       CALL getarg ( ji, cldum )
       IF ( cldum(1:1) /= '-' ) THEN ; nfiles = nfiles+1
       ELSE                          ; EXIT
       ENDIF
    ENDDO
    ALLOCATE (cf_lst(nfiles) )
    DO ji = icur, icur + nfiles -1
       CALL getarg(ji, cf_lst( ji -icur +1 ) ) ; ijarg=ijarg+1
    END DO
  END SUBROUTINE GetFileList

END PROGRAM cdfmoy
