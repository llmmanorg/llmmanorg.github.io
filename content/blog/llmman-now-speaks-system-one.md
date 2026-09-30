+++
title = "llmman now speaks System One"
description = "POST /v1/systemone turns a state and a few typed questions into a probability per answer, read from a local model's own token probabilities on ggml. Nothing is generated, so there is no text to parse."
date = 2026-09-30

[taxonomies]
tags = ["serve", "system-one", "ggml"]
+++

System One is an API for decisions rather than text. You send a state
and a few typed questions, and get back a probability for every
possible answer, with nothing to parse. As of
[#585](https://github.com/llmmanorg/llmman/pull/585) (0.1.497),
`llmman serve` answers it at `/v1/systemone` for a local GGUF model.
llama.cpp is not adding a System One endpoint, so llmman provides one,
on ggml, the way it [generates images and
video](@/blog/image-audio-and-video-generation.md).

<!-- more -->

## What you send

A request is a `state`, which is text or JSON, and a map of questions.
Each question is one of three kinds:

- `noul` is a yes or no. The answer is the probability of yes.
- `choice` is a pick from named options. The answer is the likeliest
  option, and a probability for each.
- `score` is a level on a scale. The answer is the probability-weighted
  level, and a probability for each.

Here is a support ticket with one of each. Save it as `ticket.json`:

```json
{
  "state": "I've been trying to connect my Stripe account for 3 days and the integration keeps failing. I'm losing sales.",
  "model": "gemma4",
  "questions": {
    "team": {
      "type": "choice",
      "instructions": "Which team should handle this ticket?",
      "criteria": {
        "billing": "Payment or subscription issues",
        "technical": "Bugs or integration problems",
        "sales": "Pricing or account questions"
      }
    },
    "revenue": { "type": "noul", "instructions": "The customer is losing revenue because of this." },
    "frustration": {
      "type": "score",
      "instructions": "How frustrated is the customer?",
      "criteria": ["Calm", "Frustrated but civil", "Very angry"]
    }
  }
}
```

The order of the options is part of the question: the first is labelled
`A`, the second `B`, and llmman keeps the order you sent.

## What comes back

```sh
curl -s http://127.0.0.1:17434/v1/systemone -d @ticket.json | jq
```

```json
{
  "model": "docker.io/ai/gemma4:latest",
  "answers": {
    "team": {
      "type": "choice",
      "choice": "technical",
      "confidence": 0.9999999051712019,
      "probabilities": {
        "billing": 4.9778699777875856E-8,
        "technical": 0.9999999367808015,
        "sales": 1.3440498826153299E-8
      },
      "x_label_mass": 0.9999996956963991
    },
    "revenue": {
      "type": "noul",
      "noul": 0.9999771323728099,
      "x_label_mass": 0.9999980611162673
    },
    "frustration": {
      "type": "score",
      "score": 1.0400604451059396,
      "confidence": 0.9399087385937515,
      "legend": { "0": "Calm", "1": "Frustrated but civil", "2": "Very angry" },
      "probabilities": {
        "0": 1.979157796785878E-7,
        "1": 0.9599391590625009,
        "2": 0.040060643021719376
      },
      "x_label_mass": 0.9999979154536461
    }
  },
  "usage": { "input_tokens": 222, "output_tokens": 0 }
}
```

The first request took 1.7 s, loading Gemma 4 included; the next ones
0.43 s, on an M4 Max. `output_tokens` is 0 because nothing was
generated.

## Reading, not generating

llmman turns each question into one user turn, renders it with the
model's own chat template with thinking off, and runs the model over
the prompt. It then reads the model's probability of each answer label
as the next token (`A`, `B`, `C` for the options, a digit for a level,
`yes` or `no`) and renormalises over the labels. `yes` and `Yes` count
together, and so do `no` and `No`, because models differ: in our runs
Gemma 3, Qwen3-4B and Llama 3.2 answered `Yes`, and Gemma 4 and Qwen3.5
`yes`.

`llama-server` cannot do this: it will not tell you the probability of a
token it was not asked to sample. An [earlier
attempt](https://github.com/llmmanorg/llmman/pull/579), since reverted,
went through its HTTP API and could only approximate the numbers. So llmman runs the
model itself, on the `libggml` and `libllama` of the llama.cpp build it
already uses, in a backend process of its own. `llmman ps` lists it next
to your other models, and calls the processor `llama-server`, as it does
for the media backends:

```
NAME                                    ID              SIZE          PROCESSOR               CONTEXT      STARTED     UNTIL
docker.io/ai/gemma4:latest#systemone                    7.3 GB        llama-server (local)                 just now    4 minutes from now
```

It unloads after `keep_alive`, counts towards `LLMMAN_MAX_LOADED_MODELS`
and is evicted like any model, and a model you also chat with is loaded
a second time. The KV cache is kept between questions, so a state shared
by all of them is decoded once. A model with recurrent layers, such as
Qwen3.5, cannot roll its cache back and decodes it again for each
question.

## Whether to believe it

`x_label_mass` is how much probability the model put on the labels at
all, before renormalising. When it is low, the model wanted to say
something else, and the probabilities next to it are a ratio of small
numbers. Ask two models which of 30 cities is the capital of France, so
the options get two-letter labels:

| model | choice | confidence | `x_label_mass` |
|---|---|---|---|
| Gemma 4 | Paris | 1.000 | 1.000 |
| Qwen3.5 0.8B | Vienna | 0.441 | 0.177 |

The 0.8B model is lost, and the mass says so. It is the model's own
probability and repeats from run to run, but it is not a calibrated
chance of being right, and a threshold tuned on one model does not carry
to another. Tune it on your own labelled tickets.

## Which models

A GGUF with a chat template, on a llama.cpp that runs it. We compared
the probabilities and `x_label_mass` with `llama-server`'s own logprobs
for the same prompt, on an M4 Max with llama.cpp b11146:

| model | tokenizer | largest difference |
|---|---|---|
| Qwen3.5 0.8B | BPE | 3e-4 |
| Qwen3-4B | BPE | 2e-8 |
| Qwen2.5-VL-7B | BPE | 9e-5 |
| Gemma 4 E4B | Gemma 4 | 8e-5 |
| Gemma 3 12B | SentencePiece | 1e-7 |
| Llama 3.2 | BPE | 2e-4 |
| Mistral | SentencePiece | 4e-4 |

Two of the models we tried were refused, with a 400 that says why. The
DeepSeek-R1 distill opens a reasoning block in its prompt, and a read
inside it would mean nothing:

```
question "team": the chat template leaves a reasoning block open at the answer position, so this model is not supported with these chat_template_kwargs
```

And Mistral has no single token for a digit after `[/INST]`, so its
`choice` and `noul` questions work and a `score` question does not:

```
question "mood": the answer label "0" is not one distinct token after the chat prompt for this tokenizer, so this model is not supported
```

We have not tried every family. llmman renders the chat template
itself, so one that uses a Jinja feature it lacks is refused too, and a
model that starts reasoning anyway shows up as a low `x_label_mass`.

## From an existing client

Clients written for System One work by pointing their base URL at the
daemon. This is the [TypeSafe](https://typesafe.ai) Python SDK
(`pip install typesafe-sdk`, 0.7.2), unchanged:

```python
from typesafe_sdk import Choice, Noul, Score, TypeSafeClient

client = TypeSafeClient(
    base_url="http://127.0.0.1:17434",
    api_key="llmman",
    model="gemma4",
    timeout=120,
)
result = client.system_one(
    "I've been trying to connect my Stripe account for 3 days and the integration keeps failing. I'm losing sales.",
    {
        "team": Choice(
            instructions="Which team should handle this ticket?",
            criteria={
                "billing": "Payment or subscription issues",
                "technical": "Bugs or integration problems",
                "sales": "Pricing or account questions",
            },
        ),
        "revenue": Noul(instructions="The customer is losing revenue because of this."),
        "frustration": Score(
            instructions="How frustrated is the customer?",
            criteria=["Calm", "Frustrated but civil", "Very angry"],
        ),
    },
)
print(result.choices["team"].choice, round(result.choices["team"].confidence, 3))
print(round(result.nouls["revenue"].noul, 3))
print(round(result.scores["frustration"].score, 2))
```

```
technical 1.0
1.0
1.04
```

Raise `timeout` if the model has to load first.

## What it does not do

- `model` has to be a local GGUF. A hosted provider's API shows no token
  probabilities, so a provider's model, a hybrid pair, and a model served
  by vLLM, SGLang or MLX are each refused with a 400.
- A choice takes up to 255 options, a score up to 10 levels, and a
  request up to 64 questions. Options past 26 get two-letter labels where
  the tokenizer gives each one token.
- The context starts at 2048 tokens and doubles as prompts need it, up
  to `LLMMAN_CONTEXT_LENGTH` or the model's trained context. A longer
  prompt is a 400.

Details are in
[docs/api.md](https://github.com/llmmanorg/llmman/blob/main/docs/api.md#system-one-api-notes).
Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
Don't be afraid to give the project a star or open a PR.
