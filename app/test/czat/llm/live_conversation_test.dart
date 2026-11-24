import 'dart:async';

import 'package:bezpiecznik/czat/llm/live_conversation.dart';
import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _Chat {
  final List<List<LlmMessage>> sent = [];
  bool closed = false;
}

class _Harness {
  final List<String> reply = const ['Od', 'powiedź'];
  bool stopped = false;
  Object? failWith;
  final List<_Chat> opened = [];

  late final live = LiveConversation<_Chat>(
    open: (req) async {
      final chat = _Chat();
      opened.add(chat);
      return chat;
    },
    send: (chat, fresh) async* {
      chat.sent.add(fresh);
      for (final t in reply) {
        if (failWith != null) throw failWith!;
        yield t;
      }
    },
    close: (chat) async => chat.closed = true,
    isStopped: () => stopped,
  );
}

const u1 = LlmMessage.user('Pytanie 1');
const u2 = LlmMessage.user('Pytanie 2');
const a1 = LlmMessage.assistant('Odpowiedź');

LlmRequest live(List<LlmMessage> messages, {String id = 'c1', String system = 'S', int max = 300}) =>
    LlmRequest(conversationId: id, systemPrompt: system, messages: messages, maxTokens: max);

void main() {
  test('prepare opens the chat early; the first turn continues it with only the question', () async {
    final h = _Harness();
    await h.live.prepare(live(const []));
    expect(h.opened, hasLength(1));
    expect(h.opened.single.sent, isEmpty);
    await h.live.prepare(live(const [])); // already prepared: no reopen
    expect(h.opened, hasLength(1));

    await h.live.run(live([u1])).drain<void>();
    expect(h.live.lastReused, true);
    expect(h.opened, hasLength(1));
    expect(h.opened.single.sent.single.map((m) => m.content), ['Pytanie 1']);
  });

  test('prepare for another chat closes the open one', () async {
    final h = _Harness();
    await h.live.run(live([u1])).drain<void>();
    await h.live.prepare(live(const [], id: 'c2'));
    expect(h.opened.first.closed, true);
    await h.live.run(live([u1], id: 'c2')).drain<void>();
    expect(h.live.lastReused, true);
  });

  test('continues the open chat when its history is a prefix: only new messages', () async {
    final h = _Harness();
    expect(await h.live.run(live([u1])).join(), 'Odpowiedź');
    expect(h.live.lastReused, false);

    await h.live.run(live([u1, a1, u2])).drain<void>();
    expect(h.live.lastReused, true);
    expect(h.opened, hasLength(1));
    expect(h.opened.single.sent.last.map((m) => m.content), ['Pytanie 2']);
  });

  test('reopens with the full history when the prefix differs', () async {
    final h = _Harness();
    await h.live.run(live([u1])).drain<void>();
    const edited = LlmMessage.assistant('Odpowiedź skrócona');
    await h.live.run(live([u1, edited, u2])).drain<void>();
    expect(h.live.lastReused, false);
    expect(h.opened, hasLength(2));
    expect(h.opened.first.closed, true);
    expect(h.opened.last.sent.single, hasLength(3));
  });

  test('reopens on a role mismatch with the same text', () async {
    final h = _Harness();
    await h.live.run(live([u1])).drain<void>();
    await h.live.run(live([u1, const LlmMessage.user('Odpowiedź'), u2])).drain<void>();
    expect(h.live.lastReused, false);
  });

  test('reopens for another conversation id, system prompt, maxTokens or temperature', () async {
    for (final next in [
      live([u1, a1, u2], id: 'c2'),
      live([u1, a1, u2], system: 'S2'),
      live([u1, a1, u2], max: 450),
      const LlmRequest(conversationId: 'c1', systemPrompt: 'S', messages: [u1, a1, u2], maxTokens: 300, temperature: 0.7),
    ]) {
      final h = _Harness();
      await h.live.run(live([u1])).drain<void>();
      await h.live.run(next).drain<void>();
      expect(h.live.lastReused, false, reason: '${next.conversationId} ${next.systemPrompt}');
      expect(h.opened.first.closed, true);
    }
  });

  test('reopens after a stop: the partial reply is not remembered', () async {
    final h = _Harness();
    h.stopped = true;
    await h.live.run(live([u1])).drain<void>();
    expect(h.live.isOpen, false);
    expect(h.opened.single.closed, true);

    h.stopped = false;
    await h.live.run(live([u1, a1, u2])).drain<void>();
    expect(h.live.lastReused, false);
  });

  test('reopens after the subscription is cancelled mid-reply', () async {
    final h = _Harness();
    final it = StreamIterator(h.live.run(live([u1])));
    expect(await it.moveNext(), true);
    await it.cancel();
    expect(h.live.isOpen, false);
    expect(h.opened.single.closed, true);
  });

  test('reopens after an error', () async {
    final h = _Harness()..failWith = StateError('native');
    await expectLater(h.live.run(live([u1])).drain<void>(), throwsStateError);
    expect(h.live.isOpen, false);
    h.failWith = null;
    await h.live.run(live([u1, a1, u2])).drain<void>();
    expect(h.live.lastReused, false);
  });

  test('a repeated request with nothing new reopens', () async {
    final h = _Harness();
    await h.live.run(live([u1])).drain<void>();
    expect(h.live.continuation(live([u1, a1])), isNull);
  });

  test('JSON and id-less requests are one-shot and never continue the chat', () async {
    final h = _Harness();
    await h.live.run(live([u1])).drain<void>();
    const json = LlmRequest(conversationId: 'c1', systemPrompt: 'S', messages: [u1, a1, u2], maxTokens: 300, jsonMode: true);
    const schema = LlmRequest(conversationId: 'c1', systemPrompt: 'S', messages: [u1, a1, u2], maxTokens: 300, jsonSchema: {'type': 'object'});
    const noId = LlmRequest(systemPrompt: 'S', messages: [u1, a1, u2], maxTokens: 300);
    for (final r in [json, schema, noId]) {
      expect(isLiveRequest(r), false);
      expect(h.live.continuation(r), isNull);
    }
    expect(isLiveRequest(live([u1])), true);
    // The open chat is untouched by checking them.
    expect(h.live.continuation(live([u1, a1, u2])), [u2]);
  });
}
