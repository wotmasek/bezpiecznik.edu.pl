# Agent loop on the device

## What the stack offers (checked 2026-11-23)

Checked in the package source in `~/.pub-cache` and on the official pages.

- **The app uses `flutter_edge_ai`**, not flutter_gemma, with the LiteRT-LM engine (`flutter_edge_ai_litertlm`).
- **Gemma 4 E2B supports native function calling.** Format: https://gemma.ai/get-started/capabilities/function-calling/
- **flutter_edge_ai exposes:**
  - `Tool(name, description, parameters)`,
  - `openChat(tools:, supportsFunctionCalls: true)`,
  - a built-in tool loop with `maxToolTurns`,
  - `Message.toolResponse`.

  For `.litertlm` Gemma 4, the runtime renders the tool declarations itself.
- **`responseFormat` (JSON schema) cannot be combined with `tools`.** It throws `ArgumentError`. This does not matter here: the answer is free text.
- **Reliability is the open question.** The one independent test found (E4B, a stronger model) passed 2 of 6 agent tasks. The failures:
  - describing a tool instead of calling it,
  - ignoring "required",
  - no chaining.

  E2B is unmeasured. Treat tool use as optional help, not as the backbone.

## The loop

```
turn(userText):
  safety.check(userText)                    # may pin 112, may set crisis mode
  snippets = searchGuides(userText + prevUserTurn)   # app-side, always for content
  tools    = selectTools(turnContext)       # 2–3 optional tools
  conv.add(user: userText, context: snippets.compact)
  for step in 1..2:                          # max 2 tool calls
    out = conv.generate(tools)
    if out is ToolCall and allowed(out):
      result = registry.run(out)            # never throws
      if result.waitsForUser: render(result.ui); await userAnswer; result = answer
      conv.add(toolResponse: result.forModel)
      continue
    break
  render(markdown(out.text), citations(snippets, toolSources))
```

## Rules that make it work with a small model

1. **Retrieval is not the model's decision.** The orchestrator searches every content turn. The model may search again with a better query.
2. **Few tools, flat schemas, enum arguments, Polish one-line descriptions.**
3. **Max 2 tool calls per answer.** At the limit, the model must answer with what it has. Reaching `maxToolTurns` ends the stream silently in flutter_edge_ai, so the orchestrator handles it.
4. **Parse failures are text.** A malformed call is treated as plain answer text and logged. It is never retried in a loop.
5. **Clear the text buffer on a tool call.** Gemma 4 often writes a sentence before calling.
6. **Allowlist and validate** the name and arguments before dispatch.
7. **Thinking mode off** for latency.
8. **Measure tool-choice accuracy on the phone** with the eval set (M0) before trusting any tool.

## Fallbacks

| Failure | What the user gets |
|---|---|
| Model not downloaded or "Tryb bez AI" | Snippets as quotes (today's no-AI mode), rescue cards, map, SOS |
| Model error or timeout | Same as above, plus a note |
| Tool error | The model is told; it answers without it |
| No snippet found | The model answers and says the guides do not cover it; the answer is marked unsourced |
