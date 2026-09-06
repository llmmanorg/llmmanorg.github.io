+++
title = "Hybrid inference: a local model with a hosted one behind it"
description = "One model name can now carry a local model and a hosted one. llmman serve picks a side per request, and everything that fits stays on your machine."
date = 2026-09-06

[taxonomies]
tags = ["serve", "providers", "hybrid"]
+++

Until now a model in llmman was either local or hosted, chosen up front
for a whole session. Now it can be both, with the choice made per
request.

<!-- more -->

## The setup

```sh
llmman launch opencode --model gemma4 \
  --overflow-provider anthropic --overflow-model claude-sonnet-5
```

OpenCode is configured with one model, exactly as before. Under the
hood that model is `llmman.hybrid/gemma4,anthropic/claude-sonnet-5`,
which travels in the ordinary `"model"` field, so any client on any of
the daemon's three APIs can use one. `llmman run` takes the same flags.

## Which side

The rule is small and mechanical. It does not read the conversation:

1. `x-llmman-route: local` or `cloud` on the request wins. Anything else
   is a `400`, never a guess.
2. Otherwise, a request too large for the local model goes to the
   provider. That is the one thing the local model provably cannot do.
3. Otherwise, local.

Local is the default because the two mistakes are not equal. Keeping
something here that Claude would have answered better costs a worse
answer. Sending something away that could have stayed spends money and
puts your data on someone else's servers. Only the second is
unrecoverable.

The size check happens twice. First on the request's byte length,
before the model is loaded. Then, if the local backend still refuses
the prompt as over its context, the daemon retries it on the hosted half
before any output has reached the client. That second check matters for
agents: without it OpenCode saw the local model's context error,
compacted its history, and stayed local, which is the opposite of what
the pair is for.

Every request logs which way it went and why:

```
[llmman] hybrid "gemma4" + "llmman.provider/anthropic/claude-sonnet-5" -> local (no reason to leave this machine)
[llmman] hybrid "gemma4" + "llmman.provider/anthropic/claude-sonnet-5" -> cloud (request (75764 tokens) exceeds the available context size (65536 tokens))
```

## What it is not

It is not a classifier. Nothing decides that a question is "hard" and
sends it to the cloud; only size and an explicit pin do that. The
hosted half authenticates exactly as `--provider` always has, per
request, never written to disk. And a `local` pin is a promise: the
local half of a pair must itself be local, so no reference can smuggle a
pinned request off the machine.

Details are in
[docs/providers.md](https://github.com/llmmanorg/llmman/blob/main/docs/providers.md#hybrid-model-pairs).
Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
