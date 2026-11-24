# LLM adapter (`czat/llm`)

`LlmEngine` is the only AI entry point for the chat. Selection by
`--dart-define=LLM=host|edge|off` (see `wspolne/config.dart`); `llmEngineProvider`
builds the engine and disposes it.

| Mode | Engine | Notes |
|---|---|---|
| host | `HostLlmEngine` | llama-server, OpenAI-compatible, `http://127.0.0.1:8080` (`adb reverse tcp:8080 tcp:8080`). Override with `--dart-define=LLM_URL=...`. Thinking off, SSE streaming, `json_object` by default. |
| edge | `EdgeAiEngine` | `flutter_edge_ai` + LiteRT-LM, arm64 only. Native code is touched only at the first `warmUp()`. |
| off | `OffEngine` | `generate` fails with `LlmDisabled`; chat shows source quotes. |

Every generation logs `ttft`, `total`, token count via `dart:developer`
(`name: 'llm'`) and exposes it as `lastTiming`.

## On-device model (edge mode)

File name: `gemma-4-E2B-it.litertlm`. Looked up in this order:

1. `getApplicationDocumentsDirectory()` -> `/data/user/0/pl.edu.bezpiecznik.bezpiecznik/app_flutter/`
   (not writable by `adb push` without root; `run-as` only on debug builds)
2. `getExternalStorageDirectory()` -> `/sdcard/Android/data/pl.edu.bezpiecznik.bezpiecznik/files/`

Push without root:

```
adb shell mkdir -p /sdcard/Android/data/pl.edu.bezpiecznik.bezpiecznik/files
adb push gemma-4-E2B-it.litertlm /sdcard/Android/data/pl.edu.bezpiecznik.bezpiecznik/files/
```

Missing file -> `LlmUnavailable('Model AI nie jest jeszcze pobrany.')`.

## Backend (edge mode)

CPU (XNNPACK) by default. Measured on a Galaxy A55 (Exynos 1480, Samsung
Xclipse 530), 2026-11-21: on the GPU (OpenCL, float16) every answer was
random tokens, with a 4096 and with a 2048 token context; on the CPU the same
question got a valid sourced answer in under a minute including the model
load. To measure another phone:

```
--dart-define=LLM_BACKEND=gpu            # GPU, the bundle's float16
--dart-define=LLM_BACKEND=gpu --dart-define=LLM_FP32=true
```

The model is loaded with a 2048-token context; `answer_prompt.dart` keeps
prompt + answer inside it. `--dart-define=CHAT_LOG=true` prints rejected and
unparseable model output to logcat (test builds only: it contains the text of
the conversation).

## Dependency note

`flutter_edge_ai` core registers no inference engine. Edge mode needs
`flutter_edge_ai_litertlm` in pubspec and `edgeInferenceEnginesProvider`
overridden with `[LiteRtLmEngine()]` (or passed to `createLlmEngine`).
Without it the first `warmUp()` fails with `LlmUnavailable`.

## JSON output

`LlmRequest.jsonMode` -> `response_format: json_object` (host) /
`ResponseFormat.jsonObject()` (edge). With `jsonSchema`: edge uses
`ResponseFormat.jsonSchema`, falling back to no format when refused
(`ResponseFormatUnsupportedException`); host sends `json_object` unless
`useJsonSchemaFormat: true`. In the fallback the schema must be in the prompt.

## Live conversation (edge mode, D7)

A request with `conversationId` (and no JSON mode/schema) goes to the one
live chat (`LiveConversation`, `live_conversation.dart`). It is continued when
id, system prompt, temperature and `maxTokens` match and the messages it read
(including its own replies, verbatim) are an exact prefix of the request: only
the new messages are sent. Anything else, and any stop, cancel or error,
closes it; the next request reopens it with the full history flattened into
one user message (the `.litertlm` session cannot be given assistant turns).
JSON and id-less requests use a one-shot chat and leave the live one open.
`lastTiming` shows `reused=true|false` for live requests.
