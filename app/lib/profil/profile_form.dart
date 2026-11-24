import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_chip.dart';
import '../wspolne/theme/bz_theme.dart';
import 'profile_model.dart';
import 'section_card.dart';

export '../wspolne/theme/bz_chip.dart' show BzChip;

/// Editable form shared by E4 (edit) and the E0 wizard step. Reports only
/// valid data through [onChanged]; invalid entries show an error and are not
/// emitted (spec: invalid value is never saved).
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initial,
    required this.onChanged,
    this.onValidityChanged,
  });

  final HouseholdProfile initial;
  final ValueChanged<HouseholdProfile> onChanged;

  /// Reports whether every field is currently valid (false = show errors,
  /// the host should block "Dalej").
  final ValueChanged<bool>? onValidityChanged;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ContactDraft {
  _ContactDraft(String name, String phone)
    : name = TextEditingController(text: name),
      phone = TextEditingController(text: phone);
  final TextEditingController name;
  final TextEditingController phone;
  bool phoneTouched = false;
}

class _ProfileFormState extends State<ProfileForm> {
  late Map<AgeGroup, int> _counts;
  late List<Member> _extraMembers; // keeps labels/mobility of existing members
  late List<TextEditingController> _meds;
  late Set<String> _pets;
  late TextEditingController _notes;
  late TextEditingController _floor;
  bool? _elevator;
  late List<_ContactDraft> _contacts;
  late AddressForm _address;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _counts = {
      for (final g in AgeGroup.values)
        g: p.members.where((m) => m.ageGroup == g).length,
    };
    _extraMembers = p.members;
    _meds = [
      for (final m in p.medications) TextEditingController(text: m.name),
    ];
    _pets = {...p.pets};
    _notes = TextEditingController(text: p.notes ?? '');
    _floor = TextEditingController(text: p.home.floor?.toString() ?? '');
    _elevator = p.home.elevator;
    _address = p.address;
    _contacts = [for (final c in p.iceContacts) _ContactDraft(c.name, c.phone)];
  }

  @override
  void dispose() {
    for (final c in [
      ..._meds,
      _notes,
      _floor,
      for (final d in _contacts) ...[d.name, d.phone],
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _floorError() {
    final t = _floor.text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null || v < -2 || v > 100) return 'Wpisz liczbę od -2 do 100.';
    return null;
  }

  String? _nameError(_ContactDraft d) {
    if (d.name.text.trim().isEmpty && d.phone.text.trim().isNotEmpty) {
      return 'Wpisz nazwę albo usuń wpis.';
    }
    return null;
  }

  String? _phoneError(_ContactDraft d) {
    final t = d.phone.text.trim();
    if (t.isEmpty) {
      return d.name.text.trim().isEmpty || !d.phoneTouched
          ? null
          : 'Wpisz numer w formacie 600 100 200 albo +48 600 100 200.';
    }
    if (isEmergencyNumber(t)) {
      return 'To numer alarmowy. Wpisz numer bliskiej osoby.';
    }
    if (normalizePhone(t) == null) {
      return 'Wpisz numer w formacie 600 100 200 albo +48 600 100 200.';
    }
    return null;
  }

  HouseholdProfile _build() {
    // Rebuild members: keep existing entries of a group (with labels), then
    // trim/extend to the chosen count.
    final members = <Member>[];
    for (final g in AgeGroup.values) {
      final existing = _extraMembers.where((m) => m.ageGroup == g).toList();
      for (var i = 0; i < _counts[g]!; i++) {
        members.add(i < existing.length ? existing[i] : Member(ageGroup: g));
      }
    }
    final contacts = <IceContact>[];
    for (final d in _contacts) {
      if (_nameError(d) != null || _phoneError(d) != null) continue;
      final phone = normalizePhone(d.phone.text.trim());
      if (phone == null || d.name.text.trim().isEmpty) continue;
      contacts.add(IceContact(name: d.name.text.trim(), phone: phone));
    }
    return HouseholdProfile(
      members: members,
      medications: [
        for (final c in _meds)
          if (c.text.trim().isNotEmpty) Medication(name: c.text.trim()),
      ],
      home: Home(
        floor: _floorError() == null
            ? int.tryParse(_floor.text.trim())
            : widget.initial.home.floor,
        elevator: _elevator,
      ),
      iceContacts: contacts,
      pets: _pets,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      address: _address,
    );
  }

  bool get _valid =>
      _floorError() == null &&
      _contacts.every((d) => _nameError(d) == null && _phoneError(d) == null);

  void _changed([VoidCallback? mutate]) {
    setState(() => mutate?.call());
    widget.onChanged(_build());
    widget.onValidityChanged?.call(_valid);
  }

  Widget _section(String title, IconData icon, List<Widget> children) =>
      Padding(
        padding: EdgeInsets.only(top: context.bz.space4),
        child: SectionCard(title: title, icon: icon, children: children),
      );

  /// Ghost buttons carry a horizontal padding; shift left so the label lines
  /// up with the section headings.
  Widget _flushLeft(Widget child) => Align(
    alignment: Alignment.centerLeft,
    child: Transform.translate(
      offset: Offset(-BzButtonSize.md.hPadding, 0),
      child: child,
    ),
  );

  Widget _yesNo(
    String label,
    bool? value,
    ValueChanged<bool?> on, {
    String? key,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: context.bz.chat)),
        for (final (text, v) in [('Tak', true), ('Nie', false)])
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: BzChip(
              key: key == null ? null : Key('$key-$text'),
              label: text,
              selected: value == v,
              onChanged: (s) => on(s ? v : null),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Jak mam się do Ciebie zwracać?', LucideIcons.messageCircle, [
          Wrap(
            spacing: context.bz.space2,
            runSpacing: context.bz.space2,
            children: [
              for (final a in AddressForm.values)
                BzChip(
                  key: Key('address-${a.name}'),
                  label: a.label,
                  selected: _address == a,
                  onChanged: (_) => _changed(() => _address = a),
                ),
            ],
          ),
        ]),
        _section('Kto mieszka w domu?', LucideIcons.users, [
          for (final g in AgeGroup.values)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(child: Text(g.label, style: context.bz.chat)),
                  IconButton(
                    key: Key('members-${g.name}-minus'),
                    tooltip: 'Mniej: ${g.short}',
                    onPressed: _counts[g]! > 0
                        ? () => _changed(() => _counts[g] = _counts[g]! - 1)
                        : null,
                    icon: const Icon(LucideIcons.minus),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${_counts[g]}',
                      textAlign: TextAlign.center,
                      key: Key('members-${g.name}-count'),
                      style: context.bz.chat.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _counts[g] == 0
                            ? context.bz.ink300
                            : context.bz.ink100,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('members-${g.name}-plus'),
                    tooltip: 'Więcej: ${g.short}',
                    onPressed: _counts.values.fold<int>(0, (a, b) => a + b) < 15
                        ? () => _changed(() => _counts[g] = _counts[g]! + 1)
                        : null,
                    icon: const Icon(LucideIcons.plus),
                  ),
                ],
              ),
            ),
        ]),
        _section('Zwierzęta', LucideIcons.pawPrint, [
          Wrap(
            spacing: context.bz.space2,
            runSpacing: context.bz.space2,
            children: [
              for (final e in petLabels.entries)
                BzChip(
                  key: Key('pet-${e.key}'),
                  label: e.value,
                  selected: _pets.contains(e.key),
                  onChanged: (s) => _changed(
                    () => s ? _pets.add(e.key) : _pets.remove(e.key),
                  ),
                ),
            ],
          ),
        ]),
        _section('Leki', LucideIcons.pill, [
          for (var i = 0; i < _meds.length; i++)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('med-$i'),
                    controller: _meds[i],
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa leku',
                      hintText: 'Np. insulina',
                      counterText: '',
                    ),
                    onChanged: (_) => _changed(),
                  ),
                ),
                IconButton(
                  tooltip: 'Usuń lek',
                  onPressed: () => _changed(() => _meds.removeAt(i).dispose()),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          if (_meds.length < 20)
            _flushLeft(
              BzButton(
                key: const Key('med-add'),
                label: 'Dodaj lek',
                icon: LucideIcons.plus,
                variant: BzButtonVariant.ghost,
                onPressed: () =>
                    _changed(() => _meds.add(TextEditingController())),
              ),
            ),
        ]),
        _section('Twoje mieszkanie', LucideIcons.house, [
          TextField(
            key: const Key('home-floor'),
            controller: _floor,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: 'Piętro',
              helperText: '0 to parter',
              errorText: _floorError(),
            ),
            onChanged: (_) => _changed(),
          ),
          SizedBox(height: context.bz.space2),
          _yesNo(
            'Winda',
            _elevator,
            (v) => _changed(() => _elevator = v),
            key: 'home-elevator',
          ),
        ]),
        _section('Dodatkowe informacje', LucideIcons.notebookPen, [
          TextField(
            key: const Key('notes'),
            controller: _notes,
            maxLength: maxNotesLength,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Np. choroby, diety'),
            onChanged: (_) => _changed(),
          ),
        ]),
        _section('Kogo powiadomić w razie zagrożenia?', LucideIcons.bookUser, [
          Text(
            'Do tych osób przygotujemy SMS z twoją pozycją. Wyślesz go sam.',
            style: context.bz.caption.copyWith(color: context.bz.ink200),
          ),
          SizedBox(height: context.bz.space3),
          for (var i = 0; i < _contacts.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        key: Key('ice-name-$i'),
                        controller: _contacts[i].name,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: 'Imię',
                          counterText: '',
                          errorText: _nameError(_contacts[i]),
                        ),
                        onChanged: (_) => _changed(),
                      ),
                      SizedBox(height: context.bz.space3),
                      TextField(
                        key: Key('ice-phone-$i'),
                        controller: _contacts[i].phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Numer',
                          errorText: _phoneError(_contacts[i]),
                        ),
                        onChanged: (_) =>
                            _changed(() => _contacts[i].phoneTouched = true),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Usuń kontakt',
                  onPressed: () => _changed(() {
                    final d = _contacts.removeAt(i);
                    d.name.dispose();
                    d.phone.dispose();
                  }),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          if (_contacts.length < 5)
            _flushLeft(
              BzButton(
                key: const Key('ice-add'),
                label: 'Dodaj kontakt',
                icon: LucideIcons.plus,
                variant: BzButtonVariant.ghost,
                onPressed: () =>
                    _changed(() => _contacts.add(_ContactDraft('', ''))),
              ),
            ),
        ]),
      ],
    );
  }
}
