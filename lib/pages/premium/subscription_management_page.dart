part of '../../app.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  late Future<SubscriptionInfo> subscription;

  @override
  void initState() {
    super.initState();
    subscription = MapLovRepository.instance.subscriptionInfo();
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Manage subscription',
    children: [
      FutureBuilder<SubscriptionInfo>(
        future: subscription,
        builder: (context, snapshot) {
          final info = snapshot.data ?? const SubscriptionInfo();
          return Card(
            color: AppColors.palePink,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current plan',
                    style: TextStyle(color: AppColors.grayText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'MapLov ${info.tier[0].toUpperCase()}${info.tier.substring(1)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    info.renewsAt == null
                        ? 'No renewal date'
                        : 'Renews ${DateFormat.yMMMd().format(info.renewsAt!)}',
                  ),
                  Text('Status: ${info.status}'),
                ],
              ),
            ),
          );
        },
      ),
      const _SectionTitle('Subscription actions'),
      ListTile(
        leading: const Icon(Icons.upgrade, color: AppColors.coral),
        title: const Text('Explore Premium plans'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.premium),
      ),
      ListTile(
        leading: const Icon(Icons.restore),
        title: const Text('Restore purchases'),
        subtitle: const Text(
          'Restore a subscription purchased on this store account.',
        ),
        onTap: () async {
          await PurchaseService.instance.restore();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Restore request sent to the store.'),
              ),
            );
          }
        },
      ),
      FutureBuilder<SubscriptionInfo>(
        future: subscription,
        builder: (context, snapshot) {
          final history = snapshot.data?.history ?? const [];
          return ExpansionTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Billing history'),
            children: history.isEmpty
                ? const [ListTile(title: Text('No store transactions yet.'))]
                : history
                      .map(
                        (item) => ListTile(
                          title: Text('${item['tier']} • ${item['status']}'),
                          subtitle: Text(
                            '${item['created_at'] ?? ''}'.split('T').first,
                          ),
                        ),
                      )
                      .toList(),
          );
        },
      ),
    ],
  );
}
