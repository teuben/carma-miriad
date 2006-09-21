c********1*********2*********3*********4*********5*********6*********7**
       program uvimage
       implicit none
c
c= UVIMAGE  Create a 3D image from uvdata 
c& pjt
c: image conversion, analysis.
c+
c       UVIMAGE makes a Miriad image datacube of the uvdata in a
c       Channel - Baseline - Time order.
c       Missing Baselines are replaced with 0s, 
c       Missing channels cause a fatal error.
c
c
c	Related tasks:
c	  	TVFLAG - good for inspection and flagging, but
c                        only works in 8bit displays
c               UVAVER - use this to cut down the number of times
c               VARMAP - image maps of uv-variables
c@ vis
c       The input uv-dataset name. No default.
c@ select
c       This selects which visibilities to be used. Default uses
c       all the data. See the Users Guide for information about
c       how to specify uv data selection.
c       e.g. 'select=ant(1)(5),-time(00:00,01:09)'
c@ line
c       Linetype of the data in the format line,nchan,start,width,step
c       "line" can be `channel', `wide' or `velocity'.
c       Default is channel,0,1,1,1, which uses all the spectral
c       channels. 
c
c@ view
c	Visibility 'amplitude', 'phase', 'real', or 'imaginary'.
c	No calibration is applied by UVIMAGE.
c	Default: amplitude
c
c@ out
c	Output image. No default.
c       Currently the image cube is poorly labeled as CHANNEL,
c       BASELINE, TIME with no real meaningful coordinates.
c@ mode
c       This controls in what order the cube is written
c       1: CHANNEL-BASELINE-TIME (default)
c       2: TIME-CHANNEL-BASELINE
c
c--
c  History:
c     pjt  20sep06  Initial version, cloned off varmap
c     pjt  21sep06  Added mode keyword, more efficient memory usage
c
c  TODO
c     - write plane by plane, but this will limit it to mode=1
c       but handle much larger cubes
c----------------------------------------------------------------------c
       include 'maxdim.h'
       include 'mirconst.h'
       character*(*) version
       parameter(version='UVIMAGE: version 21-sep-2006 ** test6 **')
       integer MAXSELS
       parameter(MAXSELS=512)
       integer MAXSIZE
       parameter(MAXSIZE=256*266*256)

       real sels(MAXSELS)
       complex data(MAXCHAN)
       logical flags(MAXCHAN),qmnmx
       double precision preamble(4),oldtime
       integer lIn,nchan,nread,nvis,nchannel,vmode,nbl,omode
       real start,width,step
       character*128 vis,out,linetype,line
       character*10 view
       integer antsel(MAXANT),ant1,ant2,nant,ntime
       integer lout,nsize(3),i,j,k,l
       real v,array(MAXSIZE)
       real datamin,datamax
       character*1 type
       integer length
       logical updated
c
c  Get the input parameters.
c
       call output(version)
       call keyini
       call keyf ('vis',vis,' ')
       call keyline(linetype,nchan,start,width,step)
       call SelInput ('select',sels,maxsels)
       call keya ('out',out,' ')
       call keya ('view',view,'amp')
       call keyi ('mode',omode,1)
       call keyfin
