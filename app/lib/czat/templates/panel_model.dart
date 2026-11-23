import 'dart:convert';

/// Template JSON -> widget model (spec: bezpiecznik/03-ekrany/szablony-czatu.md).
///
/// Parsing is tolerant: anything malformed turns into [UnknownPanel] or is
/// dropped, never throws. The renderer ignores [UnknownPanel].

/// Source record ("Rekord zrodla" in the spec). Only the fields the renderer
/// needs. `text` falls back to `original` (the key used by rescue-card
/// `sources.json`).
class SourceRecord {
  const SourceRecord({
    required this.sourceId,
    this.docId = '',
    this.docTitle = '',
    this.docShort = '',
    this.publisher = '',
    this.issued = '',
    this.pageLabel = '',
    this.pdfPage = 0,
    this.pdfFile = '',
    this.text = '',
    this.rects = const [],
  });

  final String sourceId;
  final String docId;
  final String docTitle;
  final String docShort;
  final String publisher;
  final String issued;
  final String pageLabel;
  final int pdfPage;
  final String pdfFile;
  final String text;

  /// Highlight rectangles `[x, y, w, h]`, fractions 0-1 of the page.
  final List<List<double>> rects;

  /// Chip text, spec "Chip zrodla": `▸ {doc_short}, s. {page_label}`.
  String get chipLabel => '▸ $docShort, s. $pageLabel';

  /// Screen-reader label, spec: "Zrodlo: {doc_title}, strona {page_label}. Otworz."
  String get semanticLabel => 'Źródło: $docTitle, strona $pageLabel. Otwórz.';

  static SourceRecord? tryParse(Object? json, {String? fallbackId}) {
    if (json is! Map) return null;
    final id = _str(json['source_id']) ?? fallbackId;
    if (id == null || id.isEmpty) return null;
    return SourceRecord(
      sourceId: id,
      docId: _str(json['doc_id']) ?? '',
      docTitle: _str(json['doc_title']) ?? '',
      docShort: _str(json['doc_short']) ?? '',
      publisher: _str(json['publisher']) ?? '',
      issued: _str(json['issued']) ?? '',
      pageLabel: _str(json['page_label']) ?? '',
      pdfPage: _int(json['pdf_page']) ?? 0,
      pdfFile: _str(json['pdf_file']) ?? '',
      text: _str(json['text']) ?? _str(json['original']) ?? '',
      rects: _rects(json['rects']),
    );
  }

  Map<String, Object?> toJson() => {
    'source_id': sourceId,
    'doc_id': docId,
    'doc_title': docTitle,
    'doc_short': docShort,
    'publisher': publisher,
    'issued': issued,
    'page_label': pageLabel,
    'pdf_page': pdfPage,
    'pdf_file': pdfFile,
    'text': text,
    'rects': rects,
  };

  @override
  bool operator ==(Object other) =>
      other is SourceRecord && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => sourceId.hashCode;
}

/// One element of `steps` / `bullets`.
class PanelItem {
  const PanelItem({required this.text, this.sourceId, this.kitId, this.cardLinkLabel, this.cardLinkId});

  final String text;
  final String? sourceId;

  /// `bullets` + `checkable`: id of the thing in the profile (`supplies.kit[].id`).
  final String? kitId;

  /// Rescue-card `card_link` ("Nie oddycha → RKO"): button label + target card id.
  final String? cardLinkLabel;
  final String? cardLinkId;
}

/// `steps` variant (`adult`, `child`, `infant`...).
class StepsVariant {
  const StepsVariant({required this.id, required this.label, required this.items});

  final String id;
  final String label;
  final List<PanelItem> items;
}

/// Option of the segmented variant switch.
class VariantOption {
  const VariantOption(this.id, this.label);

  final String id;
  final String label;
}

/// A template of an assistant message (`panels[]` element).
sealed class ChatPanel {
  const ChatPanel(this.raw);

  /// The original JSON (kept so the message round-trips through storage).
  final Map<String, Object?> raw;

  /// Value of `panels[].type`.
  String get type;

  /// Variants the panel offers (only the first panel with variants draws the
  /// switch; see spec "Warianty"). Empty when none.
  List<VariantOption> get variantOptions => const [];

