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
    metrics = MapLovRepository.instance.adminDashboardStatistics();
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Administrator dashboard',
    children: [
      const Text(
        'Restricted to authorized MapLov moderators.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, int>>(
        future: metrics,
        builder: (context, snapshot) {
          final values = snapshot.data ?? const <String, int>{};
          return Row(
            children: [
              Expanded(
                child: _AdminMetric(
                  'Users',
                  '${values['users'] ?? 0}',
                  Icons.flag_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdminMetric(
                  'Open reports',
                  '${values['open_reports'] ?? 0}',
                  Icons.manage_accounts_outlined,
                ),
              ),
            ],
          );
        },
      ),
      const _SectionTitle('Management'),
      _AdminDashboardTile(
        icon: Icons.people_outline,
        title: 'Users',
        subtitle: 'Search, suspend or ban accounts',
        destination: const AdminUsersScreen(),
      ),
      _AdminDashboardTile(
        icon: Icons.badge_outlined,
        title: 'Profiles',
        subtitle: 'Discovery, completion and verification',
        destination: const AdminProfilesScreen(),
      ),
      _AdminDashboardTile(
        icon: Icons.photo_library_outlined,
        title: 'Photos',
        subtitle: 'Approve, verify or remove photos',
        destination: const AdminPhotosScreen(),
      ),
      ListTile(
        leading: const Icon(Icons.report_outlined, color: AppColors.error),
        title: const Text('User reports'),
        subtitle: const Text('Review pending safety reports'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.moderationReports),
      ),
      _AdminDashboardTile(
        icon: Icons.person_off_outlined,
        title: 'Suspensions',
        subtitle: 'Review frozen and banned accounts',
        destination: const AdminSuspensionsScreen(),
      ),
      _AdminDashboardTile(
        icon: Icons.workspace_premium_outlined,
        title: 'Subscriptions',
        subtitle: 'Store status and manual grants',
        destination: const AdminSubscriptionsScreen(),
      ),
      _AdminDashboardTile(
        icon: Icons.payments_outlined,
        title: 'Payments',
        subtitle: 'Validated Apple and Google transactions',
        destination: const AdminPaymentsScreen(),
      ),
      _AdminDashboardTile(
        icon: Icons.analytics_outlined,
        title: 'Statistics',
        subtitle: 'Platform activity and safety totals',
        destination: const AdminStatisticsScreen(),
      ),
      _AdminDashboardTile(
        icon: Icons.campaign_outlined,
        title: 'Global notifications',
        subtitle: 'Notify every active account',
        destination: const AdminGlobalNotificationsScreen(),
      ),
      _AdminDashboardTile(
        icon: Icons.restore_outlined,
        title: 'Account recovery',
        subtitle: 'Cancel deletion and restore access',
        destination: const AdminAccountRecoveryScreen(),
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

class _AdminDashboardTile extends StatelessWidget {
  const _AdminDashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destination,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget destination;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => destination),
    ),
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
