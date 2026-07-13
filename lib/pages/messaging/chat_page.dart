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
  bool _recording = false;
  bool _sending = false;

  UserProfile get profile => widget.profile ?? mockProfiles.first;
  String get conversationId => widget.conversationId ?? 'demo-${profile.id}';

  @override
  void dispose() {
    _text.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final value = _text.text;
    if (value.trim().isEmpty) return;
    _text.clear();
    setState(() => _sending = true);
    try {
      await MapLovRepository.instance.sendMessage(conversationId, value);
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
    await MapLovRepository.instance.sendMessageMedia(
      conversationId: conversationId,
      bytes: await image.readAsBytes(),
      extension: image.name.split('.').last,
      kind: 'image',
    );
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) {
        await MapLovRepository.instance.sendMessageMedia(
          conversationId: conversationId,
          bytes: await XFile(path).readAsBytes(),
          extension: 'm4a',
          kind: 'voice',
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
                    if (message.deleted) {
                      return _Bubble('Message deleted', mine);
                    }
                    if (message.kind == 'image' && message.mediaUrl != null) {
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            message.mediaUrl!,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }
                    if (message.kind == 'voice') {
                      return _Bubble('🎤 Voice message', mine);
                    }
                    return _Bubble(message.body ?? '', mine);
                  },
                );
              },
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
