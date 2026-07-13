part of '../../app.dart';

class PostDetailsScreen extends StatelessWidget {
  const PostDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = mockProfiles.first;
    return _AppPage(
      title: 'Post',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundImage: AssetImage(profile.imagePath)),
          title: Text(
            profile.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('2 hours ago • Friends only'),
          trailing: const Icon(Icons.more_horiz),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            profile.imagePath,
            height: 320,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('A perfect day exploring the city ✨'),
        ),
        const Row(
          children: [
            Icon(Icons.favorite, color: AppColors.coral),
            SizedBox(width: 6),
            Text('24 likes'),
            Spacer(),
            Text('5 comments'),
          ],
        ),
        const Divider(height: 30),
        const _SectionTitle('Comments'),
        ...[
          'This looks amazing!',
          'Such a beautiful place.',
          'We should go together!',
        ].map(
          (comment) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: const Text(
              'MapLov friend',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(comment),
          ),
        ),
        const SizedBox(height: 12),
        const TextField(
          decoration: InputDecoration(
            hintText: 'Write a comment...',
            suffixIcon: Icon(Icons.send, color: AppColors.coral),
          ),
        ),
      ],
    );
  }
}
