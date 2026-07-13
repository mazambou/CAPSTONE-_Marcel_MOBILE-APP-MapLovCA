part of '../../app.dart';

class ModerationReportsScreen extends StatelessWidget {
  const ModerationReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'User reports',
    children: [
      const _Dropdown('Status', [
        'Open reports',
        'Under review',
        'Resolved',
        'Dismissed',
      ]),
      const SizedBox(height: 14),
      ...['Fake profile', 'Harassment', 'Inappropriate content'].map(
        (reason) => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Chip(label: Text('Open')),
                  ],
                ),
                const Text('Reported user: Profile #1048'),
                const Text(
                  'Submitted 2 hours ago',
                  style: TextStyle(color: AppColors.grayText),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Review'),
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
