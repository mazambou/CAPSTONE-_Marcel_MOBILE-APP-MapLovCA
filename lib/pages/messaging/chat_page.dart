part of '../../app.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.conversationId, this.profile});
  final String? conversationId;
  final UserProfile? profile;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _recording = false;
  bool _sending = false;
  String? _playingMessageId;
  String? _sendError;
  Future<void> Function()? _retrySend;

  UserProfile get profile => widget.profile ?? mockProfiles.first;
  String get conversationId => widget.conversationId ?? 'demo-${profile.id}';

  @override
  void initState() {
    super.initState();
    unawaited(MapLovRepository.instance.markConversationRead(conversationId));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingMessageId = null);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playVoice(MapLovMessage message) async {
    if (message.mediaUrl == null && message.mediaBytes == null) return;
    if (_playingMessageId == message.id) {
      await _player.pause();
      if (mounted) setState(() => _playingMessageId = null);
      return;
    }
    await _player.play(
      message.mediaBytes == null
          ? UrlSource(message.mediaUrl!)
          : BytesSource(message.mediaBytes!),
    );
    if (mounted) setState(() => _playingMessageId = message.id);
  }

  Future<void> _delete(MapLovMessage message) async {
    await MapLovRepository.instance.deleteMessage(message.id);
  }

  Widget _messageWidget(MapLovMessage message, bool mine) {
    Widget content;
    if (message.deleted) {
      content = _Bubble('Message deleted', mine);
    } else if (message.kind == 'image') {
      content = message.mediaUrl == null && message.mediaBytes == null
          ? _Bubble(message.body ?? '📷 Photo message', mine)
          : Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: message.mediaBytes == null
                    ? Image.network(
                        message.mediaUrl!,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 220,
                          height: 120,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      )
                    : Image.memory(
                        message.mediaBytes!,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
              ),
            );
    } else if (message.kind == 'voice') {
      content = Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ActionChip(
          avatar: Icon(
            _playingMessageId == message.id ? Icons.pause : Icons.play_arrow,
          ),
          label: const Text('Voice message'),
          onPressed: message.mediaUrl == null && message.mediaBytes == null
              ? null
              : () => _playVoice(message),
        ),
      );
    } else {
      content = _Bubble(message.body ?? '', mine);
    }
    if (mine && message.read && !message.deleted) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          content,
          const Padding(
            padding: EdgeInsets.only(right: 8, bottom: 3),
            child: Text(
              'Read',
              style: TextStyle(fontSize: 11, color: AppColors.grayText),
            ),
          ),
        ],
      );
    }
    return Semantics(
      label: mine ? 'Sent message' : 'Received message',
      child: GestureDetector(
        onLongPress: mine && !message.deleted ? () => _delete(message) : null,
        child: content,
      ),
    );
  }

  Future<void> _sendText() async {
    final value = _text.text.trim();
    if (value.trim().isEmpty) return;
    _text.clear();
    await _sendWithStatus(
      () => MapLovRepository.instance.sendMessage(conversationId, value),
      'Text message',
    );
  }

  Future<void> _sendWithStatus(
    Future<void> Function() action,
    String label,
  ) async {
    setState(() {
      _sending = true;
      _sendError = null;
      _retrySend = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          _sendError = '$label could not be sent.';
          _retrySend = () => _sendWithStatus(action, label);
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final extension = image.name.split('.').last;
    await _sendWithStatus(
      () => MapLovRepository.instance.sendMessageMedia(
        conversationId: conversationId,
        bytes: bytes,
        extension: extension,
        kind: 'image',
      ),
      'Photo',
    );
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) {
        final bytes = await XFile(path).readAsBytes();
        await _sendWithStatus(
          () => MapLovRepository.instance.sendMessageMedia(
            conversationId: conversationId,
            bytes: bytes,
            extension: 'm4a',
            kind: 'voice',
          ),
          'Voice message',
        );
      }
      return;
    }
    if (!await _recorder.hasPermission()) return;
    final directory = await getTemporaryDirectory();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path:
          '${directory.path}/maplov-${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    setState(() => _recording = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(profile.name),
      actions: [
        PopupMenuButton<String>(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'block', child: Text('Block user')),
            PopupMenuItem(value: 'report', child: Text('Report user')),
          ],
          onSelected: (value) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => value == 'block'
                  ? BlockUserScreen(profile: profile)
                  : ReportUserScreen(profile: profile),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MapLovMessage>>(
              stream: MapLovRepository.instance.watchMessages(conversationId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <MapLovMessage>[];
                if (messages.isEmpty) {
                  return Center(child: Text('Say hello to ${profile.name} 👋'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine =
                        message.senderId ==
                            MapLovRepository.instance.currentUserId ||
                        message.senderId == 'me';
                    return _messageWidget(message, mine);
                  },
                );
              },
            ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          if (_sendError != null)
            Material(
              color: AppColors.error.withValues(alpha: .08),
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                ),
                title: Text(_sendError!),
                trailing: TextButton(
                  onPressed: _retrySend,
                  child: const Text('Retry'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sendImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _text,
                    onSubmitted: (_) => _sendText(),
                    decoration: const InputDecoration(hintText: 'Message...'),
                  ),
                ),
                IconButton(
                  onPressed: _toggleRecording,
                  color: _recording ? AppColors.error : null,
                  icon: Icon(
                    _recording ? Icons.stop_circle_outlined : Icons.mic_none,
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _sendText,
                  icon: const Icon(Icons.send, color: AppColors.coral),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
