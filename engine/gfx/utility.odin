/**
	Utility procs
	
*/

package engine_gfx

// Core
    import "core:strings"


byte_arr_to_str :: proc(arr: ^[$N]byte) -> string {
    return strings.truncate_to_byte(string(arr[:]), 0)
}
