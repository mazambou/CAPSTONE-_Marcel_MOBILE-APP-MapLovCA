part of '../../app.dart';

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final selectedProfile = profile ?? mockProfiles.first;
    return _AppPage(
      title: '${selectedProfile.name}, ${selectedProfile.age}',
      children: [
        GestureDetector(
          key: Key('public_profile_photo_${selectedProfile.name}'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoViewerScreen(profile: selectedProfile),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              selectedProfile.imagePath,
              height: 360,
              width: double.infinity,
              fit: BoxFit.cover,
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
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.compatibilityDetails),
            ),
          ],
        ),
        Text(
          '${selectedProfile.city}, Canada',
          style: const TextStyle(color: AppColors.grayText),
        ),
        const _SectionTitle('About'),
        const Text(
          'Warm, curious and always ready to discover a new neighbourhood or live concert.',
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoViewerScreen(profile: selectedProfile),
                  ),
                ),
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
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.secretGarden),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add friend'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.chat),
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
                Image.asset(
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