  /// Parses one `panels[]` element. Never throws; returns [UnknownPanel] for
  /// unknown types, malformed JSON and content templates without elements.
  factory ChatPanel.fromJson(Object? json) {
    if (json is! Map) return const UnknownPanel(null, {});
    final map = Map<String, Object?>.from(json);
    final type = _str(map['type']);
    try {
      switch (type) {
        case 'steps':
          return StepsPanel._parse(map) ?? UnknownPanel(type, map);
        case 'bullets':
          // Legacy: checkable bullets (stored chats) are a to-do list now.
          if (map['checkable'] == true) return TodoPanel._parse(map) ?? UnknownPanel(type, map);
          return BulletsPanel._parse(map) ?? UnknownPanel(type, map);
        case 'todo':
          return TodoPanel._parse(map) ?? UnknownPanel(type, map);
        case 'form':
          return FormPanel._parse(map) ?? UnknownPanel(type, map);
        case 'quote':
          final id = _str(map['source_id']);
          if (id == null || id.isEmpty) return UnknownPanel(type, map);
          return QuotePanel(
            sourceId: id,
            title: _str(map['title']) ?? 'Źródło',
            raw: map,
          );
        case 'no_source':
        case 'refusal':
          return NoSourcePanel(NoSourceKind.parse(_str(map['kind'])), map);
        case 'call':
          return CallPanel(map);
        case 'chat_text':
          final text = _str(map['text']);
          if (text == null || text.trim().isEmpty) return UnknownPanel(type, map);
          return ChatTextPanel(text, map);
        case 'cpr':
          return CprPanel._parse(map);
        case 'map':
          return MapPanel(target: _str(map['target']) ?? 'nearest_shelter', raw: map);
        case 'signal':
          return SignalPanel(
            modes: _strList(map['modes']) ?? const ['sound', 'flashlight', 'screen'],
            raw: map,
          );
        case 'animation':
          return AnimationPanel._parse(map);
      }
    } on Object {
      // Malformed content never reaches the UI.
    }
    return UnknownPanel(type, map);
  }
}

/// `steps`: numbered steps. Either [items] or [variants].
class StepsPanel extends ChatPanel {
  const StepsPanel({
    required this.title,
    this.readAloud = false,
    this.items = const [],
    this.variants = const [],
    Map<String, Object?> raw = const {},
  }) : super(raw);

  final String title;
  final bool readAloud;
  final List<PanelItem> items;
  final List<StepsVariant> variants;

  @override
  String get type => 'steps';

  @override
  List<VariantOption> get variantOptions => [
    for (final v in variants) VariantOption(v.id, v.label),
  ];

  /// Items for the selected variant (or the plain [items]).
  List<PanelItem> itemsFor(String? variantId) {
    if (variants.isEmpty) return items;
    final v = variants.firstWhere(
      (v) => v.id == variantId,
      orElse: () => variants.first,
    );
    return v.items;
  }

  static StepsPanel? _parse(Map<String, Object?> map) {
    final variants = <StepsVariant>[];
    final rawVariants = map['variants'];
    if (rawVariants is List) {
      for (final v in rawVariants) {
        if (v is! Map) continue;
        final id = _str(v['id']);
        final items = _items(v['items']);
        if (id == null || items.isEmpty) continue;
        variants.add(StepsVariant(id: id, label: _str(v['label']) ?? id, items: items));
      }
    }
    final items = _items(map['items']);
    if (variants.isEmpty && items.isEmpty) return null;
    return StepsPanel(
      title: _str(map['title']) ?? '',
      readAloud: map['read_aloud'] == true,
      items: variants.isEmpty ? items : const [],
      variants: variants,
      raw: map,
    );
  }
}

/// `bullets`: unordered list.
class BulletsPanel extends ChatPanel {
  const BulletsPanel({
    required this.title,
    required this.items,
    Map<String, Object?> raw = const {},
  }) : super(raw);

  final String title;
  final List<PanelItem> items;

  @override
  String get type => 'bullets';

  static BulletsPanel? _parse(Map<String, Object?> map) {
    final items = _items(map['items']);
    if (items.isEmpty) return null;
    return BulletsPanel(title: _str(map['title']) ?? '', items: items, raw: map);
  }
}

/// `todo`: a list to tick off, only for preparation (backpack, supplies,
/// home). Never for a risk phrase: the app turns it into [BulletsPanel]
/// there. Checked items live in [AssistantAnswer.done].
class TodoPanel extends ChatPanel {
  const TodoPanel({
    required this.title,
    required this.items,
    Map<String, Object?> raw = const {},
  }) : super(raw);