c
c  Check that all the inputs are reasonable.
c
       if (vis.eq.' ') call bug('f','Input name must be given')
       if (out.eq.' ') call bug('f','Output image missing')
       if (nchan.gt.0) nchan = MIN(nchan,MAXCHAN)

       if(index(view,'re').gt.0) then
          vmode = 1
       else if(index(view,'im').gt.0) then
          vmode =2 
       else if(index(view,'am').gt.0) then
          vmode = 3
       else if(index(view,'ph').gt.0) then
          vmode = 4
       else
          call bug('f','Unknown view='//view)
       endif
       write(line,'(a,a)') 'Mapping ', view
       call output(line)

c
c  Open an old visibility file, and apply selection criteria.
c
       call uvopen (lIn,vis,'old')
       if(linetype.ne.' ')
     *   call uvset (lIn,'data',linetype,nchan,start,width,step)
       call SelApply(lIn,sels,.true.)
c
c  Scan the visibilty file: open first record
c
       call uvread (lIn, preamble, data, flags, maxchan, nread)
       if(nread.le.0) call bug('f','No data found in the input.')
       nchannel = nread
       oldtime = preamble(3)
       if(index(linetype,'wide').gt.0)then
          call uvprobvr(lIn,'wcorr',type,length,updated)
       else
          call uvprobvr(lIn,'corr',type,length,updated)
       endif
       if(type.eq.'r') call bug('i','data is real')
       if(type.eq.'j'.or.type.eq.'c') call bug('i','data is complex')
       do i=1,MAXANT
          antsel(i) = 0
       enddo
       ntime = 1

c
c  Read through the uvdata a first time to gather how big the cube should be
c
       do while(nread.gt.0)
          if(nread.ne.nchannel)
     *		 call bug('w','Number of channels has changed.')
          call basant(preamble(4),ant1,ant2)
          antsel(ant1) = 1
          antsel(ant2) = 1
          if (preamble(3) .ne. oldtime) then
             ntime = ntime + 1
             oldtime = preamble(3)
          endif
          call uvread(lIn, preamble, data, flags, maxchan, nread)
          nvis = nvis + 1
       enddo
       nant=0
       do i=1,MAXANT
          if (antsel(i).gt.0) nant=nant+1
       enddo
       nbl = nvis/ntime

       write (*,*) 'Nvis=',nvis,' Nant=',nant
       write (*,*) 'Nchan=',nchannel,' Nbl=',nbl,' Ntime=',ntime,
     *    ' Space used: ',nchannel*nbl*ntime,' / ',MAXSIZE,
     *    ' = ',REAL(nchannel*nbl*ntime)/REAL(MAXSIZE)*100,'%'
       if (MOD(nvis,ntime).NE.0) call bug('w','No regular baseline set')

       if (omode.EQ.1) then
          nsize(1) = nchannel
          nsize(2) = nbl
          nsize(3) = ntime
       else
          nsize(1) = ntime
          nsize(2) = nchannel
          nsize(3) = nbl
       endif

       if (nsize(1)*nsize(2)*nsize(3) .GT. MAXSIZE) call bug('f',
     *       'Too many data, use  uvaver, or select= to cut down')


       call xyopen(lOut,Out,'new',3,nsize)
       call maphead(lIn,lOut,nsize,omode)
       call azero(array,nsize(1),nsize(2),nsize(3))

c
c   Rewind vis file and now process the data
c
       call uvrewind(lIn)
       j=1
       k=1
       qmnmx = .false.
       do l=1,nvis
          call uvread(lIn, preamble, data, flags, maxchan, nread)
          if (l.eq.1) oldtime = preamble(3)
          if (preamble(3).ne.oldtime) then
             oldtime = preamble(3)
             j=1
             k=k+1
          endif
          do i=1,nread
             if (flags(i)) then
                if(vmode.eq.1) then
                   v = real(data(i))
                else if(vmode.eq.2) then
                   v = aimag(data(i))
                else if(vmode.eq.3) then
                   v = cabs(data(i))
                else if(vmode.eq.4) then
                   v = 180./pi * atan2(aimag(data(i)),real(data(i)))
                else
                   call bug('f','Illegal view')
                endif
                if (omode.eq.1) then
                   call aset(array,nsize(1),nsize(2),nsize(3),i,j,k,v)
                else
                   call aset(array,nsize(1),nsize(2),nsize(3),k,i,j,v)
                endif
                if (qmnmx) then
                   datamin = MIN(datamin,v)
                   datamax = MAX(datamax,v)
                else
                   datamin = v
                   datamax = v
                   qmnmx = .true.
                endif
             endif
          enddo
          j=j+1
       enddo
       

c
c  Write the image and it's header.
c
      call putimage(lOut,array,nsize(1),nsize(2),nsize(3))
      call wrhdr(lOut,'datamin',datamin)
      call wrhdr(lOut,'datamax',datamax)
c
c  Write summary.
c
      write(line,'(a,i6)') ' number of records read= ',nvis
      call output(line)
c
c  Write the history file.
c
      call hisopen(lOut,'append')
      call hiswrite(lOut, 'UVIMAGE '//version)
      call hisinput(lOut, 'UVIMAGE')
      call hisclose(lOut)
c
c  Close the files after writing history
c
      call xyclose(lOut)
c
      end
c********1*********2*********3*********4*********5*********6*********7**
      subroutine azero(a,nx,ny,nz)
      implicit none
      integer nx,ny,nz
      real a(nx,ny,nz)
c
      integer i,j,k
      do k=1,nz
         do j=1,ny
            do i=1,nx
               a(i,j,k) = 0.0
            enddo
         enddo
      enddo
      end
c
      subroutine aset(a,nx,ny,nz,ix,iy,iz,v)
      implicit none
      integer nx,ny,nz,ix,iy,iz
      real a(nx,ny,nz),v
c
      a(ix,iy,iz) = v
      end

c********1*********2*********3*********4*********5*********6*********7**
      subroutine maphead(lIn,lOut,nsize,omode)
      implicit none
      integer	lin,lout,nsize(3),omode
c  Inputs:
c    lIn	The handle of the autocorrelation data.
c    lOut	The handle of the output image.
c    nsize	The output image size.
c-------------------------------------------------------------------------
      include 'maxdim.h'
      character source*16,telescop*16
      real epoch
c
c  Get source parameters.
c
      call uvrdvra(lIn,'source',source,' ')
      call uvrdvrr(lIn,'epoch',epoch,0.d0)
      call uvrdvra(lIn,'telescop',telescop,' ')
c
c  Write header values.
c
      call wrhdi(lOut,'naxis',3)
      call wrhdi(lOut,'naxis1',nsize(1))
      call wrhdi(lOut,'naxis2',nsize(2))
      call wrhdi(lOut,'naxis3',nsize(3))
      call wrhdd(lOut,'crpix1',1.0d0)
      call wrhdd(lOut,'crpix2',1.0d0)
      call wrhdd(lOut,'crpix3',1.0d0)
      call wrhdd(lOut,'cdelt1',1.0d0)
      call wrhdd(lOut,'cdelt2',1.0d0)
      call wrhdd(lOut,'cdelt3',1.0d0)
      call wrhdd(lOut,'crval1',0.0d0)
      call wrhdd(lOut,'crval2',0.0d0)
      call wrhdd(lOut,'crval3',0.0d0)
      if (omode.eq.1) then
         call wrhda(lOut,'ctype1','CHANNEL')
         call wrhda(lOut,'ctype2','BASELINE')
         call wrhda(lOut,'ctype3','TIME')
      else
         call wrhda(lOut,'ctype1','TIME')
         call wrhda(lOut,'ctype2','CHANNEL')
         call wrhda(lOut,'ctype3','BASELINE')
      endif
      call wrhdr(lOut,'epoch',epoch)
      call wrhda(lOut,'object',source)
      call wrhda(lOut,'telescop',telescop)
c
      end
c********1*********2*********3*********4*********5*********6*********7**
      subroutine putimage(lOut,array,nx,ny,nz)
      implicit none
      integer lOut,nx,ny,nz
      real array(nx,ny,nz)
c  Inputs:
c    lOut	The handle of the output image.
c    array	image values.
c    nx,ny,nz	The output image size.
c-------------------------------------------------------------------------
      integer j,k

      do k=1,nz
         call xysetpl(lOut,1,k)
	 do j=1,ny
            call xywrite(lOut,j,array(1,j,k))
         enddo
      enddo
      end
c********1*********2*********3*********4*********5*********6*********7**
