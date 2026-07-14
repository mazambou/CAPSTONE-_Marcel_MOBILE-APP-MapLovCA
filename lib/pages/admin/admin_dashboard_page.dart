part of '../../app.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, int>> metrics;

  @override
  void initState() {
    super.initState();
    metrics = MapLovRepository.instance.adminMetrics();
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Moderation dashboard',
    children: [
      const Text(
        'Restricted to authorized MapLov moderators.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, int>>(
        future: metrics,
        builder: (context, snapshot) {
          final values = snapshot.data ?? const {'reports': 0, 'review': 0};
          return Row(
            children: [
              Expanded(
                child: _AdminMetric(
                  'Open reports',
                  '${values['reports'] ?? 0}',
                  Icons.flag_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdminMetric(
                  'Review queue',
                  '${values['review'] ?? 0}',
                  Icons.manage_accounts_outlined,
                ),
              ),
            ],
          );
        },
      ),
      const _SectionTitle('Moderation'),
      ListTile(
        leading: const Icon(Icons.report_outlined, color: AppColors.error),
        title: const Text('User reports'),
        subtitle: const Text('Review pending safety reports'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.moderationReports),
      ),
      ListTile(
        leading: const Icon(Icons.person_search_outlined),
        title: const Text('User management'),
        subtitle: const Text('Search, suspend or ban accounts'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.adminUsers),
      ),
      ListTile(
        leading: const Icon(Icons.history),
        title: const Text('Audit log'),
        subtitle: const Text('Review moderator actions'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.adminAudit),
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
