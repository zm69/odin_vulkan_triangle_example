package engine_gfx

// Base
    import "base:runtime"

// Core
    import "core:log"
    import "core:slice"
    import "core:strings"

// Vendor
    import "vendor:glfw"
    import vk "vendor:vulkan"

// ODE
    import "../basic"

///////////////////////////////////////////////////////////////////////////////
// Command_Pool

    Command_Pool :: struct {
        logical_device: ^Logical_Device,
        vk_cmd_pool_create_info: vk.CommandPoolCreateInfo,
        vk_cmd_pool: vk.CommandPool,
        vk_cmd_buff_alloc_info: vk.CommandBufferAllocateInfo,
        vk_cmd_buffs_count: u32, 
        vk_cmd_buffs: []vk.CommandBuffer,
    }

    command_pool__init :: proc(self: ^Command_Pool, physical_device: ^Physical_Device, logical_device: ^Logical_Device, cmd_buffs_count: u32) {
        assert(self != nil)
        assert(logical_device != nil)
        assert(cmd_buffs_count > 0)
        
        self.logical_device = logical_device

        self.vk_cmd_pool_create_info = vk.CommandPoolCreateInfo {
            sType            = .COMMAND_POOL_CREATE_INFO,
            flags            = {.RESET_COMMAND_BUFFER},
            queueFamilyIndex = physical_device.vk_graphics_family_queue_ix,
        }
        vk_must(vk.CreateCommandPool(logical_device.vk_device, &self.vk_cmd_pool_create_info, nil, &self.vk_cmd_pool))

        self.vk_cmd_buffs = make([]vk.CommandBuffer, cmd_buffs_count)

        self.vk_cmd_buff_alloc_info = vk.CommandBufferAllocateInfo {
            sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool        = self.vk_cmd_pool,
            level              = .PRIMARY,
            commandBufferCount = cmd_buffs_count,
        }
        vk_must(vk.AllocateCommandBuffers(logical_device.vk_device, &self.vk_cmd_buff_alloc_info, &self.vk_cmd_buffs[0]))
    }

    command_pool__terminate :: proc(self: ^Command_Pool) {
        assert(self != nil)
        assert(self.logical_device != nil)

        if self.vk_cmd_buffs != nil {
            delete(self.vk_cmd_buffs)
            self.vk_cmd_buffs = nil
            self.vk_cmd_buffs_count = 0
        }

        vk.DestroyCommandPool(self.logical_device.vk_device, self.vk_cmd_pool, nil)
    }