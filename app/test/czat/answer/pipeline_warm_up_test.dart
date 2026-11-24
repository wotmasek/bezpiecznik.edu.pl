import 'package:bezpiecznik/czat/answer/answer_prompt.dart';
import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

PipelineAnswerService svc(FakeEngine e, {String Function()? profile, bool noAi = false, List<String>? log}) =>
    PipelineAnswerService(
      search: (_) async => found([chunk('c1', 'W razie pożaru nie wchodź do windy.')]),
      engine: e,
      isRisk: (_) => false,
      profileContext: () async => profile?.call() ?? '',
      noAi: () async => noAi,
      onLog: log?.add,
    );

void main() {
  test('warmUp prepares the exact system prompt the first turn then uses', () async {
    var profile = 'Wiek: 70';
    final e = FakeEngine([
      ['1. Zejdź schodami [1].'],
    ]);
    final s = svc(e, profile: () => profile);
    await s.warmUp('c');
    expect(e.prepared, hasLength(1));
    final p = e.prepared.single;
    expect(p.conversationId, 'c');
    expect(p.messages, isEmpty);
    expect(p.systemPrompt, answerSystemPrompt(profile: 'Wiek: 70'));

    profile = 'changed'; // the prepared prompt wins for this chat
    final ev = await s.answer('pożar', const ChatContext(chatId: 'c')).toList();
    expect(ev.last, isA<AnswerReady>());
    final r = e.requests.single;
    expect(r.systemPrompt, p.systemPrompt);
    expect(r.temperature, p.temperature);
    expect(r.maxTokens, p.maxTokens);
    expect(r.conversationId, 'c');
    expect(r.messages.single.role, LlmRole.user);
  });

  test('warmUp errors are swallowed and the question is still answered', () async {
    final log = <String>[];
    final e = FakeEngine([
      ['1. Zejdź schodami [1].'],
    ])..prepareError = const LlmUnavailable('brak modelu');
    final s = svc(e, log: log);
    await s.warmUp('c');
    expect(log.any((l) => l.startsWith('prepare failed')), true);
    final ev = await s.answer('pożar', const ChatContext(chatId: 'c')).toList();
    expect(ev.last, isA<AnswerReady>());
  });

  test('no-AI mode: warmUp does not touch the engine', () async {
    final e = FakeEngine([]);
    await svc(e, noAi: true).warmUp('c');
    expect(e.prepared, isEmpty);
  });
}
