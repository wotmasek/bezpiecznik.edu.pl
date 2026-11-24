# Tool probe: live chat and native tool calling on the phone

Date: 2026-11-24, 10:17–10:30 CET. Device: Pixel 9 (`47270DLAQ00421`), USB powered.
Model: `gemma-4-E2B-it.litertlm`, flutter_edge_ai 2.7.1 + flutter_edge_ai_litertlm 1.21.0,
`PreferredBackend.cpu`, `maxTokens: 4096`, `temperature: 0`.
Test: `app/integration_test/tool_probe_test.dart`. All `PROBE:` lines of the three runs: `probe.log`.

How the numbers were taken:
- `ttft_ms` / `total_ms`: Dart stopwatch from `generateChatResponseAsync()` to the first / last response.
- `m_in` / `m_out` / `m_ttft`: `chat.session.getSessionMetrics()` (LiteRT-LM `BenchmarkInfo`), read after the turn.
  In one open conversation `m_in` and `m_out` are cumulative, and `m_ttft` stays at the first turn's value.
- Prefill per turn = the `m_in` delta (live) or `m_in` (reopen).
- Decode tok/s = (output tokens − 1) / (total − ttft). Output tokens counted with `sizeInTokens` after the chats closed.
- Token sizes: system prompt 306, user turns 554 / 492 / 524 / 535 (each ~1.7k chars of `bench_corpus.txt` + a question), 0.307 tokens/char.

## Experiment A: live chat vs. reopened chat per turn

