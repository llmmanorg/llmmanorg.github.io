+++
title = "Find and pull models from the web UI"
description = "The web UI has a Models page now: popular models from Docker Hub and Hugging Face, a search of both, and a card per model with every tag or quantization you can pull, its size, and whether it fits your machine."
date = 2026-10-03

[taxonomies]
tags = ["webui", "serve", "search"]
+++

Pulling a model from llmman's web UI used to mean knowing its full
reference already, typed into a box. The UI now has a Models page,
where you find a model first and then pull it.

<!-- more -->

<img src="https://github.com/llmmanorg/llmmanorg.github.io/releases/download/blog-models-page/models-page-card.png" alt="The Models page: popular models from Docker Hub on the left, and the card for unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF on the right, with its quantizations, their sizes, a fit line and a Pull button" width="1440" height="900" loading="lazy">

## What's on it

It opens on what most people pull: Docker's own `ai/` models on Docker
Hub, then the most downloaded GGUF text-generation repos on Hugging
Face, the kind llama.cpp serves. Type in the box and it searches both
registries instead. *Pulled* lists what this machine already has.

Selecting a model opens its card:

- **Every tag or quantization `pull` can take**, each with its size.
  For a GGUF repo on Hugging Face those are its quantizations, and the
  one a plain `llmman pull` would pick is marked `default`.
- **Whether it fits.** Each size is weighed against this machine's model
  memory: green under 60%, yellow under 90%, red past that. It's
  weights only, so a green model can still run out of room at a long
  context, and the card says so.
- **Pull**, with the same progress `/api/pull` streams anywhere else.
  Once it's here, the card lets you chat with it, unload it or delete
  it.
- **The README**, the model card from Hugging Face or the overview from
  Docker Hub.

<img src="https://github.com/llmmanorg/llmmanorg.github.io/releases/download/blog-models-page/models-page-pulling.png" alt="bartowski/SmolLM2-135M-Instruct-GGUF pulling from its card, 7.7 MB of 101 MB, with its quantizations and README below" width="1440" height="900" loading="lazy">

## What it shows is what you get

A list of quantizations is only useful if picking one pulls that file.
So the card doesn't guess from file names. Each tag it lists is run
back through the same selection `llmman pull` uses, and kept only if
that lands on the file it was listed with: `Q4_K` would match the
`Q4_K_M` file too, so it isn't offered. The size includes the vision
projector when `pull` downloads one alongside, and a diffusion or
safetensors repo is a single download, because that's how `pull`
treats them.

## Same results as the CLI

The page doesn't talk to Hugging Face or Docker Hub itself. It asks
`llmman serve`, and `/llmman/search` is `llmman search` over HTTP: the
same function, the same rows in the same order, so the terminal and
the page can't disagree. The fit check went the other way. It started
on the card and then came to the CLI as a FIT column
([#603](https://github.com/llmmanorg/llmman/pull/603)), green, yellow
and red at the same 60% and 90%:

```
$ llmman search qwen3.5 -n 3
NAME                                     PULLS     LIKES    UPDATED         FIT
docker.io/ai/qwen3.5                     616.5K    10       1 month ago     34%
docker.io/ignaciolopezluna020/qwen3.5    121       0        6 months ago    -
hf.co/Qwen/Qwen3.5-9B                    9.0M      2091     7 months ago    29%
hf.co/Qwen/Qwen3.5-4B                    7.8M      996      7 months ago    14%
hf.co/Qwen/Qwen3.5-2B                    4.9M      423      7 months ago    7%
```

To try it, run `llmman serve` and open
`http://127.0.0.1:17434/#/models`.

Details are in
[docs/webui.md](https://github.com/llmmanorg/llmman/blob/main/docs/webui.md)
and [docs/api.md](https://github.com/llmmanorg/llmman/blob/main/docs/api.md#llmmans-own-api).
Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
