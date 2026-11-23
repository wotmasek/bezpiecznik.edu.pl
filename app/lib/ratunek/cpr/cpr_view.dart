import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../czat/templates/call/call_panel_view.dart'
    show callLauncherProvider;
import '../../czat/templates/panel_card.dart';
import '../../czat/templates/panel_model.dart';
import '../../czat/templates/template_registry.dart';
import '../../czat/ui/chat_controller.dart';
import '../ui/rescue_answer.dart';
import '../../wspolne/shell/cpr_state.dart' show formatCprElapsed;
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'cpr_config.dart';
import 'cpr_engine.dart';
import 'cpr_session.dart';

/// Copy of the instructor (Polish, per `instruktor-rko.md`).
const String cprTitle = 'Instruktor RKO';

/// Short name in the pinned header ("RKO · Dorosły").
const String cprShortTitle = 'RKO';
const String cprStartLabel = 'Zacznij uciskanie';
const String cprPauseLabel = 'Pauza';
const String cprResumeLabel = 'Wznów';
const String cprStopLabel = 'Zakończ';
const String cprBreathsDoneLabel = 'Dalej';
const String cprStopTitle = 'Zakończyć RKO?';
const String cprStopConfirmLabel = 'Zakończ RKO';
const String cprStopBackLabel = 'Wróć';
const String cprRestartLabel = 'Zacznij od nowa';

/// "Zakończono · czas 12:05 · 9 cykli" (Polish plural of "cykl").
String cprSummaryText(CprSummary s) {
  final n = s.cycles;
  final last = n % 10;
  final word = n == 1
      ? 'cykl'
      : (last >= 2 && last <= 4 && (n % 100 < 12 || n % 100 > 14))
      ? 'cykle'
      : 'cykli';
  return 'Zakończono · czas ${formatCprElapsed(s.elapsed)} · $n $word';
}

const String cprAedReminderLabel = 'Poproś kogoś o AED';

/// Opens the AED card in the chat (hidden without `aed_card_id`).
const String cprAedHowLabel = 'Jak użyć AED';
const String cprAedDoneLabel = 'Ukryj przypomnienie o AED';

/// Short in-chat notice while the pinned instructor runs (spec: szablony-czatu.md, CprPinned).
const String cprRunningNotice = 'Instruktor RKO działa ↓';
const String cprCompressLabel = 'Uciskaj';

/// Initial rescue breaths: neutral label; the count (card data
/// `initial_breaths`) is shown in the counter slot, like the compressions.
const String cprInitialBreathsLabel = 'Oddechy ratownicze';
const String cprPausedLabel = 'Pauza';

/// `m:ss` for the change countdown ("Zmiana za 0:18").
String formatCprChange(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// How long the "Zmiana ratownika" banner stays after the prompt.
const Duration cprChangeBannerDuration = Duration(seconds: 10);

/// Registers the `cpr` template. With [inlinePinned] the running panel is
/// drawn inside the message (use it until a [CprPinnedHost] is mounted above
/// the composer; then pass false and the card only shows a note).
void registerCprTemplate(TemplateRegistry r, {bool inlinePinned = true}) {
  r.register(
    'cpr',
    (context, scope) => CprCard(scope: scope, inlinePinned: inlinePinned),
  );
}

/// DS `CprCard`: before start (rate, Start; the variant is picked in the
/// message header). While the
/// instructor runs it shows [CprPinned] inline or a note.
class CprCard extends ConsumerWidget {
  const CprCard({super.key, required this.scope, this.inlinePinned = true});

  final PanelScope scope;
  final bool inlinePinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.bz;
    final panel = scope.panel as CprPanel;
    final config = CprConfig.tryParse(panel.raw);
    if (config == null) return const SizedBox.shrink();
    final session = ref.watch(cprSessionProvider);
    // Variant source (child/infant) wins over the adult panel-level one.
    final sourceId = config.variant(scope.variant)?.sourceId ?? panel.sourceId;
    final source = sourceId == null ? null : scope.answer.source(sourceId);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final variant = config.variant(scope.variant);
        final meta = variant == null
            ? null
            : Text(
                '${variant.label} · ${config.rateBpm}/min · ${variant.compressions}:${variant.breaths}',
                key: const ValueKey('cpr-summary'),
                style: t.chat.copyWith(
                  color: t.ink200,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
        final chip = source == null
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: SourceChip(
                  source: source,
                  onTap: () => scope.onOpenSource(source),
                ),
              );
        if (session.running) {
          if (inlinePinned) return CprPinned(session: session);
          // DS `.bz-cprcard__running`: meta, "● Instruktor RKO działa ↓", source.
          return PanelCard(
            title: cprTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (meta != null) ...[meta, SizedBox(height: t.space3)],
                Row(
                  children: [
                    _Beat(color: t.sosText),
                    SizedBox(width: t.space3),
                    Expanded(
                      child: Text(
                        cprRunningNotice,
                        style: t.chat.copyWith(
                          color: t.ink100,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (chip != null) ...[SizedBox(height: t.space2), chip],
              ],
            ),
          );
        }
        final done = session.summary;
        if (done != null) {
          return PanelCard(
            title: cprTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  cprSummaryText(done),
                  key: const ValueKey('cpr-summary-end'),
                  style: t.chat.copyWith(color: t.ink200),
                ),
                SizedBox(height: t.space3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BzButton(
                    label: cprRestartLabel,
                    variant: BzButtonVariant.secondary,
                    size: BzButtonSize.lg,
                    onPressed: () => session.start(config, scope.variant),
                  ),
                ),
              ],
            ),
          );
        }
        return PanelCard(
          title: cprTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?meta,
              SizedBox(height: t.space3),
              BzButton(
                label: cprStartLabel,
                icon: LucideIcons.play,
                variant: BzButtonVariant.primary,
                size: BzButtonSize.lg,
                fullWidth: true,
                onPressed: () => session.start(config, scope.variant),
              ),
              if (chip != null) ...[SizedBox(height: t.space2), chip],
            ],
          ),
        );
      },
    );
  }
}

