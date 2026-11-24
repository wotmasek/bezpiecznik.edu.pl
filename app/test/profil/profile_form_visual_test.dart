import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bezpiecznik/profil/profile_form.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'chips are 40 dp tall stadiums; add-medication aligns with headings',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildBzTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ProfileForm(
                initial: HouseholdProfile.empty,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      final chips = find.byType(BzChip);
      expect(chips, findsWidgets);
      for (final e in chips.evaluate()) {
        expect(tester.getSize(find.byWidget(e.widget)).height, 40);
      }
      final material = tester.widget<Material>(
        find.descendant(of: chips.first, matching: find.byType(Material)).first,
      );
      expect(material.shape, isA<StadiumBorder>());

      final headingX = tester.getTopLeft(find.byIcon(LucideIcons.pill)).dx;
      final addLabelX = tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(const Key('med-add')),
              matching: find.byIcon(LucideIcons.plus),
            ),
          )
          .dx;
      expect(addLabelX, closeTo(headingX, 0.5));
    },
  );

  testWidgets('pets and notes are editable, no overflow at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    HouseholdProfile? last;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBzTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ProfileForm(
                initial: HouseholdProfile.empty,
                onChanged: (p) => last = p,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Zwierzęta'), findsOneWidget);
    expect(find.text('Dodatkowe informacje'), findsOneWidget);
    expect(find.byKey(const Key('device-pump')), findsNothing);
    await tester.tap(find.byKey(const Key('pet-dog')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('notes')), 'Astma');
    await tester.pump();
    expect(last!.pets, {'dog'});
    expect(last!.notes, 'Astma');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an address chip reports the choice', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    HouseholdProfile? last;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileForm(
              initial: HouseholdProfile.empty,
              onChanged: (p) => last = p,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Jak mam się do Ciebie zwracać?'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('address-neutral'))),
      matchesSemantics(
        label: 'Neutralnie',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    await tester.tap(find.byKey(const Key('address-female')));
    await tester.pump();
    expect(last?.address, AddressForm.female);
    expect(
      tester.getSemantics(find.byKey(const Key('address-female'))),
      matchesSemantics(
        label: 'Pani',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    await tester.tap(find.byKey(const Key('address-male')));
    await tester.pump();
    expect(last?.address, AddressForm.male);
  });
}
