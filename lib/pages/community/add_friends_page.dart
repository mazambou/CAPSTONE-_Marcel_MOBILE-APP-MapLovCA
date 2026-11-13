part of '../../app.dart';

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  final List<FriendSuggestion> _suggestions = [];
  final Set<String> _sending = {};
  bool _loading = true;
  bool _hasMore = false;
  int _nextOffset = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _suggestions.clear();
        _nextOffset = 0;
        _hasMore = false;
      }
    });
    try {
      final page = await MapLovRepository.instance.friendSuggestions(
        offset: _nextOffset,
      );
      if (!mounted) return;
      setState(() {
        _suggestions.addAll(page.items);
        _nextOffset = page.nextOffset;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.tr('Unable to load friend suggestions.'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest(FriendSuggestion suggestion) async {
    final id = suggestion.profile?.id;
    if (id == null) {
      await _showPremiumPrompt();
      return;
    }
    if (_sending.contains(id)) return;
    setState(() => _sending.add(id));
    try {
      final blockState = await MapLovRepository.instance.chatBlockState(id);
      final blockNotice = _blockedActionText(blockState, 'other');
      if (blockNotice != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(blockNotice)));
        }
        return;
      }
      await MapLovRepository.instance.sendFriendRequest(id);
      if (!mounted) return;
      final current = _suggestions.indexWhere((item) => item.profile?.id == id);
      if (current != -1) {
        final item = _suggestions[current];
        setState(() {
          _suggestions[current] = FriendSuggestion(
            profile: item.profile,
            compatibilityScore: item.compatibilityScore,
            visitedProfile: item.visitedProfile,
            likedContent: item.likedContent,
            commentedContent: item.commentedContent,
            sentMessage: item.sentMessage,
            friendshipStatus: 'pending',
            requestSentByMe: true,
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Friend request sent.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Unable to send friend request.'))),
      );
      unawaited(_load(reset: true));
    } finally {
      if (mounted) setState(() => _sending.remove(id));
    }
  }

  Future<void> _openProfile(FriendSuggestion suggestion) async {
    final profile = suggestion.profile;
    if (profile == null) {
      await _showPremiumPrompt();
      return;
    }
    if (!await _requireProfilePhotos(context, minimum: 3) || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(profile: profile),
      ),
    );
    if (mounted) unawaited(_load(reset: true));
  }

  Future<void> _showPremiumPrompt() async {
    final subscribe = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Premium Plus required')),
        content: Text(
          context.tr(
            'Subscribe to Premium Plus to see this profile visitor and send a friend request.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('See Premium Plus')),
          ),
        ],
      ),
    );
    if (subscribe == true && mounted) {
      await Navigator.pushNamed(context, AppRoutes.premium);
      if (mounted) unawaited(_load(reset: true));
    }
  }

  String _reason(FriendSuggestion suggestion) {
    final reasons = <String>[
      if (suggestion.visitedProfile) context.tr('Visited your profile'),
      if (suggestion.likedContent) context.tr('Liked your content'),
      if (suggestion.commentedContent) context.tr('Commented on your content'),
      if (suggestion.sentMessage) context.tr('Sent you a message'),
      if (suggestion.compatibilityScore >= 60)
        '${suggestion.compatibilityScore}% ${context.tr('compatibility')}',
    ];
    return reasons.join(' · ');
  }

  Widget _requestButton(FriendSuggestion suggestion) {
    if (suggestion.visitorOnlyLocked) {
      return FilledButton(
        onPressed: _showPremiumPrompt,
        child: Text(context.tr('Add')),
      );
    }
    if (suggestion.friendshipStatus == 'pending') {
      if (suggestion.requestSentByMe) {
        return OutlinedButton(onPressed: null, child: Text(context.tr('Sent')));
      }
      return TextButton(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.friendRequests);
          if (mounted) unawaited(_load(reset: true));
        },
        child: Text(context.tr('Respond')),
      );
    }
    return FilledButton(
      onPressed: _sending.contains(suggestion.profile!.id)
          ? null
          : () => _sendRequest(suggestion),
      child: Text(context.tr('Add')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.instance.needsEmailVerificationReminder) {
      return const _EmailVerificationRequiredPage();
    }
    return _AppPage(
      title: 'Add Friends',
      actions: [
        IconButton(
          tooltip: context.tr('Refresh'),
          onPressed: _loading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        Text(
          context.tr(
            'Members who interacted with you or match at least 60%, within your saved search distance.',
          ),
          style: const TextStyle(color: AppColors.grayText),
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          Text(_error!),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _load(reset: _suggestions.isEmpty),
            child: Text(context.tr('Try again')),
          ),
        ],
        if (_suggestions.isEmpty && _loading)
          const Center(child: CircularProgressIndicator()),
        if (_suggestions.isEmpty && !_loading && _error == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              context.tr(
                'No eligible members within your search distance. Check your location and dating preferences.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        for (final suggestion in _suggestions)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (suggestion.visitorOnlyLocked)
                    const CircleAvatar(
                      backgroundColor: AppColors.lightGray,
                      child: Icon(
                        Icons.lock_outline,
                        color: AppColors.grayText,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => _openProfile(suggestion),
                      child: CircleAvatar(
                        backgroundImage: profileImageProvider(
                          suggestion.profile!,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openProfile(suggestion),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.visitorOnlyLocked
                                ? context.tr('Profile visitor')
                                : suggestion.profile!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: suggestion.visitorOnlyLocked
                                  ? AppColors.grayText
                                  : null,
                            ),
                          ),
                          Text(
                            suggestion.visitorOnlyLocked
                                ? context.tr('Premium Plus to reveal')
                                : _reason(suggestion),
                            style: const TextStyle(color: AppColors.grayText),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _requestButton(suggestion),
                ],
              ),
            ),
          ),
        if (_hasMore && !_loading)
          OutlinedButton(
            onPressed: () => _load(),
            child: Text(context.tr('Show more')),
          ),
        if (_suggestions.isNotEmpty && _loading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
