# Module contract

Every capability the agent has is a module. A module is a folder with one definition, one executor and its tests. Adding a feature means adding a folder and one line in the registry.

## Shape (Dart sketch, not final code)

```dart
enum ModuleKind { data, interaction, action }

/// One tool the model (or the orchestrator) can call.
abstract class AgentTool {
  String get name;            // snake_case, ASCII, stable: 'search_guides'
  String get description;     // one line, Polish, for the model; <= 120 chars
  Map<String, Object?> get parameters; // JSON schema, flat, enums where possible
  ModuleKind get kind;

  /// Data: returns compact text for the model.
  /// Interaction: returns a widget spec; may complete later (form answers).
  /// Action: returns a button spec; never acts by itself.
  Future<ToolResult> run(Map<String, Object?> args, TurnContext ctx);
}

class ToolResult {
  final String forModel;          // what goes into the context; budgeted (see below)
  final List<SourceRef> sources;  // cited material, numbered by the orchestrator
  final UiSpec? ui;               // interaction/action: what to render
  final bool waitsForUser;        // form: the turn pauses until the user answers
}
```

`TurnContext` gives a module read access to what it needs, all through providers: profile, location, settings, packs, and the token budget left for its result.

## Rules for every module

1. **Never throws to the model.** Errors come back as `forModel: 'błąd: …'`, so the model can say so.
2. **Budgeted output.** `forModel` respects `ctx.budgetTokens` and a module default (see [context budget](../04-context/budget-4096.md)). Long data is summarised or paged ("pokaż więcej" as a second call), never dumped.
3. **Sources travel with data.** Anything from a guide or a dataset returns `SourceRef`s. The orchestrator assigns [n].
4. **Validated input.** Arguments are checked against the schema and an allowlist before `run`; an unknown tool name is ignored and logged.
5. **Offline first.** A module works without the internet or reports clearly what is missing (e.g. "brak paczki mapy dla tego województwa").
6. **Testable without the model.** Each module has unit tests calling `run` directly; interaction modules also have a widget test of the renderer.
7. **Actions never act.** An action module renders a button; the platform call (dialer, SMS) runs only from the user's tap.

## Registry

```dart
final agentModules = <AgentTool>[
  SearchGuidesTool(),     // data; also called by the orchestrator every content turn
  ProfileTool(),          // data
  MapPlaceTool(), MapRouteTool(), // data + interaction (navigation)
  RescueCardTool(),       // interaction
  FormTool(), TodoTool(), // interaction
  Call112Tool(),          // action
];
```

The orchestrator exposes only a **subset per turn** (2–3 optional tools) chosen by simple rules: intent words, an open form, an active map. A small model chooses badly from a long list.

## Adding a new module (checklist)

1. Folder `app/lib/agent/modules/<name>/` with the tool, executor and tests.
2. Polish one-line description, flat schema, budget default.
3. Register it; add a selection rule (when the orchestrator offers it).
4. If it renders something: renderer from the design system, no new look without a design decision.
5. Eval: add 5+ Polish questions that should use it to the eval set ([roadmap](../09-roadmap/plan.md), M0) and check tool-choice accuracy on a phone.
6. Spec: one file in `bezpiecznik/02-funkcje/` describing behaviour.

Candidates already in the spec for later: AED locator (`08-w-przyszlosci/aed.md`), field modules (`moduly-terenowe.md`), voice (`glos.md`), rescue signal (`05-alarm/sygnal-ratunkowy.md`).
