import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_buttons.dart';

/// Read-aloud button labels (spec `steps`).
const String readAloudStartLabel = 'Czytaj na głos';
const String readAloudStopLabel = 'Zatrzymaj czytanie';

/// Text-to-speech port for the `steps` "Czytaj na glos" button. Fakeable in
/// tests through [readAloudVoiceProvider].
abstract interface class ReadAloudVoice {
  /// True when a Polish voice can be used. Never throws.
  Future<bool> isAvailable();

  /// Speaks [text] and completes when it finished or was stopped. Never throws.
  Future<void> speak(String text);

  /// Stops any speech. Never throws.
  Future<void> stop();
}

/// `flutter_tts` implementation, pl-PL. Every failure is swallowed: without a
/// voice the button is simply hidden.
class FlutterTtsReadAloudVoice implements ReadAloudVoice {
  FlutterTtsReadAloudVoice([FlutterTts? tts]) : _tts = tts;

  FlutterTts? _tts;
  Future<bool>? _init;

  FlutterTts get _engine => _tts ??= FlutterTts();

  Future<bool> _ensure() => _init ??= () async {
    try {
      final ok = await _engine.isLanguageAvailable('pl-PL');
      if (ok != true) return false;
      await _engine.setLanguage('pl-PL');
      await _engine.setSpeechRate(0.5);
      await _engine.awaitSpeakCompletion(true);
      return true;
    } on Object {
      return false;
    }
  }();

  @override
  Future<bool> isAvailable() => _ensure();

  @override
  Future<void> speak(String text) async {
    try {
      if (!await _ensure()) return;
      await _engine.speak(text);
    } on Object {
      // No voice available.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } on Object {
      // Ignored.
    }
  }
}

final readAloudVoiceProvider = Provider<ReadAloudVoice>((ref) {
  final voice = FlutterTtsReadAloudVoice();
  ref.onDispose(voice.stop);
  return voice;
});

/// "Czytaj na głos" / "Zatrzymaj czytanie". Reads the steps from the current
/// (first unchecked) one onwards; checking the current step moves the speech
/// to the next one. Hidden while no Polish voice is known to be available.
class ReadAloudButton extends ConsumerStatefulWidget {
  const ReadAloudButton({super.key, required this.texts, required this.done});

  final List<String> texts;
  final Set<int> done;

  @override
  ConsumerState<ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends ConsumerState<ReadAloudButton> {
  late final ReadAloudVoice _voice = ref.read(readAloudVoiceProvider);
  bool _available = false;
  bool _speaking = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _voice.isAvailable().then((ok) {
      if (mounted && ok) setState(() => _available = true);
    }, onError: (_) {});
  }

  int get _current {
    for (var i = 0; i < widget.texts.length; i++) {
      if (!widget.done.contains(i)) return i;
    }
    return -1;
  }

  @override
  void didUpdateWidget(ReadAloudButton old) {
    super.didUpdateWidget(old);
    if (!_speaking || widget.done.length == old.done.length) return;
    final cur = _current;
    if (cur == -1) {
      _stop();
    } else {
      _start(cur);
    }
  }

  @override
  void dispose() {
    if (_speaking) _voice.stop();
    _run++;
    super.dispose();
  }

  Future<void> _stop() async {
    _run++;
    if (mounted) setState(() => _speaking = false);
    await _voice.stop();
  }

  Future<void> _start(int from) async {
    final run = ++_run;
    await _voice.stop();
    if (!mounted || run != _run) return;
    setState(() => _speaking = true);
    for (var i = from; i < widget.texts.length; i++) {
      if (widget.done.contains(i)) continue;
      await _voice.speak(widget.texts[i]);
      if (!mounted || run != _run) return;
    }
    setState(() => _speaking = false);
  }

  void _toggle() {
    if (_speaking) {
      _stop();
      return;
    }
    final cur = _current;
    if (cur != -1) _start(cur);
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return BzButton(
      label: _speaking ? readAloudStopLabel : readAloudStartLabel,
      icon: _speaking ? LucideIcons.volumeX : LucideIcons.volume2,
      variant: BzButtonVariant.secondary,
      size: BzButtonSize.md,
      onPressed: _toggle,
    );
  }
}

