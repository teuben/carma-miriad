c***************************************************************
	program imgen
c
	implicit none
c
c= imgen - All-purpose image manipulator/creator
c& rjs
c: utility, map manipulation
c+
c	IMGEN is a MIRIAD task which modifies an image, or creates a new
c	image.  See also maths to create images based on expressions involving
c       X, Y and Z.
c@ in
c	The input image, which is to be modified. The default is a map
c	with one plane which consists entirely of zeros. 
c@ out
c	The name of the output image. No default. The output image has the
c	same characteristics as the input image, if present. If no input
c	image is given, the `imsize', `cell' and `radec' keywords give the
c	characteristics of the output.
c@ factor
c	Factor to multiply the input image by. This is meaningless if no
c	input image is given. The default is 1. 
c@ object
c	This determines the type of objects added to the input image.
c	Several objects can be given (the objects can be the same type, or
c	different), and minimum match is supported. Possible objects are:
c	   level      An offset (DC) level.
c	   noise      Noise (gaussian distribution).
c	   point      A point source.
c	   gaussian   An elliptical or circular gaussian.
c	   gauss3     3D elliptical or circular gaussian (for cubes).
c	   disk       An elliptical or circular disk.
c	   j1x        J1(x)/x function
c	   jet        Jet model with power law brightness.
c	   shell      2D projection of an optically-thin spherical shell
c	   comet      2D projection of a parent molecule in comet.
c	   cluster    standard isothermal 2D projection for cluster gas.
c       The default is a gaussian.
c@ spar
c	Parameters which give the characteristics of the object. The
c	parameters are given as a sequence of values, with one to six
c	values needed per object (depending on the object type). When
c	there are multiple objects, the parameter value for the second
c	object follow those for the first object, etc. The values are
c	as follows:
c	  Object Type           SPAR values
c	  -----------           -----------
c	   level                  offset
c	   noise                  rms
c	   point                  amp,x,y
c	   gaussian               amp,x,y,bmaj,bmin,pa
c	   gauss3                 amp,x,y,z,bmaj,bmin,pa,bz
c	   disk                   amp,x,y,bmaj,bmin,pa
c	   j1x                    amp,x,y,bmaj,bmin,pa
c	   jet                    amp,x,y,bmaj,bmin,pa
c	   shell                  amp,x,y,bmaj
c	   comet                  amp,x,y,scalelength
c	   cluster                amp,x,y,core radius 
c
c       Here "offset" is the offset level, "rms" is the rms value of
c       the noise, "amp" is the normally peak value of the object (but
c       see options=totflux below), "x" and "y" are the offset positions (in
c       arcsec) of the object relative to the reference pixel, "z" is the
c       absolute pixel position on the third axis, "bmaj" and "bmin" are the 
c       major and minor axes FWHM (in arcsec), "pa" is the position angle of
c       the major axis (in degrees), and "bz" is the FWHM (in pixels)
c       in the 3rd dimension. The position angle is measured from north 
c       towards east. 
c	The default is an object of unit amplitude, at the reference 
c	pixel, with a FWHM of 5 arcsec in x and y and 5 pixels in z. 
c	Comet scalelength, and cluster core radius are in arcsec units.
c	Jet model has brightness with power law index bmaj and bmin along
c	major and minor axes.
c@ imsize
c	If not input image is given, then this determines the size, in
c	pixels, of the output image. Either one or two numbers can be
c	given. If only one number is given, then the output is square.
c       For testing purposes a third number can be given to create a cube,
c       no good coordinate headers however are written for such cubes.
c	The default is 256 pixels square. 
c@ cell
c	The increment between pixels, in arcseconds. This is only used if
c	there is no input map. The default is 1 arcsec.
c@ radec
c	If no input image is given, this gives the RA and DEC of the
c	image, in hours and degrees, respectively. They can be given in
c	hh:mm:ss,dd:mm:ss, or as decimal hours and degrees. The default is
c	RA=0, DEC=30.
c@ options
c	Extra processing options. Several can be given, separated by
c	commas. Minimum match is used. Possible values are:
c	  totflux  Interpret the "amp" values in the spar keyword as
c	           total integrated flux densities (Normally the "amp"
c	           parameters are interpretted as peak values).
c@ seed
c	Number used to initialise the random number generator. This is
c	an integer. Invoking IMGEN with the same value of SEED will give you
c	identical instance of the noise, whereas a different value will
c	give you a different instance.
c--
c
c  History:
c    rjs  Dark-ages Original version.
c    rjs  27oct89   Renamed it IMGEN.
c    rjs  30may91   Write some extra header variables.
c    mchw 03jun91   Fixed a bug and added more header variables.
c    rjs  29aug91   Included 'mirconst'. The old value of pi was wrong.
c    nebk 20sep91   Made gaussian noise image start with different
c                   seed on each application of imgen.
c    pjt  15oct91   multiplied julian date by 100000 in randset() for seed
c                   created crval, cdelt and crpix all in double now
c                   filename buffers (in,out) a bit longer
c    pjt  16oct91   fixed some style ambiguities
c    pjt   7nov91   added 'bpa' item in case gaussian model
c    mchw  10jul92  fixed bug in bpa definition.
c    nebk  09sep92  Make reference pixel 1.0 for axes of length
c                   1, otherwise point models fall of map
c    nebk  04nov92  Copy BTYPE to output
c    pjt   13nov92  Initial version to handle 3D input cubes
c                   also updated pbfwhm into copy header list!!!!!!
c    rjs   24nov92  Merged pjt and nebk versions.
c    mchw  10apr93  Improved warning messages.
c    lgm   27apr93  Added feature allowing specification of position angle
c                   for disk model.
c    mchw  19may93  Merged lgm and mchw versions; Adjust doc to match code.
c    rjs   19aug94  Major rework. Multiple objects. Position angle. Better
c		    coords.
c    rjs   12sep94  totflux option.
c    bmg   08may96  Added object=shell
c    rjs   24sep96  Some corrections to object=shell.
c    rjs   13dec96  Increase max number of objects.
c    rjs   02jul97  cellscal change.
c    rjs   14jul97  Check when there are too many objects and increase
c		    max number of objects.
c    rjs   23jul97  added pbtype.
c    mchw  23oct97  added comet model for parent molecule.
c    rjs   29oct97  Check that the coordinates for a point source fall
c		    within the image.
c    rjs   11dec97  Make total flux option consistent when there is an
c		    input image.
c    rjs   19mar98  Copy across mosaic table.
c    mchw  19mar99  Add model isothermal 2D projection for cluster gas.
c    lss   07jul99  Add 3D gaussian model for cubes.
c    rjs   10jan00  Added "seed" parameter.
c    mchw  16jan01  Jet model.
c    pjt    6sep01  using MAXDIM1 instead of MAXDIM
c    pjt    3nov01  changed radec default to reflect those in uvgen
c    pjt   21jan02  using MAXDIM1
c    pjt   25jun02  allow imsize to be 3 dimensional [for MIR4]
c    pjt    3dec02  using MAXDIM again, MAXDIM1 retired; MAXDIM2 is new
c    pjt   30jan03  merged MIR4 into current release
c    pjt   23feb03  officially merged MIR4
c    pjt   19jun05  fix for g95 **(-0.5)
c    pjt   11jul07  add some dummy but reasonable header items for 3D cubes
c---
c ToDo: 
c    write good headers if 3D cubes written
c------------------------------------------------------------------------
	character version*(*)
	parameter(version='Imgen: version 6-aug-08')
	include 'mirconst.h'
	include 'maxdim.h'
	include 'maxnax.h'
	integer n1,n2,n3,i,j,k,lIn,lOut,nsize(MAXNAX),naxis,seed
	double precision crpix1,crpix2,cdelt1,cdelt2,crval1,crval2
	double precision x1(3),x2(3)
	real factor,bmaj,bmin,bpa,fac,fac3
	character In*80,Out*80
	logical totflux
	real Buff(MAXDIM)
