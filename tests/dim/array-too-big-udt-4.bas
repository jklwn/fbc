' TEST_MODE : COMPILE_ONLY_FAIL

type UDT
	as integer a, b, c, d
end type

'' check triggered in UDT field singledecl parser
const LIMIT = &h7FFFFFFF
type Container
	test(0 to LIMIT \ sizeof( UDT )) as UDT
end type
