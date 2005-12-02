''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2005 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
''
''	This program is free software; you can redistribute it and/or modify
''	it under the terms of the GNU General Public License as published by
''	the Free Software Foundation; either version 2 of the License, or
''	(at your option) any later version.
''
''	This program is distributed in the hope that it will be useful,
''	but WITHOUT ANY WARRANTY; without even the implied warranty of
''	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''	GNU General Public License for more details.
''
''	You should have received a copy of the GNU General Public License
''	along with this program; if not, write to the Free Software
''	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.

'' AST bound and null-pointer checking nodes
''
'' chng: sep/2004 written [v1ctor]

option explicit
option escape

#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\ir.bi"
#include once "inc\rtl.bi"
#include once "inc\ast.bi"

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' Bounds checking (l = index; r = link(lb, ub))
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
function astNewBOUNDCHK( byval l as ASTNODE ptr, _
					     byval lb as ASTNODE ptr, _
					     byval ub as ASTNODE ptr, _
					     byval linenum as integer ) as ASTNODE ptr static
    dim as ASTNODE ptr n

	'' lbound is a const?
	if( lb->defined ) then
		'' ubound too?
		if( ub->defined ) then
			'' index also?
			if( l->defined ) then
				'' i < lbound?
				if( l->con.val.int < lb->con.val.int ) then
					return NULL
				end if
				'' i > ubound?
				if( l->con.val.int > ub->con.val.int ) then
					return NULL
				end if

				astDel( lb )
				astDel( ub )
				return l
			end if
		end if

		'' 0? del it
		if( lb->con.val.int = 0 ) then
			astDel( lb )
			lb = NULL
		end if
	end if

	'' alloc new node
	n = astNewNode( AST_NODECLASS_BOUNDCHK, INVALID )
	function = n

	if( n = NULL ) then
		exit function
	end if

	n->l 			= l
	n->r 			= astNewLINK( lb, ub )
	n->bchk.linenum = linenum

end function

'':::::
function astLoadBOUNDCHK( byval n as ASTNODE ptr ) as IRVREG ptr
    dim as ASTNODE ptr l, r, f, t
    dim as FBSYMBOL ptr label, sym
    dim as IRVREG ptr vr

	l = n->l
	r = n->r

	if( (l = NULL) or (r = NULL) ) then
		return NULL
	end if

	'' assign to a temp, can't reuse the same vreg or registers could
	'' be spilled as IR can't handle inter-blocks
	sym = symbAddTempVar( l->dtype, l->subtype )
	t = astNewASSIGN( astNewVAR( sym, _
								 0, _
								 symbGetType( sym ), _
								 symbGetSubType( sym ) ), _
					  l )
	astLoad( t )
	astDel( t )

    '' check must be done using a function because calling ErrorThrow
    '' would spill used regs only if it was called, causing wrong
    '' assumptions after the branches
    f = rtlArrayBoundsCheck( astNewVAR( sym, _
    									0, _
    									symbGetType( sym ), _
    									symbGetSubType( sym ) ), _
    						 r->l, _
    						 r->r, _
    						 n->bchk.linenum )
    vr = astLoad( f )
    astDel( f )

    if( ast.doemit ) then
    	'' handler = boundchk( ... ): if handler <> NULL then handler( )
    	label = symbAddLabel( NULL )
    	irEmitBOPEx( IR_OP_EQ, vr, irAllocVRIMM( IR_DATATYPE_INTEGER, 0 ), NULL, label )
    	irEmitJUMPPTR( vr )
    	irEmitLABELNF( label )
    end if

	''
	astDel( r )

	'' re-load, see above
	t = astNewVAR( sym, 0, symbGetType( sym ), symbGetSubType( sym ) )
	function = astLoad( t )
	astDel( t )

end function

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' null pointer checking (l = index; r = NULL)
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
function astNewPTRCHK( byval l as ASTNODE ptr, _
					   byval linenum as integer ) as ASTNODE ptr static
    dim as ASTNODE ptr n

	'' constant? don't break OffsetOf() when used with Const's..
	if( l->class = AST_NODECLASS_CONST ) then
		return l
	end if

	'' alloc new node
	n = astNewNode( AST_NODECLASS_PTRCHK, INVALID )
	function = n

	if( n = NULL ) then
		exit function
	end if

	n->l 			= l
	n->pchk.linenum = linenum

end function

'':::::
function astLoadPTRCHK( byval n as ASTNODE ptr ) as IRVREG ptr
    dim as ASTNODE ptr l, t, f
    dim as FBSYMBOL ptr label, sym
    dim as IRVREG ptr vr

	l = n->l

	if( l = NULL ) then
		return NULL
	end if

	'' assign to a temp, can't reuse the same vreg or registers could
	'' be spilled as IR can't handle inter-blocks
	sym = symbAddTempVar( l->dtype, l->subtype )
	t = astNewASSIGN( astNewVAR( sym, _
								 0, _
								 symbGetType( sym ), _
								 symbGetSubType( sym ) ), _
					  l )
	astLoad( t )
	astDel( t )

    '' check must be done using a function, see bounds checking
    f = rtlNullPtrCheck( astNewVAR( sym, _
    								0, _
    								symbGetType( sym ), _
    								symbGetSubType( sym ) ), _
    					 n->pchk.linenum )
    vr = astLoad( f )
    astDel( f )

    if( ast.doemit ) then
    	'' handler = ptrchk( ... ): if handler <> NULL then handler( )
    	label = symbAddLabel( NULL )
    	irEmitBOPEx( IR_OP_EQ, vr, irAllocVRIMM( IR_DATATYPE_INTEGER, 0 ), NULL, label )
    	irEmitJUMPPTR( vr )
    	irEmitLABELNF( label )
    end if

	'' re-load, see above
	t = astNewVAR( sym, 0, symbGetType( sym ), symbGetSubType( sym ) )
	function = astLoad( t )
	astDel( t )

end function

