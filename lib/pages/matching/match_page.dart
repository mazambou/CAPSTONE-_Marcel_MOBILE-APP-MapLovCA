part of '../../app.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});
  @override
  Widget build(BuildContext context) => _MainPage(
    index: 3,
    title: 'Your matches',
    children: [
      const Text(
        'Compatibility helps you discover people. Messaging remains available to everyone.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 16),
      ...mockProfiles.map(
        (p) => Card(
          child: ListTile(
            leading: CircleAvatar(backgroundImage: AssetImage(p.imagePath)),
            title: Text('${p.name}, ${p.age}'),
            subtitle: Text(
              '${p.compatibilityScore}% compatible • Travel, music',
            ),
            trailing: IconButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.chat),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          ),
        ),
      ),
    ],
  );
}
