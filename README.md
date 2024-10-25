# odin_vulkan_triangle_example
The Vulkan "hello world" (triangle) example is divided into parts for learning purposes.

It was tested on Windows only. It might work on other OSes too.

## How to understand the code

Start from main.odin file. The code there is very simple. It uses the code from the /engine folder. The source code in the /engine folder is divided into parts for easier learning and understanding.
In a real engine, the code organization would be different.

## How to run the code 

1. Go to the shaders folder and run compile.bat (or commands inside it) to compile shaders
```
    compile.bat
```
3. Go back to the main folder and run:
```
    odin run .
```

## Result should be this:

![alt text](https://github.com/zm69/odin_vulkan_triangle_example/blob/main/example.png?raw=true)

## Useful Links

| Description      | Link     |
| ------------- | ------------- |
| All sources in one gist by laytan | https://gist.github.com/laytan/ba57af3e5a59ab5cb2fca9e25bcfe262 | 
| Understanding Vulkan objects | https://gpuopen.com/learn/understanding-vulkan-objects/ |
| vkguide.dev tutorial | https://vkguide.dev/ |
| Vulkan samples | https://github.com/KhronosGroup/Vulkan-Samples?tab=readme-ov-file |



