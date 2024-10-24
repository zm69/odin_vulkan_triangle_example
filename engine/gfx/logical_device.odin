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
// Logical_Device

    Logical_Device :: struct {
        vk_queue_create_infos: [dynamic]vk.DeviceQueueCreateInfo,
        vk_device_create_info: vk.DeviceCreateInfo,
        vk_device: vk.Device,

        vk_graphics_queue: vk.Queue,
        vk_present_queue: vk.Queue,
    }

    logical_device__init :: proc(self: ^Logical_Device, instance: ^Instance, physical_device: ^Physical_Device) {
        assert(self != nil)
        assert(physical_device != nil)

        self.vk_queue_create_infos = make([dynamic]vk.DeviceQueueCreateInfo, 0, 2)
		
        append(
            &self.vk_queue_create_infos,
            vk.DeviceQueueCreateInfo {
                sType = .DEVICE_QUEUE_CREATE_INFO,
                queueFamilyIndex = physical_device.vk_graphics_family_queue_ix,
                queueCount = 1,
                pQueuePriorities = raw_data([]f32{1}),
            },// Scheduling priority between 0 and 1.
        )

        if physical_device.vk_graphics_family_queue_ix != physical_device.vk_present_family_queue_ix {
            append(
                &self.vk_queue_create_infos,
                vk.DeviceQueueCreateInfo {
                    sType = .DEVICE_QUEUE_CREATE_INFO,
                    queueFamilyIndex = physical_device.vk_present_family_queue_ix,
                    queueCount = 1,
                    pQueuePriorities = raw_data([]f32{1}),
                },// Scheduling priority between 0 and 1.
            ) 
        }

        ttt:= raw_data([]cstring{"VK_LAYER_KHRONOS_validation"})

		self.vk_device_create_info = vk.DeviceCreateInfo {
			sType                   = .DEVICE_CREATE_INFO,
			pQueueCreateInfos       = raw_data(self.vk_queue_create_infos),
			queueCreateInfoCount    = u32(len(self.vk_queue_create_infos)),
			enabledLayerCount       = instance.vk_instance_create_info.enabledLayerCount,
			ppEnabledLayerNames     = instance.vk_instance_create_info.ppEnabledLayerNames,
			ppEnabledExtensionNames = raw_data(ODE_REQUIRED_DEVICE_EXTENSIONS),
			enabledExtensionCount   = u32(len(ODE_REQUIRED_DEVICE_EXTENSIONS)),
		}

		vk_must(vk.CreateDevice(physical_device.vk_device, &self.vk_device_create_info, nil, &self.vk_device))

        vk.GetDeviceQueue(self.vk_device, physical_device.vk_graphics_family_queue_ix, 0, &self.vk_graphics_queue)
		vk.GetDeviceQueue(self.vk_device, physical_device.vk_graphics_family_queue_ix, 0, &self.vk_present_queue)
    }

    logical_device__terminate :: proc(self: ^Logical_Device) {
        assert(self != nil)

        if self.vk_queue_create_infos != nil {
            delete(self.vk_queue_create_infos)
        }

        if self.vk_device != nil {
            vk.DestroyDevice(self.vk_device, nil)
        }
    }

    logical_device__wait_idle :: proc(self: ^Logical_Device) {
        vk.DeviceWaitIdle(self.vk_device)
    }