c
c  Source parameters.
c
	integer MAXOBJS
	parameter(MAXOBJS=3000)
	real fwhm1(MAXOBJS),fwhm2(MAXOBJS),posang(MAXOBJS)
	real fwhm3(MAXOBJS)
	real amp(MAXOBJS),x(MAXOBJS),y(MAXOBJS),z(MAXOBJS)
	real fwhm1d(MAXOBJS),fwhm2d(MAXOBJS),posangd(MAXOBJS)
	real xd(MAXOBJS),yd(MAXOBJS)
	character objs(MAXOBJS)*8
c
	integer NOBJECTS
	parameter(NOBJECTS=11)
	integer nobjs
	character objects(NOBJECTS)*8
c
c  Externals.
c
	logical keyprsnt
c
	data objects/'level   ','noise   ','point   ',
     *		     'gaussian','disk    ','j1x     ',
     *               'shell   ','comet   ','cluster ',
     *               'gauss3  ','jet     '/
c
c  Get the parameters from the user.
c
	call output(version)
	call keyini
	call keya('in',In,' ')
	call keya('out',Out,' ')
	call keyr('factor',Factor,1.)
	call keymatch('object',NOBJECTS,objects,MAXOBJS,objs,nobjs)
	if(nobjs.eq.0)then
	  objs(1) = 'gaussian'
	  nobjs = 1
	endif
	if(keyprsnt('object'))call bug('f','Too many objects for me!')
