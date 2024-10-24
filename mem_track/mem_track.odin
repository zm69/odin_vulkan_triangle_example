/*
    Utility code for tracking memory leaks and bad frees.
*/

package g1_mem_track
 
// Base
    import "base:runtime"

// Core
    import "core:log"
    import "core:mem"
    import "core:fmt"

///////////////////////////////////////////////////////////////////////////////
// Globals

    g_default_allocator: runtime.Allocator
    g_tracking_allocator: mem.Tracking_Allocator

///////////////////////////////////////////////////////////////////////////////
//  

    init :: proc(default_allocator: runtime.Allocator) -> runtime.Allocator {
        g_default_allocator = default_allocator
        mem.tracking_allocator_init(&g_tracking_allocator, g_default_allocator) 
        return mem.tracking_allocator(&g_tracking_allocator)
    }

    terminate :: proc() {
        clear()
    }

///////////////////////////////////////////////////////////////////////////////
//  
    clear :: proc() {
        mem.tracking_allocator_clear(&g_tracking_allocator)
    }

    check_leaks :: proc() -> bool {
        err := false

        for _, value in g_tracking_allocator.allocation_map {
            fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
            err = true
        }

        return err
    }

    panic_if_leaks :: proc() {
        if check_leaks() {
            log.panicf("\nMemory leaked!")
        }
    }

    check_bad_frees :: proc() -> bool {
        err := false

        for value in g_tracking_allocator.bad_free_array {
            fmt.printf("Bad free at: %v\n", value.location)
            err = true
        }

        return err
    }

    panic_if_bad_frees :: proc() {
        if check_bad_frees() {
            log.panicf("\nBad free!")
        }
    }

    panic_if_bad_frees_or_leaks :: proc() {
        panic_if_bad_frees()
        panic_if_leaks()
    }