  final String title;
  final List<PanelItem> items;

  @override
  String get type => 'todo';

  static TodoPanel? _parse(Map<String, Object?> map) {
    final items = _items(map['items']);
    if (items.isEmpty) return null;
    return TodoPanel(title: _str(map['title']) ?? '', items: items, raw: map);
  }
}

/// One question of a [FormPanel].
class FormQuestion {
  const FormQuestion({required this.text, required this.options, this.multiple = false});

  final String text;
  final List<String> options;

  /// Several options may be picked.
  final bool multiple;
}

/// `form`: 1-3 choice questions the assistant asks before it answers.
/// The answers go back as the user's next message. Never for a risk phrase.
/// JSON: `{"type":"form","questions":[{"text":"...","multiple":false,
/// "options":["Tak","Nie"]}]}`.
class FormPanel extends ChatPanel {
  const FormPanel({required this.questions, this.title = '', Map<String, Object?> raw = const {}})
    : super(raw);

  static const int maxQuestions = 3;
  static const int maxOptions = 5;

  final String title;
  final List<FormQuestion> questions;

  @override
  String get type => 'form';

  static FormPanel? _parse(Map<String, Object?> map) {
    final raw = map['questions'];
    if (raw is! List) return null;
    final questions = <FormQuestion>[];
    for (final q in raw) {
      if (q is! Map) continue;
      final text = _str(q['text'])?.trim();
      final options = [
        for (final o in (q['options'] is List ? q['options'] as List : const []))
          if (o is String && o.trim().isNotEmpty) o.trim()
          else if (o is Map && (_str(o['label'])?.trim().isNotEmpty ?? false)) _str(o['label'])!.trim(),
      ];
      if (text == null || text.isEmpty || options.length < 2) continue;
      questions.add(FormQuestion(
        text: text,
        options: options.take(maxOptions).toList(),
        multiple: q['multiple'] == true || q['kind'] == 'multi',
      ));
      if (questions.length == maxQuestions) break;
    }
    if (questions.isEmpty) return null;
    return FormPanel(questions: questions, title: _str(map['title']) ?? '', raw: map);
  }
}

/// `quote`: original source fragment (text, document, page come from the
/// [SourceRecord] in [AssistantAnswer.sources]).
class QuotePanel extends ChatPanel {
  const QuotePanel({
    required this.sourceId,
    this.title = 'Źródło',
    Map<String, Object?> raw = const {},
  }) : super(raw);

  final String sourceId;
  final String title;

  @override
  String get type => 'quote';
}

enum NoSourceKind {
  /// "brak w zrodlach"
  noSource,

  /// "poza tematem"
  offTopic;

  static NoSourceKind parse(String? s) => switch (s) {
    'off_topic' || 'offTopic' => NoSourceKind.offTopic,
    _ => NoSourceKind.noSource,
  };

  String get jsonValue => this == noSource ? 'no_source' : 'off_topic';
}

/// Calm refusal (`refusal` origin). JSON: `{"type":"no_source","kind":"off_topic"}`.
class NoSourcePanel extends ChatPanel {
  const NoSourcePanel(this.kind, [Map<String, Object?> raw = const {}]) : super(raw);

  final NoSourceKind kind;

  @override
  String get type => 'no_source';
}

/// `chat_text`: small talk / calming reply, not from the guides.
/// JSON: `{"type":"chat_text","text":"..."}`.
class ChatTextPanel extends ChatPanel {
  const ChatTextPanel(this.text, [Map<String, Object?> raw = const {}]) : super(raw);

  final String text;

  @override
  String get type => 'chat_text';
}

/// `call`: no fields from the model (D03 builds the widget).
class CallPanel extends ChatPanel {
  const CallPanel([super.raw = const {}]);

  @override
  String get type => 'call';
}

/// `cpr`: CPR instructor. Parameters live in [raw] (D04 reads them).
class CprPanel extends ChatPanel {
  const CprPanel({
    this.sourceId,
    this.options = const [],
    Map<String, Object?> raw = const {},
  }) : super(raw);

  final String? sourceId;
  final List<VariantOption> options;

  @override
  String get type => 'cpr';

  @override
  List<VariantOption> get variantOptions => options;

  static CprPanel _parse(Map<String, Object?> map) {
    final options = <VariantOption>[];
    final v = map['variants'];
    if (v is List) {
      for (final e in v) {
        if (e is! Map) continue;
        final id = _str(e['id']);
        if (id != null) options.add(VariantOption(id, _str(e['label']) ?? id));
      }
    }
    return CprPanel(sourceId: _str(map['source_id']), options: options, raw: map);
  }
}

