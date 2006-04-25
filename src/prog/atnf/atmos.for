c************************************************************************
	program atmos
	implicit none
c
c= atmos -- Generate ATCA-style mosaic file.
c& rjs
c: uv analysis
c+
c	ATMOS takes a list of sources (with RA and DEC), sorts them into
c	an order to minimise the slew time between the sources, and then
c	writes out an ATCA-style mosaic file which can be used by the
c	ATCA on-line system to execute a mosaic observation.
c
c	In the mosaic file, the cycles spent on each source is adjusted
c	to account for the slew time needed to reach each source.
c
c	NOTE:
c	* ATMOS neglects the ATCA's wrap limits. It is
c	conceivable that the antennas might have to do a pirouette in the
c	middle of a mosaic block to move from north to south wrap (or visa
c	versa). This will foul up all of ATMOS's calculations.
c
c	* It does not appear that mosaicing is supported in anything but
c	J2000 coordinates. All coordinates here should be in J2000.
c
c	* You must give "sched" a reference position (the positions
c	in the mosaic file generated by ATMOS will be relative to this
c	position). ATMOS uses the position of the first source as the
c	reference position.
c
c@ source
c	A text file giving a list of sources. Each line of the file contains
c	  name ra dec
c	The source name cannot contain blanks. RA and DEC are given in the
c	standard Miriad format.
c
c	If the source name ends in "C", it is assumed to be a calibrator.
c	ATMOS assumes that sources follow their calibrator -- the rearrangement
c	ensures that this continues to be so. 
c	Note that, for calibrators in a mosaic file, the on-line imaging
c	software (CASNAP and friends) require names of calibrators to be 10
c	characters long and end in a "C".
c
c@ out
c	Output mosaic text file. Default is mosaic.mos
c@ cycles
c	Number of cycles to spend on-source at each source. Default is 2.
c@ interval
c	Integration cycle time. Default is 10 seconds.
c@ origin
c	The output mosaic file stores positions as an offset from
c	some position. You have to give this value in your sched file.
c	The `origin' parameter is used to set this position in ATMOS.
c	It is an RA and DEC, in the format hh:mm:ss,dd:mm:ss, or decimal hours
c	and decimal degrees). The default is the position of the first
c	source in the list. NOTE: The on-line system always slews to the
c	origin before it starts executing a mosaic. Consequently you
c	reduce slewing time by using the default.
c@ ref
c	This gives the name, RA and DEC where the antennas are pointing
c	before the mosaic sequence is executed (the format for RA is
c	hh:mm:ss, or decimal hours; and for declination is dd:mm:ss, or
c	decimal degrees). The default is the RA and DEC of the first
c	source to be observed (i.e. already on source).
c@ lst
c	Start time, given either in the format hh:mm:ss or decimal
c	hours. The default is the reference RA.
c@ options
c	Extra processing options. Minimum match is supported. Possible
c	options are:
c	  fixed  Do not do the travelling salesmen problem, just output
c	         the source list in the order given.
c--
c   History:
c     rjs  31-dec-00 Get it to work for 1 source.
c     rjs  20-dec-03 Get it to work for 2 sources!
c     rjs  26-mar-05 options=fixed. More precision. Minor enhancements.
c------------------------------------------------------------------------
	include 'mirconst.h'
	integer MAXSRC
	parameter(MAXSRC=500)
c
	integer i,i0,nsrc,cycles,ncycles,iostat,length,lu
	integer indx(MAXSRC)
	character source(MAXSRC)*16,out*64,line*80,sfile*64
	character ssource*16
	double precision ra(MAXSRC),dec(MAXSRC),lst,long
	double precision ra0,dec0,raprev,decprev,raref,decref
	real interval,dt,dra,ddec
	logical ok,doref,fixed,nolst
c
c  Externals.
c
	integer len1
	logical keyprsnt
	character hangle*11,rangle*13
c
c  Get the input parameters.
c
	call output('Atmos: version 1.0 26-Mar-05')
	call keyini
	call keya('source',sfile,' ')
	call keyr('interval',interval,10.)
	call keyi('cycles',cycles,2)
	call keya('out',out,'mosaic.mos')
	nolst = .not.keyprsnt('lst')
	if(.not.nolst)call keyt('lst',lst,'hms',0.d0)
	doref = keyprsnt('origin')
	call keyt('origin',raref,'hms',0.d0)
	call keyt('origin',decref,'dms',0.d0)
	call keya('ref',ssource,' ')
	call keyt('ref',ra0,'hms',0.d0)
	call keyt('ref',dec0,'dms',0.d0)
	call getopt(fixed)
	call keyfin
c
c  Check inputs.
c
	if(sfile.eq.' ')call bug('f','Input source file must be given')
	if(interval.le.0)call bug('f','Bad interval parameter')
	if(cycles.le.0)call bug('f','Bad cycles parameter')
c
c  Read the source file.
c
	call RdSource(sfile,source,ra,dec,MAXSRC,nsrc,
     *					raref,decref,doref)
	if(nsrc.le.0)call bug('f','No sources given')
c
c  Fill in the place that we start from if necessary.
c
	if(ssource.eq.' ')then
	  ssource = source(1)
	  ra0 = ra(1)
	  dec0 = dec(1)
	endif
	if(nolst)lst = ra0
c
c  Give some messages.
c
	call output('*************************************************')
	call output('Source file: '//sfile)
	call output('Output file:  '//out)
c
c  Get the longitude of Narrabri.
c
	call obspar('atca','longitude',long,ok)
	if(.not.ok)call bug('f','Could not find longitude')
c
c  Open the output file.
c
	call txtopen(lu,out,'new',iostat)
	if(iostat.ne.0)call bugno('f',iostat)
c
c  Sort the list into a travelling salesman order.
c
	if(nsrc.le.2.or.fixed)then
	  do i=1,nsrc
	   indx(i) = i
	  enddo
	else
	  call output('Optimising the slew time ...')
	  call sorter(source,ra,dec,nsrc,lst,interval,
     *					cycles,ra0,dec0,indx)
	endif
c
c  Some comments.
c
	call output('Writing mosaic file ...')
	call echo(lu,'Start LST is '//hangle(lst))
c
	line = 'Reference position = '//hangle(ra(1))//
     *	  ' '//rangle(dec(1))
	call echo(lu,line)
c
c  Loop over all the source.
c
	call output('Slewing from '//ssource)
	raprev = ra0
	decprev = dec0
	do i=1,nsrc
	  i0 = indx(i)
	  call atdrive(raprev,decprev,ra(i0),dec(i0),lst,dt,ok)
	  length = len1(source(i0))
	  if(.not.ok)
     *	    call bug('f','Source is not up: '//source(i0)(1:length))
	  dra = 180./pi * (ra(i0) - ra(1))
	  ddec = 180./pi * (dec(i0) - dec(1))
	  ncycles = nint(dt/interval + 0.7) + cycles
	  if(i.eq.1.and.doref)then
	    ncycles = ncycles - cycles
	    line = '#'
	  else if(i.eq.1)then
	    write(line,'(f11.6,f12.6,i3,a,a)')dra,ddec,cycles,'  $',
     *							    source(i0)
	  else
	    write(line,'(f11.6,f12.6,i3,a,a)')dra,ddec,ncycles,'  $',
     *							    source(i0)
	  endif
	  call txtwrite(lu,line,len1(line),iostat)
	  if(iostat.ne.0)call bugno('f',iostat)
c
c  Give messages to keep the user awake.
c
	  if(dt.gt.0)then
	    write(line,'(a,i4,a)')'Drive time to '//
     *	    source(i0)(1:length)//' is',nint(dt),' seconds'
	    call output(line)
	  endif
	  lst = lst + ncycles*interval * 2*pi/(24.*3600.)*366.25/365.25
	  raprev = ra(i0)
	  decprev = dec(i0)
	enddo
c
c  Add two cycles of dead time.
c
	lst = lst + 2*interval * 2*pi/(24.*3600.)*366.25/365.25
	call echo(lu,'End LST is '//hangle(lst))
c
	call txtclose(lu)
c
c  Create an output text file containing the reference
c
	call txtopen(lu,'ref.txt','new',iostat)
	if(iostat.ne.0)call bug('f','Error opening reference')
	i0 = indx(nsrc)
	line = source(i0)//' '//hangle(ra(i0))//' '//rangle(dec(i0))
	call txtwrite(lu,line,len1(line),iostat)
	if(iostat.ne.0)call bugno('f',iostat)
	call txtclose(lu)
	call output('End source is '//line)	
c
	end
c************************************************************************
	subroutine getopt(fixed)
c
	implicit none
	logical fixed
c
c------------------------------------------------------------------------
	integer NOPTS
	parameter(NOPTS=1)
	character opts(NOPTS)*8
	logical present(NOPTS)
	data opts/'fixed   '/
c
	call options('options',opts,present,NOPTS)
	fixed = present(1)
c
	end
c************************************************************************
	subroutine RdSource(sfile,source,ra,dec,MAXSRC,nsrc,
     *						raref,decref,doref)
c
	implicit none
	integer MAXSRC,nsrc
	character sfile*(*),source(MAXSRC)*(*)
	double precision ra(MAXSRC),dec(MAXSRC),raref,decref
	logical doref
c
c  Read in all the sources.
c------------------------------------------------------------------------
	integer tinNext
c
	call tinOpen(sfile,'n')
	if(doref)then
	  nsrc = 1
	  source(1) = 'Mosaic Origin'
	  ra(1) = raref
	  dec(1) = decref
	else
	  nsrc = 0
	endif
	dowhile(tinNext().gt.0)
	  nsrc = nsrc + 1
	  if(nsrc.gt.MAXSRC)call bug('f','Too many sources')
	  call tinGeta(source(nsrc),' ')
	  call tinGett(ra(nsrc),0.d0,'hms')
	  call tinGett(dec(nsrc),0.d0,'dms')
	enddo
c
	call tinClose
	end
c************************************************************************
	subroutine sorter(source,ra,dec,nsrc,lst,interval,
     *	  cycles,ra0,dec0,indx)
c
	implicit none
	integer nsrc,cycles,indx(nsrc)
	double precision ra(nsrc),dec(nsrc),lst,ra0,dec0
	real interval
	character source(nsrc)*(*)
c
c  Sort the travelling salesman problem for a salesman slewing the ATCA
c  around the sky.
c------------------------------------------------------------------------
	integer MAXITER,NTRY
	parameter(MAXITER=100,NTRY=10)
	integer i,nsucc,ntrial,nfail,n,niter
	real sume,sume2,oldE,E,p,T,rand
	character line*64
	logical more
c
c  Externals.
c
	real tottime
c
c  Generate the initial guess at the order of travel.
c
	call IndxIni(source,nsrc)
c
c  Get the feel for the rms drive time.
c
	E = tottime(ra,dec,nsrc,lst,interval,cycles,ra0,dec0)
	sume = E
	sume2 = E**2
	n = 1
c
	do i=1,NTRY
	  call switcher(rand,.true.)
	  E = tottime(ra,dec,nsrc,lst,interval,cycles,ra0,dec0)
	  sume = sume + E
	  sume2 = sume2 + E**2
	  n = n + 1
	enddo
	sume = sume / n
	sume2 = sume2 / n
c
c  The initial temperature is 3 times to variance in the total time.
c
	T = 3*sqrt(abs(sume2 - sume**2))
	more = T.gt.interval
	if(.not.more) call bug('w','Optimisation looks screwy')
c
c  Do some temperature settings.
c
	niter = 0
	ntrial = 0
	nsucc = 0
	nfail = 0
	dowhile(more)
	  call switcher(rand,.true.)
	  oldE = E
	  E = tottime(ra,dec,nsrc,lst,interval,cycles,ra0,dec0)
	  p = (oldE - E)/T
	  if(p.lt.-20)then
	    p = 0
	  else if(p.gt.0)then
	    p = 1
	  else
	    p = exp(p)
	  endif
	  if(p.gt.rand)then
	    nsucc = nsucc + 1
	  else
	    E = oldE
	    call switcher(rand,.false.)
	    nfail = nfail + 1
	  endif
c
c  Determine if we want to lower the temperature, or what.
c
	  if(nsucc.gt.10*nsrc.or.nfail.gt.100*nsrc)then
	    T = 0.9*T
	    nsucc = 0
	    nfail = 0
	    niter = niter + 1
	  endif
	  more = T.gt.0.2*interval.and.niter.lt.MAXITER
c
c  Give a message if its about time.
c
	  ntrial = ntrial + 1
	  if(mod(ntrial,5000).eq.0.or.ntrial.eq.1.or..not.more)then
	    write(line,'(a,i6,a,f8.2)')'Total Drive Time',nint(E),
     *				       ', Time Tolerance',T
	    call output(line)
	  endif
	enddo
c
c  Retrieve the index.
c
	call IndxFin(indx,nsrc)
c
	end
c************************************************************************
	subroutine IndxFin(indx,nsrc)
c
	implicit none
	integer nsrc,indx(nsrc)
c
c------------------------------------------------------------------------
	include 'atmos.h'
c
	integer ical,ical0,isrc,i
c
	i = 0
	do ical=1,ncal
	  ical0 = calidx(ical)
	  do isrc=1,nscal(ical0)
	    i = i + 1
	    indx(i) = scalidx(isrc,ical0)
	  enddo
	enddo
c
	if(i.ne.nsrc)call bug('f','Consistency check failed in indxfin')
	end
c************************************************************************
	subroutine IndxIni(source,nsrc)
c
	implicit none
	integer nsrc
	character source(nsrc)*(*)
c
c------------------------------------------------------------------------
	include 'atmos.h'
c
	logical cal
	character line*64
	integer l,i
c
	integer len1
c
	ncal = 0
	do i=1,nsrc
	  l = len1(source(i))
	  cal = source(i)(l:l).eq.'C'.or.i.eq.1
	  if(cal)then
	    if(ncal.gt.0)then
	      line = 'No sources for cal '//source(i-1)
	      if(nscal(ncal).le.1)call bug('f',line)
	    endif
	    ncal = ncal + 1
	    if(ncal.gt.MAXCAL)call bug('f','Buffer overflow-MAXCAL')
	    calidx(ncal) = ncal
	    nscal(ncal) = 1
	    scalidx(1,ncal) = i
	  else
	    if(ncal.eq.0)then
	      line = 'No calibrator for '//source(i)
	      call bug('f',line)
	    endif
	    nscal(ncal) = nscal(ncal) + 1
	    if(nscal(ncal).gt.MAXSCAL)call bug('f',
     *	      'Buffer overflow-MAXSCAL')
	    scalidx(nscal(ncal),ncal) = i
	  endif
	enddo
	end
c************************************************************************
	subroutine switcher(rand,dosw)
c
	implicit none
	real rand
	logical dosw
c------------------------------------------------------------------------
	include 'atmos.h'
c
	logical more
	integer i1,i2,temp,ical
c
	more = .true.
	dowhile(more)
	  if(dosw)call uniform(uni,NRAN)
	  rand = uni(1)
c
c  Are we going to do a intra-group swap, or a group swap.
c
c  Do a group swap.
c
	 if(uni(2).gt.0.5)then
	    i1 = ncal*uni(3) + 1
	    i2 = ncal*uni(4) + 1
	    more = i1.eq.i2.or.i1.eq.1.or.i2.eq.1
	    if(.not.more)then
	      temp = calidx(i1)
	      calidx(i1) = calidx(i2)
	      calidx(i2) = temp
	    endif
c
c  Do an intra-group swap.
c
	  else
	    ical = ncal*uni(3) + 1
	    i1 = (nscal(ical)-1)*uni(4) + 2
	    i2 = (nscal(ical)-1)*uni(5) + 2
	    more = i1.eq.i2
	    temp = scalidx(i1,ical)
	    scalidx(i1,ical) = scalidx(i2,ical)
	    scalidx(i2,ical) = temp
	  endif
	enddo
c
	end
c************************************************************************
	real function tottime(ra,dec,nsrc,lst,interval,
     *	  cycles,ra0,dec0)
c
	implicit none
	integer nsrc
	double precision ra(nsrc),dec(nsrc),lst,ra0,dec0
	real interval
	integer cycles
c
c  Determine the total time for this configuration.
c
c------------------------------------------------------------------------
	include 'mirconst.h'
	include 'atmos.h'
c
	double precision lst0,raprev,decprev
	integer totcycle,ncycles,i1,ical,ical0,isrc
	real dt,tdrive
	logical ok
c
	lst0 = lst
	totcycle = 0
	tdrive = 0
	raprev = ra0
	decprev = dec0
	do ical=1,ncal
	 ical0 = calidx(ical)
	 do isrc=1,nscal(ical0)
	  i1 = scalidx(isrc,ical0)
	  call atdrive(raprev,decprev,ra(i1),dec(i1),lst0,dt,ok)
	  if(.not.ok)then
	    tottime = 100000.
	    return
	  endif
c
	  tdrive = tdrive + dt
	  ncycles =  (nint(dt/interval + 0.7) + cycles)
	  totcycle = totcycle + ncycles
	  dt = interval * ncycles
	  lst0 = lst0 + 2*pi*366.25/365.25/24./3600. * dt
	  raprev = ra(i1)
	  decprev = dec(i1)
	 enddo
	enddo
c
	tottime = tdrive
	end
c************************************************************************
	subroutine echo(lu,string)
c
	implicit none
	integer lu
	character string*(*)
c------------------------------------------------------------------------
	character line*80
	integer iostat
c
	integer len1
c
	call output(string)
	line = '# '//string
	call txtwrite(lu,line,len1(line),iostat)
	if(iostat.ne.0)call bugno('f',iostat)
	end
c************************************************************************
	subroutine atdrive(ra1,dec1,ra2,dec2,lst,dt,ok)
c
	implicit none
	double precision ra1,dec1,ra2,dec2,lst
	real dt
	logical ok
c
c  Determine drive time between sources for the atca antennas.
c
c  This accounts for a ramp up to the maximum slew rate at the
c  start, and a ramp down at the end.
c
c  Input:
c    ra1,dec1	Source driving from - radians.
c    ra2,dec2	Source driving to - radians.
c    lst	Local sidereal time - radians.
c  Output:
c    dt		Drive time in seconds.
c    ok		True if the drive time is valid.
c
c  Bugs:
c    This does not consider the wrap limits. 
c------------------------------------------------------------------------
	include 'mirconst.h'
c
c  Peak velocity and acceleration rates, in radians/sec, and radians/sec/sec.
c  Also the critical time and distances in az and el.
c
	real azrate,elrate,acc,tcritaz,xcritaz,tcritel,xcritel
	parameter(azrate=36./60.*pi/180.)
	parameter(elrate=18./60.*pi/180.)
	parameter(acc=400./60./60.*pi/180.)
c
	parameter(tcritaz = 2.*azrate/acc)
	parameter(xcritaz = azrate*azrate/acc)
	parameter(tcritel = 2.*elrate/acc)
	parameter(xcritel = elrate*elrate/acc)
c
	real dtaz,dtel,daz,del,az1,el1,az2,el2
	double precision lst2
	logical more
c
c  Initialise the drive time to zero.
c
	dt = 0
c
c  Determine the az and elevation of the first source.
c
	call atazel(ra1,dec1,lst,az1,el1,ok)
	if(.not.ok)return
c
c  Determine slew time to the other source.
c
	more = .true.
	dowhile(more)
	  lst2 = lst + 2*pi*366.25/365.25/(24.*3600.) * dt
	  call atazel(ra2,dec2,lst2,az2,el2,ok)
	  if(.not.ok)return
c
	  daz = abs(az1-az2)
	  if(daz.gt.pi)daz = 2*pi - daz
	  if(daz.lt.xcritaz)then
	    dtaz = 2*sqrt(daz/acc)
	  else
	    dtaz = tcritaz + (daz-xcritaz)/azrate
	  endif
c
	  del = abs(el1-el2)
	  if(del.lt.xcritel)then
	    dtel = 2*sqrt(del/acc)
	  else
	    dtel = tcritel + (del-xcritel)/elrate
	  endif
	  more = abs(max(dtaz,dtel) - dt).gt.1
	  dt = max(dtaz,dtel)
	enddo
c
	end
c************************************************************************
	subroutine atazel(ra,dec,lst,az,el,ok)
c
	implicit none
	double precision ra,dec,lst
	real az,el
	logical ok
c
c  Determine the azimuth and elevation of a source.
c
c  Input:
c    ra,dec	Apparent source position.
c    lst	Local apparent sidereal time.
c
c  Output:
c    az,el	Azimuth and elevation, in radians.
c		Elevation is in the range 0 to pi/2.
c		Azimuth is in the range -pi to pi. North
c		corresponds to AZ 0, east to AZ of pi/2.
c    ok		True if all is ok.
c------------------------------------------------------------------------
	include 'mirconst.h'
c
c  Observatory latitude in radians.
c
	double precision lat
	parameter(lat=-dpi/180.d0*(30.d0+10.d0/60.d0+52.02/3600.d0))
c
c  Assume an elevation limit of 12 degrees.
c
	real ellimit
	parameter(ellimit=12.*pi/180.)
c
	double precision ha
c
	ha = lst - ra
	el = asin(sin(lat)*sin(dec) + cos(lat)*cos(dec)*cos(ha))
	ok = el.gt.ellimit
	if(.not.ok)return
	az = atan2(-cos(dec)*sin(ha),
     *		cos(lat)*sin(dec)-sin(lat)*cos(dec)*cos(ha))
c
	end
