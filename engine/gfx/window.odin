/**
	Window - encapsulates GLFW window, contains and initializes vk.Instance
*/

package engine_gfx

// Base
    import "base:runtime"

// Core
    import "core:c"
    import "core:log"
 
// Vendor
    import "vendor:glfw"
    import vk "vendor:vulkan"

    // KHR_PORTABILITY_SUBSET_EXTENSION_NAME :: "VK_KHR_portability_subset"
    ODE_REQUIRED_DEVICE_EXTENSIONS := []cstring {
        vk.KHR_SWAPCHAIN_EXTENSION_NAME,
        // KHR_PORTABILITY_SUBSET_EXTENSION_NAME,
    }

///////////////////////////////////////////////////////////////////////////////
// Window

    Window :: struct {
        handle: glfw.WindowHandle,                                                               

        init_context: runtime.Context,
        glfw_error_callback: proc "c" (code: i32, description: cstring),

        // Set to true each time the window is resized 
        // (we can check it in the main game loop)
        framebuffer_resized: bool,               
        set_framebuffer_size_callback: proc "c" (window: glfw.WindowHandle, xscale, yscale: i32),

        title: cstring,
        app_version_major, app_version_minor, app_version_patch: u32,
    }

    window__init :: proc(self: ^Window, width, height: c.int, title: cstring, app_version_major, app_version_minor, app_version_patch: u32) {
        assert(self != nil)
        assert(title != nil)
        assert(self.glfw_error_callback != nil)
        assert(self.set_framebuffer_size_callback != nil)

        self.init_context = context
        self.title = title
        self.app_version_major = app_version_major
        self.app_version_minor = app_version_minor
        self.app_version_patch = app_version_patch

        //
        // GLFW error callback
        // 

            if self.glfw_error_callback != nil {
                glfw.SetErrorCallback(self.glfw_error_callback)
            }
        
        //
        // TODO: update vendor bindings to glfw 3.4 and use this to set a custom allocator.
        //

            // glfw.InitAllocator()

        //
        // GLFW, Create window
        // 

            if !glfw.Init() {
                log.panicf("glfw Init() failure, %s %d", glfw.GetError())
            }
    
            glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
            glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
            glfw.WindowHint(glfw.MAXIMIZED, glfw.FALSE)

            self.handle = glfw.CreateWindow(width, height, self.title, nil, nil)
            if self.handle == nil {
                log.panicf("glfw.CreateWindow failed, %s %d", glfw.GetError())
            }

            //if self.set_framebuffer_size_callback != nil {
                glfw.SetFramebufferSizeCallback(self.handle, self.set_framebuffer_size_callback)
            //}
    }

    window__terminate :: proc(self: ^Window) {
        glfw.DestroyWindow(self.handle)
        glfw.Terminate()
    }

    window__poll_events :: glfw.PollEvents

    window__should_close :: proc(self: ^Window) -> b32 {
        return glfw.WindowShouldClose(self.handle)
    }

    window__wait_if_minimized :: proc(self: ^Window) {
        // Don't do anything when minimized.
        for w, h := glfw.GetFramebufferSize(self.handle); w == 0 || h == 0; w, h = glfw.GetFramebufferSize(self.handle) {
            glfw.WaitEvents()

            // Handle closing while minimized.
            if glfw.WindowShouldClose(self.handle) { break }
        }
    }
