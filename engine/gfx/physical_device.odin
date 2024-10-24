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

///////////////////////////////////////////////////////////////////////////////
// Physical_Device

    // Collected data about physical device
    Physical_Device :: struct {
        vk_device: vk.PhysicalDevice,
        vk_properties: vk.PhysicalDeviceProperties,        
        vk_features: vk.PhysicalDeviceFeatures,                 // struct of bools
        score: int,                                             // how we scored device

        vk_extensions_count: u32,
        vk_extensions: []vk.ExtensionProperties, 

        vk_surface_capabilities_count: u32,
        vk_surface_capabilities: vk.SurfaceCapabilitiesKHR,
        
        vk_surface_formats_count: u32,
        vk_surface_formats: []vk.SurfaceFormatKHR,

        vk_present_modes_count: u32,
        vk_present_modes: []vk.PresentModeKHR,

        vk_queue_family_properties_count: u32,
        vk_queue_family_properties: []vk.QueueFamilyProperties,

        vk_graphics_family_queue_ix: u32,
        vk_graphics_family_properties: ^vk.QueueFamilyProperties,

        vk_present_family_queue_ix: u32,
        vk_present_family_properties: ^vk.QueueFamilyProperties,
    }

    // Initialize and score physical device
    physical_device__init :: proc(self: ^Physical_Device, vk_device: vk.PhysicalDevice, instance: ^Instance) -> (result: vk.Result) {
        assert(self != nil)
        assert(vk_device != nil)
        assert(instance != nil)

        self.score = -1 
        self.vk_device = vk_device

        //
        // Get physical device properties
        //

            vk.GetPhysicalDeviceProperties(self.vk_device, &self.vk_properties)

            name := byte_arr_to_str(&self.vk_properties.deviceName)
            log.infof("vulkan: evaluating device %q", name)
            defer log.infof("vulkan: device %q scored %v", name, self.score)

        //
        //  Check for required feautures
        //

            // pFeatures is a pointer to a VkPhysicalDeviceFeatures structure in which the physical device features 
            // are returned. For each feature, a value of VK_TRUE specifies that the feature is supported 
            // on this physical device, and VK_FALSE specifies that the feature is not supported.
            // VkPhysicalDeviceFeatures is just stucture of booleans
            vk.GetPhysicalDeviceFeatures(self.vk_device, &self.vk_features)

            // App can't function without geometry shaders.
            if !self.vk_features.geometryShader {
                log.info("vulkan: device does not support geometry shaders")
                return vk.Result.ERROR_FEATURE_NOT_PRESENT
            }

        //
        // Check extensions support
        // 

            vk_log_info(vk.EnumerateDeviceExtensionProperties(self.vk_device, nil, &self.vk_extensions_count, nil),
            "vulkan: enumerate device extension properties failed: %v") or_return

            self.vk_extensions = make([]vk.ExtensionProperties, self.vk_extensions_count)
            vk_log_info(vk.EnumerateDeviceExtensionProperties(self.vk_device, nil, &self.vk_extensions_count, raw_data(self.vk_extensions)), 
                "vulkan: enumerate device extension properties failed: %v") or_return

            required_loop: for required in ODE_REQUIRED_DEVICE_EXTENSIONS {
                for &extension in self.vk_extensions {
                    name := byte_arr_to_str(&extension.extensionName)
                    if name == string(required) {
                        continue required_loop
                    }
                }

                log.infof("vulkan: device does not support required extension %q", required)
                return vk.Result.ERROR_FEATURE_NOT_PRESENT
            }

        // 
        // Query swapchain support 
        //
            physical_device__query_swapchain_support(self, instance) or_return
        
        //
        // Get queue family properties
        //

            // if count == 0, then pQueueFamilyProperties parameter can be nil 
            // If pQueueFamilyProperties is NULL, then the number of queue families available is returned in pQueueFamilyPropertyCount.
            // https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/vkGetPhysicalDeviceQueueFamilyProperties.html
            vk.GetPhysicalDeviceQueueFamilyProperties(self.vk_device, &self.vk_queue_family_properties_count, nil)
        
            // now use count to create array
            self.vk_queue_family_properties = make([]vk.QueueFamilyProperties, self.vk_queue_family_properties_count)
            
            // returns [^]QueueFamilyProperties
            vk.GetPhysicalDeviceQueueFamilyProperties(self.vk_device, &self.vk_queue_family_properties_count, raw_data(self.vk_queue_family_properties))
        
            supported: b32 =  false
            for &family, i in self.vk_queue_family_properties {

                // Possible flags:
                // GRAPHICS         = 0,
                // COMPUTE          = 1,
                // TRANSFER         = 2,
                // SPARSE_BINDING   = 3,
                // PROTECTED        = 4,
                // VIDEO_DECODE_KHR = 5,
                // VIDEO_ENCODE_KHR = 6,
                // OPTICAL_FLOW_NV  = 8,

                if .GRAPHICS in family.queueFlags {
                    self.vk_graphics_family_queue_ix = u32(i)
                    self.vk_graphics_family_properties = &family
                }

                // To determine whether a queue family of a physical device supports presentation to a given surface
                // https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/vkGetPhysicalDeviceSurfaceSupportKHR.html
                vk.GetPhysicalDeviceSurfaceSupportKHR(self.vk_device, u32(i), instance.vk_surface, &supported)
                if supported {
                    self.vk_present_family_queue_ix = u32(i)
                    self.vk_present_family_properties = &family
                }

                if self.vk_graphics_family_properties != nil && self.vk_present_family_properties != nil {
                    break
                }
            }

            //log.warn("vk_graphics_family_queue_ix = %v, self.vk_present_family_queue_ix = %v", self.vk_graphics_family_queue_ix, self.vk_present_family_queue_ix)

            if self.vk_graphics_family_properties == nil || self.vk_present_family_properties == nil {
                vk_log_info(vk.Result.ERROR_FEATURE_NOT_PRESENT, 
                    "vulkan: device does not support graphics queue and presentation queue for provided surface") or_return
            }

        //
        // Device type scores
        //

            // Favor GPUs.
            switch self.vk_properties.deviceType {
            case .DISCRETE_GPU:
                self.score += 300_000
            case .INTEGRATED_GPU:
                self.score += 200_000
            case .VIRTUAL_GPU:
                self.score += 100_000
            case .CPU, .OTHER:
            }
            log.infof("vulkan: scored %i based on device type %v", self.score, self.vk_properties.deviceType)

        //
        // GPU that supports higher image dimensions is preferable
        //
            // Maximum texture size.
            self.score += int(self.vk_properties.limits.maxImageDimension2D)
            log.infof(
                "vulkan: added the max 2D image dimensions (texture size) of %v to the score",
                self.vk_properties.limits.maxImageDimension2D,
            )

        return vk.Result.SUCCESS
    }

    physical_device__terminate :: proc(self: ^Physical_Device) {
        assert(self != nil)

        if self.vk_queue_family_properties != nil {
            delete(self.vk_queue_family_properties)
            self.vk_queue_family_properties = nil
            self.vk_queue_family_properties_count = 0
        }

        physical_device__free_swapchain_support_data(self)

        if self.vk_extensions != nil {
            delete(self.vk_extensions)
            self.vk_extensions = nil
            self.vk_extensions_count = 0
        }
    }

    @(private="file")
    physical_device__free_swapchain_support_data :: proc(self: ^Physical_Device) {
        assert(self != nil)

        if self.vk_present_modes != nil {
            delete(self.vk_present_modes)
            self.vk_present_modes = nil
            self.vk_present_modes_count = 0
        }

        if self.vk_surface_formats != nil {
            delete(self.vk_surface_formats)
            self.vk_surface_formats = nil
            self.vk_surface_formats_count = 0
        }
    }

    physical_device__query_swapchain_support :: proc(self: ^Physical_Device, instance: ^Instance) -> (result: vk.Result) {
        assert(self != nil)
        assert(instance != nil)

        physical_device__free_swapchain_support_data(self)

        vk_log_info(vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
            self.vk_device, instance.vk_surface, &self.vk_surface_capabilities), 
            "vulkan: GetPhysicalDeviceSurfaceCapabilitiesKHR %v") or_return
    
        vk_log_info(
            vk.GetPhysicalDeviceSurfaceFormatsKHR(self.vk_device, instance.vk_surface, &self.vk_surface_formats_count, nil),
            "GetPhysicalDeviceSurfaceFormatsKHR count %v") or_return

        self.vk_surface_formats = make([]vk.SurfaceFormatKHR, self.vk_surface_formats_count)

        vk_log_info(
            vk.GetPhysicalDeviceSurfaceFormatsKHR(self.vk_device, instance.vk_surface, &self.vk_surface_formats_count, raw_data(self.vk_surface_formats)),
            "GetPhysicalDeviceSurfaceFormatsKHR %v") or_return

        vk_log_info(
            vk.GetPhysicalDeviceSurfacePresentModesKHR(self.vk_device, instance.vk_surface, &self.vk_present_modes_count, nil),
            "GetPhysicalDeviceSurfacePresentModesKHR conut %v") or_return

        self.vk_present_modes = make([]vk.PresentModeKHR, self.vk_present_modes_count)

        vk_log_info(
            vk.GetPhysicalDeviceSurfacePresentModesKHR(self.vk_device, instance.vk_surface, &self.vk_present_modes_count, raw_data(self.vk_present_modes)),
            "GetPhysicalDeviceSurfacePresentModesKHR %v") or_return

        return vk.Result.SUCCESS
    }
