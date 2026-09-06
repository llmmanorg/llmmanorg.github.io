+++
title = "llmman log: git log for your prompts"
description = "llmman serve now keeps a history of the prompts it is sent, and llmman log shows it the way git log shows commits."
date = 2026-09-07

[taxonomies]
tags = ["serve", "cli"]
+++

An agent runs for an hour against `llmman serve` and leaves nothing
behind but a line per request in `serve.log`, none of them saying what
was asked. Now there is `llmman log`.

<!-- more -->

## What it looks like

```
$ llmman log
prompt 1873766d2cf5fb89ddd6a2a22242ab47a52547a3
Model:  qwen3:8b
Client: claude-cli/1.2.3
Route:  /v1/chat/completions
Date:   Sun Sep 6 19:22:16 2026 +0100

    fix the failing test
    then commit

$ llmman log --oneline -3
1873766d2cf5 fix the failing test
4b55493c0b7b why is the sky blue
450036622897 first question
```

If you know `git log`, you know the rest: `-n`, `--skip`,
`--since "2 hours ago"`, `--until yesterday`, `--grep`, `--model`,
`-i`, `--reverse`, and a pager when stdout is a terminal. `llmman log`
reads a file, so it needs no daemon, just as `git log` needs no server.

## What is recorded

Every request to a generation route — Ollama, OpenAI or Anthropic — adds
one line to `prompts.jsonl` beside the store: the time, route, model,
`User-Agent`, and the text of the last user turn. Only that turn. Not
the transcript an agent re-sends on every request, and never the reply,
so the file grows with what was typed rather than with context length.

The file is readable only by its owner. Set `LLMMAN_NOHISTORY` to
record nothing; delete the file to forget everything.

Details are in
[docs/configuration.md](https://github.com/llmmanorg/llmman/blob/main/docs/configuration.md#environment-variables).
Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
