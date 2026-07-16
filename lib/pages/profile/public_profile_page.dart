part of '../../app.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, this.profile});

  final UserProfile? profile;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late bool liked = widget.profile?.likedByMe ?? false;

  @override
  void initState() {
    super.initState();
    final id = widget.profile?.id;
    if (id != null && id.isNotEmpty) {
      unawaited(MapLovRepository.instance.recordProfileView(id));
    }
  }

  Future<void> _toggleLike(UserProfile profile) async {
    final result = await _toggleProfileLikeFromDetails(context, profile);
    if (result != null && mounted) setState(() => liked = result.liked);
  }

  @override
  Widget build(BuildContext context) {
    final selectedProfile = widget.profile ?? mockProfiles.first;
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
              child: Text(
                '${selectedProfile.name}, ${selectedProfile.age}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
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
          '${selectedProfile.city}, Canada',
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
                onPressed: () async {
                  try {
                    await MapLovRepository.instance.sendFriendRequest(
                      selectedProfile.id,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friend request sent.')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Unable to send request: $error'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add friend'),
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
