+++
title = "Pass extra flags to llama-server with LLMMAN_LLAMA_ARGS"
description = "Pass any llama-server flag through llmman with one variable, LLMMAN_LLAMA_ARGS, whether llama-server runs on your machine or in a container."
date = 2026-11-02

[taxonomies]
tags = ["serve", "llama.cpp", "configuration"]
+++

When `llmman serve` loads a GGUF model, by default it starts `llama-server` from llama.cpp with flags based on your settings: context size, parallel slots, KV-cache type, among others. But `llama-server` has far more options than that, and to use the rest, you put them in `LLMMAN_LLAMA_ARGS`.

<!-- more -->

Say you're running an agent against a local model. Every request resends the same long prompt (the system prompt, the tool definitions and the conversation so far). `llama-server` has flags that control how it reuses what it has already processed, such as `--slot-prompt-similarity` and `--cache-ram`. But `llmman` starts `llama-server` for you, so you can't add those flags to its command line yourself. `LLMMAN_LLAMA_ARGS` lets you add them anyway.

## Extra flags for each engine

`llmman` runs models with several inference engines: `llama-server`, vLLM, SGLang and ds4. Each one has its own variable for passing extra flags: `LLMMAN_LLAMA_ARGS` for `llama-server`, `LLMMAN_VLLM_ARGS` for vLLM, `LLMMAN_SGLANG_ARGS` for SGLang and `LLMMAN_DS4_ARGS` for ds4. With `LLMMAN_LLAMA_ARGS`, you can use any `llama-server` flag on your own workload without waiting for `llmman` to add a dedicated setting for it.

## The variable

```sh
LLMMAN_LLAMA_ARGS="--slot-prompt-similarity 0.5 --cache-ram 16384" llmman serve
```

This starts the daemon with `LLMMAN_LLAMA_ARGS` set. Every `llama-server` it launches from then on gets those two flags appended to its command line: `--slot-prompt-similarity` sets how closely a new prompt must match a slot's cached one for that slot to be reused, and `--cache-ram` sets the size of the prompt cache in RAM, in MiB.

> If `llmman serve` is already running, restart it to pick up a new value.

Those two are only examples. Any flag `llama-server` accepts works here, except the few covered under [What it refuses, and what to avoid](#what-it-refuses-and-what-to-avoid). For the full list, see the [llama-server parameters](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md#common-params) or run `llama-server --help`.

## How llmman applies LLMMAN_LLAMA_ARGS

Set `LLMMAN_LLAMA_ARGS` once and every `llama-server` that `llmman` starts gets the same flags, however and wherever it runs:

- **Local or in a container:** it doesn't matter whether `llama-server` runs as a local binary or from the `ghcr.io/ggml-org/llama.cpp` image under `--runtime docker` or `podman`. Both get exactly the same arguments. The one catch is file paths; see [Paths in a container](#paths-in-a-container).
- **Quoted like the others:** the value is split the same way `LLMMAN_VLLM_ARGS` is, so a quoted argument can hold a space. Put the quotes around the value, not the whole flag: `--flag 'a b'`, not `--flag='a b'`.
- **Works under `launch` too:** when `llmman launch` starts the daemon for you, the daemon inherits your environment, so a [`llmman launch dsh`](@/blog/launch-dsh.md) session served by a local GGUF picks up the variable as well.

## What it refuses, and what to avoid

A few mistakes are caught when `llmman serve` starts, so they never show up as a failed load later:

- **An unclosed quote** stops the daemon, with an error that names the variable but not its value.
- **`--port` or `--host`** also stop it. `llmman` sets both itself, and a second copy would only conflict.

Some flags already have their own `llmman` variable, so set them there. For instance, set context size (`--ctx-size`) with `LLMMAN_CONTEXT_LENGTH`, parallel slots (`--parallel`) with `LLMMAN_NUM_PARALLEL`, and so on. `llmman` already passes these flags to `llama-server`, so if you add one to `LLMMAN_LLAMA_ARGS` as well, `llama-server` receives it twice and logs a warning that it was specified more than once.

## Paths in a container

Flags such as `--chat-template-file` take a file path. `llmman` passes the path through unchanged, and `llama-server` opens the file itself, so whether the path works depends on where `llama-server` runs:

- **Local binary:** `llama-server` runs on your machine, so any path on your machine works.
- **Container:** `llama-server` can only see files inside the container, and `llmman` mounts just two directories into it: the model's, at `/models`, and the multimodal projector's, at `/mmproj`. A path like `/home/you/template.jinja` doesn't exist there, so `llama-server` won't find the file.

For reference, [docs/configuration.md](https://github.com/llmmanorg/llmman/blob/main/docs/configuration.md#environment-variables) lists every `llmman` variable, including the full quoting rules, and [docs/backends.md](https://github.com/llmmanorg/llmman/blob/main/docs/backends.md) covers how `llmman` runs `llama-server` locally and in a container. Questions are welcome at [github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
