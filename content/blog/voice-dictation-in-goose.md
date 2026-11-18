+++
title = "Dictate to goose with a speech model on your own machine"
description = "goose's mic button sends your voice to an OpenAI-style transcription endpoint. Point it at llmman, which hands the audio to llama-server, and the speech never leaves your machine."
date = 2026-11-18

[taxonomies]
tags = ["goose", "speech", "serve", "llama.cpp"]
+++

goose has a microphone button: click it, talk, and your words land in the
prompt box. By default the audio goes to a hosted service, but goose can send
it to any server that speaks the OpenAI transcription API, and `llmman serve`
is one.

This post sets that up so the audio is transcribed by a model running on your
own machine, using Voxtral Mini through llama-server.

<!-- more -->

## What goose sends

goose's dictation settings offer a few providers: OpenAI, Groq, ElevenLabs, a
Whisper model that goose runs itself, and "model", which asks your chat model
to transcribe. The OpenAI one is the useful one here, because its address can
be changed. It does two things:

- It records **16 kHz, mono, 16-bit WAV** and uploads it as a multipart
  `POST` to `<OPENAI_HOST>/v1/audio/transcriptions`, with two fields: `file`
  and `model`.
- It reads the `text` field from the JSON reply and puts it in the prompt box.

That is the whole contract. `llmman serve` answers
`/v1/audio/transcriptions` and passes the request to llama-server, which
transcribes with any model that can take audio in. Voxtral Mini is one such
model: Mistral built it for speech, and `ggml-org` publishes a GGUF of it.

## Start the server

```sh
LLMMAN_CONTEXT_LENGTH=8192 LLMMAN_KEEP_ALIVE=30m llmman serve
```

Both variables are there for a reason:

- **`LLMMAN_CONTEXT_LENGTH=8192`**: by default llmman asks llama-server for a
  256k-token context, capped at what the model was trained on, and the memory
  for it is reserved up front. A spoken prompt is a few hundred tokens, so
  that memory is wasted. On my machine the default needed more than 8 GiB
  with Voxtral, and with 8192 the machine's memory use rose by about 3.7 GB.
- **`LLMMAN_KEEP_ALIVE=30m`**: an idle model unloads after 5 minutes by
  default, and loading Voxtral again takes about half a minute. You do not
  want to wait that long after pausing to think, so keep it loaded for longer.

> `LLMMAN_CONTEXT_LENGTH` applies to every model this daemon serves. If the
> same daemon also serves your chat model and that model needs a longer
> context, either pick a value that suits both, or start a second daemon for
> speech on another port with `LLMMAN_HOST=127.0.0.1:17435` and use that
> address below.

## Try it before you talk to it

Send the same request goose will send. Any WAV works. To make one from a
recording:

```sh
ffmpeg -i recording.m4a -ar 16000 -ac 1 -c:a pcm_s16le clip.wav
```

```sh
curl -s http://127.0.0.1:17434/v1/audio/transcriptions \
  -F "file=@clip.wav;filename=audio.wav;type=audio/wav" \
  -F "model=hf.co/ggml-org/Voxtral-Mini-3B-2507-GGUF:Q4_K_M"
```

```json
{"type":"transcript.text.done","text":"\"Please summarize the open pull requests in this repository.\"","usage":{"type":"tokens","input_tokens":1437,"output_tokens":12,"total_tokens":1449,"input_tokens_details":{"cached_tokens":1436}}}
```

The first request pulls the model and its audio projector from Hugging Face
and loads them, which took about 30 seconds here once the download was done.
The next request, with the model already loaded, took about a second for a
five-second clip. llmman finds the projector file that belongs to the model
by itself, and prints `found companion mmproj file` when it does. A model
with no audio projector cannot transcribe, and the request will fail.

The reply has more fields than goose needs, which is fine: goose only reads
`text`.

## Point goose at it

goose needs three settings. It reads each one from an environment variable
first and from `~/.config/goose/config.yaml` second.

| Setting | Value |
|---|---|
| `OPENAI_HOST` | `http://127.0.0.1:17434` |
| `OPENAI_API_KEY` | any non-empty string, such as `local`. goose will not use the provider without one; llmman accepted whatever I sent |
| `OPENAI_TRANSCRIPTION_MODEL` | `hf.co/ggml-org/Voxtral-Mini-3B-2507-GGUF:Q4_K_M` |

`OPENAI_HOST` is the bare address, with no `/v1`: goose adds
`v1/audio/transcriptions` itself.

Then choose **OpenAI** as the Voice Dictation Provider in goose's settings.
Two details to know:

- goose's settings page lists only `whisper-1` as a model for the OpenAI
  provider and has no field for another name. The environment variable (or a
  line in `config.yaml`) is how you choose a different model.
- `OPENAI_HOST` is also the address of goose's OpenAI chat provider. If you
  chat with real OpenAI and only want dictation to be local, this setting is
  shared, so use the route below or keep it in a launcher that sets it just
  for the session.

### If you already start goose with llmman

`llmman launch goose` and `llmman launch goose-desktop` start goose with
`OPENAI_HOST` and `OPENAI_API_KEY` already pointed at your daemon, because
that is how they send chat to a local model. So dictation only needs the
model name:

```sh
OPENAI_TRANSCRIPTION_MODEL=hf.co/ggml-org/Voxtral-Mini-3B-2507-GGUF:Q4_K_M \
  llmman launch goose-desktop --model qwen3.8
```

Then pick **OpenAI** as the dictation provider once, in the settings. The
variable reaches goose because `llmman launch` adds its own variables to your
environment instead of replacing it.

## Other models

Nothing here is specific to Voxtral. Any model llama-server can feed audio to
works the same way, as long as it comes with an audio projector, which llmman
passes as `--mmproj`. Change the model name in `OPENAI_TRANSCRIPTION_MODEL`
and in the `curl` test, and keep the context-length advice: it applies to any
model with a long trained context.

## If the mic button does nothing

Check in this order:

1. The `curl` above returns text. If not, the problem is the model or
   llmman, not goose.
2. `OPENAI_HOST` has no `/v1` at the end.
3. `OPENAI_API_KEY` is set to something.
4. `OPENAI_TRANSCRIPTION_MODEL` is the full reference, `hf.co/...:Q4_K_M`,
   not just `Voxtral-Mini-3B-2507-GGUF`.
5. OpenAI is the provider selected under Voice Dictation.

I ran the request goose sends, with the format and fields taken from goose's
source, against llmman 0.1.676 and llama.cpp b12359. The goose behaviour
described above comes from the dictation code on goose's `main` branch, which
the goose 1.60 build I had installed also contains. Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
