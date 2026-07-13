part of '../../app.dart';

class FriendsListScreen extends StatelessWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Friends',
    children: [
      const TextField(
        decoration: InputDecoration(
          hintText: 'Search friends',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 16),
      ...mockProfiles.map(
        (profile) => Card(
          child: ListTile(
            onTap: () => Navigator.pushNamed(context, AppRoutes.publicProfile),
            leading: CircleAvatar(
              backgroundImage: AssetImage(profile.imagePath),
            ),
            title: Text(
              profile.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(profile.city),
            trailing: PopupMenuButton<String>(
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'message', child: Text('Message')),
                PopupMenuItem(value: 'remove', child: Text('Remove friend')),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
