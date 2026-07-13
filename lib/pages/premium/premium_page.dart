part of '../../app.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const plans = [
      (
        'Free',
        '0 CAD/month',
        [
          'Profile, search and messaging',
          'Friendship and posts',
          'Secret Garden',
          'Block and report',
        ],
      ),
      (
        'Premium Plus',
        '9.99 CAD/month • 89.99 CAD/year',
        [
          'Invisible mode and visitors',
          'Advanced filters',
          'Moderate priority',
          'More Garden requests',
        ],
      ),
      (
        'Premium Elite',
        '19.99 CAD/month • 179.99 CAD/year',
        [
          'Maximum priority',
          'Advanced suggestions',
          'Detailed statistics',
          'Priority support',
        ],
      ),
    ];
    return _AppPage(
      title: 'MapLov Premium',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/premium/premium_pricing_placeholder.png',
            height: 230,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        ...plans.map(
          (plan) => Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.$1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    plan.$2,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Divider(),
                  ...plan.$3.map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    plan.$1 == 'Free' ? 'Current plan' : 'Choose ${plan.$1}',
                    onPressed: () => plan.$1 == 'Free'
                        ? Navigator.pushNamed(
                            context,
                            AppRoutes.subscriptionManagement,
                          )
                        : Navigator.pushNamed(
                            context,
                            AppRoutes.purchaseStatus,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
