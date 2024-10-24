package game01

// Core
    import "core:log"
    import "core:mem"
    import "core:fmt"

// ODE
    import eng "engine"
    import "basic"
    import "mem_track"


///////////////////////////////////////////////////////////////////////////////
// Types

    SHADER_VERT :: #load("out/spv/vert.spv")
    SHADER_FRAG :: #load("out/spv/frag.spv")

///////////////////////////////////////////////////////////////////////////////
// MAIN 

    main :: proc() {
        // Log into console when panic happens
        context.logger = log.create_console_logger()
        // Track memory leaks and bad frees
        context.allocator = mem_track.init(context.allocator)  

        defer mem_track.terminate()
        defer mem_track.panic_if_bad_frees_or_leaks() // Defer statements are executed in the reverse order that they were declared
        
        eng.init(1024, 768, basic.G1_APP_NAME, basic.G1_VERSION_MAJOR, basic.G1_VERSION_MINOR, basic.G1_VERSION_PATCH)
        defer eng.terminate()

        eng.shaders__append(SHADER_VERT, { eng.ShaderStageFlag.VERTEX } , "main")
        eng.shaders__append(SHADER_FRAG, { eng.ShaderStageFlag.FRAGMENT } , "main")

        for !eng.window__should_close() {
            free_all(context.temp_allocator)
            eng.window__events_poll()

            eng.render_start() or_continue

            eng.render_test_triangle()

            eng.render_end()

            mem_track.panic_if_bad_frees()
        }

        eng.device__wait_idle()
    }


