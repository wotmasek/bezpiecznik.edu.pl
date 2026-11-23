# Cleanup at merge

`docs/` is a working folder. Before the final merge to `main`, move what stays true into the spec and delete the rest.

| From `docs/` | To the spec (`bezpiecznik/`) |
|---|---|
| `03-architecture/*` | `05-technologia/architektura.md` (agent section), new `05-technologia/agent-i-moduly.md` |
| `03-architecture/modules.md` | One file per module in `02-funkcje/` where behaviour is user-visible (map: `03-mapa/`) |
| `04-context/budget-4096.md` | `05-technologia/lokalne-ai.md` |
| `05-retrieval/hybrid-search.md` | `02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md` (rewrite: "odpowiedzi ze źródłami") |
| `06-answers/citations.md` | `03-ekrany/szablony-czatu.md`, `02-funkcje/01-czat/panele.md` |
| `07-safety/safety.md` | `01-wizja/zasady.md`, `02-funkcje/02-pierwsza-pomoc/karty-ratunkowe.md` |
| `08-performance/performance.md` | `05-technologia/wymagania-systemowe.md` |
| `02-decisions/decisions.md` | Spec decision log in `bezpiecznik/README.md` (one row per decision) |
| `01-diagnosis/*`, `09-roadmap/*` | Not moved: history. Delete. |

Checklist:

- [ ] Every "Decided" row is reflected in the spec.
- [ ] No spec file still describes the keyword gate, the JSON-only answer or "Rozmowa – nie z poradników".
- [ ] `git rm -r docs/`.
