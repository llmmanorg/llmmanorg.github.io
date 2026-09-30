+++
title = "llmman now speaks System One"
description = "POST /v1/systemone turns a state and a few typed questions into a probability per answer. llmman reads them from a local model such as Gemma 4, or asks a hosted one such as claude-sonnet-5-5 at xhigh."
date = 2026-09-30

[taxonomies]
tags = ["serve", "providers", "system-one"]
+++

System One is an API for decisions rather than text. You send a state and
a few typed questions, and get back a probability for every possible
answer, with no free text to parse. As of
[#579](https://github.com/llmmanorg/llmman/pull/579), `llmman serve`
answers it at `/v1/systemone`, for a local model or for any hosted one.
llama.cpp is not adding a System One endpoint, so llmman provides it on
top of the `llama-server` it already runs.

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

## A local model: Gemma 4

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
      "confidence": 0.999999905064302,
      "probabilities": {
        "billing": 4.975824919073594E-8,
        "technical": 0.9999999367095347,
        "sales": 1.3532216097173669E-8
      },
      "x_label_mass": 0.9999999440811793,
      "x_source": "logprobs"
    },
    "revenue": {
      "type": "noul",
      "noul": 0.9999770353810086,
      "x_label_mass": 0.9999987312360447,
      "x_source": "logprobs"
    },
    "frustration": {
      "type": "score",
      "score": 1.0398614830488992,
      "confidence": 0.9402071821761258,
      "legend": {
        "0": "Calm",
        "1": "Frustrated but civil",
        "2": "Very angry"
      },
      "probabilities": {
        "0": 1.9775017517482435E-7,
        "1": 0.9601381214507505,
        "2": 0.039861680799074324
      },
      "x_label_mass": 0.9999992137222249,
      "x_source": "logprobs"
    }
  },
  "usage": {
    "input_tokens": 222,
    "output_tokens": 0
  }
}
```

llmman loaded `gemma4`, turned each question into one user turn through
the model's own chat template with thinking off, and read the model's
next-token probability of each answer label (`A`, `B`, `C` for the
options, a digit for a level, `yes` or `no`), renormalised over the
labels. Nothing was generated, which is why `output_tokens` is 0, and
with the model already loaded the request took under a second. The
questions share their state, so `llama-server`'s prompt cache reads it
once.

Gemma 4 is sure of itself here: `technical` at 0.9999999, and "Frustrated
but civil" at 0.96. `x_label_mass` is how much probability the model put
on the labels at all, before renormalising, and it tells you whether to
believe the rest. Ask Gemma 4 something it does not want to answer with a
yes or no:

```json
{
  "type": "noul",
  "noul": 0.0068429411894585426,
  "x_label_mass": 0.017658317594327223,
  "x_source": "logprobs"
}
```

That was "The customer needs an answer today." Under 2% of the
probability went to yes or no, because the model starts a sentence
instead, so the 0.007 is the ratio of two tiny numbers and should be
ignored. A low mass is the model telling you it is not answering the
question you asked.

One correction to our own work. Gemma 4 writes yes and no with a capital:
`Yes` at 1.000 where `yes` is 0.000. The first version of `noul` counted
only the lowercase tokens, so `x_label_mass` read close to 0.0 on most yes/no questions.

## A hosted model: claude-sonnet-5-5 at xhigh

Same request, with only the model changed:

```sh
jq '.model = "anthropic/claude-sonnet-5-5/xhigh"' ticket.json \
  | curl -s http://127.0.0.1:17434/v1/systemone -d @- \
  | jq '{model, answers: (.answers | map_values(del(.legend))), usage}'
