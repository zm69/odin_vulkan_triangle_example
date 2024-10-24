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
// Pipeline

    Pipeline :: struct {
        logical_device: ^Logical_Device,
        vk_pipeline_layout_create_info: vk.PipelineLayoutCreateInfo,
        vk_layout: vk.PipelineLayout,
        vk_pipeline_create_info: vk.GraphicsPipelineCreateInfo,
        vk_pipeline: vk.Pipeline,
    }

    pipeline__init :: proc(self: ^Pipeline, logical_device: ^Logical_Device, shaders: ^Shaders, render_pass: ^Render_Pass) {
        assert(self != nil)
        assert(logical_device != nil)
        assert(shaders != nil)

        self.logical_device = logical_device

        self.vk_pipeline_layout_create_info = vk.PipelineLayoutCreateInfo {
			sType = .PIPELINE_LAYOUT_CREATE_INFO,
		}
		vk_must(vk.CreatePipelineLayout(logical_device.vk_device, &self.vk_pipeline_layout_create_info, nil, &self.vk_layout))

		dynamic_states := []vk.DynamicState{.VIEWPORT, .SCISSOR}
		dynamic_state := vk.PipelineDynamicStateCreateInfo {
			sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
			dynamicStateCount = 2,
			pDynamicStates    = raw_data(dynamic_states),
		}

		vertex_input_info := vk.PipelineVertexInputStateCreateInfo {
			sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		}

		input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
			sType    = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
			topology = .TRIANGLE_LIST,
		}

		viewport_state := vk.PipelineViewportStateCreateInfo {
			sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
			viewportCount = 1,
			scissorCount  = 1,
		}

		rasterizer := vk.PipelineRasterizationStateCreateInfo {
			sType       = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
			polygonMode = .FILL,
			lineWidth   = 1,
			cullMode    = {.BACK},
			frontFace   = .CLOCKWISE,
		}

		multisampling := vk.PipelineMultisampleStateCreateInfo {
			sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
			rasterizationSamples = {._1},
			minSampleShading     = 1,
		}

		color_blend_attachment := vk.PipelineColorBlendAttachmentState {
			colorWriteMask = {.R, .G, .B, .A},
		}

		color_blending := vk.PipelineColorBlendStateCreateInfo {
			sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			attachmentCount = 1,
			pAttachments    = &color_blend_attachment,
		}

		self.vk_pipeline_create_info = vk.GraphicsPipelineCreateInfo {
			sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
			stageCount          = 2,
			pStages             = &shaders.vk_stages[0],
			pVertexInputState   = &vertex_input_info,
			pInputAssemblyState = &input_assembly,
			pViewportState      = &viewport_state,
			pRasterizationState = &rasterizer,
			pMultisampleState   = &multisampling,
			pColorBlendState    = &color_blending,
			pDynamicState       = &dynamic_state,
			layout              = self.vk_layout,
			renderPass          = render_pass.vk_render_pass,
			subpass             = 0,
			basePipelineIndex   = -1,
		}
		vk_must(vk.CreateGraphicsPipelines(logical_device.vk_device, 0, 1, &self.vk_pipeline_create_info, nil, &self.vk_pipeline))
    }

    pipeline__terminate :: proc(self: ^Pipeline) {
        assert(self != nil)
        assert(self.logical_device != nil)

        vk.DestroyPipelineLayout(self.logical_device.vk_device, self.vk_layout, nil)
        vk.DestroyPipeline(self.logical_device.vk_device, self.vk_pipeline, nil)
    }

	pipeline__is_initialized :: proc(self: ^Pipeline) -> bool {
		if self.logical_device == nil {
			return false
		}

		return true
	}


    