c
c  Get the source parameters.
c
	do i=1,nobjs
	  call keyr('spar',amp(i),1.)
	  if(objs(i).ne.'level'.and.objs(i).ne.'noise')then
	    call keyr('spar',x(i),0.)
	    call keyr('spar',y(i),0.)
	    x(i) = x(i) / 3600. * pi/180.
	    y(i) = y(i) / 3600. * pi/180.
	  else
	    x(i) = 0
	    y(i) = 0
	  endif
	  if(objs(i).eq.'gauss3') call keyr('spar',z(i),0.)
	  if(objs(i)(1:5).eq.'gauss'.or.objs(i).eq.'disk'.or.
     *	     objs(i).eq.'j1x'.or.objs(i).eq.'jet')then
	    call keyr('spar',fwhm1(i),5.)
	    call keyr('spar',fwhm2(i),5.)
	    call keyr('spar',posang(i),0.)
	    if(objs(i).ne.'jet')then
	      fwhm1(i) = fwhm1(i) / 3600. * pi/180.
	      fwhm2(i) = fwhm2(i) / 3600. * pi/180.
	      if(min(fwhm1(i),fwhm2(i)).le.0)
     * 	      call bug('f','BMAJ and BMIN parameters must be positive')
	    endif
	    posang(i) = posang(i) * pi/180.
	    if(objs(i).eq.'gauss3') call keyr('spar',fwhm3(i),5.)
	  elseif(objs(i).eq.'shell'.or.objs(i).eq.'comet') then
            call keyr('spar',fwhm1(i),5.)
	    fwhm1(i) = fwhm1(i) / 3600. * pi/180.
	    if(fwhm1(i).le.0)
     *	      call bug('f','BMAJ and BMIN parameters must be positive')
	    fwhm2(i) = fwhm1(i)
	    posang(i) = 0
	  elseif(objs(i).eq.'cluster') then
	    call keyr('spar',fwhm1(i),50.)
	    fwhm1(i) = fwhm1(i) / 3600. * pi/180.
	    fwhm2(i) = fwhm1(i)
	    posang(i) = 0
	  else
	    fwhm1(i) = 0
	    fwhm2(i) = 0
	    posang(i) = 0
	  endif
	enddo
c
c  Get parameters used to construct the output image (if needed).
c
	call keyd('cell',cdelt1,-1.0d0)
	call keyd('cell',cdelt2,cdelt1)
	cdelt1 = -abs(cdelt1/3600 * pi/180.)
	cdelt2 =  abs(cdelt2/3600 * pi/180.)
	call keyi('imsize',n1,256)
	call keyi('imsize',n2,n1)
	call keyi('imsize',n3,1)
	call keyt('radec',crval1,'hms',0.d0)
	call keyt('radec',crval2,'dms',dpi/6.0d0)
	crpix1 = n1/2 + 1
	crpix2 = n2/2 + 1
