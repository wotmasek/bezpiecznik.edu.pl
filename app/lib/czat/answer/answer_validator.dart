/// Post-answer validation (odpowiedzi-tylko-ze-zrodel.md, warstwa 3): every
/// step / bullet is compared with the chunk it cites. The model writes, the
/// code decides.
library;

import '../retrieval/retriever.dart';
import '../retrieval/stopwords_fallback.dart';
import '../templates/panel_model.dart' show FormPanel;
import '../../ratunek/detect/normalize.dart';
import 'answer_text.dart';

/// Why one item was rejected.
enum RejectReason {
  emptyText,
  tooLong,
  unknownSource,
  invalidNumber,
  droppedNegation,
  addedNegation,
  lowOverlap,
}

class RejectedItem {
  const RejectedItem(this.text, this.sourceId, this.reason);
  final String text;
  final String? sourceId;
  final RejectReason reason;

  @override
  String toString() => '$reason: "$text" [$sourceId]';
}

/// Outcome of validating a whole model object.
class ValidatedAnswer {
  const ValidatedAnswer({required this.panels, required this.rejected});

  /// Panel JSON maps that survived: only `steps` / `bullets` / `todo` with
  /// `items`, `quote` and `form`. Never contains other types.
  final List<Map<String, Object?>> panels;
  final List<RejectedItem> rejected;

  bool get hasContent => panels.isNotEmpty;
}

/// Max chars of one step (spec: up to 120; some slack for Polish inflection
/// the model adds, anything longer is not a single action).
const int kMaxItemChars = 240;
const int kMaxTitleChars = 30;
const int kMaxItemsPerPanel = 8;
const int kMaxFormQuestionChars = 90;
const int kMaxFormOptionChars = 40;

/// Item lists: `todo` items are checked exactly like `bullets` items.
const Set<String> _listTypes = {'steps', 'bullets', 'todo'};

/// A `form` (1-3 choice questions, 2-5 short options each) is not a claim, so
/// it gets structural checks only; anything malformed drops the whole form.
Map<String, Object?>? _form(Map<Object?, Object?> p) {
  final raw = p['questions'];
  if (raw is! List || raw.isEmpty || raw.length > FormPanel.maxQuestions) return null;
  final questions = <Map<String, Object?>>[];
  for (final q in raw) {
    if (q is! Map) return null;
    final text = q['text'], options = q['options'];
    if (text is! String || options is! List) return null;
    final t = text.trim();
    if (t.isEmpty || t.length > kMaxFormQuestionChars) return null;
    if (options.length < 2 || options.length > FormPanel.maxOptions) return null;
    final opts = [for (final o in options) if (o is String) o.trim()];
    if (opts.length != options.length || opts.any((o) => o.isEmpty || o.length > kMaxFormOptionChars)) {
      return null;
    }
    questions.add({'text': t, 'multiple': q['multiple'] == true, 'options': opts});
  }
  return {'type': 'form', 'questions': questions};
}

/// Panel titles the UI may show (spec szablony-czatu.md examples + the
/// defaults). Anything else the model writes is replaced by a default, so a
/// title can never carry an invented instruction.
const List<String> kAllowedTitles = [
  'Teraz',
  'Kroki',
  'Co zrobić',
  'Najważniejsze',
  'Do zapamiętania',
  'Do plecaka',
  'RKO',
  'Gdy straci przytomność',
];

/// Spec limit for `title` (szablony-czatu.md: "Do 30 znaków").
const int kMaxTitleLength = 30;

/// The spec gives titles only as examples ("Teraz", "RKO", "Do plecaka",
/// "Gdy straci przytomność"), so besides the fixed list a title is accepted
/// when it is short, every content word of it occurs (5-character prefix,
/// Polish inflection) in the chunks the panel cites, and it passes the same
/// number and negation checks as an item against every cited chunk (BG101):
/// a title can then never carry an instruction the sources do not contain,
/// nor flip "Nie wchodź do windy" into "Wchodź do windy".
String _safeTitle(Object? raw, String type, List<_ChunkFacts> cited) {
  if (raw is String) {
    final n = normalizePl(raw);
    for (final t in kAllowedTitles) {
      if (normalizePl(t) == n) return t;
    }
    final trimmed = raw.trim();
    final sourceWords = {for (final f in cited) ...f.words};
    if (trimmed.isNotEmpty &&
        trimmed.length <= kMaxTitleLength &&
        _titleGrounded(n, sourceWords) &&
        cited.any((f) => _numberReason(trimmed, f) == null) &&
        cited.every((f) => _negationReason(trimmed, f) == null)) {
      return sentenceCase(trimmed);
    }
  }
  return type == 'steps' ? 'Co zrobić' : 'Najważniejsze';
}

