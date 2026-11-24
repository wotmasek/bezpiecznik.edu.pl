/// Prompt layer of the single answer pass (docs/06-answers/style.md,
/// docs/04-context/budget-4096.md): one Polish system prompt, the snippet
/// block of a turn and the live-conversation transcript budget.
library;

import '../llm/llm_engine.dart';
import '../retrieval/retriever.dart';

/// Chunks given to the model per turn.
const int kMaxPromptChunks = 3;

/// Context size the on-device model is loaded with: prompt + answer must fit
/// in it. 2048 is also the most Gemma 4 handles at float16 on Android GPUs
/// (LiteRT-LM #4001), should a build switch the backend to the GPU.
const int kModelContextTokens = 2048;

/// Answer limits (style.md): short by default, longer for preparation lists.
const int kAnswerMaxTokens = 300;
const int kPrepAnswerMaxTokens = 450;

/// Sampling temperature of the single answer pass (D15).
const double kAnswerTemperature = 0.6;

/// Per-chunk cap in the prompt, cut at a sentence end.
const int kMaxChunkChars = 600;

/// System prompt + transcript budget, in estimated tokens.
const int kTranscriptBudgetTokens = 2600;

/// Rough token estimate of Polish text (budget-4096.md).
int estimateTokens(String text) => (text.length * 0.31).ceil();

const String kSystemPrompt = '''
Jesteś Bezpiecznikiem, asystentem bezpieczeństwa w aplikacji, która działa bez internetu. Aplikacja ma poradniki, karty ratunkowe, mapę schronów i przycisk SOS.

Styl:
- Zacznij od odpowiedzi. Bez wstępów („Rozumiem, że…”, „Oczywiście”), bez powtarzania pytania, bez podsumowań.
- Krótko: 1–3 zdania albo lista do 6 punktów. Jedno zdanie, jedna informacja.
- W nagłej sytuacji tylko czynności, po kolei, w trybie rozkazującym, jako lista numerowana. Gdy życie jest zagrożone, wspomnij o 112.
- Gdy ktoś mówi o emocjach: jedno, dwa zdania, które to uznają, i jedno pytanie. Bez rad, o które nie prosi.
- Gdy temat jest szerszy: najważniejsze, potem jedno pytanie „Chcesz więcej o …?”.
- Pisz neutralnie płciowo („czy jesteś w bezpiecznym miejscu?”). Jesteś programem: nie wymyślaj swoich uczuć ani wspomnień.

Źródła:
- Fakty z fragmentów oznaczaj [n] na końcu zdania lub punktu.
- Nie dodawaj liczb, dawek ani nazw leków spoza fragmentów. Zachowaj „nie” i „nigdy” ze źródła.
- Gdy fragmenty nie pasują albo ich brak, powiedz jednym zdaniem, że poradniki tego nie opisują, i odpowiedz tylko ogólnie.
- O rozmówcy wiesz tylko to, co napisał, i to, co jest w profilu domu.

Przykład 1
Użytkownik: Ile wody na osobę?
Ty: 3 litry dziennie na osobę, zapas na minimum 3 dni [1]. Chcesz listę reszty zapasów?

Przykład 2
Użytkownik: Pokłóciłem się z mamą i jest mi źle.
Ty: Kłótnia z bliską osobą potrafi długo ciążyć. O co poszło?''';

/// Added to the user turn of a crisis sentence (isCrisis).
const String kCrisisPromptNote =
    'Ta osoba może być teraz w kryzysie. Odpowiedz ciepło, bez oceniania. '
    'Zapytaj, czy jest teraz bezpieczna. Podaj 116 123 (telefon zaufania) i 112.';

/// The system prompt with the profile facts.
String answerSystemPrompt({String profile = ''}) {
  final b = StringBuffer(kSystemPrompt);
  b.write(profile.trim().isEmpty ? '\nProfil domu: pusty.' : '\nProfil domu: ${profile.trim()}');
  return b.toString();
}

/// [text] cut to at most [cap] characters at the last sentence or line end,
/// else at the last space.
String fitSnippet(String text, [int cap = kMaxChunkChars]) {
  final t = text.trim();
  if (t.length <= cap) return t;
  final head = t.substring(0, cap);
  var cut = -1;
  for (final end in const ['. ', '.\n', '! ', '? ', '\n']) {
    final i = head.lastIndexOf(end);
    if (i > cut) cut = i + (end == '\n' ? 0 : 1);
  }
  if (cut < cap ~/ 3) cut = head.lastIndexOf(' ');
  return (cut <= 0 ? head : head.substring(0, cut)).trimRight();
}

const String kSnippetHeader = 'Fragmenty poradników:';
const String kNoSnippets = 'Fragmenty poradników: brak pasujących.';

/// The user message of one turn: numbered snippets + the question.
String snippetMessage(String question, List<KbChunk> chunks) {
  final b = StringBuffer();
  if (chunks.isEmpty) {
    b.writeln(kNoSnippets);
  } else {
    b.writeln(kSnippetHeader);
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      final page = c.pageLabel.isEmpty ? '' : ', s. ${c.pageLabel}';
      b.writeln('[${i + 1}] (${c.publisher.isEmpty ? c.docShort : c.publisher}$page) ${fitSnippet(c.text)}');
    }
  }
  b
    ..writeln()
    ..write('Pytanie: ${question.trim()}');
  return b.toString();
}

/// A user message without its snippet block (older turns in a trimmed
/// transcript): just the question.
String stripSnippets(String message) {
  final i = message.lastIndexOf('\nPytanie: ');
  return i < 0 ? message : message.substring(i + 1);
}

/// Preparation / packing questions get the longer answer limit.
bool isPrepQuestion(String q) =>
    RegExp(r'spakow|przygotow|zapas|plecak|list', caseSensitive: false).hasMatch(q);

/// Keeps system + transcript + [next] within [kTranscriptBudgetTokens]: first
/// strips the snippet blocks of older user turns, then drops the oldest
/// turns (a user/assistant pair at a time). Returns [transcript] itself when
/// it already fits, so the engine sees an exact prefix.
List<LlmMessage> trimTranscript(String system, List<LlmMessage> transcript, LlmMessage next) {
  int size(List<LlmMessage> m) =>
      estimateTokens(system) + estimateTokens(next.content) + m.fold(0, (s, x) => s + estimateTokens(x.content));
  if (size(transcript) <= kTranscriptBudgetTokens) return transcript;
  var out = [
    for (final m in transcript)
      m.role == LlmRole.user ? LlmMessage.user(stripSnippets(m.content)) : m,
  ];
  while (out.isNotEmpty && size(out) > kTranscriptBudgetTokens) {
    out = out.sublist(out.length >= 2 ? 2 : 1);
  }
  return out;
}

/// The request of one turn on the live conversation [chatId].
LlmRequest buildAnswerRequest({
  required String system,
  required List<LlmMessage> messages,
  required String question,
  String? chatId,
}) => LlmRequest(
  systemPrompt: system,
  messages: messages,
  maxTokens: isPrepQuestion(question) ? kPrepAnswerMaxTokens : kAnswerMaxTokens,
  temperature: kAnswerTemperature,
  conversationId: chatId,
);
