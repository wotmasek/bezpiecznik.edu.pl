/// Household profile (E4). Local only; empty means "no data" (null / empty).
library;

const emergencyNumbers = {'112', '999', '998', '997'};

/// Age groups per spec (ekran-4-profil.md, section 1).
enum AgeGroup {
  infant('Niemowlę (0–1)', 'niemowlę'),
  child('Dziecko (2–12)', 'dziecko'),
  teen('Nastolatek (13–17)', 'nastolatek'),
  adult('Dorosły (18–64)', 'dorosły'),
  senior('Senior (65+)', 'senior');

  const AgeGroup(this.label, this.short);
  final String label;
  final String short;
}

/// Pet kinds (section 3).
const petLabels = <String, String>{
  'dog': 'Pies',
  'cat': 'Kot',
  'other': 'Inne',
};

const maxNotesLength = 300;

/// How the assistant addresses the user (grammatical gender in Polish).
enum AddressForm {
  female('Pani', 'Zwracaj się do rozmówcy w formie żeńskiej.'),
  male('Pan', 'Zwracaj się do rozmówcy w formie męskiej.'),
  neutral('Neutralnie', null);

  const AddressForm(this.label, this.promptFact);
  final String label;

  /// Null for neutral: the system prompt already defaults to neutral.
  final String? promptFact;
}

/// Legacy power-dependent device types: no longer edited or sent to the
/// model, kept so stored data and the SMS body still read.
const powerDeviceLabels = <String, String>{
  'oxygen_concentrator': 'Koncentrator tlenu',
  'suction': 'Ssak',
  'electric_wheelchair': 'Wózek elektryczny',
  'pump': 'Pompa (np. insulinowa)',
  'other': 'Inne',
};

/// Normalises a phone number per spec: strips spaces and dashes; 9 digits
/// become `+48XXXXXXXXX`; otherwise `+` and 8-15 digits. Returns null when
/// invalid (including emergency numbers).
String? normalizePhone(String raw) {
  final s = raw.replaceAll(RegExp(r'[\s\-]'), '');
  if (RegExp(r'^\d{9}$').hasMatch(s)) return '+48$s';
  if (RegExp(r'^\+\d{8,15}$').hasMatch(s)) return s;
  return null;
}

bool isEmergencyNumber(String raw) =>
    emergencyNumbers.contains(raw.replaceAll(RegExp(r'[\s\-]'), ''));

class Member {
  const Member({required this.ageGroup, this.label, this.limitedMobility});
  final AgeGroup ageGroup;
  final String? label;
  final bool? limitedMobility;

  Map<String, dynamic> toJson() => {
    'ageGroup': ageGroup.name,
    if (label != null) 'label': label,
    if (limitedMobility != null) 'limitedMobility': limitedMobility,
  };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    ageGroup: AgeGroup.values.firstWhere(
      (a) => a.name == j['ageGroup'],
      orElse: () => AgeGroup.adult,
    ),
    label: j['label'] as String?,
    limitedMobility: j['limitedMobility'] as bool?,
  );
}

class Medication {
  const Medication({required this.name, this.needsFridge});
  final String name;
  final bool? needsFridge;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (needsFridge != null) 'needsFridge': needsFridge,
  };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
    name: j['name'] as String? ?? '',
    needsFridge: j['needsFridge'] as bool?,
  );
}

class Home {
  const Home({this.floor, this.elevator});
  final int? floor;
  final bool? elevator;

  bool get isEmpty => floor == null && elevator == null;

  Map<String, dynamic> toJson() => {
    if (floor != null) 'floor': floor,
    if (elevator != null) 'elevator': elevator,
  };

  factory Home.fromJson(Map<String, dynamic> j) =>
      Home(floor: j['floor'] as int?, elevator: j['elevator'] as bool?);
}

class IceContact {
  const IceContact({required this.name, required this.phone});
  final String name;

  /// Normalised, e.g. `+48600100200`.
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory IceContact.fromJson(Map<String, dynamic> j) => IceContact(
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
  );
}

class HouseholdProfile {
  const HouseholdProfile({
    this.members = const [],
    this.medications = const [],
    this.powerDevices = const {},
    this.powerOtherText,
    this.home = const Home(),
    this.iceContacts = const [],
    this.pets = const {},
    this.notes,
    this.address = AddressForm.neutral,
  });

  static const empty = HouseholdProfile();

  final List<Member> members;
  final List<Medication> medications;

  /// Keys of [powerDeviceLabels].
  final Set<String> powerDevices;
  final String? powerOtherText;
  final Home home;
  final List<IceContact> iceContacts;

  /// Keys of [petLabels].
  final Set<String> pets;

  /// Free text (illnesses, diets), max [maxNotesLength] chars.
  final String? notes;

  /// Not part of [isEmpty]: it is a preference, not household data.
  final AddressForm address;

