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
// Shaders

    Shaders :: struct {
        logical_device: ^Logical_Device,
        vk_modules: [dynamic]vk.ShaderModule,
        vk_stages: [dynamic]vk.PipelineShaderStageCreateInfo,
    }

    shaders__init :: proc(self: ^Shaders, logical_device: ^Logical_Device) {
        assert(self != nil)
        assert(logical_device != nil)

        self.logical_device = logical_device

        self.vk_modules = make([dynamic]vk.ShaderModule, 0, 2)
        self.vk_stages = make([dynamic]vk.PipelineShaderStageCreateInfo, 0, 2)
    }

    shaders__terminate :: proc(self: ^Shaders) {
        assert(self != nil)

        if self.vk_modules != nil {
            for module in self.vk_modules {
                vk.DestroyShaderModule(self.logical_device.vk_device, module, nil)
            }

            delete(self.vk_modules)
            self.vk_modules = nil
        }

        if self.vk_stages != nil {
            delete(self.vk_stages)
            self.vk_stages = nil
        }
    }

    shaders__is_initialized :: proc(self: ^Shaders) -> bool {
        assert(self != nil)

        if self.vk_modules == nil || self.vk_stages == nil {
            return false
        }

        return true
    }

    shaders__append :: proc(self: ^Shaders, code: []byte, stage: vk.ShaderStageFlags, pipe_name: cstring) {
        assert(shaders__is_initialized(self))

        as_u32 := slice.reinterpret([]u32, code)

        create_info := vk.ShaderModuleCreateInfo {
            sType    = .SHADER_MODULE_CREATE_INFO,
            codeSize = len(code),
            pCode    = raw_data(as_u32),
        }

        module: vk.ShaderModule
        vk_must(vk.CreateShaderModule(self.logical_device.vk_device, &create_info, nil, &module))
        append(&self.vk_modules, module)

        shader_stage := vk.PipelineShaderStageCreateInfo {
			sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage  = stage,
			module = module,
			pName  = pipe_name,
		}
        append(&self.vk_stages, shader_stage)
    }

