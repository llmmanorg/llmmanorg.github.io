+++
title = "GPU acceleration for Adreno on Windows on ARM"
description = "llama.cpp's only prebuilt GPU binary for Windows on ARM is an OpenCL one, not Vulkan. llmman now probes for it, so machines having it stop silently falling back to CPU."
date = 2026-09-27

[taxonomies]
tags = ["serve", "hostgpu", "windows-arm"]
+++

`llmman serve --runtime bin` probes the host for a GPU and downloads the matching prebuilt `llama-server` from llama.cpp's own releases. On Windows on ARM, that probe ended up not working as llama.cpp ships no arm64 Vulkan binary, so an Adreno-equipped laptop always got the CPU build, with no indication anything had been skipped. [#516](https://github.com/llmmanorg/llmman/pull/516) adds the backend llama.cpp actually publishes for that combination, OpenCL.

<!-- more -->

## Where OpenCL is picked

Detection is a fixed priority order, and OpenCL now sits between ROCm and Vulkan in it:

```
CUDA > ROCm > OpenCL > Vulkan > CPU        (Linux/Windows)
Metal > CPU                                (macOS)
```

In practice that slot only ever gets used on Windows arm64. The probe loads `OpenCL.dll`, walks every platform's GPU devices with `clGetPlatformIDs`/`clGetDeviceIDs`, and keeps only the ones whose `clGetDeviceInfo` name contains "adreno". llama.cpp's OpenCL release is built for that GPU family specifically, so a match on anything else would just point at a binary that doesn't run there. It reports total VRAM the same way the CUDA and ROCm probes already did, summed across devices if there's more than one.

`LLMMAN_LLM_LIBRARY=opencl` forces it, same as the other backends.

## Why not Vulkan

Adreno GPUs can run Vulkan, and llmman's asset picker still prefers it where it's available but "available" means llama.cpp publishes a `-bin-win-vulkan-<arch>.zip`, and it only does that for `x64`. OpenCL is the backend llama.cpp actually ships for `win-opencl-adreno-arm64`, so that's the asset llmman now downloads on that combination, picked ahead of the Vulkan check for exactly that reason.

Details are in [docs/backends.md](https://github.com/llmmanorg/llmman/blob/main/docs/backends.md#llamacpp) and [docs/configuration.md](https://github.com/llmmanorg/llmman/blob/main/docs/configuration.md).
