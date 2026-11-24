/// Prompt layer of the single answer pass (docs/06-answers/style.md,
/// docs/04-context/budget-4096.md): one Polish system prompt, the snippet
/// block of a turn and the live-conversation transcript budget.
library;

import '../llm/llm_engine.dart';
import '../retrieval/retriever.dart';

/// Chunks given to the model per turn.
const int kMaxPromptChunks = 3;

/// Context size the on-device model is loaded with: prompt + answer must fit
/// in it. 4096 decided (docs/04-context/budget-4096.md): measured 2.9 GB and
/// ~7.7 s TTFT on a Pixel 9. The GPU float16 2k limit (LiteRT-LM #4001) does
/// not apply to the CPU backend we run.
const int kModelContextTokens = 4096;

/// Answer limit (style.md). One value for every turn: the engine reuses a
/// live conversation only when system prompt, temperature and maxTokens stay
/// the same, so short answers come from the prompt, not from this cap.
const int kAnswerMaxTokens = 450;

/// Sampling temperature of the single answer pass (D15).
const double kAnswerTemperature = 0.6;

/// Per-chunk cap in the prompt, cut at a sentence end.
const int kMaxChunkChars = 600;

/// System prompt + transcript budget, in estimated tokens.
const int kTranscriptBudgetTokens = 2600;

/// Rough token estimate of Polish text (budget-4096.md).
int estimateTokens(String text) => (text.length * 0.31).ceil();

const String kSystemPrompt = '''
Jesteś Bezpiecznikiem, asystentem bezpieczeństwa w aplikacji bez internetu. Piszesz zawsze po polsku. Aplikacja ma poradniki, karty ratunkowe, mapę schronów i przycisk SOS.

Styl:
- Zacznij od odpowiedzi. Nigdy nie zaczynaj od „Rozumiem” ani „Oczywiście”. Bez powtarzania pytania i podsumowań.
- Krótko: 1–3 zdania albo lista do 6 punktów.
- Nagła sytuacja: tylko czynności po kolei, w trybie rozkazującym, lista numerowana, bez pytania na końcu. Gdy życie może być zagrożone, pierwszy krok to „Zadzwoń pod 112”.
- Emocje: jedno, dwa zdania, które je uznają, i jedno pytanie. Bez nieproszonych rad.
- Szerszy temat: najważniejsze, potem „Chcesz więcej o …?”.
- Pisz neutralnie płciowo („czy możesz napisać więcej?”, nie „mógłbyś”). Nie wymyślaj swoich uczuć ani wspomnień.
- O bezpieczeństwo pytaj tylko, gdy ktoś pisze o zagrożeniu, przemocy albo myślach o śmierci.

Źródła:
- Fakty z fragmentów oznaczaj [n] (numer fragmentu) na końcu zdania lub punktu.
- Nie dodawaj liczb, dawek ani nazw leków spoza fragmentów. Zachowaj „nie” i „nigdy”.
- Gdy fragmenty nie pasują lub ich brak, powiedz jednym zdaniem, że poradniki tego nie opisują, i odpowiedz ogólnie.
- O rozmówcy wiesz tylko to, co napisał, i profil domu (na górze). Pytania o rozmówcę („co o mnie wiesz”, domownicy, zwierzęta, piętro, leki): wymień fakty z profilu domu, bez [n]. Czego tam nie ma, tego nie wiesz.

Przykład 1
Użytkownik: Ile wody na osobę?
Ty: 3 litry dziennie na osobę, zapas na minimum 3 dni [1]. Chcesz listę reszty zapasów?

Przykład 2
Użytkownik: Pokłóciłem się z mamą i jest mi źle.
Ty: Kłótnia z bliską osobą potrafi długo ciążyć. O co poszło?''';

/// Added to the user turn of a crisis sentence (isCrisis).
const String kCrisisPromptNote =
    '(Ta osoba może być w kryzysie. Odpowiedz ciepło, bez oceniania, nie zaczynaj od „Rozumiem”. '
    'Przy panice zaproponuj spokojny, powolny oddech. Zapytaj: „Czy jesteś w bezpiecznym miejscu?”. '
    'Podaj 116 123 (telefon zaufania) i 112.)';

/// The system prompt with the profile facts.
String answerSystemPrompt({String profile = ''}) {
  final p = profile.trim().isEmpty ? 'Profil domu: pusty.' : 'Profil domu rozmówcy: ${profile.trim()}';
  return kSystemPrompt.replaceFirst('\n\nStyl:', '\n$p\n\nStyl:');
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
  String? chatId,
}) => LlmRequest(
  systemPrompt: system,
  messages: messages,
  maxTokens: kAnswerMaxTokens,
  temperature: kAnswerTemperature,
  conversationId: chatId,
);
