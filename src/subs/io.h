/************************************************************************/
/*									*/
/*	A general header file for the various file and i/o handling	*/
/*	routines.							*/
/*									*/
/*  History:								*/
/*   rjs  Dark-ages Original version.					*/
/*   rjs  20aug92   Correct "roundup" macro when rounding 0.		*/
/*   rjs  15may96   Moved roundup macro elsewhere.			*/
/*   pjt  28may02   Added H_INT8                                        */
/*   pjt  17jun02   different MIR4 structures?                          */
/*   pjt  23aug06   merged  ATNF for MIR5 + static comments             */
/************************************************************************/

/* Binary items start with a sequence to allow routines to blindly determine
   how to read them. The "binary_item" is a catch all with only indicates
   that the data is binary valued, but does not hint at the format. */

#if !defined(MIR_IO_H)
#define MIR_IO_H

#include "hio.h"
#include <unistd.h>

#define ITEM_HDR_SIZE		4

/* careful: some linkers may only like one static version, 
            others will have to be done via a 'extern' and 
	    a single global version. 
 */
   

static char 	binary_item[ITEM_HDR_SIZE]	= {0,0,0,0},
		real_item[ITEM_HDR_SIZE]	= {0,0,0,H_REAL},
		int_item[ITEM_HDR_SIZE]		= {0,0,0,H_INT},
		int2_item[ITEM_HDR_SIZE]	= {0,0,0,H_INT2},
		int8_item[ITEM_HDR_SIZE]	= {0,0,0,H_INT8},
		char_item[ITEM_HDR_SIZE]	= {0,0,0,H_BYTE},
		dble_item[ITEM_HDR_SIZE]	= {0,0,0,H_DBLE},
		cmplx_item[ITEM_HDR_SIZE]	= {0,0,0,H_CMPLX};

#endif /* MIR_IO_H */