c
	call GetOpt(totflux)
c
	call keyi('seed',seed,0)
c
	call keyfin
c
	if(seed.ne.0)call randset(seed)
c
c  If there is an input file, open it and get parameters about it.
c  Otherwise set the default parameters.
c
	if(Out.eq.' ')call bug('f','Output file name missing')
	if(In.ne.' ')then
	  call xyopen(lIn,in,'old',3,nsize)
	  n1 = nsize(1)
	  n2 = nsize(2)
 	  n3 = nsize(3)
	  if(nsize(3).ne.1)call bug('w','Crude handling of 3D images')
	  call rdhdi(lIn,'naxis',naxis,1)
	  naxis = min(naxis,MAXNAX)
	  do i=4,naxis
	    nsize(i) = 1
	  enddo
	  call rdhdr(lIn,'bmaj',bmaj,0.)
	  call rdhdr(lIn,'bmin',bmin,0.)
	  call rdhdr(lIn,'bpa',bpa,0.)
	  call rdhdd(lIn,'cdelt1',cdelt1,1d0*cdelt1)
	  call rdhdd(lIn,'cdelt2',cdelt2,1d0*cdelt2)
	else
	  if (n3.eq.1) then
	     naxis = 2
	  else
	     naxis = 3
	  endif
	  nsize(1) = n1
	  nsize(2) = n2
	  nsize(3) = n3
	  lIn = 0
	  bmaj = 0
	  bmin = 0
	  bpa = 0
	  if(n1.le.0.or.n2.le.0)call bug('f','Image size error')
	endif
	if(n1.gt.MAXDIM) call bug('f','Image dimension too big')
c
c  If we have a single gaussian object, use this as the beam
c  parameters.
c
	if(nobjs.eq.1.and.objs(1)(1:5).eq.'gauss'.and..not.
     *		totflux.and.abs(bmaj*bmin).eq.0)then
	  if(fwhm1(1).gt.fwhm2(1))then
	    bmaj = fwhm1(1)
	    bmin = fwhm2(1)
	    bpa  = 180/pi * posang(1)
	  else
	    bmaj = fwhm2(1)
	    bmin = fwhm1(1)
	    bpa  = 180/pi * posang(1) - 90
	  endif
	  if(bpa.lt.-90)bpa = bpa + 180
	  if(bpa.gt. 90)bpa = bpa - 180
	endif
c
c  Now open the output, and add a header to it.
c
	call xyopen(lOut,Out,'new',naxis,nsize)
	call header(lIn,lOut,naxis,
     *    crpix1,crpix2,crval1,
     *    crval2,cdelt1,cdelt2,
     *	  bmaj,bmin,bpa,version)
c
c  Convert to units that we want, namely x and y in grid coordinates
c  and fwhm in pixels.
c
	call coInit(lOut)
c
c  Fiddle fwhm and position angle parameters to be with respect to the 
c  pixel grid.
c
	do k=1,n3
	  if(lIn.ne.0)call xysetpl(lIn,1,k)
	  call xysetpl(lOut,1,k)
c
c  Convert the offsets and gaussian parameters from world to pixel units.
c
	  do i=1,nobjs
	    x1(1) = x(i)
	    x1(2) = y(i)
	    x1(3) = k
	    call coCvt(lOut,'ow/ow/p',x1,'ap/ap/ap',x2)
	    xd(i) = x2(1)
	    yd(i) = x2(2)
	    if(objs(i).ne.'jet')then
	     if(fwhm1(i)*fwhm2(i).gt.0.and.objs(i).ne.'jet')then
	      call coGauCvt(lOut,'ow/ow/p',x1,
     *	        'w',fwhm1(i), fwhm2(i), posang(i),
     *	        'p',fwhm1d(i),fwhm2d(i),posangd(i))
	     else
	      fwhm1d(i) = 0
	      fwhm2d(i) = 0
	      posangd(i) = 0
	     endif
	    else
	      fwhm1d(i) = fwhm1(i)
	      fwhm2d(i) = fwhm2(i)
	    endif
	  enddo
