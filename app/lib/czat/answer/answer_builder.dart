/// Builds [AssistantAnswer]s (panels + source records) for the pipeline.
library;

import 'conversation.dart';
import '../retrieval/retriever.dart';
import '../templates/md_text.dart' show MdKind, parseMd;
import '../templates/panel_model.dart';

/// How many chunks the quote fallback shows.
const int kFallbackQuotes = 3;

/// Note under a quote fallback after the model timed out (ekran-1-czat.md).
const String kLlmTimeoutNote = 'Model nie odpowiedział na czas. Pokazuję fragmenty źródeł.';

Map<String, Object?> _sourceJson(KbChunk c) => {
  'source_id': c.id,
  'doc_id': c.docId,
  'doc_title': c.title,
  'doc_short': c.docShort,
  'publisher': c.publisher,
  'page_label': c.pageLabel,
  'pdf_page': c.pdfPage,
  'text': c.text,
};

const Map<String, Object?> _callPanel = {'type': 'call'};

List<Map<String, Object?>> _withCall(
  List<Map<String, Object?>> panels,
  bool risk,
) => [if (risk) _callPanel, ...panels];

/// Joins neighbouring `steps` / `bullets` panels that share a title into one.
/// The on-device model tends to open a new panel for every step, which would
/// show three cards each numbered "1" instead of one list 1-2-3.
List<Map<String, Object?>> _mergeNeighbours(List<Map<String, Object?>> panels) {
  final out = <Map<String, Object?>>[];
  for (final p in panels) {
    final last = out.isEmpty ? null : out.last;
    final list = p['type'] == 'steps' || p['type'] == 'bullets' || p['type'] == 'todo';
    final a = last?['items'], b = p['items'];
    if (list && last != null && last['type'] == p['type'] && last['title'] == p['title'] && a is List && b is List) {
      out[out.length - 1] = {...last, 'items': [...a, ...b]};
    } else {
      out.add(p);
    }
  }
  return out;
}

/// On a risk question `todo` becomes `bullets` and `form` is dropped (never
/// ask questions in an emergency). Otherwise a `form` is kept only when it is
/// the only panel: mixed with content, the content wins.
List<Map<String, Object?>> _shape(List<Map<String, Object?>> panels, bool risk) {
  final content = [
    for (final p in panels)
      if (p['type'] != 'form') risk && p['type'] == 'todo' ? {...p, 'type': 'bullets'} : p,
  ];
  return risk || content.isNotEmpty ? content : panels.take(1).toList();
}

/// Answer from validated model panels. `call` goes first when [risk]; the
/// result may hold no content panel (risk + only a `form`).
AssistantAnswer buildModelAnswer(
  List<Map<String, Object?>> panels,
  List<KbChunk> chunks, {
  required bool risk,
}) {
  panels = _mergeNeighbours(_shape(panels, risk));
  final used = <String>{};
  for (final p in panels) {
    final id = p['source_id'];
    if (id is String) used.add(id);
    final items = p['items'];
    if (items is List) {
      for (final e in items) {
        if (e is Map && e['source_id'] is String) used.add(e['source_id'] as String);
      }
    }
  }
  return AssistantAnswer.fromJson({
    'origin': 'ai',
    'panels': _withCall(panels, risk),
    'sources': {
      for (final c in chunks)
        if (used.contains(c.id)) c.id: _sourceJson(c),
    },
  });
}

/// `[1]`, `[1, 2]`, `[1][2]` with the punctuation right after it.
final _cite = RegExp(r'\s*((?:\[\s*\d+(?:\s*,\s*\d+)*\s*\]\s*)+)([.,;:!?]*)');

/// Sentences of [text] split at its citations: each segment ends where a
/// citation stood (marker removed, punctuation kept) and carries the chunk
/// id of the first valid snippet number; unknown numbers are dropped.
List<({String text, String? id})> citedSegments(String text, List<KbChunk> chunks) {
  String? idOf(String marks) {
    for (final m in RegExp(r'\d+').allMatches(marks)) {
      final n = int.parse(m[0]!);
      if (n >= 1 && n <= chunks.length) return chunks[n - 1].id;
    }
    return null;
  }

  final out = <({String text, String? id})>[];
  var last = 0;
  for (final m in _cite.allMatches(text)) {
    final seg = text.substring(last, m.start) + m[2]!;
    final id = idOf(m[1]!);
    last = m.end;
    if (seg.trim().isEmpty) continue;
    out.add((text: seg, id: id));
  }
  if (last < text.length && text.substring(last).trim().isNotEmpty) {
    out.add((text: text.substring(last), id: null));
  }
  return out;
}

/// Numbers of [text] (digits, `1,5` == `1.5`) missing from the cited chunk.
bool numberNotInSource(String text, KbChunk? c) {
  if (c == null) return false;
  String norm(String s) => s.replaceAll(',', '.');
  final src = norm(c.original ?? c.text) + norm(c.text);
  return RegExp(r'\d+(?:[.,]\d+)?').allMatches(text).any((m) => !src.contains(norm(m[0]!)));
}

