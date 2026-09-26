+++
title = "llmman now speaks Gemini"
description = "Antigravity's CLI talks to models over the Gemini API. llmman now translates that protocol, so AGY can run against a local model or a hosted one."
date = 2026-09-15

[taxonomies]
tags = ["serve", "providers", "agy", "gemini"]
+++

Every integration llmman launches speaks its own protocol.
Claude Code speaks Anthropic's API, OpenCode and Codex speak OpenAI's.
Antigravity, Google's CLI, speaks Gemini: Gemini-shaped history, system
instructions, function declarations, streaming events. Until
[#400](https://github.com/llmmanorg/llmman/pull/400), llmman understood
none of it.

<!-- more -->

## Launching it

```sh
llmman launch agy --model qwen3.5:9b
```

Same as any other integration: `llmman launch` starts `serve` if it
isn't already running, preloads the model, and execs AGY with the right
environment. Anything after `--` is forwarded to AGY itself. AGY 1.1.13
or newer is required for Gemini API-key and custom-endpoint support.

llmman writes its own Gemini settings to
`~/.gemini/llmman/antigravity-cli/`, so launching through llmman never
touches your regular AGY or Gemini CLI configuration.

## What crosses the wire

The adapter translates system instructions, conversation history,
function declarations and results, generation controls, stop
sequences, finish reasons and streaming usage metadata between
Gemini's shape and the backend's.

Images travel too: PNG, JPEG, WebP and GIF `inlineData` become data
URIs the backend already knows how to read. A MIME type llmman doesn't
support, or base64 that doesn't decode, is rejected at translation
time with a clear error instead of failing somewhere downstream.

## Tool calls that stay matched up

Gemini can constrain a request to an `ANY`-mode allow-list of
functions. llmman filters the declared tools down to that list and
requires the model to use one; an empty or missing list leaves
everything available, same as AGY would see talking to Gemini directly.

AGY doesn't always attach call IDs to tool results. When it doesn't,
llmman generates one and keeps it out of the way of IDs AGY did supply,
so a long tool-heavy conversation can't collide the two.

## Streaming first, then the rest

AGY's own turn uses Gemini's `streamGenerateContent`, and that's what
shipped first: backend response chunks become Gemini-shaped
server-sent events, text and tool calls and finish reasons and usage
all included.

The non-streaming `generateContent` and `countTokens` endpoints landed
a day later, in
[#491](https://github.com/llmmanorg/llmman/pull/491):
`generateContent` folds that same backend stream into one response,
and `countTokens` gets an exact count from a one-token unstreamed
completion against the backend's own tokenizer, reusing the prompt
llama-server already has cached.

## One model, pinned

AGY tucks a model name into the path of some of its own requests,
including the auxiliary calls it makes for titles and planning. llmman
ignores that and encodes the model chosen at launch into the route
instead, so every request AGY sends lands on the model you asked for.

## Credentials that don't leak

AGY authenticates with `x-goog-api-key`. When that header carries the
daemon's own key, llmman accepts it and strips it before the request
goes anywhere else; any other provider key in that header is left
alone. AGY can talk to llmman without llmman's key ever reaching
whatever backend actually answers the request.

Details are in
[README.md#launch-an-integration](https://github.com/llmmanorg/llmman#launch-an-integration).
Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
Don't be afraid to give the project a star or open a PR.
