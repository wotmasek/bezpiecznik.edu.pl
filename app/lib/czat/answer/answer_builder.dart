/// Builds [AssistantAnswer]s (panels + source records) for the pipeline.
library;

import 'conversation.dart';
import '../retrieval/retriever.dart';
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
