import 'llm_engine.dart';

/// Whether a request belongs in the live conversation at all: it has a
/// [LlmRequest.conversationId] and is not a JSON request (those are one-shot).
bool isLiveRequest(LlmRequest req) =>
    req.conversationId != null && !req.jsonMode && req.jsonSchema == null;

/// The one live conversation of the edge engine (D7): keeps a chat [C] open
/// across turns and feeds it only the messages it has not read. Pure Dart;
/// the native chat is reached only through [open], [send] and [close], so the
/// decisions are testable on host.
class LiveConversation<C extends Object> {
  LiveConversation({
    required this.open,
    required this.send,
    required this.close,
    required this.isStopped,
  });

  /// Opens a chat for the request's system prompt, temperature, maxTokens.
  final Future<C> Function(LlmRequest req) open;

  /// Gives [chat] the new messages and streams its reply.
  final Stream<String> Function(C chat, List<LlmMessage> fresh) send;
  final Future<void> Function(C chat) close;

  /// True when the runtime was asked to stop the running generation.
  final bool Function() isStopped;

  C? _chat;
  String? _id;
  String _systemPrompt = '';
  double _temperature = 0;
  int _maxTokens = 0;
  final List<LlmMessage> _read = [];

  /// Whether the last [run] continued the open chat (false: it (re)opened).
  bool? lastReused;

  bool get isOpen => _chat != null;

  /// The messages of [req] the open chat has not read yet, or null when it
  /// cannot continue: none open, other id / system prompt / temperature /
  /// maxTokens, history that is not an exact prefix (role + content) of
  /// [LlmRequest.messages], or nothing new to read.
  List<LlmMessage>? continuation(LlmRequest req) {
    if (_chat == null || !isLiveRequest(req)) return null;
    if (req.conversationId != _id ||
        req.systemPrompt != _systemPrompt ||
        req.temperature != _temperature ||
        req.maxTokens != _maxTokens) {
      return null;
    }
    final msgs = req.messages;
    if (msgs.length <= _read.length) return null;
    for (var i = 0; i < _read.length; i++) {
      if (msgs[i].role != _read[i].role || msgs[i].content != _read[i].content) return null;
    }
    return msgs.sublist(_read.length);
  }

  /// Continues the open chat when [continuation] allows it, else closes it
  /// and opens a new one fed with the full history. Only a reply that ran to
  /// its end is remembered (as an assistant message, so the next request that
  /// repeats it matches); a stop, a cancelled subscription or an error closes
  /// the chat.
  Stream<String> run(LlmRequest req) async* {
    var fresh = continuation(req);
    lastReused = fresh != null;
    if (fresh == null) {
      await closeChat();
      _chat = await open(req);
      _id = req.conversationId;
      _systemPrompt = req.systemPrompt;
      _temperature = req.temperature;
      _maxTokens = req.maxTokens;
      fresh = req.messages;
    }
    final chat = _chat!;
    final reply = StringBuffer();
    var done = false;
    try {
      await for (final t in send(chat, fresh)) {
        reply.write(t);
        yield t;
      }
      done = !isStopped();
    } finally {
      if (identical(_chat, chat)) {
        if (done) {
          _read
            ..addAll(fresh)
            ..add(LlmMessage.assistant(reply.toString()));
        } else {
          await closeChat();
        }
      }
    }
  }

  /// Opens the chat for [req] (system prompt, temperature, maxTokens; its
  /// messages are ignored) before the first turn, unless an open chat already
  /// matches. Nothing is read, so the next [run] of the same chat continues
  /// it with its full message list.
  Future<void> prepare(LlmRequest req) async {
    if (_chat != null &&
        _read.isEmpty &&
        req.conversationId == _id &&
        req.systemPrompt == _systemPrompt &&
        req.temperature == _temperature &&
        req.maxTokens == _maxTokens) {
      return;
    }
    await closeChat();
    _chat = await open(req);
    _id = req.conversationId;
    _systemPrompt = req.systemPrompt;
    _temperature = req.temperature;
    _maxTokens = req.maxTokens;
  }

  /// Runs [f] on the open, still unused chat (a hidden warm-up turn that makes
  /// the engine read the system prompt). Not recorded as read: the next [run]
  /// still continues this chat. Any error closes the chat.
  Future<void> prime(Future<void> Function(C chat) f) async {
    final chat = _chat;
    if (chat == null || _read.isNotEmpty) return;
    try {
      await f(chat);
    } catch (_) {
      await closeChat();
      rethrow;
    }
  }

  /// Closes the open chat, if any; the next [run] reopens.
  Future<void> closeChat() async {
    final chat = _chat;
    _chat = null;
    _id = null;
    _read.clear();
    if (chat != null) await close(chat);
  }
}
