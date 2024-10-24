package engine_gfx

// Base
    import "base:runtime"

// Core
    import "core:c"
    import "core:log"
    import "core:fmt"
    import "core:slice"
    import "core:strings"
 
// Vendor
    import "vendor:glfw"
    import vk "vendor:vulkan"


///////////////////////////////////////////////////////////////////////////////
// Render_Pass

    Render_Pass :: struct {
        logical_device: ^Logical_Device,
        vk_attachment_desc: vk.AttachmentDescription,
        vk_attachment_ref: vk.AttachmentReference,
        vk_subpass_desc: vk.SubpassDescription,
        vk_subpass_dependency: vk.SubpassDependency,
        vk_render_pass_create_info: vk.RenderPassCreateInfo,
        vk_render_pass: vk.RenderPass,
    }

    render_pass__init :: proc(self: ^Render_Pass, logical_device: ^Logical_Device, swapchain: ^Swapchain) {
        assert(self != nil)
        assert(logical_device != nil)

        self.logical_device = logical_device

		self.vk_attachment_desc = vk.AttachmentDescription {
			format         = swapchain.vk_surface_format.format,
			samples        = {._1},
			loadOp         = .CLEAR,
			storeOp        = .STORE,
			stencilLoadOp  = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout  = .UNDEFINED,
			finalLayout    = .PRESENT_SRC_KHR,
		}

		self.vk_attachment_ref = vk.AttachmentReference {
			attachment = 0,
			layout     = .COLOR_ATTACHMENT_OPTIMAL,
		}

		self.vk_subpass_desc = vk.SubpassDescription {
			pipelineBindPoint    = .GRAPHICS,
			colorAttachmentCount = 1,
			pColorAttachments    = &self.vk_attachment_ref,
		}

		self.vk_subpass_dependency = vk.SubpassDependency {
			srcSubpass    = vk.SUBPASS_EXTERNAL,
			dstSubpass    = 0,
			srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
			srcAccessMask = {},
			dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
			dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		}

		self.vk_render_pass_create_info = vk.RenderPassCreateInfo {
			sType           = .RENDER_PASS_CREATE_INFO,
			attachmentCount = 1,
			pAttachments    = &self.vk_attachment_desc,
			subpassCount    = 1,
			pSubpasses      = &self.vk_subpass_desc,
			dependencyCount = 1,
			pDependencies   = &self.vk_subpass_dependency,
		}     
        
        vk_must(vk.CreateRenderPass(logical_device.vk_device, &self.vk_render_pass_create_info, nil, &self.vk_render_pass))
    }

    render_pass__terminate :: proc(self: ^Render_Pass) {
        assert(self != nil)

        vk.DestroyRenderPass(self.logical_device.vk_device, self.vk_render_pass, nil)
    }