/// Mount above the composer: shows [CprPinned] while the instructor runs and
/// nothing otherwise.
class CprPinnedHost extends ConsumerWidget {
  const CprPinnedHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cprSessionProvider);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => session.running
          ? CprPinned(session: session)
          : const SizedBox.shrink(),
    );
  }
}

/// DS `CprPinned`: the running instructor (phase, counter, stopwatch,
/// rescuer change, pause / stop, 112).
class CprPinned extends ConsumerWidget {
  const CprPinned({super.key, required this.session});

  final CprSession session;

  Future<void> _dial(WidgetRef ref) async {
    try {
      await ref.read(callLauncherProvider)(Uri(scheme: 'tel', path: '112'));
    } on Object {
      // The chat call panel carries the fallback hint.
    }
  }

  /// Inserts the AED card as a new assistant message; the session keeps
  /// running and stays pinned.
  Future<void> _insertAedCard(WidgetRef ref, String cardId) async {
    try {
      final service = await ref.read(rescueAnswerServiceProvider.future);
      final answer = service.answerForCard(
        cardId,
        variant: session.variant?.id,
      );
      if (answer == null) return;
      ref.read(chatControllerProvider.notifier).insertAssistantAnswer(answer);
    } on Object {
      // Card assets failed to load: the instructor keeps running untouched.
    }
  }

