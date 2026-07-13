part of '../../app.dart';

class PostsScreen extends StatelessWidget {
  const PostsScreen({super.key});
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Friends posts',
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.createPost),
          icon: const Icon(Icons.add),
          label: const Text('Create post'),
        ),
      ),
      const SizedBox(height: 12),
      ...mockProfiles.map(
        (p) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(backgroundImage: AssetImage(p.imagePath)),
                title: Text(p.name),
                subtitle: const Text('Friends only'),
                trailing: IconButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.reportUser),
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
              InkWell(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.postDetails),
                child: Image.asset(
                  p.imagePath,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('A perfect day exploring the city ✨'),
              ),
              const Row(
                children: [
                  IconButton(
                    onPressed: null,
                    icon: Icon(Icons.favorite_border),
                  ),
                  Text('Like'),
                  SizedBox(width: 20),
                  Icon(Icons.chat_bubble_outline),
                  SizedBox(width: 6),
                  Text('Comment'),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ],
  );
}
