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
    import "../basic"

///////////////////////////////////////////////////////////////////////////////
// Render_Loop
// NOTE: Unlike most of other objects, this object uses global (g_) variables.
// Think about this file almost like an extension of gfx.odin

    Render_Loop :: struct {
        vk_sem_info: vk.SemaphoreCreateInfo,
        vk_fence_info: vk.FenceCreateInfo,
        vk_image_available_semaphores: [basic.ODE_MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
        vk_render_finished_semaphores: [basic.ODE_MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
        vk_in_flight_fences: [basic.ODE_MAX_FRAMES_IN_FLIGHT]vk.Fence,
        current_frame: uint,
        image_index: u32,
    }

    render_loop__init :: proc(self: ^Render_Loop) {
        assert(self != nil)

        self.current_frame = 0

        self.vk_sem_info = vk.SemaphoreCreateInfo {
            sType = .SEMAPHORE_CREATE_INFO,
        }
        self.vk_fence_info = vk.FenceCreateInfo {
            sType = .FENCE_CREATE_INFO,
            flags = {.SIGNALED},
        }
        for i in 0 ..< basic.ODE_MAX_FRAMES_IN_FLIGHT {
            vk_must(vk.CreateSemaphore(g_logical_device.vk_device, &self.vk_sem_info, nil, &self.vk_image_available_semaphores[i]))
            vk_must(vk.CreateSemaphore(g_logical_device.vk_device, &self.vk_sem_info, nil, &self.vk_render_finished_semaphores[i]))
            vk_must(vk.CreateFence(g_logical_device.vk_device, &self.vk_fence_info, nil, &self.vk_in_flight_fences[i]))
        }
    }

    render_loop__terminate :: proc(self: ^Render_Loop) {
        assert(self != nil)

        for sem in self.vk_image_available_semaphores {vk.DestroySemaphore(g_logical_device.vk_device, sem, nil)}
        for sem in self.vk_render_finished_semaphores {vk.DestroySemaphore(g_logical_device.vk_device, sem, nil)}
        for fence in self.vk_in_flight_fences {vk.DestroyFence(g_logical_device.vk_device, fence, nil)}
    }
 
    render_loop__recreate_swapchain :: proc(self: ^Render_Loop) {
        window__wait_if_minimized(&g_window)
        
        logical_device__wait_idle(&g_logical_device)

        framebuffers__terminate(&g_framebuffers)
        swapchain__terminate(&g_swapchain)

        physical_device__query_swapchain_support(g_physical_devices_list.primary_device, &g_instance)

        swapchain__init(&g_swapchain, &g_window, &g_instance, 
            g_physical_devices_list.primary_device, &g_logical_device)
        framebuffers__init(&g_framebuffers, &g_logical_device, &g_swapchain, &g_render_pass)
    }

    // returns false if error
    render_loop__start :: proc(self: ^Render_Loop) -> bool {

        if !pipeline__is_initialized(&g_pipeline) {
            pipeline__init(&g_pipeline, &g_logical_device, &g_shaders, &g_render_pass)
        }

        vk_must(vk.WaitForFences(g_logical_device.vk_device, 1, &self.vk_in_flight_fences[self.current_frame], true, max(u64)))

        // Acquire an image from the swapchain.
		acquire_result := vk.AcquireNextImageKHR(
			g_logical_device.vk_device,
			g_swapchain.vk_swapchain,
			max(u64),
			self.vk_image_available_semaphores[self.current_frame],
			0,
			&self.image_index,
		)
		#partial switch acquire_result {
		case .ERROR_OUT_OF_DATE_KHR:
            render_loop__recreate_swapchain(self)
			return false
		case .SUCCESS, .SUBOPTIMAL_KHR:
		case:
			log.panicf("vulkan: acquire next image failure: %v", acquire_result)
		}

        vk_must(vk.ResetFences(g_logical_device.vk_device, 1, &self.vk_in_flight_fences[self.current_frame]))
		vk_must(vk.ResetCommandBuffer(g_command_pool.vk_cmd_buffs[self.current_frame], {}))

        return true
    }

    render_loop__end :: proc(self: ^Render_Loop) {
		// Submit.
		submit_info := vk.SubmitInfo {
			sType                = .SUBMIT_INFO,
			waitSemaphoreCount   = 1,
			pWaitSemaphores      = &self.vk_image_available_semaphores[self.current_frame],
			pWaitDstStageMask    = &vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT},
			commandBufferCount   = 1,
			pCommandBuffers      = &g_command_pool.vk_cmd_buffs[self.current_frame],
			signalSemaphoreCount = 1,
			pSignalSemaphores    = &self.vk_render_finished_semaphores[self.current_frame],
		}
		vk_must(vk.QueueSubmit(g_logical_device.vk_graphics_queue, 1, &submit_info, self.vk_in_flight_fences[self.current_frame]))

		// Present.
		present_info := vk.PresentInfoKHR {
			sType              = .PRESENT_INFO_KHR,
			waitSemaphoreCount = 1,
			pWaitSemaphores    = &self.vk_render_finished_semaphores[self.current_frame],
			swapchainCount     = 1,
			pSwapchains        = &g_swapchain.vk_swapchain,
			pImageIndices      = &self.image_index,
		}
		present_result := vk.QueuePresentKHR(g_logical_device.vk_present_queue, &present_info)
		switch {
		case present_result == .ERROR_OUT_OF_DATE_KHR || present_result == .SUBOPTIMAL_KHR || g_window.framebuffer_resized:
			g_window.framebuffer_resized = false
			render_loop__recreate_swapchain(self)
		case present_result == .SUCCESS:
		case:
			log.panicf("vulkan: present failure: %v", present_result)
		}

		self.current_frame = (self.current_frame + 1) % basic.ODE_MAX_FRAMES_IN_FLIGHT
    }

    render_loop__record_cmd_buff :: proc(self: ^Render_Loop) {
        command_buffer := g_command_pool.vk_cmd_buffs[self.current_frame]

        begin_info := vk.CommandBufferBeginInfo {
            sType = .COMMAND_BUFFER_BEGIN_INFO,
        }
        vk_must(vk.BeginCommandBuffer(command_buffer, &begin_info))
    
        clear_color := vk.ClearValue{}
        clear_color.color.float32 = {0.0, 0.0, 0.0, 1.0}
    
        render_pass_info := vk.RenderPassBeginInfo {
            sType = .RENDER_PASS_BEGIN_INFO,
            renderPass = g_render_pass.vk_render_pass,
            framebuffer = g_framebuffers.vk_framebuffers[self.image_index],
            renderArea = {extent = g_swapchain.vk_extent2D},
            clearValueCount = 1,
            pClearValues = &clear_color,
        }
        vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)
    
        vk.CmdBindPipeline(command_buffer, .GRAPHICS, g_pipeline.vk_pipeline)
    
        viewport := vk.Viewport {
            width    = f32(g_swapchain.vk_extent2D.width),
            height   = f32(g_swapchain.vk_extent2D.height),
            maxDepth = 1.0,
        }
        vk.CmdSetViewport(command_buffer, 0, 1, &viewport)
    
        scissor := vk.Rect2D {
            extent = g_swapchain.vk_extent2D,
        }
        vk.CmdSetScissor(command_buffer, 0, 1, &scissor)
    
        vk.CmdDraw(command_buffer, 3, 1, 0, 0)
    
        vk.CmdEndRenderPass(command_buffer)
    
        vk_must(vk.EndCommandBuffer(command_buffer))
    }