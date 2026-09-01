+++
title = "Mirror Hugging Face models into any OCI registry"
description = "If you want somewhere other than Hugging Face to keep model weights, the boring answer is the registry infrastructure you already run."
date = 2026-09-01

[taxonomies]
tags = ["oci", "registries", "distribution"]
+++

I've been building llmman, a CLI that packages LLM models as OCI
artifacts and serves them over Ollama-, OpenAI- and
Anthropic-compatible APIs.

The reported Nvidia/Hugging Face deal is why I'm writing this now. In
last week's discussion, the alternatives people reached for were
torrents and ModelScope, and one question went unanswered: is there a
third option that isn't a US GPU monopoly or a Chinese hyperscaler? I
think the boring answer is the registry infrastructure a lot of us
already run.

<!-- more -->

## Weights are already OCI artifacts

Model weights are large immutable blobs with a name, a version and no
dependencies. That is an OCI artifact. Registries already solve
mirroring, caching, auth, signing, retention and air-gapped pulls, a
decade of unglamorous work the model ecosystem has been rebuilding from
scratch.

## Stream them into your own registry

So this streams weights straight from Hugging Face into your own
registry without staging them on disk first, which matters on a machine
with no room for them:

```sh
llmman transfer hf.co/unsloth/Qwen3.5-0.8B-GGUF docker.io/you/qwen3.5:0.8b
```

Docker Hub there because it is the one everyone recognises. Any OCI
registry works, including ghcr.io, quay.io, or a self-hosted Harbor.

From that point on the reference is the model, and nothing reaches back
to Hugging Face:

```sh
llmman run docker.io/you/qwen3.5:0.8b
```

That pulls from your registry, starts a daemon if one isn't running, and
drops you into a chat.

## One server, three API dialects

`llmman serve` answers `/api/chat`, `/v1/chat/completions` and
`/v1/messages` on one port, so Ollama, OpenAI and Anthropic clients work
unchanged. GGUF goes to `llama-server`, safetensors to vllm, or MLX on
Apple Silicon. The local store is an OCI image layout, so `docker` and
`podman` can read it directly. The format is
[CNCF ModelPack](https://github.com/modelpack/model-spec), not something
I invented, so the artifacts stay readable if you stop using llmman.

## What it does not do

It does not replace Hugging Face. Discovery, model cards and the fact
that everything lands there first are the real lock-in, and a registry
does not fix that. What it gives you is somewhere you control to put the
weights, and one command to get them there.

Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
Don't be afraid to give the project a star or open a PR.