c
c  Convert the flux units.
c
	  if(totflux)then
	    if(abs(bmaj*bmin).gt.0)then
	      fac = 0.25*PI/log(2.0)*abs(bmaj*bmin/(cdelt1*cdelt2))
	    else
	      fac = 1
	    endif
	  else
	    fac = 0
	  endif
c
c  Do the real work.
c
	  do j=1,n2
	    call GetBuf(lIn,j,Buff,n1,factor)
	    do i=1,nobjs
c
c  Find flux density for gauss3.
c
	      if(objs(i).eq.'gauss3') then
	        fac3=exp(-2.0*log(4.0)*(real(k)-z(i))**2/fwhm3(i)**2)
	      else
		fac3=1.0
	      endif
	      call DoMod(j,objs(i),Buff,n1,fac3*amp(i),fwhm1d(i),
     *                    fwhm2d(i),posangd(i),xd(i),yd(i),fac)
	    enddo
	    call xywrite(lOut,j,Buff)
	  enddo
	enddo
c
c  Close up shop.
c
	if(lIn.ne.0)call xyclose(lIn)
	call xyclose(lOut)
	end
c************************************************************************
	subroutine GetOpt(totflux)
c
	implicit none
	logical totflux
c
c  Get extra processing options.
c------------------------------------------------------------------------
	integer NOPTS
	parameter(NOPTS=1)
	character opts(NOPTS)*8
	logical present(NOPTS)
c
	data opts/'totflux '/
c
	call options('options',opts,present,NOPTS)
	totflux = present(1)
	end
c************************************************************************
	subroutine GetBuf(lIn,j,Buff,n1,factor)
c
	implicit none
	integer lIn,j,n1
	real factor,Buff(n1)
c
c  Initialise a row.
c
c------------------------------------------------------------------------
	integer i
c
	if(lIn.eq.0.or.factor.eq.0)then
	  do i=1,n1
	    Buff(i) = 0
	  enddo
	else
	  call xyread(lIn,j,Buff)
	  do i=1,n1
	    Buff(i) = factor * Buff(i)
	  enddo
	endif
c
	end
c*******************************************************************
	subroutine header(lIn,lOut,naxis,crpix1,crpix2,crval1,crval2,
     *	  cdelt1,cdelt2,bmaj,bmin,bpa,version)
c
	implicit none
	integer lIn,lOut,naxis
        double precision crpix1,crpix2,cdelt1,cdelt2,crval1,crval2
	real bmaj,bmin,bpa
	character version*(*)
c
c  Make a header for the output image.
c
c------------------------------------------------------------------------
	integer nkeys
	parameter(nkeys=45)
	character line*64
	integer i
	character keyw(nkeys)*8
	data keyw/   'bmaj    ','bmin    ','bpa     ','bunit   ',
     *    'cdelt1  ','cdelt2  ','cdelt3  ','cdelt4  ','cdelt5  ',
     *	  'crpix1  ','crpix2  ','crpix3  ','crpix4  ','crpix5  ',
     *	  'crval1  ','crval2  ','crval3  ','crval4  ','crval5  ',
     *	  'ctype1  ','ctype2  ','ctype3  ','ctype4  ','ctype5  ',
     *	  'epoch   ','ltype   ','lstart  ','lwidth  ','mostable',
     *	  'lstep   ','mask    ','niters  ','object  ','history ',
     *    'observer','obsra   ','obsdec  ','restfreq','telescop',
     *	  'vobs    ','cellscal','obstime ','pbfwhm  ','btype   ',
     *	  'pbtype  '/