/// The answer from the model's free markdown (citations.md): a numbered list
/// is a `steps` panel, a `- ` list a `bullets` panel, a paragraph chat text;
/// `[n]` becomes the source of snippet n. `call` goes first on [risk]; a
/// [crisis] reply always carries the 116 123 / 112 line. Never a form/todo.
AssistantAnswer buildMarkdownAnswer(
  String text,
  List<KbChunk> chunks, {
  required bool risk,
  bool crisis = false,
}) {
  final panels = <Map<String, Object?>>[];
  final used = <String>{};
  String? title;
  final plain = <String>[];
  void flushPlain() {
    if (plain.isEmpty) return;
    panels.add({'type': 'chat_text', 'text': plain.join('\n\n')});
    plain.clear();
  }

  final byId = {for (final c in chunks) c.id: c};
  // Stretch of citations.md: a number not in the cited chunk is marked, not deleted.
  bool check(String t, String? id) => id != null && numberNotInSource(t, byId[id]);

  Map<String, Object?> item(String t) {
    final segs = citedSegments(t, chunks);
    final id = segs.map((s) => s.id).whereType<String>().firstOrNull;
    if (id != null) used.add(id);
    final text = segs.map((s) => s.text).join().trim();
    return {'text': text, 'source_id': ?id, if (check(text, id)) 'check': true};
  }

  text = cleanAnswerText(text);
  for (final b in parseMd(text)) {
    switch (b.kind) {
      case MdKind.heading:
        flushPlain();
        title = b.text.replaceAll('**', '');
      case MdKind.numbered || MdKind.bullet:
        flushPlain();
        final type = b.kind == MdKind.numbered ? 'steps' : 'bullets';
        final last = panels.isEmpty ? null : panels.last;
        final it = item(b.text);
        if ((it['text'] as String).isEmpty) continue;
        if (last != null && last['type'] == type && title == null) {
          (last['items']! as List).add(it);
        } else {
          panels.add({'type': type, 'title': title ?? '', 'items': [it]});
          title = null;
        }
      case MdKind.paragraph:
        if (title != null) {
          plain.add('**$title**');
          title = null;
        }
        final segs = citedSegments(b.text, chunks);
        if (segs.every((s) => s.id == null)) {
          final clean = segs.map((s) => s.text).join().trim();
          if (clean.isNotEmpty) plain.add(clean);
          continue;
        }
        flushPlain();
        used.addAll(segs.map((s) => s.id).whereType<String>());
        panels.add({
          'type': 'chat_text',
          'text': segs.map((s) => s.text).join().trim(),
          'items': [
            for (final (i, s) in segs.indexed)
              {
                'text': i == 0 ? s.text.trimLeft() : s.text,
                'source_id': ?s.id,
                if (check(s.text, s.id)) 'check': true,
              },
          ],
        });
    }
  }
  if (title != null) plain.add('**$title**');
  if (crisis && !text.contains('116 123')) plain.add(kCrisisHelpLine);
  flushPlain();
  return AssistantAnswer.fromJson({
    'origin': 'ai',
    'panels': _withCall(panels, risk || crisis),
    'sources': {
      for (final c in chunks)
        if (used.contains(c.id)) c.id: _sourceJson(c),
    },
  });
}

/// Quote panels of the best chunks (sourced, no model text). [modelOff] marks
/// the "no AI" origin (engine unavailable); validation failures stay `ai`.
AssistantAnswer buildQuoteFallback(
  List<KbChunk> chunks, {
  required bool risk,
  required bool modelOff,
  String? note,
}) {
  final top = chunks.take(kFallbackQuotes).toList();
  return AssistantAnswer.fromJson({
    'origin': modelOff ? 'no_ai' : 'ai',
    'note': ?note,
    'panels': _withCall([
      for (final c in top) {'type': 'quote', 'source_id': c.id},
    ], risk),
    'sources': {for (final c in top) c.id: _sourceJson(c)},
  });
}

/// The two calm refusals. Never carries a `call` panel except for a risk
/// phrase in a `noSource` case (spec: "Gdy wiadomość zawiera frazę ryzyka,
/// aplikacja dodaje szablon call"). Off-topic never gets 112.
/// A conversational reply. A crisis reply starts with the call panel (pinned
/// 112) and always ends with the 116 123 / 112 line.
AssistantAnswer buildChatReply(String text, {bool crisis = false}) {
  final t = crisis && !text.contains('116 123') ? '$text\n\n$kCrisisHelpLine' : text;
  return AssistantAnswer.fromJson({
    'origin': 'ai',
    'panels': _withCall([
      {'type': 'chat_text', 'text': t},
    ], crisis),
  });
}

AssistantAnswer buildRefusal(NoSourceKind kind, {bool risk = false}) {
  final callAllowed = risk && kind == NoSourceKind.noSource;
  return AssistantAnswer.fromJson({
    'origin': 'refusal',
    'panels': _withCall([
      {'type': 'no_source', 'kind': kind.jsonValue},
    ], callAllowed),
  });
}

/// Model text before parsing (docs/06-answers/style.md):
/// - placeholders and word "citations" the model invents ("[n]", "[Profil
///   domu]", "[Poradnik]") are removed; numeric [n] stay for the sources;
/// - a leading "Rozumiem, że …" / "Oczywiście, …" opener is dropped and the
///   rest of the sentence kept ("Rozumiem, że czujesz lęk" -> "Czujesz lęk").
String cleanAnswerText(String text) {
  var t = text.replaceAll(RegExp(r'\s*\[(?:n|[^\]\d]{2,40})\]'), '');
  final opener = RegExp(r'^\s*(?:Rozumiem|Oczywiście|Jasne|Świetne pytanie|Dobre pytanie)[,!.]?\s*(?:że\s+)?', caseSensitive: false);
  final m = opener.firstMatch(t);
  if (m != null && m.end < t.length) {
    final rest = t.substring(m.end);
    t = rest[0].toUpperCase() + rest.substring(1);
  }
  return t;
}
