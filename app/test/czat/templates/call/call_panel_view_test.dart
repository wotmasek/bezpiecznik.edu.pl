import 'package:bezpiecznik/czat/templates/call/call_panel_view.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pump(WidgetTester tester, List<Uri> launched, Widget child) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        callLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
      ],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('one full-width "Zadzwoń 112" button, nothing else', (tester) async {
    await pump(tester, [], const CallPanelView());
    expect(find.text(callButtonLabel), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('Wezwij pomoc'), findsNothing);
    expect(find.text('Dodaj kontakty'), findsNothing);
    expect(find.text('Więcej'), findsNothing);
    final size = tester.getSize(find.byKey(const Key('call-112')));
    expect(size.width, 400);
    expect(size.height, greaterThanOrEqualTo(56));
    final semantics = tester.getSemantics(find.text(callButtonLabel));
    expect(semantics.label, callButtonLabel);
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('icon and label sit centred on one line', (tester) async {
    await pump(tester, [], const CallPanelView());
    final button = tester.getRect(find.byKey(const Key('call-112')));
    final icon = tester.getRect(find.byType(Icon));
    final label = tester.getRect(find.text(callButtonLabel));
    expect((icon.center.dy - label.center.dy).abs(), lessThanOrEqualTo(1));
    expect((icon.center.dy - button.center.dy).abs(), lessThanOrEqualTo(1));
    // The icon + gap + label group is centred horizontally.
    final group = icon.expandToInclude(label);
    expect((group.center.dx - button.center.dx).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('nothing dialled before a tap; a tap dials 112', (tester) async {
    final launched = <Uri>[];
    await pump(tester, launched, const CallPanelView());
    expect(launched, isEmpty);
    await tester.tap(find.byKey(const Key('call-112')));
    await tester.pump();
    expect(launched.single.toString(), 'tel:112');
  });

  testWidgets('registerCallTemplate replaces the placeholder', (tester) async {
    final r = TemplateRegistry.withDefaults();
    registerCallTemplate(r);
    await pump(
      tester,
      [],
      Builder(
        builder: (c) => r.builderFor('call')!(
          c,
          PanelScope(
            panel: const CallPanel(),
            index: 0,
            answer: const AssistantAnswer(),
            variant: null,
            showVariantSwitch: false,
            onVariantChanged: (_) {},
            done: const {},
            onDoneChanged: (_, _) {},
            onOpenSource: (_) {},
          ),
        ),
      ),
    );
    expect(find.text(callButtonLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('placeholder-call')), findsNothing);
  });
}