c
c  Either create a new header, or copy the old one.
c
	if(lIn.eq.0)then
	  call wrhdd(lOut,'crpix1',crpix1)
	  call wrhdd(lOut,'crpix2',crpix2)
	  call wrhdd(lOut,'cdelt1',cdelt1)
	  call wrhdd(lOut,'cdelt2',cdelt2)
	  call wrhdd(lOut,'crval1',crval1)
	  call wrhdd(lOut,'crval2',crval2)
	  call wrhda(lOut,'ctype1','RA---SIN')
	  call wrhda(lOut,'ctype2','DEC--SIN')
	  if (naxis.eq.3) then
	     call wrhdd(lOut,'crpix3',1.0d0)
	     call wrhdd(lOut,'cdelt3',1.0d0)
	     call wrhdd(lOut,'crval3',0.0d0)
	     call wrhda(lOut,'ctype3','VELO-LSR')
	  endif
	  if(bmaj*bmin.gt.0)then
	    call wrhda(lOut,'bunit','JY/BEAM')
	    call wrhdr(lOut,'bmaj',bmaj)
	    call wrhdr(lOut,'bmin',bmin)
	    call wrhdr(lOut,'bpa',bpa)
	  else
	    call wrhda(lOut,'bunit','JY/PIXEL')
	  endif
	else
	  do i=1,nkeys
	    call hdcopy(lIn,lOut,keyw(i))
	  enddo
	endif
c
c  Update the history.
c
	call hisopen(lOut,'append')
	line = 'IMGEN: Miriad '//version
	call hiswrite(lOut,line)
	call hisinput(lOut,'IMGEN')
	call hisclose(lOut)
c
	end
c************************************************************************
	subroutine DoMod(j0,object,Data,n1,amp,fwhm1,fwhm2,posang,x,y,
     *								fac)
c
	implicit none
	integer n1,j0
	character object*(*)
	real Data(n1)
        real amp,fwhm1,fwhm2,posang,x,y,fac
c
c  Add the contribution of a particular component.
c
c  Input:
c    fac	Flux adjustment.
c------------------------------------------------------------------------
	include 'maxdim.h'
	include 'mirconst.h'
	integer i,j,ymin,ymax,xmin,xmax,maxit,it
	real xx,yy,xp,yp,scale,cospa,sinpa,t,a,log2,limit,p,theta,sum
	real Buff(MAXDIM)
c
c  Externals.
c
	real j1xbyx
c
c  Add the new contribution.First the gaussian. Work out the region
c  where the exponential greater than exp(-25), and don't bother
c  processing those regions.
c
c  Note: pi/4/log(2) == 1.1331.
c
	if(object(1:5).eq.'gauss')then
	  log2 = log(2.0)
	  if(fac.ne.0)then
	    a = fac * amp / (pi/4/log2 * fwhm1 * fwhm2)
	  else
	    a = amp
	  endif
	  cospa = cos(posang)
	  sinpa = sin(posang)
	  scale = 2. * sqrt(log2)
	  limit = 5/scale * max(fwhm1,fwhm2)
	  ymin = nint(y-limit)
	  ymax = nint(y+limit)
	  xmin = max(nint(x-limit),1)
	  xmax = min(nint(x+limit),n1)
	  if(ymin.le.j0.and.j0.le.ymax)then
	    yy = scale * (j0-y)
	    do i=xmin,xmax
	      xx = scale * (i-x)
              yp =  yy*cospa + xx*sinpa
              xp = -yy*sinpa + xx*cospa
              t = (xp*xp)/(fwhm2*fwhm2) + (yp*yp)/(fwhm1*fwhm1)
	      if(t.lt.25)data(i) = data(i) + a*exp(-t)
	    enddo
	  endif
c
c  Handle a J1(x)/x function.
c
	else if(object.eq.'j1x')then
	  scale = 3.83
	  if(fac.ne.0)then
	    a = fac * amp / (4*pi/scale/scale * fwhm1 * fwhm2)
	  else
	    a = amp
	  endif
	  cospa = cos(posang)
	  sinpa = sin(posang)
	  yy = scale * (j0-y)
	  do i=1,n1
	    xx = scale * (i-x)
            yp =  yy*cospa + xx*sinpa
            xp = -yy*sinpa + xx*cospa
            t = (xp*xp)/(fwhm2*fwhm2) + (yp*yp)/(fwhm1*fwhm1)
	    data(i) = data(i) + 2 * a * j1xbyx(sqrt(t))
	  enddo