  Future<void> _confirmStop(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(cprStopTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(cprStopBackLabel),
          ),
          BzButton(
            key: const ValueKey('cpr-stop-confirm'),
            label: cprStopConfirmLabel,
            variant: BzButtonVariant.dangerSolid,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok == true) session.stop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session.snapshot;
        final cfg = session.config;
        final v = session.variant;
        if (s == null || cfg == null || v == null) {
          return const SizedBox.shrink();
        }
        return _KeyboardBuilder(
          builder: (context, kb) => _body(context, ref, kb, s, cfg, v),
        );
      },
    );
  }

  Widget _aedRowBody(
    BuildContext context,
    WidgetRef ref,
    CprConfig cfg,
    bool large,
  ) {
    final t = context.bz;
    final text = Text(
      cprAedReminderLabel,
      style: t.label.copyWith(color: t.ink100),
    );
    final how = cfg.aedCardId == null
        ? null
        : BzButton(
            key: const ValueKey('cpr-aed-how'),
            label: cprAedHowLabel,
            variant: BzButtonVariant.ghost,
            size: BzButtonSize.md,
            onPressed: () => unawaited(_insertAedCard(ref, cfg.aedCardId!)),
          );
    final check = BzButton(
      icon: LucideIcons.check,
      semanticLabel: cprAedDoneLabel,
      variant: BzButtonVariant.ghost,
      size: BzButtonSize.md,
      onPressed: session.dismissAedReminder,
    );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: t.space2, right: t.space3),
            child: text,
          ),
          Wrap(children: [?how, check]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: text),
        ?how,
        check,
      ],
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    bool keyboardOpen,
    CprSnapshot s,
    CprConfig cfg,
    CprVariantConfig v,
  ) {
    final t = context.bz;
    final paused = s.phase == CprPhase.paused;
    final breathing =
        s.phase == CprPhase.breathing || s.phase == CprPhase.initialBreaths;
    final inBreaths =
        breathing || (paused && (s.awaitingTap || s.breathRemaining != null));
    final breathLeft = s.breathRemaining;
    final breathTime = breathLeft == null
        ? null
        : formatCprChange(Duration(seconds: ceilSeconds(breathLeft)!));
    final String label;
    if (paused) {
      label = cprPausedLabel;
    } else if (s.phase == CprPhase.breathing) {
      // "Dwa oddechy · 0:08": card text plus the countdown of a timed phase.
      label = breathTime == null
          ? cfg.voice.breaths
          : '${cfg.voice.breaths} · $breathTime';
    } else if (s.phase == CprPhase.initialBreaths) {
      label = cprInitialBreathsLabel;
    } else {
      label = cprCompressLabel;
    }
    // "17 z 30": the big number, then the quieter total (DS `.bz-cpr__count`).
    final counter = s.phase == CprPhase.initialBreaths
        ? '${v.initialBreaths}'
        : inBreaths
        ? ''
        : '${s.beatInCycle}';
    final total = s.phase == CprPhase.compressing || (paused && !inBreaths)
        ? s.cycleLength
        : null;
    final showChange =
        s.changesDue > 0 &&
        s.sinceChange < cprChangeBannerDuration &&
        cfg.voice.change.isNotEmpty;
    // Keyboard open: one line "UCISKAJ 17/30 · 03:42 · [Pauza]".
    if (keyboardOpen) {
      final line = [
        if (counter.isEmpty)
          label
        else
          '$label $counter${total == null ? '' : '/$total'}',
        formatCprElapsed(s.elapsed),
      ].join(' · ');
      return DecoratedBox(
        key: const ValueKey('cpr-pinned-compact'),
        decoration: BoxDecoration(
          color: t.bg200,
          border: Border.all(color: t.line150),
          borderRadius: BorderRadius.circular(t.radiusLg),
          boxShadow: t.shadowFloat,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(t.space4, 0, t.space2, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(color: t.ink100),
                ),
              ),
              // Same "Dalej" as the full view: untimed breath phases (child /
              // infant) wait for it.
              if (breathing)
                BzButton(
                  label: cprBreathsDoneLabel,
                  variant: BzButtonVariant.secondary,
                  size: BzButtonSize.md,
                  onPressed: session.breathsDone,
                ),
              BzButton(
                label: paused ? cprResumeLabel : cprPauseLabel,
                variant: BzButtonVariant.ghost,
                size: BzButtonSize.md,
                onPressed: paused ? session.resume : session.pause,
              ),
            ],
          ),
        ),
      );
    }
    final accent = breathing ? t.signal : t.sosText;

    // Large text: the AED reminder wraps to two lines instead of overflowing.
    final large = MediaQuery.textScalerOf(context).scale(15) > 15 * 1.25;
    final metaStyle = t.label.copyWith(
      color: t.ink300,
      fontWeight: FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final phaseStyle = t.readout.copyWith(
      color: t.ink100,
      height: 34 / 28,
      fontFeatures: const [],
    );

    return DecoratedBox(
      key: const ValueKey('cpr-pinned'),
      decoration: BoxDecoration(
        color: t.bg200,
        // The rescuer-change prompt is the only time the card turns red (DS).
        border: Border.all(color: showChange ? t.sos : t.line150),
        borderRadius: BorderRadius.circular(t.radiusLg),
        boxShadow: t.shadowFloat,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.space4, t.space3, t.space4, t.space3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showChange)
              Padding(
                padding: EdgeInsets.only(bottom: t.space3),
                child: Container(
                  key: const ValueKey('cpr-change-banner'),
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space3,
                    vertical: t.space2,
                  ),
                  decoration: BoxDecoration(
                    color: t.sosTint,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                  child: Text(
                    cfg.voice.change,
                    style: t.label.copyWith(
                      color: t.sosText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            // Phase + counter: "● Uciskaj        17 z 30".
            Row(
              children: [
                _Beat(
                  color: paused ? t.ink300 : accent,
                  tick: s.phase == CprPhase.compressing ? s.beatInCycle : null,
                ),
                SizedBox(width: t.space3),
                Expanded(
                  // One line, never broken mid-phrase: shrinks when too wide.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      key: const ValueKey('cpr-phase'),
                      maxLines: 1,
                      softWrap: false,
                      style: phaseStyle,
                    ),
                  ),
                ),
                SizedBox(width: t.space3),
                // Not flexible: the counter hugs the right edge, the phase
                // label shrinks first.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      counter,
                      key: const ValueKey('cpr-counter'),
                      style: t.readout.copyWith(color: t.ink100),
                    ),
                    if (total != null)
                      Text(
                        ' z $total',
                        style: t.chat.copyWith(
                          color: t.ink200,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // One meta line "RKO · Dorosły · 01:28 · zmiana za 0:32" + the
            // 112 pill (kept: 112 is always one tap away, 48 dp hit area).
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: t.space1,
                    children: [
                      Text('$cprShortTitle · ${v.label}', style: metaStyle),
                      Text('·', style: metaStyle),
                      Text(
                        formatCprElapsed(s.elapsed),
                        key: const ValueKey('cpr-time'),
                        style: metaStyle,
                      ),
                      Text('·', style: metaStyle),
                      Text(
                        'zmiana za ${formatCprChange(s.untilChange)}',
                        key: const ValueKey('cpr-change'),
                        style: metaStyle,
                      ),
                    ],
                  ),
                ),
                BzButton(
                  key: const ValueKey('cpr-112'),
                  label: '112',
                  variant: BzButtonVariant.sos,
                  size: BzButtonSize.sm,
                  onPressed: () => unawaited(_dial(ref)),
                ),
              ],
            ),
            if (session.aedReminderVisible)
              Container(
                key: const ValueKey('cpr-aed-row'),
                margin: EdgeInsets.only(top: t.space1),
                padding: EdgeInsets.only(left: t.space3),
                decoration: BoxDecoration(
                  color: t.overlayHover,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
                child: _aedRowBody(context, ref, cfg, large),
              )
            else if (cfg.aedCardId case final aedId?)
              Align(
                alignment: Alignment.centerLeft,
                child: BzButton(
                  key: const ValueKey('cpr-aed-how'),
                  label: cprAedHowLabel,
                  variant: BzButtonVariant.ghost,
                  size: BzButtonSize.md,
                  onPressed: () => unawaited(_insertAedCard(ref, aedId)),
                ),
              ),
            SizedBox(height: t.space1),
            // DS `.bz-cpr__actions`: equal columns, 44 px ("Dalej" joins the
            // row during breaths, so the pinned card stays short).
            Row(
              children: [
                if (breathing) ...[
                  Expanded(
                    child: BzButton(
                      label: cprBreathsDoneLabel,
                      variant: BzButtonVariant.primary,
                      size: BzButtonSize.lg,
                      fullWidth: true,
                      onPressed: session.breathsDone,
                    ),
                  ),
                  SizedBox(width: t.space2),
                ],
                Expanded(
                  child: BzButton(
                    label: paused ? cprResumeLabel : cprPauseLabel,
                    icon: paused ? LucideIcons.play : LucideIcons.pause,
                    variant: BzButtonVariant.secondary,
                    size: BzButtonSize.lg,
                    fullWidth: true,
                    onPressed: paused ? session.resume : session.pause,
                  ),
                ),
                SizedBox(width: t.space2),
                Expanded(
                  child: BzButton(
                    label: cprStopLabel,
                    variant: BzButtonVariant.ghost,
                    size: BzButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => unawaited(_confirmStop(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells whether the soft keyboard is open. Reads the raw view insets: the
/// chat Scaffold strips `MediaQuery.viewInsets` from its body, and rebuilds on
/// metrics changes.
class _KeyboardBuilder extends StatefulWidget {
  const _KeyboardBuilder({required this.builder});
  final Widget Function(BuildContext context, bool keyboardOpen) builder;

  @override
  State<_KeyboardBuilder> createState() => _KeyboardBuilderState();
}

class _KeyboardBuilderState extends State<_KeyboardBuilder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    MediaQuery.viewInsetsOf(context).bottom > 0 ||
        View.of(context).viewInsets.bottom > 0,
  );
}

/// Metronome dot (DS `.bz-beat`): 10 dp, pulses 1.35 -> 0.85 on every
/// compression ([tick] changes). A function, not decoration: it keeps beating
/// with reduced motion; [tick] null = still dot (pause, breaths).
class _Beat extends StatefulWidget {
  const _Beat({required this.color, this.tick});

  final Color color;
  final int? tick;

  @override
  State<_Beat> createState() => _BeatState();
}

class _BeatState extends State<_Beat> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );

  @override
  void didUpdateWidget(_Beat old) {
    super.didUpdateWidget(old);
    if (widget.tick != null && widget.tick != old.tick) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ScaleTransition(
      scale: Tween<double>(
        begin: 1.35,
        end: widget.tick == null ? 1 : 0.85,
      ).animate(CurvedAnimation(parent: _c, curve: context.bz.easeOut)),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    ),
  );
}
