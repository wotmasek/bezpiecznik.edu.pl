import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = HouseholdProfile(
    members: [
      Member(ageGroup: AgeGroup.adult),
      Member(ageGroup: AgeGroup.adult, limitedMobility: true),
      Member(ageGroup: AgeGroup.child, label: 'Ola'),
    ],
    medications: [
      Medication(name: 'Insulina', needsFridge: true),
      Medication(name: 'Euthyrox'),
    ],
    pets: {'dog', 'cat'},
    notes: 'Cukrzyca typu 1, dieta bezglutenowa',
    home: Home(floor: 7, elevator: false),
    iceContacts: [IceContact(name: 'Anna Kowalska', phone: '+48600100200')],
  );

  test('JSON round trip', () {
    final back = HouseholdProfile.fromJson(full.toJson());
    expect(back.toJson(), full.toJson());
    expect(back.members.length, 3);
    expect(back.home.floor, 7);
    expect(back.home.elevator, false);
    expect(back.iceContacts.single.phone, '+48600100200');
  });

  test('empty profile: null fields stay absent, empty context', () {
    final j = HouseholdProfile.empty.toJson();
    expect((j['home'] as Map), isEmpty);
    expect(HouseholdProfile.fromJson(j).isEmpty, isTrue);
    expect(HouseholdProfile.empty.toPromptContext(), '');
  });

  test('prompt context is compact and has no ICE names or phones', () {
    final c = full.toPromptContext();
    expect(c.length, lessThanOrEqualTo(maxPromptContext));
    expect(c, contains('2 dorosły'));
    expect(c, contains('1 dziecko'));
    expect(c, contains('Insulina (lodówka)'));
    expect(c, contains('Zwierzęta: pies, kot.'));
    expect(c, contains('Dodatkowo: Cukrzyca typu 1'));
    expect(c, isNot(contains('Urządzenia')));
    expect(c, contains('7. piętro'));
    expect(c, contains('brak windy'));
    expect(c, isNot(contains('Anna')));
    expect(c, isNot(contains('Kowalska')));
    expect(c, isNot(contains('600')));
  });

  test('prompt context never exceeds the limit', () {
    final p = HouseholdProfile(
      medications: [
        for (var i = 0; i < 20; i++)
          Medication(name: 'Lek numer $i bardzo długa nazwa'),
      ],
      home: const Home(floor: 3),
    );
    expect(p.toPromptContext().length, lessThanOrEqualTo(maxPromptContext));
  });

  test('pets and notes round trip; old JSON without them still loads', () {
    final back = HouseholdProfile.fromJson(full.toJson());
    expect(back.pets, {'dog', 'cat'});
    expect(back.notes, 'Cukrzyca typu 1, dieta bezglutenowa');
    final old = HouseholdProfile.fromJson({
      'members': [],
      'powerDevices': ['pump'],
      'powerOtherText': 'x',
      'home': {'floor': 2},
    });
    expect(old.pets, isEmpty);
    expect(old.notes, isNull);
    expect(old.toPromptContext(), 'Mieszkanie: 2. piętro.');
    expect(const HouseholdProfile(pets: {'cat'}).isEmpty, isFalse);
  });

  test('long notes are truncated to fit the context limit', () {
    final p = HouseholdProfile(
      home: const Home(floor: 1),
      notes: 'Choroba ' * 60,
    );
    final c = p.toPromptContext();
    expect(c.length, lessThanOrEqualTo(maxPromptContext));
    expect(c, contains('Dodatkowo: Choroba'));
    expect(c, endsWith('…'));
  });

  test('phone normalisation and emergency numbers', () {
    expect(normalizePhone('600 100 200'), '+48600100200');
    expect(normalizePhone('+48 600-100-200'), '+48600100200');
    expect(normalizePhone('+4915112345678'), '+4915112345678');
    expect(normalizePhone('12345'), isNull);
    expect(isEmergencyNumber('112'), isTrue);
    expect(isEmergencyNumber('997'), isTrue);
    expect(isEmergencyNumber('600100200'), isFalse);
  });

  test('address form: round trip, old JSON loads as neutral, fact first', () {
    final old = HouseholdProfile.fromJson(full.toJson());
    expect(old.address, AddressForm.neutral);
    expect(full.toJson().containsKey('address'), isFalse);
    expect(old.toPromptContext(), isNot(contains('Zwracaj')));

    final female = full.copyWith(address: AddressForm.female);
    expect(female.toJson()['address'], 'female');
    expect(
      HouseholdProfile.fromJson(female.toJson()).address,
      AddressForm.female,
    );
    expect(
      female.toPromptContext(),
      startsWith('Zwracaj się do rozmówcy w formie żeńskiej. Domownicy:'),
    );
    expect(
      const HouseholdProfile(address: AddressForm.male).toPromptContext(),
      'Zwracaj się do rozmówcy w formie męskiej.',
    );
    expect(
      HouseholdProfile.fromJson({'address': 'bogus'}).address,
      AddressForm.neutral,
    );

    final long = female.copyWith(notes: 'x' * maxNotesLength);
    final ctx = long.toPromptContext();
    expect(ctx.length, lessThanOrEqualTo(maxPromptContext));
    expect(ctx, startsWith('Zwracaj się'));
  });
}
