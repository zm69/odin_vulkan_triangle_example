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
// Instance 

    Instance :: struct {
        enabled_layer_names: []cstring,
        vk_instance_create_info: vk.InstanceCreateInfo,
        vk_instance: vk.Instance,
        extensions: [dynamic]cstring,   
        init_context: runtime.Context,

        debug_messenger: vk.DebugUtilsMessengerEXT,
        debug_messenger_callback: proc "system" (
                    messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
                    messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
                    pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
                    pUserData: rawptr,
                ) -> b32 , 

        vk_surface: vk.SurfaceKHR,
    } 

    instance__init :: proc(self: ^Instance, window: ^Window) {
        assert(self != nil)
        assert(window != nil)
        assert(self.debug_messenger_callback != nil)

        self.init_context = context

        //
        // Load global vk procs.
        // 
            instance_proc_addr := rawptr(glfw.GetInstanceProcAddress)
            if instance_proc_addr == nil {
                log.panicf("glfw.GetInstanceProcAddress is nil, %s %d", glfw.GetError())
            }

            vk.load_proc_addresses_global(instance_proc_addr)
            assert(vk.CreateInstance != nil, "vulkan function pointers not loaded")

        //
        // TODO: set up Vulkan allocator.
        //

        //
        // Create Vulkan Instance
        //
            self.vk_instance_create_info = vk.InstanceCreateInfo {
                sType            = .INSTANCE_CREATE_INFO,
                pApplicationInfo = &vk.ApplicationInfo {
                    sType = .APPLICATION_INFO,
                    pApplicationName = window.title,
                    applicationVersion = vk.MAKE_VERSION(
                        window.app_version_major, 
                        window.app_version_minor, 
                        window.app_version_patch
                    ),
                    pEngineName = "ODE",
                    engineVersion = vk.MAKE_VERSION(
                        basic.ODE_VERSION_MAJOR, 
                        basic.ODE_VERSION_MINOR, 
                        basic.ODE_VERSION_PATCH
                    ),
                    apiVersion = vk.API_VERSION_1_0,
                },
            }

            self.extensions = slice.clone_to_dynamic(glfw.GetRequiredInstanceExtensions(), context.temp_allocator)

            // MacOS is a special snowflake 
            when ODIN_OS == .Darwin {
                self.vk_instance_create_info.flags |= {.ENUMERATE_PORTABILITY_KHR}
                append(&self.extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
            }

            when basic.ODE_VALIDATION_LAYERS {

                self.enabled_layer_names = make([]cstring, 1)
                self.enabled_layer_names[0] = "VK_LAYER_KHRONOS_validation"

                self.vk_instance_create_info.ppEnabledLayerNames = raw_data(self.enabled_layer_names)
                self.vk_instance_create_info.enabledLayerCount = 1
        
                append(&self.extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
        
                // Severity based on logger level.
                severity: vk.DebugUtilsMessageSeverityFlagsEXT
                if context.logger.lowest_level <= .Error {
                    severity |= {.ERROR}
                }
                if context.logger.lowest_level <= .Warning {
                    severity |= {.WARNING}
                }
                if context.logger.lowest_level <= .Info {
                    severity |= {.INFO}
                }
                if context.logger.lowest_level <= .Debug {
                    severity |= {.VERBOSE}
                }
        
                dbg_create_info := vk.DebugUtilsMessengerCreateInfoEXT {
                    sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                    messageSeverity = severity,
                    messageType     = {.GENERAL, .VALIDATION, .PERFORMANCE, .DEVICE_ADDRESS_BINDING}, // all of them.
                    pfnUserCallback = self.debug_messenger_callback,
                }
                self.vk_instance_create_info.pNext = &dbg_create_info
            }

            self.vk_instance_create_info.enabledExtensionCount = u32(len(self.extensions))
            self.vk_instance_create_info.ppEnabledExtensionNames = raw_data(self.extensions)

            vk_must(vk.CreateInstance(&self.vk_instance_create_info, nil, &self.vk_instance))

        //
        // Load instance VK procedures adresses 
        //

            vk.load_proc_addresses_instance(self.vk_instance)

        //
        // Create debug utils messeger
        // 

            when basic.ODE_VALIDATION_LAYERS {
                vk_must(vk.CreateDebugUtilsMessengerEXT(self.vk_instance, &dbg_create_info, nil, &self.debug_messenger))
            }

        //
        // GLFW create surface for Vulcan instance and window
        //

            vk_must(glfw.CreateWindowSurface(self.vk_instance, window.handle, nil, &self.vk_surface))
    }

    instance__terminate :: proc(self: ^Instance) {
        assert(self != nil)

        vk.DestroySurfaceKHR(self.vk_instance, self.vk_surface, nil)

        when basic.ODE_VALIDATION_LAYERS {
            vk.DestroyDebugUtilsMessengerEXT(self.vk_instance, self.debug_messenger, nil)
        }

        vk.DestroyInstance(self.vk_instance, nil)

        if self.enabled_layer_names != nil {
            delete(self.enabled_layer_names)
        } 
    }