/// Numbers, doses and times: each number must be in the chunk, bound to the
/// same unit / counted noun ("30 razy" is not "30 oddechów").
RejectReason? _numberReason(String t, _ChunkFacts f) {
  for (final n in numberFacts(t)) {
    final cands = f.numbers.where((c) => c.value == n.value);
    if (cands.isEmpty) return RejectReason.invalidNumber;
    if (n.following.isEmpty) continue;
    final ok = cands.any(
      (c) => c.following.isEmpty || anySame(c.following, n.following.first),
    );
    if (!ok) return RejectReason.invalidNumber;
  }
  return null;
}

RejectReason? _negationReason(String t, _ChunkFacts f) {
  final item = scanNegations(t);
  // A clause that uses a word the source only mentions under a negation
  // must itself negate it (any verb form, any word order).
  for (final clause in clauses(t)) {
    final neg = negatedIn(clause);
    for (final w in clause) {
      if (w.length < 3 || functionWords.contains(w) || isNegationWord(w)) continue;
      if (anySame(f.negated, w) && !anySame(f.affirmed, w) && !neg.contains(w)) {
        return RejectReason.droppedNegation;
      }
    }
  }
  for (final w in item.negated) {
    if (anySame(f.affirmed, w) && !anySame(f.negated, w)) {
      return RejectReason.addedNegation;
    }
  }
  if (item.hasNegation && !f.hasNegation) return RejectReason.addedNegation;
  return null;
}

/// "Sygnały Alarmowe" -> "Sygnały alarmowe": Polish sentence case, acronyms
/// ("RKO", "SOR") kept.
String sentenceCase(String s) => s
    .split(' ')
    .indexed
    .map((e) {
      final w = e.$2;
      if (w == w.toUpperCase()) return w;
      return e.$1 == 0 ? w : w.toLowerCase();
    })
    .join(' ');

bool _titleGrounded(String normalized, Set<String> sourceWords) {
  var content = 0;
  for (final w in normalized.split(' ')) {
    if (w.length < 3 || functionWords.contains(w)) continue;
    content++;
    final k = w.length < 5 ? w.length : 5;
    final stem = w.substring(0, k);
    if (!sourceWords.any((s) => s.startsWith(stem))) return false;
  }
  return content > 0;
}

class _ChunkFacts {
  _ChunkFacts(KbChunk c) {
    final text = [c.text, if (c.original != null) c.original!].join('\n');
    numbers = numberFacts(text);
    final scan = scanNegations(text);
    negated = scan.negated;
    affirmed = scan.affirmed;
    hasNegation = scan.hasNegation;
    words = tokens(text).toSet();
  }

  late final List<NumberFact> numbers;
  late final Set<String> negated;
  late final Set<String> affirmed;
  late final bool hasNegation;
  late final Set<String> words;
}

/// Small models sometimes mis-shape panels. Normalised here, before any
/// check (every item is still validated against its cited chunk afterwards):
/// - `{"type":"steps","title":"X"}, {"items":[...]}`: the untyped `items`
///   object is merged into the title-only panel before it;
/// - flat panels `{"type":"bullets","text":"..","source_id":".."}` become
///   one-item panels, and consecutive flat panels of the same type merge into
///   one (the first title wins; a title-only panel right before supplies it).
List<Object?> _mergeSplitPanels(List<Object?> raw) {
  bool titleOnly(Object? p) =>
      p is Map &&
      _listTypes.contains(p['type']) &&
      p['items'] == null &&
      p['text'] == null;
  bool flat(Object? p) =>
      p is Map &&
      _listTypes.contains(p['type']) &&
      p['items'] == null &&
      p['text'] is String &&
      p['source_id'] is String;

  final out = <Object?>[];
  // Types of panels created from flat items (only those may absorb more).
  final flatMade = <int>{};
  for (final p in raw) {
    if (p is Map && p['type'] == null && p['items'] is List && out.isNotEmpty) {
      final prev = out.last;
      if (titleOnly(prev)) {
        out[out.length - 1] = {...(prev as Map), 'items': p['items']};
        continue;
      }
    }
    if (flat(p)) {
      final m = p as Map;
      final item = {'text': m['text'], 'source_id': m['source_id']};
      if (out.isNotEmpty) {
        final prev = out.last;
        if (flatMade.contains(out.length - 1) &&
            prev is Map &&
            prev['type'] == m['type']) {
          out[out.length - 1] = {
            ...prev,
            'items': [...(prev['items'] as List), item],
          };
          continue;
        }
        if (titleOnly(prev)) {
          out[out.length - 1] = {
            'type': m['type'],
            'title': (prev as Map)['title'] ?? m['title'],
            'items': [item],
          };
          flatMade.add(out.length - 1);
          continue;
        }
      }
      out.add({'type': m['type'], 'title': m['title'], 'items': [item]});
      flatMade.add(out.length - 1);
      continue;
    }
    out.add(p);
  }
  return out;
}

