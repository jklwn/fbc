/*
 *  libfb - FreeBASIC's runtime library
 *	Copyright (C) 2004-2005 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * sys_cdir.c -- curdir$
 *
 * chng: nov/2004 written [v1ctor]
 *
 */

#include <malloc.h>
#include <string.h>
#include "fb.h"

#ifdef WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <unistd.h>
#define MAX_PATH	1024
#endif

/*:::::*/
FBCALL FBSTRING *fb_CurDir ( void )
{
	FBSTRING 	*dst;
	char		tmp[MAX_PATH];
	int			len;

#ifdef WIN32
	len = GetCurrentDirectory( MAX_PATH, tmp );
#else
	len = strlen(getcwd(tmp, MAX_PATH));
#endif

	/* alloc temp string */
	if( len > 0 )
	{
		dst = (FBSTRING *)fb_hStrAllocTmpDesc( );
		if( dst != NULL )
		{
			fb_hStrAllocTemp( dst, len );

			strncpy( dst->data, tmp, len + 1 );
		}
		else
			dst = &fb_strNullDesc;
	}
	else
		dst = &fb_strNullDesc;

	return dst;
}

