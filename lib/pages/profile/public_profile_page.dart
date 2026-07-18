part of '../../app.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, this.profile});

  final UserProfile? profile;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late bool liked = widget.profile?.likedByMe ?? false;
  FriendshipItem? friendship;
  bool friendshipLoading = true;

  @override
  void initState() {
    super.initState();
    final id = widget.profile?.id;
    if (id != null && id.isNotEmpty) {
      unawaited(MapLovRepository.instance.recordProfileView(id));
    }
    unawaited(_loadFriendship());
  }

  Future<void> _toggleLike(UserProfile profile) async {
    final result = await _toggleProfileLikeFromDetails(context, profile);
    if (result != null && mounted) setState(() => liked = result.liked);
  }

  Future<void> _loadFriendship() async {
    final profile = widget.profile ?? demoProfileOrUnavailable;
    try {
      final loaded = await MapLovRepository.instance.friendshipWith(
        profile.id,
        profile: profile,
      );
      if (mounted) setState(() => friendship = loaded);
    } catch (_) {
      if (mounted) setState(() => friendship = null);
    } finally {
      if (mounted) setState(() => friendshipLoading = false);
    }
  }

  Future<bool> _confirmRemoveFriend(UserProfile profile) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove ${profile.name} from friends?'),
          content: const Text(
            'You can send a new friend request later if you change your mind.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove friend'),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool?> _chooseRequestResponse(UserProfile profile) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Friend request from ${profile.name}'),
      content: const Text('Would you like to accept this request?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Accept'),
        ),
      ],
    ),
  );

  Future<void> _friendAction(UserProfile profile) async {
    if (friendshipLoading) return;
    setState(() => friendshipLoading = true);
    try {
      final current = friendship;
      String confirmation;
      if (current == null) {
        await MapLovRepository.instance.sendFriendRequest(profile.id);
        confirmation = 'Friend request sent.';
      } else if (current.status == 'accepted') {
        if (!await _confirmRemoveFriend(profile)) return;
        await MapLovRepository.instance.removeFriendship(current.id);
        confirmation = 'Friend removed.';
      } else if (current.sentByMe) {
        await MapLovRepository.instance.removeFriendship(
          current.id,
          cancel: true,
        );
        confirmation = 'Friend request cancelled.';
      } else {
        final accept = await _chooseRequestResponse(profile);
        if (accept == null) return;
        await MapLovRepository.instance.respondToFriendRequest(
          current.id,
          accept,
        );
        confirmation = accept
            ? 'Friend request accepted.'
            : 'Friend request declined.';
      }
      if (!mounted) return;
      friendship = await MapLovRepository.instance.friendshipWith(
        profile.id,
        profile: profile,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(confirmation)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update friendship: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => friendshipLoading = false);
    }
  }

  String get _friendActionLabel {
    final current = friendship;
    if (current == null) return 'Add friend';
    if (current.status == 'accepted') return 'Remove friend';
    return current.sentByMe ? 'Cancel request' : 'Respond';
  }

  IconData get _friendActionIcon {
    final current = friendship;
    if (current == null) return Icons.person_add_alt;
    if (current.status == 'accepted') return Icons.person_remove_outlined;
    return current.sentByMe
        ? Icons.cancel_schedule_send_outlined
        : Icons.how_to_reg;
  }

  @override
  Widget build(BuildContext context) {
    final selectedProfile = widget.profile ?? demoProfileOrUnavailable;
    return _AppPage(
      title: '${selectedProfile.name}, ${selectedProfile.age}',
      children: [
        GestureDetector(
          key: Key('public_profile_photo_${selectedProfile.name}'),
          onTap: () async {
            if (!await _requireProfilePhotos(context, minimum: 1) ||
                !context.mounted) {
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhotoViewerScreen(profile: selectedProfile),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 360,
              width: double.infinity,
              child: profileImage(selectedProfile),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${selectedProfile.name}, ${selectedProfile.age}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (selectedProfile.isVip) const _VipBadge(),
                ],
              ),
            ),
            ActionChip(
              avatar: const Icon(
                Icons.favorite,
                color: AppColors.coral,
                size: 18,
              ),
              label: Text('${selectedProfile.compatibilityScore}%'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CompatibilityDetailsScreen(profile: selectedProfile),
                ),
              ),
            ),
          ],
        ),
        Text(
          '${selectedProfile.city}, ${selectedProfile.country}',
          style: const TextStyle(color: AppColors.grayText),
        ),
        if (selectedProfile.originCountry.isNotEmpty)
          Text(
            'Originally from ${selectedProfile.originCity.isEmpty ? '' : '${selectedProfile.originCity}, '}${selectedProfile.originCountry}',
            style: const TextStyle(color: AppColors.grayText),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: Key('public_profile_like_${selectedProfile.name}'),
            onPressed: () => _toggleLike(selectedProfile),
            icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
            label: Text(liked ? 'Liked' : 'Like profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepPink,
            ),
          ),
        ),
        const _SectionTitle('About'),
        Text(
          selectedProfile.bio.isEmpty
              ? 'Warm, curious and always ready to discover a new neighbourhood or live concert.'
              : selectedProfile.bio,
        ),
        const _SectionTitle('Interests'),
        const Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('Travel')),
            Chip(label: Text('Music')),
            Chip(label: Text('Coffee')),
            Chip(label: Text('Hiking')),
          ],
        ),
        const _SectionTitle('Photo albums'),
        Row(
          children: [
            Expanded(
              child: _ProfileAlbumCard(
                key: const Key('public_photos_album'),
                title: 'Public Photos',
                subtitle: 'Visible to everyone',
                imagePath: selectedProfile.imagePath,
                icon: Icons.photo_library_outlined,
                onTap: () async {
                  if (!await _requireProfilePhotos(context, minimum: 1) ||
                      !context.mounted) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PhotoViewerScreen(profile: selectedProfile),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileAlbumCard(
                key: const Key('secret_garden_album'),
                title: 'Secret Garden',
                subtitle: 'Permission required',
                imagePath:
                    'assets/secret_garden/secret_garden_locked_placeholder.png',
                icon: Icons.lock_outline,
                locked: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SecretGardenScreen(owner: selectedProfile),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('public_profile_friend_action'),
                onPressed: friendshipLoading
                    ? null
                    : () => _friendAction(selectedProfile),
                icon: friendshipLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_friendActionIcon),
                label: Text(
                  friendshipLoading ? 'Loading…' : _friendActionLabel,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final id = await MapLovRepository.instance.startConversation(
                    selectedProfile.id,
                  );
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: id,
                          profile: selectedProfile,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Message'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileAlbumCard extends StatelessWidget {
  const _ProfileAlbumCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.icon,
    required this.onTap,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final String imagePath;
  final IconData icon;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                imagePath.startsWith('http')
                    ? Image.network(
                        imagePath,
                        height: 128,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        imagePath,
                        height: 128,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                if (locked)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.64),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock, color: Colors.white),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: AppColors.coral, size: 18),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.grayText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
