import 'dart:async';

import 'package:bezpiecznik/czat/templates/call/call_panel_view.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/czat/ui/chat_screen.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<List<Uri>> pumpChat(WidgetTester tester, AnswerService service) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final launched = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        answerServiceProvider.overrideWithValue(service),
        chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        callLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
      ],
      child: MaterialApp(theme: buildBzTheme(), home: const ChatScreen()),
    ),
  );
  return launched;
}

Future<void> ask(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(const Key('composer-field')), q);
  await tester.pump();
  await tester.tap(find.byKey(const Key('composer-send')));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'risk: Zadzwoń 112 is pinned while the answer is pending, then stays once',
    (tester) async {
      final answer = StreamController<AnswerEvent>();
      final launched = await pumpChat(
        tester,
        FakeAnswerService(script: (_, _) => answer.stream),
      );
      await ask(tester, 'pożar w bloku');

      answer.add(const AnswerThinking(ThinkingPhase.searching, true));
      await tester.pump();
      expect(find.text(callButtonLabel), findsOneWidget);
      expect(find.byKey(const Key('thinking-label')), findsOneWidget);
      // Pinned above the composer, below the thinking indicator.
      expect(
        tester.getTopLeft(find.text(callButtonLabel)).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('thinking-label'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.text(callButtonLabel)).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('composer-field'))).dy),
      );

      // A later phase without the flag keeps the panel (sticky).
      answer.add(const AnswerThinking(ThinkingPhase.composing));
      await tester.pump();
      expect(find.text(callButtonLabel), findsOneWidget);
      final before = tester.getTopLeft(find.text(callButtonLabel)).dy;

      answer.add(
        AnswerReady(
          AssistantAnswer.fromJson({
            'origin': 'ai',
            'panels': [
              {'type': 'call'},
              {'type': 'no_source', 'kind': 'no_source'},
            ],
          }),
        ),
      );
      await answer.close();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('thinking-label')), findsNothing);
      expect(find.text(callButtonLabel), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(callButtonLabel)).dy,
        before,
      ); // no jump
      expect(launched, isEmpty); // nothing dialled without a tap
    },
  );

  testWidgets('a call panel in the answer pins 112 without the thinking flag', (
    tester,
  ) async {
    final answer = StreamController<AnswerEvent>();
    await pumpChat(tester, FakeAnswerService(script: (_, _) => answer.stream));
    await ask(tester, 'pożar w bloku');
    expect(find.text(callButtonLabel), findsNothing);
    answer.add(
      AnswerReady(
        AssistantAnswer.fromJson({
          'panels': [
            {'type': 'call'},
            {'type': 'no_source', 'kind': 'no_source'},
          ],
        }),
      ),
    );
    await answer.close();
    await tester.pump();
    await tester.pump();
    expect(find.text(callButtonLabel), findsOneWidget);
  });

  testWidgets('no risk: the thinking bubble has no call panel', (tester) async {
    final answer = StreamController<AnswerEvent>();
    await pumpChat(tester, FakeAnswerService(script: (_, _) => answer.stream));
    await ask(tester, 'zapas wody');
    answer.add(const AnswerThinking(ThinkingPhase.composing));
    await tester.pump();
    expect(find.byKey(const Key('thinking-label')), findsOneWidget);
    expect(find.text(callButtonLabel), findsNothing);
    answer.add(
      AnswerReady(
        AssistantAnswer.fromJson({
          'panels': [
            {'type': 'no_source', 'kind': 'no_source'},
          ],
        }),
      ),
    );
    await answer.close();
    await tester.pump();
    await tester.pump();
    expect(find.text(callButtonLabel), findsNothing);
  });
  testWidgets('stopping a risk answer keeps the 112 panel', (tester) async {
    final answer = StreamController<AnswerEvent>();
    final launched = await pumpChat(
      tester,
      FakeAnswerService(script: (_, _) => answer.stream),
    );
    await ask(tester, 'pożar w bloku');
    answer.add(const AnswerThinking(ThinkingPhase.searching, true));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-stop')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('thinking-label')), findsNothing);
    expect(find.text(callButtonLabel), findsOneWidget);
    expect(launched, isEmpty);
    unawaited(
      answer.close(),
    ); // the subscription is cancelled: close never completes
  });

  AnswerReady ready(List<Map<String, Object?>> panels) =>
      AnswerReady(AssistantAnswer.fromJson({'panels': panels}));
  const noSource = {'type': 'no_source', 'kind': 'no_source'};

  testWidgets(
    '112 follows the latest turn: unpins a few seconds after an answer without it',
    (tester) async {
      final replies = <StreamController<AnswerEvent>>[];
      await pumpChat(
        tester,
        FakeAnswerService(
          script: (_, _) {
            final c = StreamController<AnswerEvent>();
            replies.add(c);
            return c.stream;
          },
        ),
      );
      await ask(tester, 'pożar w bloku');
      replies.last.add(
        ready([
          {'type': 'call'},
          noSource,
        ]),
      );
      await replies.last.close();
      await tester.pump();
      await tester.pump();
      expect(find.text(callButtonLabel), findsOneWidget);

      // Next question: 112 stays while it is being answered.
      await ask(tester, 'ibuprofen z paracetamolem');
      replies.last.add(const AnswerThinking(ThinkingPhase.composing));
      await tester.pump(call112UnpinDelay * 2);
      expect(find.text(callButtonLabel), findsOneWidget);

      // The answer does not call for 112: still there right after it lands...
      replies.last.add(ready([noSource]));
      await replies.last.close();
      await tester.pump();
      await tester.pump();
      expect(find.text(callButtonLabel), findsOneWidget);
      await tester.pump(call112UnpinDelay - const Duration(milliseconds: 100));
      expect(find.text(callButtonLabel), findsOneWidget);
      // ...and gone after the delay.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text(callButtonLabel), findsNothing);

      // A later answer that calls for 112 again brings it back at once.
      await ask(tester, 'dym na klatce');
      replies.last.add(const AnswerThinking(ThinkingPhase.searching, true));
      await tester.pump();
      expect(find.text(callButtonLabel), findsOneWidget);
      replies.last.add(
        ready([
          {'type': 'call'},
          noSource,
        ]),
      );
      await replies.last.close();
      await tester.pump();
      await tester.pump(call112UnpinDelay * 2);
      expect(find.text(callButtonLabel), findsOneWidget);
    },
  );

  testWidgets(
    'a risk answer right after a calm one cancels the pending unpin',
    (tester) async {
      final replies = <StreamController<AnswerEvent>>[];
      await pumpChat(
        tester,
        FakeAnswerService(
          script: (_, _) {
            final c = StreamController<AnswerEvent>();
            replies.add(c);
            return c.stream;
          },
        ),
      );
      await ask(tester, 'pożar w bloku');
      replies.last.add(
        ready([
          {'type': 'call'},
          noSource,
        ]),
      );
      await replies.last.close();
      await tester.pump();
      await ask(tester, 'zapas wody');
      replies.last.add(ready([noSource]));
      await replies.last.close();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await ask(tester, 'ktoś nie oddycha');
      replies.last.add(
        ready([
          {'type': 'call'},
          noSource,
        ]),
      );
      await replies.last.close();
      await tester.pump();
      await tester.pump(call112UnpinDelay * 2);
      expect(find.text(callButtonLabel), findsOneWidget);
    },
  );
}