/// `map`: mini map to the nearest point (B06 builds the widget).
class MapPanel extends ChatPanel {
  const MapPanel({required this.target, Map<String, Object?> raw = const {}}) : super(raw);

  /// `nearest_shelter`, `nearest_hospital`, ...
  final String target;

  @override
  String get type => 'map';
}

/// `signal`: rescue signal (sound / flashlight / screen).
class SignalPanel extends ChatPanel {
  const SignalPanel({required this.modes, Map<String, Object?> raw = const {}}) : super(raw);

  final List<String> modes;

  @override
  String get type => 'signal';
}

/// `animation`: looped GIF (D05 builds the widget).
class AnimationPanel extends ChatPanel {
  const AnimationPanel({
    required this.caption,
    this.sourceId,
    this.animationId,
    this.variants = const {},
    Map<String, Object?> raw = const {},
  }) : super(raw);

  final String caption;
  final String? sourceId;

  /// Used when there are no [variants].
  final String? animationId;

  /// Variant id -> animation id.
  final Map<String, String> variants;

  @override
  String get type => 'animation';

  static AnimationPanel _parse(Map<String, Object?> map) {
    final variants = <String, String>{};
    final v = map['variants'];
    if (v is Map) {
      v.forEach((k, value) {
        if (k is String && value is String) variants[k] = value;
      });
    }
    return AnimationPanel(
      caption: _str(map['caption']) ?? '',
      sourceId: _str(map['source_id']),
      animationId: _str(map['animation_id']),
      variants: variants,
      raw: map,
    );
  }
}

/// Unknown type or malformed panel. Ignored by the renderer.
class UnknownPanel extends ChatPanel {
  const UnknownPanel(this.unknownType, super.raw);

  final String? unknownType;

  @override
  String get type => unknownType ?? 'unknown';
}

/// Where an assistant answer came from (spec "Wiadomosc asystenta").
enum AnswerOrigin {
  rescueCard('rescue_card'),
  rules('rules'),
  ai('ai'),
  noAi('no_ai'),
  refusal('refusal');

  const AnswerOrigin(this.json);

  final String json;

  static AnswerOrigin parse(String? s) => AnswerOrigin.values.firstWhere(
    (o) => o.json == s,
    orElse: () => AnswerOrigin.ai,
  );
}

/// Validated assistant answer: the panels, the source records they refer to
/// and per-message UI state (variant, checked items).
class AssistantAnswer {
  const AssistantAnswer({
    this.panels = const [],
    this.sources = const {},
    this.verify = false,
    this.cardId,
    this.origin = AnswerOrigin.ai,
    this.selectedVariant,
    this.done = const {},
    this.intent,
    this.note,
  });

  final List<ChatPanel> panels;

  /// `source_id` -> record.
  final Map<String, SourceRecord> sources;

  /// True when the content is drafted and awaits human verification
  /// (rescue cards: show `VerifyBadge`).
  final bool verify;

  /// Rescue card id (`rko`...), for `origin == rescueCard`.
  final String? cardId;

  final AnswerOrigin origin;

  /// One variant per message, shared by all panels with variants.
  final String? selectedVariant;

  /// Checked items: key `"{panelIndex}:{variantId or ''}"` -> item indexes.
  final Map<String, Set<int>> done;

  /// Intent id (`map`...) for tool answers (`origin: rules`); such answers show
  /// no origin label (szablony-czatu.md, "Etykieta nad wiadomoscia").
  final String? intent;

  /// Short note shown under the panels (e.g. the LLM timeout note).
  final String? note;

  static String doneKey(int panelIndex, String? variantId) =>
      '$panelIndex:${variantId ?? ''}';

  Set<int> doneFor(int panelIndex, String? variantId) =>
      done[doneKey(panelIndex, variantId)] ?? const {};

  /// Whether the form of panel [panelIndex] was sent or skipped. Stored in
  /// [done] like a checked item 0 (a form has no variants), so it round-trips
  /// with the message and [PanelScope.onDoneChanged] can set it.
  bool formClosed(int panelIndex) => doneFor(panelIndex, null).isNotEmpty;

