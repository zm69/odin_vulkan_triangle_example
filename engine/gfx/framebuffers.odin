package engine_gfx

// Base
    import "base:runtime"

// Core
    import "core:log"
    import "core:slice"
    import "core:strings"
    import "core:fmt"

// Vendor
    import "vendor:glfw"
    import vk "vendor:vulkan"

// ODE
    import "../basic"

///////////////////////////////////////////////////////////////////////////////
// Framebuffers

    Framebuffers :: struct {
        logical_device: ^Logical_Device,
        vk_framebuffers: []vk.Framebuffer,
    }

    framebuffers__init :: proc(self: ^Framebuffers, logical_device: ^Logical_Device, swapchain: ^Swapchain, render_pass: ^Render_Pass) {
        assert(self != nil)
        assert(logical_device != nil)
        assert(swapchain != nil)
        assert(render_pass != nil)

        self.logical_device = logical_device

        self.vk_framebuffers = make([]vk.Framebuffer, len(swapchain.vk_views))
        for view, i in swapchain.vk_views {
            attachments := []vk.ImageView{view}
    
            frame_buffer := vk.FramebufferCreateInfo {
                sType           = .FRAMEBUFFER_CREATE_INFO,
                renderPass      = render_pass.vk_render_pass,
                attachmentCount = 1,
                pAttachments    = raw_data(attachments),
                width           = swapchain.vk_extent2D.width,
                height          = swapchain.vk_extent2D.height,
                layers          = 1,
            }
            vk_must(vk.CreateFramebuffer(logical_device.vk_device, &frame_buffer, nil, &self.vk_framebuffers[i]))
        }
    }

    framebuffers__terminate :: proc(self: ^Framebuffers) {
        assert(self != nil)

        for frame_buffer in self.vk_framebuffers { 
            vk.DestroyFramebuffer(self.logical_device.vk_device, frame_buffer, nil) 
        }
        delete( self.vk_framebuffers)
        self.vk_framebuffers = nil
        self.logical_device = nil
    }
