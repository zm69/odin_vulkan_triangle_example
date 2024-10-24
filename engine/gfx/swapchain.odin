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
// Swap_Chain

    Swapchain :: struct {
        logical_device: ^Logical_Device,

        vk_surface_format: vk.SurfaceFormatKHR,
        vk_present_mode: vk.PresentModeKHR,
        vk_extent2D: vk.Extent2D,
        image_count: u32,
        vk_swapchain_create_info: vk.SwapchainCreateInfoKHR,

        vk_swapchain: vk.SwapchainKHR,
        vk_images: []vk.Image,
        vk_views: []vk.ImageView,
    }

    swapchain__init :: proc(self: ^Swapchain, window: ^Window, instance: ^Instance, physical_device: ^Physical_Device, logical_device: ^Logical_Device) {
        assert(self != nil)
        assert(window != nil)
        assert(instance != nil)
        assert(physical_device != nil)
        assert(logical_device != nil)

        self.logical_device = logical_device

        //
        // Choose surface format
        //

            // Default, first one, not optimal
            self.vk_surface_format = physical_device.vk_surface_formats[0]
            for format in physical_device.vk_surface_formats {
                if format.format == vk.Format.B8G8R8A8_SRGB && format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
                    self.vk_surface_format = format
                    break
                }
            }

        //
        // Choose present mode
        //
            // Default is FIFO
            self.vk_present_mode = vk.PresentModeKHR.FIFO
            // But check if device supports .MAILBOX for the best tradeoff between tearing and latency
            for mode in physical_device.vk_present_modes {
                if mode ==  vk.PresentModeKHR.MAILBOX {
                    self.vk_present_mode = mode
                    break
                }
            }

        //
        // Choose extent
        //
            if physical_device.vk_surface_capabilities.currentExtent.width != max(u32) {
                self.vk_extent2D = physical_device.vk_surface_capabilities.currentExtent
            } else {
                width, height := glfw.GetFramebufferSize(window.handle)
                self.vk_extent2D = vk.Extent2D {
                    width = clamp(u32(width), physical_device.vk_surface_capabilities.minImageExtent.width, physical_device.vk_surface_capabilities.maxImageExtent.width),
                    height = clamp(u32(height), physical_device.vk_surface_capabilities.minImageExtent.height, physical_device.vk_surface_capabilities.maxImageExtent.height),
                }
            }

        //
        // Image count
        //

            self.image_count = physical_device.vk_surface_capabilities.minImageCount + 1
            if physical_device.vk_surface_capabilities.maxImageCount > 0 && self.image_count > physical_device.vk_surface_capabilities.maxImageCount {
                self.image_count = physical_device.vk_surface_capabilities.maxImageCount
            }

        //
        // Create swapchain
        //

            self.vk_swapchain_create_info = vk.SwapchainCreateInfoKHR {
                sType            = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR,
                surface          = instance.vk_surface,
                minImageCount    = self.image_count,
                imageFormat      = self.vk_surface_format.format,
                imageColorSpace  = self.vk_surface_format.colorSpace,
                imageExtent      = self.vk_extent2D,
                imageArrayLayers = 1,
                imageUsage       = {.COLOR_ATTACHMENT},
                preTransform     = physical_device.vk_surface_capabilities.currentTransform,
                compositeAlpha   = {.OPAQUE},
                presentMode      = self.vk_present_mode,
                clipped          = true,
            }

            if physical_device.vk_graphics_family_queue_ix != physical_device.vk_present_family_queue_ix {
                self.vk_swapchain_create_info.imageSharingMode = .CONCURRENT
                self.vk_swapchain_create_info.queueFamilyIndexCount = 2
                self.vk_swapchain_create_info.pQueueFamilyIndices = raw_data([]u32{
                    physical_device.vk_graphics_family_queue_ix, 
                    physical_device.vk_present_family_queue_ix, 
                })
            }

            vk_must(vk.CreateSwapchainKHR(logical_device.vk_device, &self.vk_swapchain_create_info, nil, &self.vk_swapchain))
    
        //
        // Setup swapchain images
        //
            count: u32
            vk_must(vk.GetSwapchainImagesKHR(logical_device.vk_device, self.vk_swapchain, &count, nil))

            if count != self.image_count {
                log.warn("swapchain count != self.image_count", count, self.image_count) 
                self.image_count = count
            }
                          
            self.vk_images = make([]vk.Image, self.image_count)
            self.vk_views = make([]vk.ImageView, self.image_count)

            vk_must(vk.GetSwapchainImagesKHR(logical_device.vk_device, self.vk_swapchain, &count, raw_data(self.vk_images)))

            for image, i in self.vk_images {
                create_info := vk.ImageViewCreateInfo {
                    sType = .IMAGE_VIEW_CREATE_INFO,
                    image = image,
                    viewType = .D2,
                    format = self.vk_surface_format.format,
                    subresourceRange = {aspectMask = {.COLOR}, levelCount = 1, layerCount = 1},
                }

                vk_must(vk.CreateImageView(logical_device.vk_device, &create_info, nil, &self.vk_views[i]))
            }
    }

    swapchain__terminate :: proc(self: ^Swapchain) {
        assert(self != nil)

        for view in self.vk_views {
            vk.DestroyImageView(self.logical_device.vk_device, view, nil)
        }

        if self.vk_images != nil {
            delete(self.vk_images)
            self.vk_images = nil
        }
        
        if self.vk_views != nil {
            delete(self.vk_views)
            self.vk_views = nil
        }
        
        vk.DestroySwapchainKHR(self.logical_device.vk_device, self.vk_swapchain, nil)
    }