Live = one `InferenceChat`, `addQuery` with only the new user message.
Reopen = a new chat per turn with the history flattened into one user message (today's behaviour).
Both use `systemInstruction` (306 tokens) and `maxOutputTokens: 160`.

### Run 1 (10:18)

| turn | variant | prefill tokens | ttft ms | total ms | out tokens | decode tok/s |
|---|---|---|---|---|---|---|
| 1 | live | 874 | 7685 | 12327 | 82 | 17.4 |
| 2 | live | 500 | 2459 | 2604 | 3 | (3 tokens) |
| 3 | live | 532 | 2803 | 4831 | 38 | 18.2 |
| 4 | live | 543 | 2651 | 3918 | 24 | 18.2 |
| 1 | reopen | 874 | 3365 | 7884 | 82 | 17.9 |
| 2 | reopen | 1475 | 7156 | 13323 | 111 | 17.8 |
| 3 | reopen | 2121 | 9752 | 15493 | 102 | 17.6 |
| 4 | reopen | 2769 | 12357 | 12586 | 5 | (5 tokens) |

Turns 2–4: live prefilled 1575 tokens and waited 7913 ms for first tokens in total; reopen prefilled 6365 tokens and waited 29265 ms.
Live turn 1 is the first chat after model load (cold); reopen turn 1, same 874 tokens, took 3365 ms.
Prefill rate: reopen 266 / 209 / 219 / 226 tok/s (`m_in / m_ttft`); live turns 2–4 ~190–205 tok/s.

### Run 3 (10:25, repeat of A)

| turn | variant | prefill tokens | ttft ms | total ms | out tokens | decode tok/s |
|---|---|---|---|---|---|---|
| 1 | live | 874 | 3632 | 8247 | 82 | 17.6 |
| 2 | live | 500 | 2148 | 2262 | 3 | (3 tokens) |
| 3 | live | 532 | 2623 | 4749 | 38 | 17.4 |
| 4 | live | 543 | 2748 | 4112 | 24 | 16.9 |
| 1 | reopen | 874 | 4425 | 10693 | 82 | 12.9 |
| 2 | reopen | 1475 | 10657 | 18930 | 111 | 13.3 |
| 3 | reopen | 2121 | 50478 | 85436 | 102 | 2.9 |
| 4 | reopen | 2769 | 83396 | 84820 | 5 | (5 tokens) |

The phone slowed down during the reopen half of run 3: decode fell to 2.8–2.9 tok/s (the seed check after it also: 2.8 tok/s).
At 10:28 `top` showed 462 MB RAM free and swap 5161 / 5602 MB used, app RES 2.8 GB, app at 344 % CPU; `dumpsys thermalservice` said status 0 (no throttling).
So it looks like memory pressure, not heat, but the cause was not confirmed. Run 3 reopen turns 3–4 are not a fair comparison; run 1 is.

### Answer quality (same in both runs, temperature 0)

- Turn 1: both variants gave the same answer (same input).
- Turn 2 ("Co z tego fragmentu dotyczy rodziny z małym dzieckiem?"): live answered only "Nie wiem."; reopen gave a 111-token answer.
- Turn 4 ("Przypomnij … o co zapytałem w pierwszym pytaniu"): live answered "Pytasz, co zrobić najpierw w sytuacji, gdy napotkasz osobę potrzebującą pomocy." (right: the first question was "co mam zrobić najpierw"); reopen answered only "Spokojnie."
- One prompt set; this says nothing general about quality.

### Context use

Live turn 4 ended at 2449 input + 151 output tokens = 2600 of 4096. Previous answers were not prefilled again
(`m_in` grew by ~ the user message + ~8 tokens per turn). What the chat does when it reaches `maxTokens` was not tested.

### Seeding a fresh chat with earlier turns

`clearHistory(replayHistory: [user "Zapamiętaj: kod … ZIELONY-47.", Message(isUser: false) "Zapamiętałem. … ZIELONY-47."])`, then a new user question:

| run | replay ms | ttft ms | total ms | m_in | recalled |
|---|---|---|---|---|---|
| 1 | 3 | 1562 | 2207 | 376 | yes, "Podałeś kod ZIELONY-47." |
| 3 | 17 | 11351 | 15331 | 376 | yes (slow phone, see above) |

It works, but not as a real assistant turn. On `.litertlm` every message is formatted raw
(`flutter_edge_ai-2.7.1/lib/src/extensions.dart`: "the LiteRT-LM Conversation API applies the model's own chat template … so the message goes in raw"),
and the LiteRT-LM session only appends its text to `_queryBuffer` (`flutter_edge_ai_litertlm-1.21.0/lib/src/adapter/ffi_inference_model.dart`, `addQueryChunk`).
`_takeTurnMessage` then sends the whole buffer as one `lm.Role.user` message (or one `tool` message) at generation time.
So the replay, the assistant text and the new question all go out as one user message. It has the same prefill cost as today's flattening.
A seeded chat does not save prefill. Only a chat that is kept open does.

## Experiment B: native tool calling

3 tools (`get_profile` section enum, `map_find_place` what, `show_form` questions[]), Polish one-line descriptions.
A fresh chat per prompt: `openChat(tools:, supportsFunctionCalls: true, modelType: ModelType.gemma4, maxOutputTokens: 200)`.
Run 1 system prompt: "Jesteś Bezpiecznikiem … Używaj narzędzi tylko wtedy, gdy są potrzebne."
Run 2 adds one sentence (`TOOL_HINT=true`): "Masz dostęp do profilu użytkownika (adres, domownicy, leki, zwierzęta), do mapy offline z lokalizacją telefonu i schronami oraz do formularza …".
The tool result was not fed back. We only measured the first response.

| # | prompt | expected | run 1 (plain) | ms | run 2 (hint) | ms |
|---|---|---|---|---|---|---|
| 1 | Ile osób mieszka ze mną? | get_profile | get_profile{section: domownicy} | 4745 | get_profile{section: domownicy} | 5673 |
| 2 | Jakie leki biorę na stałe? | get_profile | get_profile{section: leki} | 4456 | get_profile{section: leki} | 4919 |
| 3 | Czy mam w domu jakieś zwierzęta, … przy ewakuacji? | get_profile | get_profile{section: zwierzeta} | 4533 | get_profile{section: zwierzeta} | 5150 |
| 4 | Jaki jest mój adres zamieszkania? | get_profile | text: "nie mam dostępu do Twoich danych" | 5364 | text: same | 5810 |
| 5 | Gdzie jest najbliższy schron? | map_find_place | text: "podaj mi swoją aktualną lokalizację" | 5191 | map_find_place{what: schron} | 5364 |
| 6 | Zaprowadź mnie do domu | map_find_place | map_find_place{what: dom} | 4617 | map_find_place{what: dom} | 4820 |
| 7 | Jak dojść do najbliższego szpitala? | map_find_place | map_find_place{what: szpital} | 4784 | map_find_place{what: szpital} | 5451 |
| 8 | Pokaż mi na mapie, gdzie mogę się schronić | map_find_place | map_find_place{what: schron} | 4601 | map_find_place{what: schron} | 5592 |
| 9 | Pomóż mi przygotować plan, ale nie wiem od czego zacząć | show_form | text: "o jaki plan chodzi?" | 5121 | text: same | 6767 |
| 10 | Chcę zrobić plan ewakuacji rodziny, zadawaj mi pytania | show_form | text: asks questions in prose | 10246 | text: same | 12633 |
| 11 | Przygotuj ze mną listę rzeczy do plecaka … dopasowaną do mnie | show_form | text: asks questions in prose | 11890 | text: same | 21663 |
| 12 | Jak zatamować krwawienie? | none | text | 15321 | text | 20057 |
| 13 | Dzięki | none | text "W czym mogę pomóc?" | 4389 | text | 5695 |
| 14 | Co zrobić, gdy zabraknie prądu na kilka dni? | none | text | 6245 | text | 19195 |
| 15 | Ile wody na osobę trzeba mieć w zapasie? | none | text (asks back) | 6085 | text (asks back) | 9042 |
| 16 | Cześć, kim jesteś? | none | text | 5195 | text | 7529 |

ms = time to the call, or the whole text turn.

| | run 1 | run 2 (hint) |
|---|---|---|
| accuracy | **11/16** | **12/16** |
| get_profile | 3/4 | 3/4 |
| map_find_place | 3/4 | 4/4 |
| show_form | 0/3 | 0/3 |
| none (no false calls) | 5/5 | 5/5 |
| described the tool in text | 0 | 0 |
| wrong tool / bad args | 0 | 0 |
| tool call latency | 4456–4784 ms | 4820–5673 ms |
| prompt tokens (`m_in`) | 324–343 | 380–399 |

- Every call was a single `FunctionCallResponse`, and every argument was valid: enum values and `what` exactly as expected.
  There were no parallel calls, no raw `<|tool_call>` text and no calls on chit-chat or first-aid questions.
- `show_form` was never called. The model asks its questions in prose instead. This holds with the hint sentence too.
- Latency gap, not explained: native `m_ttft` was 1415–1537 ms (run 1), but a call reached Dart after 4456–4784 ms, and the first text chunk after 3766–4104 ms.
  Without tools (A, reopen turn 1) the Dart ttft and `m_ttft` differ by only ~80 ms.
  A plausible cause is the chat buffering the stream to detect a call (`maxFunctionBufferLength`), but I did not check it.
- Run 2 decode fell to 12.8–14.9 tok/s in its second half (run 1: 17.2–18.2). That is the same slowdown seen in run 3.

### Q12: can the tool list change inside one open chat?

Package source, `flutter_edge_ai-2.7.1/lib/src/chat.dart`:

```dart
  final List<Tool> _tools;

  /// Tools available to this chat, fixed for the chat's lifetime. A cached
  /// unmodifiable VIEW over `_tools` ...
  late final List<Tool> tools = UnmodifiableListView(_tools);
```

`openChat` (`interface.dart`) builds the `sessionCreator` closure with `tools: resolved.tools`.
`clearHistory()` creates its new session with that same closure, so it keeps the same tools.
There is no setter or `updateTools` anywhere in the package (grep for `setTools|updateTools|_tools =`).

Measured (chat opened with `[get_profile]` only):

| check | result |
|---|---|
| `chat.tools.add(map_find_place)` | threw `UnsupportedError` |
| add to the list passed to `openChat` afterwards | `chat.tools` still `[get_profile]` (the list is copied) |
| "Zaprowadź mnie do domu" in the same session (run 2) | no call; text "Proszę, podaj mi swoją obecną lokalizację…" |
| same after `clearHistory()` (run 2) | no call; same text |
| control: same prompt, `map_find_place` declared at `openChat` (B #6, both runs) | `map_find_place{what: dom}` |

(Run 1 used "Gdzie jest najbliższy schron?" for this check: no call either. That prompt is a weak control, though: it also failed in B run 1 with the tool declared.)

Answer: no. To change the tools you open a new chat, and getting the history there means a replay. On `.litertlm` a replay is a flattened prefill (see seeding above).
This rules out "live chat + per-turn tool sets". The tool set has to be fixed for the whole conversation, or each change pays a full re-prefill.

## Commands

```bash
export PATH=$HOME/development/flutter/bin:$PATH JAVA_HOME=$HOME/development/jdk21 ANDROID_HOME=$HOME/Android/Sdk
cd app
# screen kept awake during runs:
(while true; do $HOME/Android/Sdk/platform-tools/adb -s 47270DLAQ00421 shell input keyevent KEYCODE_WAKEUP; sleep 20; done) &
# run 1 (A + B + Q12; first version of the test, no defines)
flutter test integration_test/tool_probe_test.dart --no-uninstall -d 47270DLAQ00421
# run 2 (B with the hint sentence + Q12)
flutter test integration_test/tool_probe_test.dart --no-uninstall -d 47270DLAQ00421 --dart-define=PROBE=BQ --dart-define=TOOL_HINT=true
# run 3 (A again)
flutter test integration_test/tool_probe_test.dart --no-uninstall -d 47270DLAQ00421 --dart-define=PROBE=A
```

## Raw log excerpt (run 1)

```
PROBE: t=1795511879335 load_ms=1860 tokens_per_char=0.307 probe=AB
PROBE: t=1795511891672 A live turn=1 user_chars=1731 ttft_ms=7685 total_ms=12327 chunks=82 m_in=874 m_out=83 m_ttft=7020 m_tps=15.8 answer=Spokojnie. /  / 1. Wezwij pomoc, zadzwoń pod numer alarmowy 112 ...
PROBE: t=1795511894277 A live turn=2 user_chars=1714 ttft_ms=2459 total_ms=2604 chunks=3 m_in=1374 m_out=87 m_ttft=7020 m_tps=15.5 answer=Nie wiem.
PROBE: t=1795511899110 A live turn=3 user_chars=1704 ttft_ms=2803 total_ms=4831 chunks=38 m_in=1906 m_out=126 m_ttft=7020 m_tps=18.4 answer=Nie wolno przerywać uciśnięć klatki piersiowej ...
PROBE: t=1795511903030 A live turn=4 user_chars=1734 ttft_ms=2651 total_ms=3918 chunks=24 m_in=2449 m_out=151 m_ttft=7020 m_tps=18.1 answer=Pytasz, co zrobić najpierw w sytuacji, gdy napotkasz osobę potrzebującą pomocy.
PROBE: t=1795511924247 A reopen turn=2 prompt_chars=3739 ttft_ms=7156 total_ms=13323 chunks=111 m_in=1475 m_out=112 m_ttft=7046 m_tps=17.8 ...
PROBE: t=1795511952331 A reopen turn=4 prompt_chars=7911 ttft_ms=12357 total_ms=12586 chunks=5 m_in=2769 m_out=6 m_ttft=12272 m_tps=17.9 answer=Spokojnie.
PROBE: t=1795511954547 A seed replay_ms=3 ttft_ms=1562 total_ms=2207 m_in=376 m_out=13 m_ttft=1483 m_tps=17.3 history_len=4 recalled=true answer=Podałeś kod ZIELONY-47.
PROBE: t=1795511954567 A tokens system=306 user_turns=[554, 492, 524, 535] out_live=[82, 3, 38, 24] out_reopen=[82, 111, 102, 5]
PROBE: t=1795511959321 B expected=get_profile ok=true outcome=tool [get_profile{section: domownicy}] ttft_ms=4744 total_ms=4745 m_in=330 m_out=16 m_ttft=1537 m_tps=17.9 prompt="Ile osób mieszka ze mną?" text=
PROBE: t=1795511979524 B expected=map_find_place ok=false outcome=text ttft_ms=3947 total_ms=5191 m_in=330 m_out=24 m_ttft=1415 m_tps=17.7 prompt="Gdzie jest najbliższy schron?" text=Proszę, podaj mi swoją aktualną lokalizację, abym mógł znaleźć najbliższy schron.
PROBE: t=1795512060038 B accuracy=11/16
PROBE: t=1795512060043 Q12 chat.tools.add threw UnsupportedError
PROBE: t=1795512060044 Q12 after mutating the passed list chat.tools=[get_profile]
```

## Not done

- Each variant ran once per run (n=2 for A, of which run 3 is degraded). There is no variance estimate beyond that, and the prompts were not shuffled.
- The tool result was not fed back (`Message.toolResponse`), and `generateChatResponseWithTools` was not used. Only the first-response choice was measured.
- No GPU backend, no other `maxTokens`, no RAM sampling (`dumpsys meminfo`) during the runs.
- Behaviour at the 4096-token limit in a live chat (`_recreateSessionWithReducedChunks`) was not tested.
- The cause of the run 3 slowdown and of the ~2.5–3 s Dart-side delay with tools was not established.
