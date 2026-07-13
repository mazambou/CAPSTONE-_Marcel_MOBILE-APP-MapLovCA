part of '../../app.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Moderation dashboard',
    children: [
      const Text(
        'Restricted to authorized MapLov moderators.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 16),
      const Row(
        children: [
          Expanded(
            child: _AdminMetric('Open reports', '12', Icons.flag_outlined),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _AdminMetric(
              'Review queue',
              '7',
              Icons.manage_accounts_outlined,
            ),
          ),
        ],
      ),
      const _SectionTitle('Moderation'),
      ListTile(
        leading: const Icon(Icons.report_outlined, color: AppColors.error),
        title: const Text('User reports'),
        subtitle: const Text('Review pending safety reports'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.moderationReports),
      ),
      const ListTile(
        leading: Icon(Icons.person_search_outlined),
        title: Text('User management'),
        subtitle: Text('Search, suspend or ban accounts'),
        trailing: Icon(Icons.chevron_right),
      ),
      const ListTile(
        leading: Icon(Icons.history),
        title: Text('Audit log'),
        subtitle: Text('Review moderator actions'),
        trailing: Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.coral),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
