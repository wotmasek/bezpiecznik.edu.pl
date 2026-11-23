import 'dart:convert';

import 'package:bezpiecznik/app_router.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_fixtures.dart';
import 'package:bezpiecznik/czat/templates/source_sheet.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/shell/root_overlay.dart';
import 'package:bezpiecznik/wspolne/shell/sos_button.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpApp(WidgetTester t, String fixture) => t.pumpWidget(
  ProviderScope(
    overrides: [
      templateRegistryProvider.overrideWithValue(
        TemplateRegistry.withDefaults(),
      ),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: buildBzTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TemplateRenderer(
            answer: AssistantAnswer.fromJson(
              jsonDecode(templateFixtures[fixture]!),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'chip opens source sheet with title, page, text; Zamknij closes',
    (t) async {
      await pumpApp(t, 'steps');
      await t.tap(find.text('Przykład, s.\u00A022'));
      await t.pumpAndSettle();
      expect(find.text('Strona 22'), findsOneWidget);
      expect(find.text('Zamknij'), findsOneWidget);
      await t.tap(find.text('Zamknij'));
      await t.pumpAndSettle();
      expect(find.text('Strona 22'), findsNothing);
    },
  );

  testWidgets('200% font on a phone: quote card and sheet do not overflow', (t) async {
    t.view.physicalSize = const Size(360, 740);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(t, 'quote');
    await t.ensureVisible(find.text('Powiększ'));
    await t.pumpAndSettle();
    await t.tap(find.text('Powiększ'));
    await t.pumpAndSettle();
    expect(find.text('Strona 14'), findsOneWidget);
    expect(find.text('Zamknij').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Powiększ in quote opens sheet with fragment text', (t) async {
    await pumpApp(t, 'quote');
    await t.tap(find.text('Powiększ'));
    await t.pumpAndSettle();
    expect(find.text('Strona 14'), findsOneWidget);
    // The chat shows only `{doc_short} · s. {page}`; the full title is in the sheet.
    expect(find.text('Dokument przykładowy (fixture)'), findsOneWidget);
    expect(
      find.textContaining('Przykładowy fragment źródła'),
      findsNWidgets(2),
    );
  });

  testWidgets(
    'SOS stays on top and hit-testable while the source sheet is open',
    (t) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final router = createAppRouter(initialLocation: '/mapa');
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          profileStoreProvider.overrideWithValue(ProfileStore.inMemory()),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        ],
      );
      addTearDown(container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: buildBzTheme(),
            routerConfig: router,
            builder: (context, child) =>
                RootOverlay(sosLauncher: (_) async => true, child: child!),
          ),
        ),
      );
      await t.pumpAndSettle();
      final ctx = t.element(find.byType(Scaffold).first);
      showSourceSheet(
        ctx,
        const SourceRecord(
          sourceId: 's',
          docShort: 'D',
          docTitle: 'Dokument',
          pageLabel: '7',
          text: 'Fragment',
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Strona 7'), findsOneWidget);
      final sos = find.byType(SosButton);
      expect(sos, findsOneWidget);
      expect(sos.hitTestable(), findsOneWidget);
    },
  );
}
