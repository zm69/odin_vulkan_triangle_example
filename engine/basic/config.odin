package ode_basic

///////////////////////////////////////////////////////////////////////////////
// Types

    ODE_DEBUG :: #config(ODE_DEBUG, ODIN_DEBUG)
    
    ODE_MAX_FRAMES_IN_FLIGHT :: 2

    // Enables Vulkan debug logging and validation layers.
    ODE_VALIDATION_LAYERS :: #config(ODE_VALIDATION_LAYERS, ODE_DEBUG)