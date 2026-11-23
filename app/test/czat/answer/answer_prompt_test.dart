// The on-device model is loaded with a 2048-token context (also the float16
// limit of Gemma 4 on Android GPUs, LiteRT-LM #4001), so the prompt has a
// hard size budget.
import 'package:bezpiecznik/czat/answer/answer_prompt.dart';
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

String _prompt(List<String> texts) => buildAnswerRequest(
  question: 'co robić',
  chunks: [for (var i = 0; i < texts.length; i++) chunk('c$i', texts[i])],
).messages.single.content;

List<String> _ids(List<String> texts) {
  final req = buildAnswerRequest(
    question: 'co robić',
    chunks: [for (var i = 0; i < texts.length; i++) chunk('c$i', texts[i])],
  );
  final panels = (req.jsonSchema!['properties'] as Map)['panels'] as Map;
  final props = (panels['items'] as Map)['properties'] as Map;
  return ((props['source_id'] as Map)['enum'] as List).cast<String>();
}

void main() {
  test('short chunks go in whole, all four', () {
    final texts = [for (var i = 0; i < 4; i++) 'Fragment $i. ${_sentences(400)}'];
    final p = _prompt(texts);
    for (final t in texts) {
      expect(p, contains(t.trim()));
    }
    expect(_ids(texts), ['c0', 'c1', 'c2', 'c3']);
  });

  test('the worst case (four maximal chunks) stays inside the budget', () {
    final texts = [for (var i = 0; i < 4; i++) _sentences(1500)];
    final p = _prompt(texts);
    expect(p.length, lessThanOrEqualTo(kPromptChunkBudgetChars + 500));
  });

  test('the whole request fits the model context with room for the answer', () {
    final req = buildAnswerRequest(
      question: 'co robić gdy nie ma prądu od dwóch dni i jest zimno',
      previousQuestion: 'ile wody na osobę',
      profileContext: 'Dorośli: 2. Dzieci: 1. Pies.',
      chunks: [for (var i = 0; i < 4; i++) chunk('c$i', _sentences(1500))],
    );
    final promptChars = req.systemPrompt.length + req.messages.single.content.length;
    // Polish text measured at >= 2.5 characters per Gemma token.
    final promptTokens = promptChars / 2.5;
    expect(promptTokens + req.maxTokens, lessThanOrEqualTo(kModelContextTokens));
  });

  test('schema and prompt allow todo and form', () {
    final req = buildAnswerRequest(question: 'co spakować', chunks: [chunk('c0', 'Woda.')]);
    final panels = (req.jsonSchema!['properties'] as Map)['panels'] as Map;
    final props = (panels['items'] as Map)['properties'] as Map;
    expect((props['type'] as Map)['enum'], containsAll(['todo', 'form']));
    expect(props['questions'], isA<Map>());
    expect(kSystemPrompt, allOf(contains('"todo"'), contains('"form"')));
  });

  // 2048-token context: every character of the system prompt is paid on
  // every question (1168 before todo/form, 1311 with them; the worst case
  // above then leaves ~7 tokens).
  test('system prompt stays within its size budget', () {
    expect(kSystemPrompt.length, lessThanOrEqualTo(1320));
  });

  test('a long chunk is cut at a sentence end, not mid-word', () {
    final p = _prompt([_sentences(1500)]);
    final body = p.split('\n')[2];
    expect(body.length, lessThanOrEqualTo(kMaxChunkChars));
    expect(body.trimRight(), endsWith('.'));
  });

  test('the best chunk is never squeezed out by later ones', () {
    final texts = [_sentences(850), _sentences(1500), _sentences(1500), _sentences(1500)];
    expect(_prompt(texts), contains(texts.first.trim()));
  });

  test('a chunk with no room left is dropped and cannot be cited', () {
    final texts = [for (var i = 0; i < 4; i++) _sentences(1500)];
    final ids = _ids(texts);
    final p = _prompt(texts);
    expect(ids, isNotEmpty);
    expect(ids.length, lessThan(4));
    for (final id in ['c0', 'c1', 'c2', 'c3']) {
      expect(p.contains('[source_id: $id]'), ids.contains(id), reason: id);
    }
  });
}
