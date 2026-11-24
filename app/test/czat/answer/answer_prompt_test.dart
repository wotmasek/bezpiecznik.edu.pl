import 'package:bezpiecznik/czat/answer/answer_prompt.dart';
import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

String _sentences(int chars) {
  final b = StringBuffer();
  var i = 0;
  while (b.length < chars) {
    b.write('Zdanie numer ${i++} o bezpieczeństwie w domu. ');
  }
  return b.toString().substring(0, chars);
}

void main() {
  test('system prompt is compact (<= 480 estimated tokens), Polish markdown, no JSON', () {
    final tokens = estimateTokens(answerSystemPrompt());
    expect(tokens, inInclusiveRange(200, 480));
    expect(kSystemPrompt, isNot(contains('JSON')));
    expect(kSystemPrompt, allOf(contains('[n]'), contains('poradniki'), contains('mapę schronów'), contains('SOS')));
    expect(answerSystemPrompt(), contains('\nProfil domu: pusty.\n'));
    expect(answerSystemPrompt(profile: 'Domownicy: 2 dorosłych.'), contains('\nProfil domu rozmówcy: Domownicy: 2 dorosłych.\n'));
  });

  test('a snippet is cut at a sentence end to at most 600 characters', () {
    final cut = fitSnippet(_sentences(1400));
    expect(cut.length, lessThanOrEqualTo(kMaxChunkChars));
    expect(cut, endsWith('.'));
    expect(fitSnippet('Krótko.'), 'Krótko.');
  });

  test('snippet block: numbered snippets with publisher and page, then the question', () {
    final m = snippetMessage('Ile wody?', [chunk('a', 'Trzy litry na osobę.', page: '33'), chunk('b', 'Latarka.')]);
    expect(m, startsWith('$kSnippetHeader\n[1] (RCB, s. 33) Trzy litry na osobę.\n[2] (RCB, s. 14) Latarka.\n'));
    expect(m, endsWith('\n\nPytanie: Ile wody?'));
    expect(snippetMessage('Hej', const []), '$kNoSnippets\n\nPytanie: Hej');
    expect(stripSnippets(m), 'Pytanie: Ile wody?');
  });

  test('one maxTokens for every turn, temperature 0.6, no JSON', () {
    LlmRequest req(String q) => buildAnswerRequest(system: 's', messages: const [], chatId: 'c');
    expect(req('Co spakować do plecaka?').maxTokens, 450);
    expect(req('Jak zatamować krwawienie?').maxTokens, 450);
    expect(req('x').temperature, 0.6);
    expect(req('x').jsonMode, isFalse);
    expect(req('x').jsonSchema, isNull);
    expect(req('x').conversationId, 'c');
  });

  test('trimTranscript: unchanged when it fits; else snippets stripped, oldest turns dropped', () {
    const next = LlmMessage.user('Pytanie: nowe');
    final small = [const LlmMessage.user('Pytanie: a'), const LlmMessage.assistant('b')];
    expect(identical(trimTranscript('sys', small, next), small), isTrue);

    final big = <LlmMessage>[
      for (var i = 0; i < 6; i++) ...[
        LlmMessage.user('$kSnippetHeader\n[1] ${_sentences(2000)}\n\nPytanie: q$i'),
        LlmMessage.assistant('odpowiedź $i'),
      ],
    ];
    final out = trimTranscript(answerSystemPrompt(), big, next);
    final size = estimateTokens(answerSystemPrompt()) +
        estimateTokens(next.content) +
        out.fold(0, (s, m) => s + estimateTokens(m.content));
    expect(size, lessThanOrEqualTo(kTranscriptBudgetTokens));
    expect(out.where((m) => m.content.contains(kSnippetHeader)), isEmpty);
    expect(out.first.role, LlmRole.user);
    expect(out.last.content, 'odpowiedź 5');

    final huge = [for (var i = 0; i < 40; i++) ...[LlmMessage.user('Pytanie: ${_sentences(200)}'), LlmMessage.assistant(_sentences(300))]];
    final cut = trimTranscript('sys', huge, next);
    expect(cut.length, lessThan(huge.length));
    expect(cut.first.role, LlmRole.user);
  });
}
