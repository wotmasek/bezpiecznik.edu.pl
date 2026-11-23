import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../ratunek/cpr/cpr_session.dart';
import '../../ratunek/cpr/cpr_view.dart';
import '../../wspolne/theme/bz_theme.dart';
import '../llm/llm_provider.dart';
import '../templates/call/call_panel_view.dart';
import '../templates/panel_model.dart';
import 'chat_controller.dart';
import 'composer.dart';
import 'message_view.dart';
import 'quick_actions.dart';

const String emptyChatHeading = 'Co się dzieje?';
const String emptyChatNote = 'Działa bez internetu. Nie zastępuje 112.';
const String newAnswerLabel = 'Nowa odpowiedź';

/// E1: the chat. The shell overlay draws the island (top left) and SOS (top
/// right) above this screen, so the list leaves room at the top and scrolls
/// under a soft gradient.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Start loading the model once the first frame is on screen. Listening
    // (not a one-off read) keeps the provider active, so it loads the model
    // by itself when the in-app download finishes later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.listenManual(llmWarmUpProvider, (_, _) {});
    });
  }

  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  bool _atBottom = true;

  /// True from sending a question until the user drags the list themselves:
  /// the answer then scrolls to its start. Lazy-list extents are estimates, so
  /// `_atBottom` alone can be spuriously false after the question's own
  /// scroll-to-end (BG83).
  bool _follow = true;
  String? _chatId;

  /// Height of the band covered by the island/SOS; set in build.
  double _listTop = 0;

  /// Id of an answer that arrived while the user was reading higher up.
  String? _unseenAnswerId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) _follow = false;
    final m = n.metrics;
    final atBottom = m.pixels >= m.maxScrollExtent - 80;
    final seen =
        _unseenAnswerId != null &&
        (atBottom || !_endBelowViewport(_unseenAnswerId!));
    if (atBottom != _atBottom || seen) {
      setState(() {
        _atBottom = atBottom;
        if (seen) _unseenAnswerId = null;
      });
    }
    return false;
  }

  /// Whether the end of message [id] is below the visible list (unbuilt items
  /// count as below).
  bool _endBelowViewport(String id) {
    final box = _keys[id]?.currentContext?.findRenderObject();
    if (box == null || !_scroll.hasClients) return true;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return true;
    final end = viewport.getOffsetToReveal(box, 1).offset;
    return end > _scroll.position.pixels + 1;
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: context.bz.durationBase,
        curve: context.bz.easeOut,
      );
    });
  }

  /// Scrolls so the top of the message [id] lands just below the floating
  /// island/SOS band (`_listTop`), not at the raw viewport top where the
  /// island would cover the first line.
  void _toStartOf(String id, {bool retry = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final ctx = _keys[id]?.currentContext;
      if (ctx == null) {
        // The lazy list has not built the item yet (far below a tall
        // neighbour): jump near the end so it gets built, then retry once.
        if (retry) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
          _toStartOf(id, retry: false);
        }
        return;
      }
      final box = ctx.findRenderObject();
      if (box == null) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final messages = ref.read(chatControllerProvider).messages;
      final index = messages.indexWhere((m) => m.id == id);
      // Every item but the first carries a top gap; the card itself should
      // start at the band edge.
      final gap = index > 0 ? context.bz.space5 : 0.0;
      final reveal = viewport.getOffsetToReveal(box, 0).offset;
      final pos = _scroll.position;
      final target = (reveal + gap - _listTop).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      _scroll.animateTo(
        target,
        duration: context.bz.durationBase,
        curve: context.bz.easeOut,
      );
    });
  }

  void _onState(ChatState? prev, ChatState next) {
    if (next.saveFailed) {
      ref.read(chatControllerProvider.notifier).ackSaveError();
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text(saveErrorText)));
    }
    if (next.chatId != _chatId) {
      // Another chat (or a fresh one): drop state tied to the previous list.
      _chatId = next.chatId;
      if (prev != null &&
          prev.chatId != next.chatId &&
          _unseenAnswerId != null) {
        setState(() => _unseenAnswerId = null);
      }
    }
    final before = prev?.messages ?? const [];
    if (next.messages.length == before.length + 1 &&
        before.isNotEmpty &&
        prev?.chatId == next.chatId) {
      // An assistant message inserted without a question (e.g. the AED card
      // from the CPR instructor): show its start, like a fresh answer.
      final added = next.messages.last;
      if (!added.isUser && !added.isThinking && added.answer != null) {
        _toStartOf(added.id);
        return;
      }
    }
    if (next.messages.length > before.length) {
      // A new question: show it with the thinking bubble.
      _follow = true;
      _toEnd();
      return;
    }
    if (before.isEmpty || next.messages.isEmpty) return;
    // Match by id: a card inserted meanwhile may sit after the still-thinking
    // message, so it is not necessarily the last one.
    final thinkingIds = {
      for (final m in before)
        if (m.isThinking) m.id,
    };
    ChatMessage? last;
    for (final m in next.messages) {
      if (thinkingIds.contains(m.id) &&
          !m.isUser &&
          !m.isThinking &&
          m.answer != null) {
        last = m;
      }
    }
    if (last != null) {
      final answerId = last.id;
      // Spec: scroll to the START of the new answer, not to the end; when the
      // user is reading higher up, only offer the pill.
      if (_follow || _atBottom) {
        _toStartOf(answerId);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _endBelowViewport(answerId)) {
            setState(() => _unseenAnswerId = answerId);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final cpr = ref.watch(cprSessionProvider);
    ref.listen(chatControllerProvider, _onState);

    // Shell: island/SOS sit at topInset (status bar + 8, at least 48) and are
    // 48 dp high.
    final statusBar = MediaQuery.paddingOf(context).top;
    final topInset = statusBar + 8 > 48 ? statusBar + 8 : 48.0;
    // SOS (56 dp) is taller than the island (48 dp): clear the taller one so
    // the first bubble never touches SOS (final QA B16).
    final listTop = topInset + 56 + t.space2;
    _listTop = listTop;
    // A risk conversation (flagged while generating, or an answer carrying
    // `call`) keeps "Zadzwoń 112" pinned above the composer.
    final risk = state.messages.any(
      (m) => m.risk || (m.answer?.panels.any((p) => p is CallPanel) ?? false),
    );

    return Scaffold(
      backgroundColor: t.bg000,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: state.isEmpty
                      ? _EmptyChat(topPadding: listTop, onSend: controller.send)
                      : NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: ListView.builder(
                            key: const Key('message-list'),
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(
                              t.space4,
                              listTop,
                              t.space4,
                              t.space4,
                            ),
                            itemCount: state.messages.length,
                            itemBuilder: (context, i) {
                              final m = state.messages[i];
                              return Padding(
                                key: _keyFor(m.id),
                                padding: EdgeInsets.only(
                                  top: i == 0 ? 0 : t.space5,
                                ),
                                child: MessageView(
                                  message: m,
                                  onAnswerChanged: (a) =>
                                      controller.updateAnswer(m.id, a),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                // "Zadzwoń 112" (risk conversation) and the running RKO
                // instructor stay pinned above the composer.
                ListenableBuilder(
                  listenable: cpr,
                  builder: (context, _) => Padding(
                    padding: EdgeInsets.fromLTRB(t.space4, 0, t.space4, t.space2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (risk)
                          Padding(
                            padding: EdgeInsets.only(bottom: cpr.running ? t.space2 : 0),
                            child: const CallPanelView(),
                          ),
                        const CprPinnedHost(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  // The pill is wider than the content column (reference
                  // start.png: 12 dp from the screen edge).
                  padding: EdgeInsets.fromLTRB(
                    t.space3,
                    t.space1,
                    t.space3,
                    t.space2 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Composer(
                    generating: state.generating,
                    onSend: controller.send,
                    onStop: controller.stop,
                  ),
                ),
              ],
            ),
          ),
          // Fade under the floating island and SOS (spec E1: content scrolls
          // under them over a soft background gradient). Solid behind the
          // status bar and most of the island so scrolled text never collides
          // with the clock or the island (BG16), then a short fade.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: topInset + 48 + t.space4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.bg000, t.bg000, t.bg000.withValues(alpha: 0)],
                    stops: [0, (topInset + 36) / (topInset + 48 + t.space4), 1],
                  ),
                ),
              ),
            ),
          ),
          if (_unseenAnswerId != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      52 +
                      (risk ? 56 + t.space2 : 0) +
                      t.space4 +
                      t.space2 +
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: Center(
                  child: _JumpPill(
                    onTap: () {
                      final id = _unseenAnswerId!;
                      setState(() => _unseenAnswerId = null);
                      _toStartOf(id);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.topPadding, required this.onSend});

  final double topPadding;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(t.space4, topPadding, t.space4, t.space4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - topPadding - t.space4).clamp(
              0.0,
              double.infinity,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                emptyChatHeading,
                textAlign: TextAlign.center,
                style: t.display.copyWith(fontSize: 32, height: 38 / 32),
              ),
              SizedBox(height: t.space5),
              QuickActions(onSend: onSend),
              SizedBox(height: t.space5),
              Text(
                emptyChatNote,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: t.ink300),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpPill extends StatelessWidget {
  const _JumpPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Semantics(
      button: true,
      label: newAnswerLabel,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('jump-to-answer'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.bg200,
                border: Border.all(color: t.line150),
                borderRadius: BorderRadius.circular(t.radiusFull),
                boxShadow: t.shadowPop,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(LucideIcons.arrowDown, size: 16, color: t.ink100),
                  const SizedBox(width: 6),
                  Text(
                    newAnswerLabel,
                    style: t.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
