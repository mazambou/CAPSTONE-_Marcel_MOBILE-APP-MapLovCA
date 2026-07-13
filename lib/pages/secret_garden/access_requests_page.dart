part of '../../app.dart';

class AccessRequestsScreen extends StatelessWidget {
  const AccessRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Garden access requests',
    children: [
      const Text(
        'You decide who can view your private albums and for how long.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 16),
      ...mockProfiles
          .take(2)
          .map(
            (profile) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: AssetImage(profile.imagePath),
                      ),
                      title: Text(
                        profile.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Requested access to My private moments',
                      ),
                    ),
                    const _Dropdown('Access duration', [
                      '5 minutes',
                      '10 minutes',
                      '20 minutes',
                      '1 hour',
                      'Permanent',
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {},
                            child: const Text('Allow'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    ],
  );
}
