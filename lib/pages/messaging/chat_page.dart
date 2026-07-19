part of '../../app.dart';

enum _DeletionScope { me, everyone }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.conversationId, this.profile});
  final String? conversationId;
  final UserProfile? profile;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _messageScrollController = ScrollController();
  final _messageFocusNode = FocusNode();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  late final Stream<List<MapLovMessage>> _messageStream;
  bool _recording = false;
  bool _sending = false;
  bool _pickingAttachment = false;
  bool _showEmojiPanel = false;
  String? _lastVisibleMessageId;
  DateTime? _clearedAt;
  final Set<String> _locallyHiddenMessageIds = {};
  String? _playingMessageId;
  String? _sendError;
  Future<void> Function()? _retrySend;

  bool get _busy => _sending || _pickingAttachment;
  bool get _canSendText => !_busy && _text.text.trim().isNotEmpty;

  UserProfile get profile => widget.profile ?? demoProfileOrUnavailable;
  String get conversationId => widget.conversationId ?? 'demo-${profile.id}';

  @override
  void initState() {
    super.initState();
    _messageStream = MapLovRepository.instance.watchMessages(conversationId);
    _text.addListener(_handleComposerChanged);
    unawaited(MapLovRepository.instance.markConversationRead(conversationId));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingMessageId = null);
    });
  }

  @override
  void dispose() {
    _text.removeListener(_handleComposerChanged);
    _text.dispose();
    _messageScrollController.dispose();
    _messageFocusNode.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    if (mounted) setState(() {});
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: profile)),
    );
  }

  void _scheduleScrollToBottom(String? lastMessageId) {
    if (lastMessageId == null || lastMessageId == _lastVisibleMessageId) return;
    _lastVisibleMessageId = lastMessageId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleEmojiPanel() {
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
      _messageFocusNode.requestFocus();
      return;
    }
    _messageFocusNode.unfocus();
    setState(() => _showEmojiPanel = true);
  }

  void _insertEmoji(String emoji) {
    final value = _text.value;
    var start = value.selection.start;
    var end = value.selection.end;
    if (start < 0 || end < 0) {
      start = value.text.length;
      end = value.text.length;
    }
    final updated = value.text.replaceRange(start, end, emoji);
    _text.value = value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
      composing: TextRange.empty,
    );
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

  Future<void> _delete(
    MapLovMessage message, {
    required bool forEveryone,
  }) async {
    try {
      await MapLovRepository.instance.deleteMessage(
        message.id,
        forEveryone: forEveryone,
      );
      if (!forEveryone && mounted) {
        setState(() => _locallyHiddenMessageIds.add(message.id));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete this message: $error')),
        );
      }
    }
  }

  Future<void> _confirmDelete(MapLovMessage message) async {
    final subscription = await MapLovRepository.instance.subscriptionInfo();
    if (!mounted) return;
    final canDeleteForEveryone = !message.read || subscription.isVip;
    final scope = await showDialog<_DeletionScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: Text(
          canDeleteForEveryone
              ? 'Choose whether to remove this message only from your account or from both accounts.'
              : 'This message has already been read. Premium VIP is required to remove it from both accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DeletionScope.me),
            child: const Text('Delete for me'),
          ),
          FilledButton(
            onPressed: canDeleteForEveryone
                ? () => Navigator.pop(context, _DeletionScope.everyone)
                : null,
            child: const Text('Delete for everyone'),
          ),
        ],
      ),
    );
    if (scope != null) {
      await _delete(message, forEveryone: scope == _DeletionScope.everyone);
    }
  }

  Future<void> _clearChat() async {
    final subscription = await MapLovRepository.instance.subscriptionInfo();
    if (!mounted) return;
    final scope = await showDialog<_DeletionScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: Text(
          subscription.isVip
              ? 'Clear for me hides this history only on your account. Clear for everyone removes the full conversation from both accounts.'
              : subscription.isPremium
              ? 'Clear for everyone removes the chat from your account and removes only your unread messages from ${profile.name}’s account.'
              : 'You can clear this history from your account. Clearing an entire chat for everyone requires Premium Plus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DeletionScope.me),
            child: const Text('Clear for me'),
          ),
          FilledButton(
            onPressed: subscription.isPremium
                ? () => Navigator.pop(context, _DeletionScope.everyone)
                : null,
            child: const Text('Clear for everyone'),
          ),
        ],
      ),
    );
    if (scope == null) return;
    try {
      final clearedAt = await MapLovRepository.instance.clearConversation(
        conversationId,
        forEveryone: scope == _DeletionScope.everyone,
      );
      if (!mounted) return;
      setState(() => _clearedAt = clearedAt);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat cleared.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to clear this chat: $error')),
        );
      }
    }
  }

  Widget _messageWidget(MapLovMessage message, bool mine) {
    Widget content;
    if (message.deleted) {
      content = _ChatMessageBubble(
        text: 'Message deleted',
        mine: mine,
        time: message.createdAt,
        deleted: true,
      );
    } else if (message.kind == 'image') {
      content = message.mediaUrl == null && message.mediaBytes == null
          ? _ChatMessageBubble(
              text: message.body ?? '📷 Photo message',
              mine: mine,
              time: message.createdAt,
              read: message.read,
            )
          : Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: mine ? null : const Color(0xFFF5F5F5),
                  gradient: mine
                      ? const LinearGradient(
                          colors: [Color(0xFFFF5A5F), Color(0xFFFF85A2)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ClipRRect(
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 5, 6, 2),
                      child: _MessageMeta(
                        time: message.createdAt,
                        mine: mine,
                        read: message.read,
                      ),
                    ),
                  ],
                ),
              ),
            );
    } else if (message.kind == 'voice') {
      content = Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
          decoration: BoxDecoration(
            color: mine ? null : const Color(0xFFF5F5F5),
            gradient: mine
                ? const LinearGradient(
                    colors: [Color(0xFFFF5A5F), Color(0xFFFF85A2)],
                  )
                : null,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed:
                    message.mediaUrl == null && message.mediaBytes == null
                    ? null
                    : () => _playVoice(message),
                icon: Icon(
                  _playingMessageId == message.id
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.graphic_eq, color: AppColors.grayText, size: 54),
              const SizedBox(width: 8),
              _MessageMeta(
                time: message.createdAt,
                mine: mine,
                read: message.read,
              ),
            ],
          ),
        ),
      );
    } else if (message.kind == 'document') {
      content = Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 9),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .76,
          ),
          decoration: BoxDecoration(
            color: mine ? null : const Color(0xFFF5F5F5),
            gradient: mine
                ? const LinearGradient(
                    colors: [Color(0xFFFF5A5F), Color(0xFFFF85A2)],
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: mine ? null : Border.all(color: const Color(0xFFE7E7EC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                color: mine ? Colors.white : AppColors.coral,
                size: 30,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.body ?? 'Document',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mine ? Colors.white : AppColors.darkText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MessageMeta(
                      time: message.createdAt,
                      mine: mine,
                      read: message.read,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      content = _ChatMessageBubble(
        text: message.body ?? '',
        mine: mine,
        time: message.createdAt,
        read: message.read,
      );
    }
    return Semantics(
      label: mine ? 'Sent message' : 'Received message',
      child: GestureDetector(
        onTap: mine && !message.deleted ? () => _confirmDelete(message) : null,
        onLongPress: !mine && !message.deleted
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportUserScreen(
                    profile: profile,
                    targetType: 'message',
                    targetId: message.id,
                  ),
                ),
              )
            : null,
        child: content,
      ),
    );
  }

  Future<void> _sendText() async {
    if (_busy) return;
    final value = _text.text.trim();
    if (value.isEmpty) return;
    final requestId = MapLovRepository.instance.createClientMessageId();
    final sent = await _sendWithStatus(
      () => MapLovRepository.instance.sendMessage(
        conversationId,
        value,
        clientMessageId: requestId,
      ),
      'Text message',
    );
    if (sent && _text.text.trim() == value) _text.clear();
  }

  Future<bool> _sendWithStatus(
    Future<void> Function() action,
    String label,
  ) async {
    if (_sending) return false;
    setState(() {
      _sending = true;
      _sendError = null;
      _retrySend = null;
    });
    try {
      await action();
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _sendError = '$label could not be sent.';
          _retrySend = () async {
            await _sendWithStatus(action, label);
          };
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage(ImageSource source) async {
    if (_busy) return;
    setState(() => _pickingAttachment = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last.toLowerCase();
      final requestId = MapLovRepository.instance.createClientMessageId();
      await _sendWithStatus(
        () => MapLovRepository.instance.sendMessageMedia(
          conversationId: conversationId,
          bytes: bytes,
          extension: extension,
          kind: 'image',
          clientMessageId: requestId,
        ),
        'Photo',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _sendError = 'Unable to open photos: $error');
      }
      return;
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  Future<void> _sendDocument() async {
    if (_busy) return;
    setState(() => _pickingAttachment = true);
    try {
      final document = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Documents',
            extensions: [
              'pdf',
              'doc',
              'docx',
              'txt',
              'rtf',
              'csv',
              'xls',
              'xlsx',
              'ppt',
              'pptx',
              'zip',
            ],
          ),
        ],
      );
      if (document == null) return;
      final bytes = await document.readAsBytes();
      final extension = document.name.split('.').last.toLowerCase();
      final requestId = MapLovRepository.instance.createClientMessageId();
      await _sendWithStatus(
        () => MapLovRepository.instance.sendMessageMedia(
          conversationId: conversationId,
          bytes: bytes,
          extension: extension,
          kind: 'document',
          fileName: document.name,
          clientMessageId: requestId,
        ),
        'Document',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _sendError = 'Unable to open documents: $error');
      }
      return;
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  Future<void> _showAttachmentOptions() async {
    if (_busy) return;
    setState(() => _pickingAttachment = true);
    String? choice;
    try {
      choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose a photo'),
                onTap: () => Navigator.pop(context, 'photo'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Choose a document'),
                onTap: () => Navigator.pop(context, 'document'),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
    if (!mounted) return;
    if (choice == 'photo') await _sendImage(ImageSource.gallery);
    if (choice == 'document') await _sendDocument();
  }

  void _showCallsUnavailable(String kind) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$kind calls are not configured yet.')),
    );
  }

  Future<void> _toggleRecording() async {
    if (_sending || _pickingAttachment) return;
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) {
        final bytes = await XFile(path).readAsBytes();
        final requestId = MapLovRepository.instance.createClientMessageId();
        await _sendWithStatus(
          () => MapLovRepository.instance.sendMessageMedia(
            conversationId: conversationId,
            bytes: bytes,
            extension: 'm4a',
            kind: 'voice',
            clientMessageId: requestId,
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
    backgroundColor: const Color(0xFFFCFCFD),
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      toolbarHeight: 82,
      leadingWidth: 44,
      titleSpacing: 0,
      title: InkWell(
        key: const Key('chat_profile_link'),
        onTap: _openProfile,
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundImage: profileImageProvider(profile),
                  ),
                  if (profile.isOnline)
                    Positioned(
                      right: -1,
                      bottom: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18BE72),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            color: AppColors.deepPink,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          profile.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: profile.isOnline
                                ? const Color(0xFF12B76A)
                                : AppColors.grayText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          key: const Key('chat_match_badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEF2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${profile.compatibilityScore}% Match',
                            style: const TextStyle(
                              color: AppColors.coral,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Voice call',
          onPressed: () => _showCallsUnavailable('Voice'),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.phone_outlined),
        ),
        IconButton(
          tooltip: 'Video call',
          onPressed: () => _showCallsUnavailable('Video'),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.videocam_outlined),
        ),
        SizedBox(
          width: 40,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'block', child: Text('Block user')),
              PopupMenuItem(value: 'report', child: Text('Report user')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
            onSelected: (value) {
              if (value == 'clear') {
                unawaited(_clearChat());
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => value == 'block'
                      ? BlockUserScreen(profile: profile)
                      : ReportUserScreen(profile: profile),
                ),
              );
            },
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          const _ChatPrivacyBanner(),
          Expanded(
            child: StreamBuilder<List<MapLovMessage>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                final allMessages = snapshot.data ?? const <MapLovMessage>[];
                final messagesById = <String, MapLovMessage>{};
                for (final message in allMessages) {
                  if (_locallyHiddenMessageIds.contains(message.id) ||
                      (_clearedAt != null &&
                          !message.createdAt.isAfter(_clearedAt!))) {
                    continue;
                  }
                  messagesById[message.id] = message;
                }
                final messages = messagesById.values.toList()
                  ..sort((a, b) {
                    final byDate = a.createdAt.compareTo(b.createdAt);
                    return byDate != 0 ? byDate : a.id.compareTo(b.id);
                  });
                _scheduleScrollToBottom(
                  messages.isEmpty ? null : messages.last.id,
                );
                return ListView(
                  key: const Key('chat_message_list'),
                  controller: _messageScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  children: [
                    const _ChatDateDivider(),
                    if (messages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: Center(
                          child: Text('Say hello to ${profile.name} 👋'),
                        ),
                      )
                    else
                      ...messages.map((message) {
                        final mine =
                            message.senderId ==
                                MapLovRepository.instance.currentUserId ||
                            message.senderId == 'me';
                        return _messageWidget(message, mine);
                      }),
                  ],
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
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE7E7EC)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  key: const Key('chat_emoji_action'),
                  tooltip: 'Emoji',
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _toggleEmojiPanel,
                  icon: const Icon(Icons.sentiment_satisfied_alt_outlined),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('chat_message_field'),
                    controller: _text,
                    focusNode: _messageFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onTap: () {
                      if (_showEmojiPanel) {
                        setState(() => _showEmojiPanel = false);
                      }
                    },
                    onSubmitted: (_) {
                      if (_canSendText) unawaited(_sendText());
                    },
                    decoration: InputDecoration(
                      hintText: context.tr('Type a message...'),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Choose a photo',
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _busy ? null : _showAttachmentOptions,
                  icon: const Icon(Icons.attach_file),
                ),
                IconButton(
                  tooltip: 'Take a photo',
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _busy
                      ? null
                      : () => _sendImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                Padding(
                  padding: EdgeInsets.zero,
                  child: IconButton(
                    key: const Key('chat_voice_action'),
                    tooltip: 'Voice message',
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: _busy ? null : _toggleRecording,
                    color: _recording ? AppColors.error : AppColors.darkText,
                    icon: Icon(
                      _recording ? Icons.stop_circle_outlined : Icons.mic_none,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('chat_primary_action'),
                  tooltip: 'Send message',
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _canSendText ? _sendText : null,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: AppColors.coral),
                ),
              ],
            ),
          ),
          if (_showEmojiPanel)
            _EmojiPanel(
              onSelected: _insertEmoji,
              onClose: () => setState(() => _showEmojiPanel = false),
            ),
        ],
      ),
    ),
  );
}

