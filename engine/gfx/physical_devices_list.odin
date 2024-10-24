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
// Physical_Devices_List

    Physical_Devices_List :: struct {
        count: u32,
        devices: []Physical_Device,
        primary_device: ^Physical_Device,
    }

    physical_devices_list__init :: proc(self: ^Physical_Devices_List, instance: ^Instance) {
        assert(self != nil)
        assert(instance != nil)

        vk_must(vk.EnumeratePhysicalDevices(instance.vk_instance, &self.count, nil))
        if self.count == 0 { log.panic("vulkan: no GPU found") }

        self.devices = make([]Physical_Device, self.count)

        vk_devices := make([]vk.PhysicalDevice, self.count)
        defer delete(vk_devices)

        vk_must(vk.EnumeratePhysicalDevices(instance.vk_instance, &self.count, raw_data(vk_devices)))

        device : ^Physical_Device
        for vk_device, index in vk_devices {
            device = &self.devices[index]

            physical_device__init(device, vk_device, instance)
            if self.primary_device == nil || device.score > self.primary_device.score {
                self.primary_device = device
            } 
        } 

        if (self.primary_device == nil || self.primary_device.score <= 0) {
            log.panicf("No suitable GPU found")
        }
    }

    physical_devices_list__terminate :: proc(self: ^Physical_Devices_List) {
        assert(self != nil)
        assert(self.devices != nil)

        for &device in self.devices {
            physical_device__terminate(&device)
        }

        delete(self.devices)
    }