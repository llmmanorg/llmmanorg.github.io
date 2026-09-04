+++
title = "An aggregation of llmman"
description = "llmman serve daemons on several machines can now pool their hardware. Name the peers and a request to any node is served by whichever one has the model loaded, or the most room to load it."
date = 2026-09-04

[taxonomies]
tags = ["serve", "distributed", "aggregation"]
+++

A group of manatees is called an aggregation. As of this week, so is a
group of `llmman serve` daemons.

<!-- more -->

## The problem

Most of us who run local models have more than one machine that can
run them. A laptop, a workstation under the desk, a spare box with a
GPU that was expensive three years ago. Each one runs its own llmman,
and each one is an island: the model you want is loaded on the machine
you are not sitting at, and the big one is idle while the laptop fans
spin.

Two machines ought to be more than twice as useful as one, and today
they are less.

## The setup

On every node, name the others and bind somewhere they can reach:

```sh
llmman config set aggregation.peers asahi,spark
LLMMAN_HOST=0.0.0.0 llmman serve
```

That is the whole of it. Send a request to any node and it is served by
whichever node already has the model loaded, or, for a model loaded
nowhere, whichever has the most room for it. `llmman ps` gains a NODE
column, `/api/tags` and `/v1/models` list every node's models, and
`llmman stop` unloads a model wherever the aggregation put it.

```
$ llmman ps
NAME                        ID            SIZE      PROCESSOR     CONTEXT   STARTED       NODE           UNTIL
docker.io/ai/qwen3.5:0.8b   b17a799ff352  737.5 MB  llama-server  262144    just now      spark:17434    4 minutes from now
docker.io/ai/gemma4:e2b     0a4cfc34b9fe  4.1 GB    llama-server  65536     2 minutes ago local          3 minutes from now
```

A node does not have to be named back. A laptop can list a workstation
and offload to it while the workstation serves as it always did.

## How it decides

Every node is a whole llmman: its own store, its own `llama-server`
children, the same API. There is no leader and nothing is shared. When a
request names a model a node does not have loaded, it asks every peer
one question, `GET /llmman/node`, which answers with what that peer has
loaded, what it has stored, and how much memory it has. Then it picks:

1. A node that already has the model loaded. Never a second copy.
2. Otherwise, of the nodes the model fits on, one that already has it
   on disk. Loading from disk beats pulling over the network.
3. Otherwise the node with the most room. Ties go to itself.

If that is a peer, the request is forwarded there as-is, streaming and
all, with one extra header: `x-llmman-hop: 1`. A node that receives a
hopped request never forwards it again, so two nodes that name each
other cannot bounce a request between them. The peer treats it as an
ordinary request: its own queue, keep-alive and eviction apply.

Memory is what `llmman gpu-discover` reports as VRAM, or system RAM for
a node with no accelerator, since that is what a CPU-only `llama-server`
fills. Nothing is remembered between requests. Bring a node up or down
and the next request sees it; a peer that does not answer within a few
seconds is simply not part of the aggregation for that decision.

I tested it across a Mac (38 GB unified), a DGX Spark (128 GB) and an
Asahi Linux box (8 GB, no usable GPU). A cold request on the Mac for a
model all three had stored went to the Spark, which loaded it and
streamed the answer back in under three seconds. A model only the Mac
had stored stayed on the Mac, even though the Spark had more room.
Twelve concurrent streams through the Mac all landed on the node that
had the model loaded. Killing a peer mid-run cost nothing but that
peer.

## What it is not

It routes whole requests to whole models. It does not split one model
across machines. For a model too large for any single node, llama.cpp's
`rpc-server` plus `--rpc` on one `llama-server` does that, and it is a
different tool for a different problem.

It is also not what llm-d or NVIDIA Dynamo do. Those put a tokenizer in
the router, consume KV-cache events from the engines, and route by
prefix overlap and queue depth across a cluster with etcd or Kubernetes
behind it. Both fall back to a static endpoint list when there is no
cluster to ask, and that fallback, plus a cheap poll per cold request,
is all a handful of machines on one network needs. If you have a
cluster, use a cluster router.

Two honest limits. First, "never a second copy" means that with a small
model loaded on the slow box and a big idle box beside it, every
request still goes to the slow box. Load-aware spreading is the obvious
next step and I left it out to keep the first version small. Second,
`llmman serve` has no authentication and no TLS, so an aggregation is
for a network you already trust, the same caveat as any non-loopback
`LLMMAN_HOST`. If your distribution ships a host firewall, open
`17434/tcp`, or the node is silently just not part of anyone's
aggregation. I learned that one the hard way on Fedora.

The full write-up is in
[docs/aggregation.md](https://github.com/llmmanorg/llmman/blob/main/docs/aggregation.md).
Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
Don't be afraid to give the project a star or open a PR.