class _ChatPrivacyBanner extends StatelessWidget {
  const _ChatPrivacyBanner();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(22, 14, 22, 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF0F3), Color(0xFFFFF7F8)],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.shield_outlined, color: AppColors.deepPink, size: 30),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Messages are private. Only chat participants can access this conversation.',
            style: TextStyle(fontSize: 13, height: 1.25),
          ),
        ),
      ],
    ),
  );
}

class _ChatDateDivider extends StatelessWidget {
  const _ChatDateDivider();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 64,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text('Today', style: TextStyle(fontSize: 13)),
    ),
  );
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.text,
    required this.mine,
    required this.time,
    this.read = false,
    this.deleted = false,
  });

  final String text;
  final bool mine;
  final DateTime time;
  final bool read;
  final bool deleted;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 11, 12, 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .76,
      ),
      decoration: BoxDecoration(
        color: mine ? null : const Color(0xFFF5F5F5),
        gradient: mine
            ? const LinearGradient(
                colors: [Color(0xFFFFE9EE), Color(0xFFFFF4F6)],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(mine ? 20 : 5),
          bottomRight: Radius.circular(mine ? 5 : 20),
        ),
        border: Border.all(
          color: mine ? const Color(0xFFFFCAD5) : const Color(0xFFE9E9ED),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 10,
        runSpacing: 4,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              height: 1.25,
              color: deleted ? AppColors.grayText : AppColors.darkText,
              fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          _MessageMeta(time: time, mine: mine, read: read),
        ],
      ),
    ),
  );
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.time,
    required this.mine,
    required this.read,
  });

  final DateTime time;
  final bool mine;
  final bool read;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        DateFormat.jm().format(time.toLocal()),
        style: TextStyle(fontSize: 11, color: AppColors.grayText),
      ),
      if (mine) ...[
        const SizedBox(width: 4),
        Icon(
          Icons.done_all,
          size: 16,
          color: read ? const Color(0xFF1687FF) : AppColors.grayText,
        ),
      ],
    ],
  );
}