c
c  Handle a jet model with power law brightness.
c
	else if(object.eq.'jet')then
	  cospa = cos(posang)
	  sinpa = sin(posang)
	  yy =  (j0-y)
	  do i=1,n1
	    xx = (i-x)
            yp =  yy*cospa + xx*sinpa
            xp = -yy*sinpa + xx*cospa
	    if(xp.ne.0.and.yp.ne.0)then
              a = amp * abs(yp)**fwhm1 * abs(xp)**fwhm2
    	      data(i) = data(i) + a 
	    endif
	  enddo
c
c  Handle a comet.
c
	else if(object.eq.'comet')then
	  maxit = 50
	  yy = (j0-y)
	  do i=1,n1
	    xx = (i-x)
	    p = sqrt(xx*xx+yy*yy)
            sum = 0.
            do it = -maxit+1,maxit-1
              theta = it*pi/2./maxit
              sum = sum +
     *          exp(-p/fwhm1/(cos(theta)))*pi/2./(maxit-2)
            enddo
	    if(p.ne.0.)then
	      a = amp / p * sum 
	      data(i) = data(i) + a
	    endif
	  enddo
c
c  Handle a cluster isothermal gas projection.
c
	else if(object.eq.'cluster')then
	  yy = (j0-y)
	  do i=1,n1
	    xx = (i-x)
	    p = (xx*xx+yy*yy)/(fwhm1*fwhm1)
	    a = amp * (1. + p)**(-0.5)
c	    a = amp * (1. + p)**(0.5-1.5*beta)
	    data(i) = data(i) + a
	  enddo
c
c  Handle a disk.
c
	else if(object.eq.'disk')then
	  if(fac.ne.0)then
	    a = fac * amp / (pi/4 * fwhm1 * fwhm2)
	  else
	    a = amp
	  endif
	  cospa = cos(posang)
	  sinpa = sin(posang)
	  limit = 0.5 * max(fwhm1,fwhm2)
	  ymin = nint(y-limit)
	  ymax = nint(y+limit)
	  xmin = max(nint(x-limit),1)
	  xmax = min(nint(x+limit),n1)
	  if(ymin.le.j0.and.j0.le.ymax)then
	    yy = (j0-y)
	    do i=xmin,xmax
	      xx = (i-x)
              yp =  yy*cospa + xx*sinpa
              xp = -yy*sinpa + xx*cospa
              t = (xp*xp)/(fwhm2*fwhm2) + (yp*yp)/(fwhm1*fwhm1)
	      if(t.lt.0.25) data(i) = data(i) + a
	    enddo
	  endif 
c
c  Handle a spherical shell.
c
	else if(object.eq.'shell')then
	  if(fac.ne.0)then
	    a = fac * amp / (pi * sqrt(fwhm1 * fwhm1))
	  else
	    a = amp
	  endif
	  cospa = cos(posang)
	  sinpa = sin(posang)
	  limit = 0.5 * max(fwhm1,fwhm1)
	  ymin = nint(y-limit)
	  ymax = nint(y+limit)
	  xmin = max(nint(x-limit),1)
	  xmax = min(nint(x+limit),n1)
	  if(ymin.le.j0.and.j0.le.ymax)then
	    yy = (j0-y)
	    do i=xmin,xmax
	      xx = (i-x)
              yp =  yy*cospa + xx*sinpa
              xp = -yy*sinpa + xx*cospa
              t = (xp*xp)/(fwhm1*fwhm1) + (yp*yp)/(fwhm1*fwhm1)
	      if(t.lt.0.25) data(i) = data(i) + a/0.5/fwhm1/
      *            sqrt(1.-4.*t)
	    enddo
	  endif 
c
c  Handle a DC level.
c
	else if(object.eq.'level')then
	  do i=1,n1
	    data(i) = data(i) + amp
	  enddo
c
c  Handle a Noise level.
c
	else if(object.eq.'noise')then
	  call gaus(buff,n1)
	  do i=1,n1
	    data(i) = data(i) + amp * buff(i)
	  enddo
c
c  Handle a point source.
c
	else if(object.eq.'point')then
	  i = nint(x)
	  j = nint(y)
	  if(j.eq.j0.and.i.ge.1.and.i.le.n1)
     *		data(i) = data(i) + Amp
c
c  Should never get here.
c
	else
	  call bug('f','Unknown object type (object=)')
	endif
	end
