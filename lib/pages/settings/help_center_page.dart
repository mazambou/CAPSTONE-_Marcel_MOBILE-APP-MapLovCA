part of '../../app.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Help Center',
    children: [
      const TextField(
        decoration: InputDecoration(
          hintText: 'Search for help',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const _SectionTitle('Popular topics'),
      ...[
        'Managing your account',
        'Profile and privacy',
        'Messages and friendships',
        'Secret Garden safety',
        'Premium subscriptions',
      ].map(
        (topic) => ExpansionTile(
          title: Text(topic),
          children: const [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Helpful information for this topic will be available here.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Contact support'),
            content: const SelectableText('support@maplov.ca'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.support_agent),
        label: const Text('Contact MapLov Support'),
      ),
    ],
  );
}