```

```json
{
  "model": "llmman.provider/anthropic/claude-sonnet-5-5",
  "answers": {
    "team": {
      "type": "choice",
      "choice": "technical",
      "confidence": 0.7749999999999999,
      "probabilities": {
        "billing": 0.12,
        "technical": 0.85,
        "sales": 0.03
      },
      "x_source": "elicited"
    },
    "revenue": {
      "type": "noul",
      "noul": 0.94,
      "x_source": "elicited"
    },
    "frustration": {
      "type": "score",
      "score": 1.0899999999999999,
      "confidence": 0.7449999999999999,
      "probabilities": {
        "0": 0.04,
        "1": 0.83,
        "2": 0.13
      },
      "x_source": "elicited"
    }
  },
  "usage": {
    "input_tokens": 698,
    "output_tokens": 297
  }
}
```

`anthropic/claude-sonnet-5-5/xhigh` is a provider, a model and a
variant. The variant is how hard the model thinks before it answers:
`none`, `minimal`, `low`, `medium`, `high`, `xhigh` or `max`, which llmman
hands to each provider in its own form (its catalog lists `low` through
`max` for this model). Anthropic gets adaptive thinking with
`output_config.effort` set to `xhigh`. An SDK can
only set `model`, which is why the variant can ride on the end of it.
These are the same request:

```
"model": "anthropic/claude-sonnet-5-5/xhigh"
"model": "llmman.provider/anthropic/claude-sonnet-5-5/xhigh"
"model": "llmman.provider/anthropic/claude-sonnet-5-5", "reasoning_effort": "xhigh"
```

The key comes from `ANTHROPIC_API_KEY` or `llmman.conf`, as it does for
`llmman launch --provider anthropic`. The bare two-part form,
`anthropic/claude-sonnet-5-5`, stays a Hugging Face repository, as it does
everywhere else in llmman.

A hosted model cannot be read the way Gemma 4 was. Anthropic's API has no
token probabilities at all, and a model thinking at `xhigh` has no first
token to read anyway. So llmman asks: one request per question, four at a
time, through the same path as any other hosted call, telling the model to
state a probability for every answer as JSON. That is what
`"x_source": "elicited"` means, and why there is no `x_label_mass`.
`usage` counts what the provider billed, and `llmman usage` prices it:

```
$ llmman usage --provider anthropic --route systemone
MODEL                                          PROVIDER     REQUESTS    INPUT    CACHED    OUTPUT    COST
llmman.provider/anthropic/claude-sonnet-5-5    anthropic    1           698      0         297       $0.0044
```

Side by side, for the same ticket:

| | Gemma 4, read | claude-sonnet-5-5 at xhigh, asked |
|---|---|---|
| `team` | technical, 1.0000 (billing 5e-8) | technical, 0.85 (billing 0.12) |
| `revenue` | 1.00 | 0.94 |
| `frustration` | 1.04 (level 1 at 0.96) | 1.09 (level 1 at 0.83) |
| time | 0.9 s, model loaded | 4.2 s |
| tokens | 222 in, 0 out | 698 in, 297 out |
| cost | none | $0.0044 |

## From an existing client

Clients written for System One work by pointing their base URL at the
daemon. This is the [TypeSafe](https://typesafe.ai) Python SDK
(`pip install typesafe-sdk`, 0.7.2), calling Claude through llmman:

```python
from typesafe_sdk import Choice, Noul, Score, TypeSafeClient

client = TypeSafeClient(
    base_url="http://127.0.0.1:17434",
    api_key="llmman",
    model="anthropic/claude-sonnet-5-5/xhigh",
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
technical 0.775
0.93
1.12
```

Change `model=` to `"gemma4"` and the same script reads Gemma 4 instead;
it printed `technical 1.0`, `1.0` and `1.04`. Two details. The SDK sends
`api_key` to llmman, and llmman forwards a caller's key to the provider,
so `llmman` is the placeholder that means "use the daemon's own key";
pass a real Anthropic key instead and that one is used for the request.
And the SDK gives up after 10 seconds by default and retries, which a
model that has to load, or a long `xhigh` think, can outlast, so the
example raises `timeout`.

## What to trust

Both kinds of number are useful, and they are not the same thing.

- A token probability is the model's own, repeats from run to run, and
  is checked by `x_label_mass`. A stated probability is the model's account
  of its own uncertainty, and moves between runs: asked again, Claude said
  0.93 for `revenue` where it had said 0.94, and 1.12 for `frustration`
  where it had said 1.09.
- Neither is a calibrated probability that the answer is right, and a
  threshold tuned on one does not carry over to the other. Tune it on your
  own labelled tickets.
- Reading a local model needs `llama-server`. A model served by vLLM,
  SGLang or MLX is refused with a 501 that names the engine.
- A choice takes up to 26 options and a request up to 64 questions. Each
  hosted question is its own paid request, and repeats the state.
- `model` has to be something llmman serves. An SDK's default name
  resolves to nothing here.

Details are in
[docs/api.md](https://github.com/llmmanorg/llmman/blob/main/docs/api.md#system-one-api-notes).
Questions are welcome at
[github.com/llmmanorg/llmman](https://github.com/llmmanorg/llmman).
Don't be afraid to give the project a star or open a PR.
