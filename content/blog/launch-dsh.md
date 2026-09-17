+++
title = "llmman launch dsh: Run DeepSeek Harness on any local or hosted model"
description = "DeepSeek Harness treats the model as a plugin. llmman runs any model on your own hardware, in one command."
date = 2026-09-14

[taxonomies]
tags = ["dsh", "serve", "launch"]
+++

An artificial intelligence (AI) agent is a system that autonomously performs tasks by designing workflows with available tools. 

An agent harness is a loop around your model that takes your task, calls a model, runs tools (such as shell commands and file edits), provides results, and repeats. Claude Code, Codex, and OpenCode are all harnesses. DeepSeek Harness is DeepSeek's.

Unlike Claude Code, DeepSeek Harness is fully customizable. It builds on the idea that everything is a plugin including the model, tools, memory and even the agent loop itself. With DeepSeek Harness, you can build a custom AI agent entirely from scratch, run it locally with any AI model and even; call Claude Code and Codex as sub-agents from inside of it. 

<!-- more -->

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 520" role="img" aria-label="Inputs flow into DeepSeek Harness, which fans out to pluggable capabilities; its model slot is filled by llmman serve" style="width:100%;height:auto;max-width:900px;margin:2rem 0;font-family:system-ui,-apple-system,'Segoe UI',sans-serif">
<defs><marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0 10 5 0 10z" fill="var(--accent,#7aa2f7)"/></marker></defs>
<g fill="var(--muted,#8a94a8)" font-size="10" letter-spacing="1.6"><text x="8" y="74">INPUTS</text><text x="892" y="46" text-anchor="end">PLUGGABLE CAPABILITIES</text></g>
<g stroke="var(--line,#232a3a)" fill="var(--panel,#151a25)"><rect x="8" y="96" width="150" height="52" rx="8"/><rect x="8" y="168" width="150" height="52" rx="8"/><rect x="8" y="240" width="150" height="52" rx="8"/></g>
<g font-size="12" fill="var(--text,#d7dce6)"><text x="24" y="118">User</text><text x="24" y="190">Data</text><text x="24" y="262">Applications</text></g>
<g font-size="10" fill="var(--muted,#8a94a8)"><text x="24" y="134">questions, tasks</text><text x="24" y="206">files, context</text><text x="24" y="278">web and internal tools</text></g>
<g fill="none" stroke="var(--accent,#7aa2f7)" stroke-width="1.2" opacity=".75"><path d="M158 122 C182 122 182 194 205 194"/><path d="M158 194 H205"/><path d="M158 266 C182 266 182 194 205 194"/></g>
<circle cx="205" cy="194" r="4.5" fill="var(--accent,#7aa2f7)"/>
<line x1="205" y1="194" x2="244" y2="194" stroke="var(--accent,#7aa2f7)" stroke-width="1.2" marker-end="url(#ar)"/>
<rect x="250" y="60" width="340" height="290" rx="12" fill="var(--bg-soft,#11151f)" stroke="var(--line,#232a3a)"/>
<text x="420" y="101" text-anchor="middle" font-size="15" letter-spacing="1.4" fill="var(--head,#f2f5fa)">DEEPSEEK HARNESS</text>
<rect x="274" y="132" width="292" height="76" rx="10" fill="var(--panel,#151a25)" stroke="var(--accent,#7aa2f7)" stroke-dasharray="4 3"/>
<text x="420" y="166" text-anchor="middle" font-size="15" fill="var(--head,#f2f5fa)">Model slot</text>
<text x="420" y="188" text-anchor="middle" font-size="11" fill="var(--muted,#8a94a8)">any OpenAI-compatible endpoint</text>
<g stroke="var(--line,#232a3a)" fill="var(--panel,#151a25)"><rect x="274" y="230" width="92" height="46" rx="8"/><rect x="374" y="230" width="92" height="46" rx="8"/><rect x="474" y="230" width="92" height="46" rx="8"/></g>
<g font-size="11" text-anchor="middle" fill="var(--text,#d7dce6)"><text x="320" y="258">Routing</text><text x="420" y="258">Memory</text><text x="520" y="258">Tool loop</text></g>
<text x="420" y="316" text-anchor="middle" font-size="10" letter-spacing="1.4" fill="var(--muted,#8a94a8)">EVERY PART A PLUGIN</text>
<line x1="590" y1="194" x2="645" y2="194" stroke="var(--accent,#7aa2f7)" stroke-width="1.2"/>
<circle cx="650" cy="194" r="4.5" fill="var(--accent,#7aa2f7)"/>
<g fill="none" stroke="var(--accent,#7aa2f7)" stroke-width="1.2" opacity=".75" marker-end="url(#ar)"><path d="M650 194 C695 194 695 94 736 94"/><path d="M650 194 C695 194 695 152 736 152"/><path d="M650 194 C695 194 695 210 736 210"/><path d="M650 194 C695 194 695 268 736 268"/><path d="M650 194 C695 194 695 326 736 326"/><path d="M650 194 C695 194 695 384 736 384"/></g>
<g stroke="var(--line,#232a3a)" fill="var(--panel,#151a25)"><rect x="740" y="72" width="152" height="44" rx="8"/><rect x="740" y="130" width="152" height="44" rx="8"/><rect x="740" y="188" width="152" height="44" rx="8"/><rect x="740" y="246" width="152" height="44" rx="8"/><rect x="740" y="304" width="152" height="44" rx="8"/></g>
<rect x="740" y="362" width="152" height="44" rx="8" fill="none" stroke="var(--line,#232a3a)" stroke-dasharray="4 3"/>
<g font-size="12" fill="var(--text,#d7dce6)"><text x="756" y="92">Tools</text><text x="756" y="150">APIs</text><text x="756" y="208">Retrieval</text><text x="756" y="266">Memory</text><text x="756" y="324">I/O</text></g>
<g font-size="10" fill="var(--muted,#8a94a8)"><text x="756" y="107">shell, code, search</text><text x="756" y="165">external services</text><text x="756" y="223">RAG, vector stores</text><text x="756" y="281">short and long term</text><text x="756" y="339">files, streams</text></g>
<text x="756" y="390" font-size="11" fill="var(--muted,#8a94a8)">+ your own</text>
<line x1="420" y1="350" x2="420" y2="404" stroke="var(--accent,#7aa2f7)" stroke-width="1.2" marker-end="url(#ar)"/>
<text x="432" y="382" font-size="10" fill="var(--accent,#7aa2f7)">model</text>
<rect x="180" y="410" width="540" height="86" rx="12" fill="var(--panel,#151a25)" stroke="var(--accent,#7aa2f7)"/>
<text x="450" y="442" text-anchor="middle" font-size="15" fill="var(--head,#f2f5fa)">llmman serve</text>
<text x="450" y="463" text-anchor="middle" font-size="11" fill="var(--muted,#8a94a8)">127.0.0.1:17434 — Ollama, OpenAI and Anthropic APIs on one port</text>
<text x="450" y="482" text-anchor="middle" font-size="11" fill="var(--muted,#8a94a8)">a GGUF on your machine via llama.cpp, or any hosted provider</text>
</svg>

## Why llmman?

An agent CLI normally talks to one vendor's API, and your prompts and code go with it. `llmman` puts a server in between: DeepSeek Harness (`dsh`) talks to `127.0.0.1:17434`, and what answers is a model on your own machine, or a hosted one, when you ask for that explicitly.

Launch DeepSeek Harness with llmman and you get the following out of the box:

- **Nothing leaves your machine unless you say:** Prompts, file contents and diffs stay on your machine. Once the weights are pulled, the loop works offline. 
- **One configuration either way:** `--provider` changes where the daemon forwards a request, not what `dsh` talks to, so the agent config is the same for both local and hosted models. 
- **The model is yours to move.** Models are OCI artifacts from Docker Hub, Hugging Face. Pull one from Docker Hub or Hugging Face, push it to your own registry, or copy it into a network with no internet at all.


## The setup

```sh
llmman launch dsh --model <model-name>    # eg. gemma4:12b
```

One command does four things: it starts `llmman serve` if there isnt a running server, pulls the model and loads it, writes the configuration `dsh` expects, and hands over to dsh's `web` profile. Short names work here the way they do everywhere else in `llmman`, so `gemma4:12b` resolves to `docker.io/ai/gemma4:12b`.

<video controls preload="metadata" width="1512" height="850" src="https://github.com/llmmanorg/llmmanorg.github.io/releases/download/blog-launch-dsh/launch-dsh.mp4"></video>

You do not need `dsh` installed for this. When it isn't on your `PATH`, llmman sets it up with `npx` instead, and says so before it starts downloading anything.

`--model` is required here, unlike most integrations. `dsh` has no default model of its own, and leaving it empty writes the literal string `default` into its settings; which fails at the first request rather than at the command you typed.

## Executing a single task

When you run `llmman launch dsh --model <model-name>`, dsh's `web` profile boots a server and answers in a browser, so it has nothing to print to your terminal. When you want one answer and no
browser, pass dsh's headless profile instead. Everything after `--` goes to dsh's own CLI:

```sh
llmman launch dsh --model gemma4:12b \
-- --profile headless "Explain what git rebase does in one sentence"
```

`llmman` defaults to a `web` profile. Providing `--profile headless` overrides the default profile and uses the `headless` profile.

<img src="https://github.com/llmmanorg/llmmanorg.github.io/releases/download/blog-launch-dsh/headless-run.png" alt="dsh's headless profile answering a question about git rebase from gemma4:12b, run through llmman" width="1398" height="370" loading="lazy">


## What llmman configures for you

When you launch `dsh` with `llmman`, `llmman` sets up two files under `~/.config/llmman/launch/dsh`. The first registers the daemon as a provider and picks the model:

```yaml
agent-default-model:
  provider: llmman
  model: "docker.io/ai/gemma4:12b"
llm-pi-ai:
  providers:
    llmman:
      displayName: llmman
      apiKeyEnv: LLMMAN_API_KEY
      api: openai-completions
      baseURL: "http://127.0.0.1:17434/v1"
      models:
        - id: "docker.io/ai/gemma4:12b"
          name: "docker.io/ai/gemma4:12b"
          input: [text, image]
```

The second is the patch that points `dsh` at the first. Both are rewritten on every launch, so the model `dsh` talks to is always the one you just named.

In that configuration:

- **`apiKeyEnv`** names an environment variable rather than holding a key, so the credential travels in dsh's environment and never lands on disk. That is a deliberate security choice: a config file that never holds a credential cannot leak one.
- **`input`** is populated from local model metadata. llmman asks the daemon what a local model can do, so dsh offers image attachments when a locally served model supports them. Hosted-provider launches currently advertise text input only.

## Hosted models

Sometimes you don't want the model on your machine at all. The weights may not fit on your disk, your hardware may not run them at a useful speed, or the task may need a bigger model than you can run. For those cases, `llmman` can send `dsh`'s requests to a model someone else runs.

This is different from pulling a model from Docker Hub or Hugging Face. The registries only store weights; once pulled, the model runs on your machine. A hosted provider runs the model for you, which means your prompts, file contents and diffs go to that provider. That is the "unless you say" from earlier: nothing leaves your machine until you pass `--provider`.

### Run dsh on a hosted provider

Export the provider's key and add `--provider` to the same command:

```sh
export OPENROUTER_API_KEY=...
llmman launch dsh --provider openrouter --model google/gemma-4-31b-it
```

The key is read from your environment and sent with each request. It is never written into dsh's configuration or anywhere else on disk.

### Find a provider and a model

The provider list comes from [models.dev](https://models.dev) at runtime, so a provider that appears there works without waiting for an llmman release. There are around 180, including OpenAI, Anthropic, DeepSeek, Groq, Mistral, Together and Fireworks. `llmman providers` prints each one with the environment variable it expects, whether yours is set, and how many models it serves:

```console
$ llmman providers | grep -E '^(PROVIDER|openrouter)'
PROVIDER      NAME          API KEY               KEY    MODELS
openrouter    OpenRouter    OPENROUTER_API_KEY    set    369
```

To see those models, and the exact name to pass to `--model`, list them:

```sh
llmman list --provider openrouter
```

### Use your own server

A server the catalog has never heard of works too: vLLM on a GPU machine down the hall, LM Studio on a laptop, or a proxy in front of OpenAI. Give it a `base_url` in `llmman.conf` and it takes the same flag:

```sh
llmman config set providers.local.base_url http://192.168.1.50:8000/v1
llmman launch dsh --provider local --model google/gemma-4-26b-a4b-it
```

Servers on your own network often need no key. If yours does, set `providers.local.api_key_env` to the name of the environment variable that holds it. If the server speaks the Anthropic API rather than OpenAI's, set `providers.local.wire` to `anthropic`.

### Stay local, and use a hosted model only when needed

You don't have to choose one or the other for a whole session. With `--overflow-provider` and `--overflow-model`, dsh gets a local model and a hosted one behind it:

```sh
llmman launch dsh --model gemma4:12b \
  --overflow-provider anthropic --overflow-model claude-sonnet-5
```

Every request runs on the local model unless it is too large for the local model's context window. Only those requests go to Anthropic. This suits an agent loop well: short turns stay on your machine, and a long session that outgrows the small model doesn't fail. [Hybrid inference](@/blog/hybrid-inference.md) explains how llmman decides where each request goes.

In every case, `dsh` still talks to `llmman serve` on `127.0.0.1:17434`, with the same generated config. `--provider` and `--overflow-provider` only change where the daemon sends the request.

