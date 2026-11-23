/// Prompt for the closed-book answer (odpowiedzi-tylko-ze-zrodel.md,
/// szablony-czatu.md, lokalne-ai.md). Polish, so the model answers in Polish.
library;

import '../llm/llm_engine.dart';
import '../retrieval/retriever.dart';

const int kMaxPromptChunks = 4;

/// Context size the on-device model is loaded with: prompt + answer must fit
/// in it. 2048 is also the most Gemma 4 handles at float16 on Android GPUs
/// (LiteRT-LM #4001), should a build switch the backend to the GPU.
const int kModelContextTokens = 2048;

/// Tokens reserved for the answer: 6 items of <= 120 characters plus the JSON
/// around them and the (long) source ids.
const int kAnswerMaxTokens = 600;

/// Characters of source text in one prompt. With the system prompt (~1.3 k
/// characters) and the question this keeps the prompt under 1.45 k tokens at
/// 2.5 characters per token, the densest Polish text measured.
const int kPromptChunkBudgetChars = 2000;

/// Per-chunk cap, so one long chunk cannot take the whole budget (the median
/// chunk is ~600 characters, the longest ~1400).
const int kMaxChunkChars = 900;

/// Below this a truncated chunk is too short to be worth citing.
const int _minChunkChars = 200;

/// [text] cut to at most [cap] characters, at the last sentence or line end
/// when there is one in the second half, else at the last space.
String _fit(String text, int cap) {
  final t = text.trim();
  if (t.length <= cap) return t;
  final head = t.substring(0, cap);
  var cut = -1;
  for (final end in const ['. ', '.\n', '\n']) {
    final i = head.lastIndexOf(end);
    if (i > cut) cut = i + (end == '\n' ? 0 : 1);
  }
  if (cut < cap ~/ 2) cut = head.lastIndexOf(' ');
  return (cut <= 0 ? head : head.substring(0, cut)).trimRight();
}

/// The chunks that go into the prompt (best first) with their text cut to the
/// budget. A chunk that would get less than [_minChunkChars] is left out.
List<({KbChunk chunk, String text})> fitChunks(List<KbChunk> chunks) {
  final out = <({KbChunk chunk, String text})>[];
  var left = kPromptChunkBudgetChars;
  for (final c in chunks.take(kMaxPromptChunks)) {
    final cap = left < kMaxChunkChars ? left : kMaxChunkChars;
    if (cap < _minChunkChars && c.text.trim().length > cap) continue;
    final text = _fit(c.text, cap);
    out.add((chunk: c, text: text));
    left -= text.length;
  }
  return out;
}

const String kSystemPrompt = '''
Jesteś asystentem bezpieczeństwa. Odpowiadasz WYŁĄCZNIE na podstawie podanych fragmentów źródeł. Nigdy nie korzystaj z własnej wiedzy.

Zwróć jeden obiekt JSON, bez tekstu poza nim:
{"panels":[{"type":"steps","title":"Teraz","items":[{"text":"...","source_id":"..."}]}]}

Panele:
- "steps": czynności po kolei. "bullets": fakty, znaczenia sygnałów, lista bez kolejności. Każdy element ma "text" i "source_id" z fragmentów.
- "todo": co przygotować, spakować, sprawdzić; elementy jak w "bullets". Nie w nagłym wypadku.
- "quote": {"type":"quote","source_id":"..."} gdy nie umiesz krótko streścić fragmentu.
- "form": gdy pytanie jest zbyt ogólne, zamiast odpowiedzi 1-3 pytania wyboru, 2-5 opcji: {"type":"form","questions":[{"text":"...","multiple":false,"options":["...","..."]}]}

Zasady:
- Element to jedna czynność, jedno krótkie zdanie (do 120 znaków), po polsku.
- Używaj słów i liczb z fragmentu. Nie dodawaj liczb, dawek, czasów ani nazw leków, których nie ma we fragmencie.
- Zachowaj zaprzeczenia ze źródła: jeśli fragment mówi "nie" lub "nigdy", krok też. Nie dodawaj zaprzeczeń, których nie ma.
- Nie diagnozuj. Nie dodawaj panelu "call" ani innych.
- Gdy fragmenty nie odpowiadają na pytanie, zwróć {"panels":[]}.
- Najwyżej 6 elementów łącznie, wybierz najważniejsze.
- Tytuł panelu: do 30 znaków.''';

/// Short reminder appended on the single retry after an unparseable answer.
const String kRetryReminder =
    'Poprzednia odpowiedź nie była poprawnym JSON. Zwróć wyłącznie jeden '
    'kompletny obiekt JSON {"panels":[...]} i nic poza nim. Krótko.';

/// JSON schema for engines with constrained decoding (the edge engine). The
/// host engine only uses `json_object`; the schema is repeated in the prompt.
Map<String, Object?> answerSchema(List<String> sourceIds) => {
  'type': 'object',
  'properties': {
    'panels': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['steps', 'bullets', 'todo', 'quote', 'form'],
          },
          'title': {'type': 'string'},
          'source_id': {'type': 'string', 'enum': sourceIds},
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'text': {'type': 'string'},
                'source_id': {'type': 'string', 'enum': sourceIds},
              },
              'required': ['text', 'source_id'],
            },
          },
          'questions': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'text': {'type': 'string'},
                'multiple': {'type': 'boolean'},
                'options': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
              },
              'required': ['text', 'options'],
            },
          },
        },
        'required': ['type'],
      },
    },
  },
  'required': ['panels'],
};

/// Builds the request: top-k chunks (best first), profile context and the
/// current plus previous question.
LlmRequest buildAnswerRequest({
  required String question,
  String? previousQuestion,
  String profileContext = '',
  required List<KbChunk> chunks,
  bool retry = false,
}) {
  final used = fitChunks(chunks);
  final b = StringBuffer('Fragmenty źródeł:\n');
  for (final (:chunk, :text) in used) {
    b
      ..writeln('[source_id: ${chunk.id}] (${chunk.docShort}, s. ${chunk.pageLabel})')
      ..writeln(text)
      ..writeln();
  }
  if (profileContext.trim().isNotEmpty) {
    b
      ..writeln('Profil domu (tylko kontekst, nie źródło faktów):')
      ..writeln(profileContext.trim())
      ..writeln();
  }
  if (previousQuestion != null && previousQuestion.trim().isNotEmpty) {
    b.writeln('Poprzednie pytanie: ${previousQuestion.trim()}');
  }
  b.writeln('Pytanie: ${question.trim()}');
  if (retry) b.writeln('\n$kRetryReminder');
  return LlmRequest(
    systemPrompt: kSystemPrompt,
    messages: [LlmMessage.user(b.toString())],
    jsonMode: true,
    jsonSchema: answerSchema([for (final u in used) u.chunk.id]),
    maxTokens: kAnswerMaxTokens,
    temperature: retry ? 0.0 : 0.1,
  );
}
