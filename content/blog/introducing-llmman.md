+++
title = "Introducing llmman"
description = "A command-line tool that treats LLM models as ordinary OCI artifacts, and serves them over the Ollama, OpenAI and Anthropic APIs your tools already speak."
date = 2026-08-31

[taxonomies]
tags = ["announcement", "oci", "inference"]
+++

Model weights are large binary blobs with a name, a version, and a
dependency on nothing. That is exactly the shape of an OCI artifact, and
the infrastructure for moving OCI artifacts around is already deployed
almost everywhere: OCI registries, mirrors, caches, auth, signing,
retention policies, quotas.

`llmman` is a command-line tool built on that premise. Models are
packaged as standard OCI artifacts and stored in any compatible OCI
registry (Docker Hub, GHCR, quay, or something self-hosted), and
`llmman serve` exposes Ollama-, OpenAI-, and Anthropic-compatible HTTP
APIs on top of the local store.

<!-- more -->

## Install

Linux and macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/llmmanorg/llmman/main/install.sh | sh
```

Windows, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/llmmanorg/llmman/main/install.ps1 | iex
```

## Run

One command pulls the model if it is not already local, starts the
background daemon if it is not already running, and drops you into an
interactive chat:

```sh
llmman run gemma4
```

Short names work wherever a model reference is accepted. Pass a prompt
after the model for a one-shot answer instead of a session.

Models are loaded on demand: each one gets its own backend subprocess on
a random loopback port, and subsequent requests reuse the running
process. An idle model is unloaded after `keep_alive` (five minutes by
default, matching Ollama), and `llmman ps` reports each loaded model's
`expires_at`.

## Three API dialects, one port

That daemon is `llmman serve`, and you can start it on its own rather
than letting `run` do it. It listens on `127.0.0.1:17434` by default,
overridable with `LLMMAN_HOST`, and answers three families of routes at
once, so most existing clients need no changes beyond an endpoint:

| API | Endpoints |
|-----|-----------|
| Ollama | `/api/generate`, `/api/chat`, `/api/tags`, `/api/show`, `/api/pull`, `/api/ps`, `/api/delete` |
| OpenAI | `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/models`, `/v1/responses` |
| Anthropic | `/v1/messages` |

## No embedded inference engine

llmman does not ship its own inference engine. It picks an existing one
based on the model format:

- **GGUF** is served by `llama-server` from
  [llama.cpp](https://github.com/ggml-org/llama.cpp). If it is already
  on `PATH`, that build is used. Otherwise llmman downloads and caches a
  prebuilt release matching your OS, architecture and GPU.
- **Safetensors** is served by [vllm](https://github.com/vllm-project/vllm).
- **Safetensors on Apple Silicon** is served by
  [mlx-lm](https://github.com/ml-explore/mlx-lm)'s `mlx_lm.server`
  whenever it is on `PATH`: Metal-accelerated, no vLLM dependency, and
  it covers more model families than vllm-metal does.

That keeps llmman's own job small: resolve a reference, materialize the
weights, start the right process, route the request. It also means
engine upgrades are not gated on an llmman release.

## Transfer without landing on disk

Because both ends are just OCI registries, an image can be streamed from
a source straight to a destination without being stored locally first:

```sh
llmman transfer hf.co/unsloth/Qwen3.5-0.8B-GGUF docker.io/owner/model:latest
```

Any source `llmman pull` understands (an OCI registry, `hf://`, `ms://`)
can be paired with any OCI registry destination. This is the
convenient path for getting a model out of HuggingFace and into the OCI
registry your cluster actually pulls from, on a machine that may not
have room for the weights at all.

## Launching your tools

Wiring a coding agent to a local model is usually three steps: start a
server, wait for the model, then set the right environment variables for
whatever the tool expects. `llmman launch` collapses that into one:

```sh
llmman launch claude --model gemma4
```

It starts `serve` in the background if it is not already running,
preloads the requested model, sets the environment and execs the
integration. Run `llmman launch` with no arguments to see the supported
integrations and whether each is installed. Anything after `--` is
forwarded to the integration's own CLI.

The same command can point at a model llmman does not serve itself:

```sh
export OPENROUTER_API_KEY=...
llmman launch opencode --provider openrouter --model qwen/qwen3-coder
```

The provider list is fetched at runtime from
[models.dev](https://models.dev), so a newly added provider works
without an llmman release. Requests still go through `llmman serve`;
`--provider` only changes where the daemon forwards them. One endpoint,
one place to configure integrations, whether the model is local or
hosted.

API keys travel per request and are never written to disk. `--provider`
also requires a local daemon: `llmman serve` speaks plain HTTP with no
authentication, so llmman will not hand an integration a real key
addressed at a remote `LLMMAN_HOST`.

## Try it

[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman)

Issues and pull requests are welcome. More posts here as things land.
