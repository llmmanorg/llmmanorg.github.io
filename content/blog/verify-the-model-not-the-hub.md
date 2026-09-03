+++
title = "Verify the model, not the hub"
description = "llmman now checks cosign signatures before it will run a model, against a trust policy you write with keys you hold."
date = 2026-09-03

[taxonomies]
tags = ["security", "signing", "oci", "registries"]
+++

llmman has always content-addressed everything it pulls. Every blob is
re-hashed on the way in, so the bytes always match what the registry
said they would be. That proves nothing about who put them there.

<!-- more -->

## Nobody is vouching for the weights

llmman does not run a registry. `llmman pull gemma4` resolves to Docker
Hub by default, and you can point it at any OCI registry instead. What
it does not have is a curated library: llmman reviews nothing and
vouches for nothing, and the GGUF it lands on goes straight into
`llama-server`'s parser. Integrity alone does not help you there.

## How the other two handle it

Hugging Face puts the trust in Hugging Face: TLS to their CDN, their
malware and pickle scanning, their verified-organisation badges. That is
all real, and none of it is attached to the artifact. Mirror the weights
into your own registry and none of it comes with them. Gated repos are
access control, which is a different question from authenticity.

Ollama's registry is content-addressed too, so integrity is solid there
as well. Authenticity comes from curation: the library is theirs, and
trusting a model largely means trusting them to have put it there.

Neither is wrong, and both derive their trust from operating the hub.
llmman is a client of whichever registry you point it at rather than the
operator of one, so that route is not open to it. Verifying the artifact
is.

## Signing and verifying

```sh
llmman push docker.io/you/qwen3.5:0.8b --sign-key signing.key
llmman verify docker.io/you/qwen3.5:0.8b --key signing.pub
```

The on-registry format is cosign simple signing, published at the tag
that convention already uses, so a signature is a plain OCI artifact
any registry will hold and other tooling can read. Any standard PEM key
works; `openssl genpkey` is enough to make one.

## A policy, so pulls check themselves

`verify.conf`, in `/etc/llmman/` or `~/.config/llmman/`:

```toml
[[trust]]
pattern = "docker.io/you/**"
keys    = ["keys/you.pub"]
mode    = "enforce"          # off, warn, or enforce
```

Under `enforce`, a model that is not signed by a key you listed does not
get pulled. The check runs before any layer is fetched, so a rejection
costs one manifest lookup instead of a multi-gigabyte download.

It is off until you configure it. With no keys there is nothing to check
against, and a warning on every pull that you can do nothing about only
teaches you to ignore the one that eventually matters.

## What gets checked

The payload has to be a cosign simple-signing document, name that exact
manifest digest, be covered by a key you trust, and claim the repository
you actually pulled from.

That last one matters more than it looks. A signature binds to a digest,
not to a location, so without it anyone can copy a legitimately signed
model and its signature into their own repository and have both verify
against the real publisher's key.

## What it does not do

Key-based only. Keyless signing through Fulcio and Rekor is a much
larger trust-root surface and is unusable in the air-gapped setups that
want `enforce` most. There is also a newer sigstore bundle format llmman
cannot read yet; it names that case rather than calling those models
unsigned, and still refuses them under `enforce`. A pull-through mirror
cannot verify either, because the claimed-repository check is doing its
job, and the per-rule identity override that would fix it is not
written.

None of this replaces Hugging Face's scanning. It answers a different
question: not "is this model malicious" but "is this the model the
person I trust published".

Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
Don't be afraid to give the project a star or open a PR.
