/**
   This is example of "engine" for learning purposes. A real engine could look differently.
*/
    package engine

    import "core:c"
    import "core:log"
    import "core:strings"

    import "basic"
    import "gfx"


    import "vendor:glfw"
    import vk "vendor:vulkan"

    when ODIN_OS == .Darwin {
        // NOTE: just a bogus import of the system library,
        // needed so we can add a linker flag to point to /usr/local/lib (where vulkan is installed by default)
        // when trying to load vulkan.
        @(require, extra_linker_flags = "-rpath /usr/local/lib")
        foreign import __ "system:System.framework"
    }    

///////////////////////////////////////////////////////////////////////////////
// Types

    Result :: basic.Result

    ShaderStageFlag :: vk.ShaderStageFlag
    ShaderStageFlags :: vk.ShaderStageFlags
  
///////////////////////////////////////////////////////////////////////////////
// Init / Terminate 

    init :: proc(width, height: c.int, title: cstring, app_version_major, app_version_minor, app_version_patch: u32) {
        gfx.init(width, height, title, app_version_major, app_version_minor, app_version_patch)
    }

    terminate :: proc() {
        gfx.terminate()
    }
 
///////////////////////////////////////////////////////////////////////////////
// Procs

    // pipeline__init :: gfx.g_pipeline__init
    //
    // Window
    //
        window__events_poll :: gfx.window__poll_events
        window__should_close :: gfx.g_window__should_close

    //
    // Device
    //
        device__wait_idle :: gfx.g_logical_device__wait_idle
    //
    // Shaders
    //
        shaders__append :: gfx.g_shaders__append

    //
    // Render_Loop
    //
        render_start :: gfx.g_render_loop__start
        render_end :: gfx.g_render_loop__end
        render_test_triangle :: gfx.g_render_loop__render_test_triangle