  AssistantAnswer copyWith({
    List<ChatPanel>? panels,
    Map<String, SourceRecord>? sources,
    bool? verify,
    String? cardId,
    AnswerOrigin? origin,
    String? selectedVariant,
    Map<String, Set<int>>? done,
    String? intent,
    String? note,
  }) {
    return AssistantAnswer(
      panels: panels ?? this.panels,
      sources: sources ?? this.sources,
      verify: verify ?? this.verify,
      cardId: cardId ?? this.cardId,
      origin: origin ?? this.origin,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      done: done ?? this.done,
      intent: intent ?? this.intent,
      note: note ?? this.note,
    );
  }

  /// Returns a copy with item [index] of panel [panelIndex] checked or not.
  AssistantAnswer withDone(int panelIndex, String? variantId, int index, bool value) {
    final key = doneKey(panelIndex, variantId);
    final next = {for (final e in done.entries) e.key: {...e.value}};
    final set = next.putIfAbsent(key, () => <int>{});
    value ? set.add(index) : set.remove(index);
    return copyWith(done: next);
  }

  /// Parses `{ panels: [...], sources: {id: record} | [record], verify, card_id,
  /// origin, selected_variant, done }`. Never throws.
  factory AssistantAnswer.fromJson(Object? json) {
    if (json is! Map) return const AssistantAnswer();
    final sources = <String, SourceRecord>{};
    final rawSources = json['sources'];
    if (rawSources is Map) {
      rawSources.forEach((k, v) {
        final r = SourceRecord.tryParse(v, fallbackId: k is String ? k : null);
        if (r != null) sources[r.sourceId] = r;
      });
    } else if (rawSources is List) {
      for (final v in rawSources) {
        final r = SourceRecord.tryParse(v);
        if (r != null) sources[r.sourceId] = r;
      }
    }
    final rawPanels = json['panels'];
    final done = <String, Set<int>>{};
    final rawDone = json['done'];
    if (rawDone is Map) {
      rawDone.forEach((k, v) {
        if (k is String && v is List) done[k] = {for (final i in v) if (i is int) i};
      });
    }
    return AssistantAnswer(
      panels: rawPanels is List ? [for (final p in rawPanels) ChatPanel.fromJson(p)] : const [],
      sources: sources,
      verify: json['verify'] == true,
      cardId: _str(json['card_id']),
      origin: AnswerOrigin.parse(_str(json['origin'])),
      selectedVariant: _str(json['selected_variant']),
      done: done,
      intent: _str(json['intent']),
      note: _str(json['note']),
    );
  }

  Map<String, Object?> toJson() => {
    'origin': origin.json,
    'verify': verify,
    if (cardId != null) 'card_id': cardId,
    if (selectedVariant != null) 'selected_variant': selectedVariant,
    if (intent != null) 'intent': intent,
    if (note != null) 'note': note,
    'panels': [for (final p in panels) p.raw],
    'sources': {for (final e in sources.entries) e.key: e.value.toJson()},
    if (done.isNotEmpty)
      'done': {
        for (final e in done.entries) e.key: (e.value.toList()..sort()),
      },
  };

  /// Panels the renderer draws (without [UnknownPanel]).
  List<ChatPanel> get visiblePanels => [
    for (final p in panels)
      if (p is! UnknownPanel) p,
  ];

  /// Resolves a source id; null when the record is missing.
  SourceRecord? source(String? id) => id == null ? null : sources[id];
}

String? _str(Object? v) => v is String ? v : null;

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

List<String>? _strList(Object? v) {
  if (v is! List) return null;
  final out = [for (final e in v) if (e is String) e];
  return out.isEmpty ? null : out;
}

List<List<double>> _rects(Object? v) {
  if (v is! List) return const [];
  return [
    for (final r in v)
      if (r is List && r.length == 4 && r.every((n) => n is num))
        [for (final n in r) (n as num).toDouble()],
  ];
}

List<PanelItem> _items(Object? v) {
  if (v is! List) return const [];
  final out = <PanelItem>[];
  for (final e in v) {
    if (e is! Map) continue;
    final text = _str(e['text']);
    if (text == null || text.trim().isEmpty) continue;
    final link = e['card_link'];
    out.add(PanelItem(
      text: text,
      sourceId: _str(e['source_id']),
      kitId: _str(e['kit_id']),
      cardLinkLabel: link is Map ? _str(link['label']) : null,
      cardLinkId: link is Map ? _str(link['card_id']) : null,
    ));
  }
  return out;
}