  bool get isEmpty =>
      members.isEmpty &&
      medications.isEmpty &&
      powerDevices.isEmpty &&
      home.isEmpty &&
      iceContacts.isEmpty &&
      pets.isEmpty &&
      (notes ?? '').trim().isEmpty;

  HouseholdProfile copyWith({
    List<Member>? members,
    List<Medication>? medications,
    Set<String>? powerDevices,
    String? powerOtherText,
    Home? home,
    List<IceContact>? iceContacts,
    Set<String>? pets,
    String? notes,
    AddressForm? address,
  }) => HouseholdProfile(
    members: members ?? this.members,
    medications: medications ?? this.medications,
    powerDevices: powerDevices ?? this.powerDevices,
    powerOtherText: powerOtherText ?? this.powerOtherText,
    home: home ?? this.home,
    iceContacts: iceContacts ?? this.iceContacts,
    pets: pets ?? this.pets,
    notes: notes ?? this.notes,
    address: address ?? this.address,
  );

  Map<String, dynamic> toJson() => {
    'members': [for (final m in members) m.toJson()],
    'medications': [for (final m in medications) m.toJson()],
    'powerDevices': powerDevices.toList()..sort(),
    if (powerOtherText != null) 'powerOtherText': powerOtherText,
    'home': home.toJson(),
    'iceContacts': [for (final c in iceContacts) c.toJson()],
    if (pets.isNotEmpty) 'pets': pets.toList()..sort(),
    if (notes != null) 'notes': notes,
    if (address != AddressForm.neutral) 'address': address.name,
  };

  factory HouseholdProfile.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) => [
      for (final e in (j[k] as List? ?? const []))
        Map<String, dynamic>.from(e as Map),
    ];
    return HouseholdProfile(
      members: [for (final e in list('members')) Member.fromJson(e)],
      medications: [
        for (final e in list('medications')) Medication.fromJson(e),
      ],
      powerDevices: {
        for (final e in (j['powerDevices'] as List? ?? const [])) e as String,
      },
      powerOtherText: j['powerOtherText'] as String?,
      home: Home.fromJson(
        Map<String, dynamic>.from(j['home'] as Map? ?? const {}),
      ),
      iceContacts: [
        for (final e in list('iceContacts')) IceContact.fromJson(e),
      ],
      pets: {
        for (final e in (j['pets'] as List? ?? const []))
          if (e is String) e,
      },
      notes: j['notes'] is String ? j['notes'] as String : null,
      address: AddressForm.values.firstWhere(
        (a) => a.name == j['address'],
        orElse: () => AddressForm.neutral,
      ),
    );
  }

  /// Compact Polish context for the LLM prompt (max [maxPromptContext]
  /// characters). Privacy: never includes ICE contact names or phones.
  String toPromptContext() {
    // Address form goes first so the length cap never cuts it.
    final parts = <String>[?address.promptFact];
    if (members.isNotEmpty) {
      final counts = <AgeGroup, int>{};
      for (final m in members) {
        counts[m.ageGroup] = (counts[m.ageGroup] ?? 0) + 1;
      }
      final desc = [
        for (final g in AgeGroup.values)
          if (counts[g] != null) '${counts[g]} ${g.short}',
      ].join(', ');
      final mobility = members.where((m) => m.limitedMobility == true).length;
      parts.add(
        'Domownicy: $desc${mobility > 0 ? ' (ograniczona mobilność: $mobility)' : ''}.',
      );
    }
    if (medications.isNotEmpty) {
      parts.add(
        'Leki na stałe: ${medications.map((m) => m.name + (m.needsFridge == true ? ' (lodówka)' : '')).join(', ')}.',
      );
    }
    if (pets.isNotEmpty) {
      parts.add(
        'Zwierzęta: ${[for (final k in petLabels.keys)
          if (pets.contains(k)) petLabels[k]!.toLowerCase()].join(', ')}.',
      );
    }
    final h = <String>[
      if (home.floor != null)
        home.floor == 0 ? 'parter' : '${home.floor}. piętro',
      if (home.elevator != null) home.elevator! ? 'winda jest' : 'brak windy',
    ];
    if (h.isNotEmpty) parts.add('Mieszkanie: ${h.join(', ')}.');
    final n = (notes ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.isNotEmpty) parts.add('Dodatkowo: $n');
    var out = '';
    for (final p in parts) {
      final next = out.isEmpty ? p : '$out $p';
      if (next.length > maxPromptContext) {
        // Notes are free text: keep what fits rather than drop them whole.
        final room = maxPromptContext - out.length - 1;
        if (p.startsWith('Dodatkowo: ') && room > 15) {
          out = '$out ${p.substring(0, room - 1)}…';
        }
        break;
      }
      out = next;
    }
    return out;
  }
}

const maxPromptContext = 300;
