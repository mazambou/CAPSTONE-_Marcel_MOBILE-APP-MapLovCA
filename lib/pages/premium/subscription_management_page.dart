part of '../../app.dart';

class SubscriptionManagementScreen extends StatelessWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Manage subscription',
    children: [
      Card(
        color: AppColors.palePink,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current plan', style: TextStyle(color: AppColors.grayText)),
              SizedBox(height: 6),
              Text(
                'MapLov Free',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text('No renewal date'),
            ],
          ),
        ),
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
      const ListTile(
        leading: Icon(Icons.receipt_long_outlined),
        title: Text('Billing history'),
        trailing: Icon(Icons.chevron_right),
      ),
    ],
  );
}
