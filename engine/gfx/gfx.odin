/**
	Graphics
	
*/

package engine_gfx

// Base
    import "base:runtime"

// Core
    import "core:c"
    import "core:log"
    import "core:fmt"
    import "core:slice"
 
// Vendor
    import "vendor:glfw"
    import vk "vendor:vulkan"

// ODE
    import ode_os "../os"
    import "../basic"

///////////////////////////////////////////////////////////////////////////////
// Globals

    g_window : Window
    g_instance : Instance
    g_physical_devices_list: Physical_Devices_List
    g_logical_device: Logical_Device
    g_swapchain: Swapchain
    g_shaders: Shaders
    g_render_pass: Render_Pass
    g_framebuffers: Framebuffers
    g_pipeline: Pipeline
    g_command_pool: Command_Pool
    g_render_loop: Render_Loop

///////////////////////////////////////////////////////////////////////////////
// 
    init :: proc(width, height: c.int, title: cstring, app_version_major, app_version_minor, app_version_patch: u32) {

        //
        // g_window
        // 
            // Setup callbacks before init
            g_window.glfw_error_callback = gfx__glfw_error_callback
            g_window.set_framebuffer_size_callback = gfx__set_framebuffer_size_callback

            window__init(&g_window, width, height, title, app_version_major, app_version_minor, app_version_patch) 

        //
        // g_instance
        //
            g_instance.debug_messenger_callback = gfx__vk_dbg

            instance__init(&g_instance, &g_window) 

        //
        // g_physical_devices_list
        // 
            physical_devices_list__init(&g_physical_devices_list, &g_instance)

        //
        // g_logical_device
        //
            logical_device__init(&g_logical_device, &g_instance, g_physical_devices_list.primary_device)

        //
        // g_swap_chain
        //
            swapchain__init(&g_swapchain, &g_window, &g_instance, 
                                 g_physical_devices_list.primary_device, &g_logical_device)

        //
        // g_render_pass 
        //
            render_pass__init(&g_render_pass, &g_logical_device, &g_swapchain)

        //
        // g_shaders
        //
            shaders__init(&g_shaders, &g_logical_device)

        //
        // g_framebuffers
        //
            framebuffers__init(&g_framebuffers, &g_logical_device, &g_swapchain, &g_render_pass)

        //
        // g_command_pool
        //
            command_pool__init(&g_command_pool, g_physical_devices_list.primary_device, 
                &g_logical_device, basic.ODE_MAX_FRAMES_IN_FLIGHT)

        //
        // g_render_loop
        //
            render_loop__init(&g_render_loop)

    }

    terminate :: proc() {
        render_loop__terminate(&g_render_loop)
        command_pool__terminate(&g_command_pool)
        pipeline__terminate(&g_pipeline)
        framebuffers__terminate(&g_framebuffers)
        shaders__terminate(&g_shaders)
        render_pass__terminate(&g_render_pass) 
        swapchain__terminate(&g_swapchain)
        logical_device__terminate(&g_logical_device)
        physical_devices_list__terminate(&g_physical_devices_list)
        instance__terminate(&g_instance)
        window__terminate(&g_window)
    }

///////////////////////////////////////////////////////////////////////////////
// g_ Procs

    //
    // Window
    //
        g_window__should_close :: proc()-> b32 {
            return window__should_close(&g_window)
        }

    //
    // Device
    //
        g_logical_device__wait_idle :: proc() {
            logical_device__wait_idle(&g_logical_device)
        }

    //
    // Shaders
    //
        g_shaders__append :: proc(code: []byte, stage: vk.ShaderStageFlags, pipe_name: cstring) {
            shaders__append(&g_shaders, code, stage, pipe_name)
        }

    //
    // g_render_loop
    //

        // return false if error
        g_render_loop__start :: proc() -> bool {
            return render_loop__start(&g_render_loop)
        }

        g_render_loop__end :: proc() {
            render_loop__end(&g_render_loop)
        }

        g_render_loop__render_test_triangle :: proc() {
            render_loop__record_cmd_buff(&g_render_loop)
        }

///////////////////////////////////////////////////////////////////////////////
// Callbacks

    @(private="file")
    gfx__glfw_error_callback :: proc "c" (code: i32, description: cstring) {
        context = g_window.init_context   
        log.errorf("glfw: %i: %s", code, description)
    }

    @(private="file")
    gfx__set_framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, xscale, yscale: i32) {
        g_window.framebuffer_resized = true
        context = g_window.init_context   
    }

    @(private="file")
    gfx__vk_dbg :: proc "system" (
        messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
        messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
        pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
        pUserData: rawptr,
    ) -> b32 {
        context = g_instance.init_context

        level: log.Level
        if .ERROR in messageSeverity {
            level = .Error
        } else if .WARNING in messageSeverity {
            level = .Warning
        } else if .INFO in messageSeverity {
            level = .Info
        } else {
            level = .Debug
        }

        log.logf(level, "vulkan[%v]: %s", messageTypes, pCallbackData.pMessage)
        return false
    }

///////////////////////////////////////////////////////////////////////////////
// Utility

    vk_must :: proc(result: vk.Result, loc := #caller_location) -> (ret: vk.Result) {
        if result != vk.Result.SUCCESS {
            log.panicf("vulkan failure %v", result, location = loc)
        }

        return result
    }

    vk_log_info :: proc(result: vk.Result, message := "vulkan failure %v", loc := #caller_location) -> (ret: vk.Result) {
        if result != vk.Result.SUCCESS {
            log.info(message, result, location = loc)
        }

        return result
    }

    must_not_nil :: proc(object: rawptr, loc := #caller_location) {
        if object == nil {
            log.panicf("object is nil", location = loc)
        }
    }

///////////////////////////////////////////////////////////////////////////////
// 
