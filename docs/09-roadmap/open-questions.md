# Open questions

| # | Question | Options | Recommendation | Who decides |
|---|---|---|---|---|
| Q1 | Rescue cards deterministic? | Verified assets only / model may rewrite | Verified only; the model opens them (D10) | Decided |
| Q2 | Should the model decide when to search the guides? | Always app-side / model's tool only / both | Both: app searches every content turn, model may search again (D8) | Decided |
| Q3 | Which embedding model? | EmbeddingGemma 2, EmbeddingGemma, Gecko | Decide by recall@3 on Polish eval (M3) | Data |
| Q4 | Whole-Poland offline routing and address search: what data, how big? | Road graph + address index per region pack / Poland-wide | Measure in M6 before promising "anywhere in Poland" | Data, then owner |
| Q5 | History compaction | Summary pass by the model / keep last N turns | Last N first; summary only if eval shows lost context | Data |
| Q6 | Tool-choice threshold to enable a tool | 70% / 80% / 90% | 80% on the phone eval | Owner |
| Q7 | Context by RAM | Fixed 4096 / dynamic | Fixed 4096, RAM only lowers it (D6) | Decided |
| Q8 | GPU | Off / opt-in / auto by device list | Opt-in in settings, FLOAT32 above 2k | Owner |
| Q9 | Where todo ticks live | In the message / in the profile (`supplies.kit[]`) | Profile, so the backpack list survives chats | Owner |
| Q10 | Crisis wording review | Internal / clinician or crisis-line volunteer | External review before release | Owner |
| Q11 | Answer label | "Z poradników" / "Rozmowa" vs per-sentence markers only | Both: label on top, markers inline | Owner (design) |
| Q12 | Can the tool set change inside a live conversation? flutter_edge_ai takes `tools` when the chat is opened | Fixed small set per conversation / reopen the chat when the set changes / offer all and gate calls in the orchestrator | Check the API in M1; default: fixed set of ≤ 5 tools per conversation, gated by the orchestrator | Data |