class _EmojiPanel extends StatefulWidget {
  const _EmojiPanel({required this.onSelected, required this.onClose});

  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  @override
  State<_EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<_EmojiPanel> {
  static const _categories = <String, List<String>>{
    'Love': [
      '❤️',
      '🩷',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🤍',
      '🤎',
      '🖤',
      '💖',
      '💗',
      '💓',
      '💕',
      '💞',
      '💘',
      '💝',
      '💟',
      '❣️',
      '💌',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😚',
      '😙',
      '🫶',
      '🤗',
      '💋',
      '🌹',
      '🌷',
      '💐',
      '🕯️',
      '💍',
      '👩‍❤️‍👨',
      '👩‍❤️‍👩',
      '👨‍❤️‍👨',
      '👩‍❤️‍💋‍👨',
      '👩‍❤️‍💋‍👩',
      '👨‍❤️‍💋‍👨',
    ],
    'Smileys': [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '😊',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😋',
      '😛',
      '😜',
      '🤪',
      '🤨',
      '🧐',
      '🤓',
      '😎',
      '🥳',
      '😏',
      '😔',
      '🥺',
      '😢',
      '😭',
      '😤',
      '😴',
      '🤭',
    ],
    'Gestures': [
      '👋',
      '🤚',
      '🖐️',
      '✋',
      '🖖',
      '👌',
      '🤌',
      '🤏',
      '✌️',
      '🤞',
      '🤟',
      '🤘',
      '🤙',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '👍',
      '👎',
      '👏',
      '🙌',
      '👐',
      '🤲',
      '🙏',
      '✍️',
      '💪',
      '🫂',
    ],
    'Activities': [
      '🎉',
      '🎊',
      '🎈',
      '🎁',
      '🎵',
      '🎶',
      '🎬',
      '📸',
      '🎨',
      '⚽',
      '🏀',
      '🏈',
      '🎾',
      '🏐',
      '🏓',
      '🏸',
      '🏆',
      '🧘',
      '🏊',
      '🚴',
    ],
    'Food': [
      '☕',
      '🍷',
      '🥂',
      '🍹',
      '🍓',
      '🍒',
      '🍕',
      '🍔',
      '🍣',
      '🍰',
      '🧁',
      '🍫',
      '🍯',
      '🥐',
      '🥗',
      '🍜',
      '🍿',
      '🫖',
      '🍽️',
    ],
    'Travel': [
      '🌍',
      '🌎',
      '🌏',
      '✈️',
      '🚗',
      '🚆',
      '🚲',
      '⛵',
      '🏖️',
      '🏕️',
      '🏔️',
      '🌅',
      '🌇',
      '🌃',
      '🗺️',
      '📍',
      '🏠',
      '🏨',
      '🎡',
    ],
  };

  String _category = _categories.keys.first;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('chat_emoji_panel'),
    color: Colors.white,
    elevation: 8,
    child: SizedBox(
      height: 285,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final name in _categories.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: _category == name,
                      onSelected: (_) => setState(() => _category = name),
                    ),
                  ),
                IconButton(
                  tooltip: 'Close emojis',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.keyboard_alt_outlined),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _categories[_category]!.length,
              itemBuilder: (context, index) {
                final emoji = _categories[_category]![index];
                return InkWell(
                  key: ValueKey('chat_emoji_${_category}_$index'),
                  onTap: () => widget.onSelected(emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: material.Text(
                      emoji,
                      style: const TextStyle(fontSize: 25),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