class AnswerValidator {
  AnswerValidator({Set<String>? stopwords})
    : _stop = stopwords ?? {for (final w in fallbackStopwords) normalizePl(w)};

  final Set<String> _stop;

  /// Checks one item; returns null when it is covered by [chunk].
  RejectReason? checkItem(String text, KbChunk chunk) =>
      _check(text, _ChunkFacts(chunk));

  bool _isContent(String w) =>
      w.length >= 3 &&
      numericValue(w) == null &&
      !functionWords.contains(w) &&
      !_stop.contains(w) &&
      !isNegationWord(w);

  RejectReason? _check(String text, _ChunkFacts f) {
    final t = text.trim();
    if (t.isEmpty) return RejectReason.emptyText;
    if (t.length > kMaxItemChars) return RejectReason.tooLong;

    final reason = _numberReason(t, f) ?? _negationReason(t, f);
    if (reason != null) return reason;

    // Coverage: every content word of the item must occur in the chunk.
    for (final w in tokens(t)) {
      if (!_isContent(w)) continue;
      if (!anySame(f.words, w)) return RejectReason.lowOverlap;
    }
    return null;
  }

  /// Validates the parsed model object against the retrieved [chunks].
  /// Unknown panel types are dropped; items without a known `source_id` or
  /// without coverage are removed; empty panels are removed.
  ValidatedAnswer validate(Map<String, Object?> json, List<KbChunk> chunks) {
    final byId = {for (final c in chunks) c.id: c};
    final facts = <String, _ChunkFacts>{};
    final rejected = <RejectedItem>[];
    final out = <Map<String, Object?>>[];
    final quoted = <String>{};

    final rawJson = json['panels'];
    if (rawJson is! List) return ValidatedAnswer(panels: out, rejected: rejected);
    final rawPanels = _mergeSplitPanels(rawJson);

    for (final p in rawPanels) {
      if (p is! Map) continue;
      final type = p['type'];
      if (type == 'quote') {
        final id = p['source_id'];
        if (id is String && byId.containsKey(id) && quoted.add(id)) {
          out.add({'type': 'quote', 'source_id': id});
        }
        continue;
      }
      if (type == 'form') {
        final form = _form(p);
        if (form != null) out.add(form);
        continue;
      }
      if (!_listTypes.contains(type)) continue;
      final items = p['items'];
      if (items is! List) continue;
      final kept = <Map<String, Object?>>[];
      for (final e in items) {
        if (e is! Map) continue;
        final text = e['text'];
        final id = e['source_id'];
        if (text is! String) continue;
        final chunk = id is String ? byId[id] : null;
        if (chunk == null) {
          rejected.add(RejectedItem(text, id is String ? id : null, RejectReason.unknownSource));
          continue;
        }
        final reason = _check(text, facts.putIfAbsent(chunk.id, () => _ChunkFacts(chunk)));
        if (reason != null) {
          rejected.add(RejectedItem(text, chunk.id, reason));
          continue;
        }
        kept.add({'text': text.trim(), 'source_id': chunk.id});
        if (kept.length >= kMaxItemsPerPanel) break;
      }
      if (kept.isEmpty) continue;
      final cited = {for (final k in kept) facts[k['source_id']]!}.toList();
      final title = _safeTitle(p['title'], type as String, cited);
      out.add({'type': type, 'title': title, 'items': kept});
    }
    return ValidatedAnswer(panels: out, rejected: rejected);
  }
}
