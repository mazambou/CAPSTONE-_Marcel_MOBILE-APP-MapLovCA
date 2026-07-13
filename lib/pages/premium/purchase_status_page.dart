part of '../../app.dart';

class PurchaseStatusScreen extends StatelessWidget {
  const PurchaseStatusScreen({super.key, this.planName = 'Premium Plus'});
  final String planName;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: PurchaseService.instance,
    builder: (context, _) {
      final service = PurchaseService.instance;
      final verified = service.lastVerifiedProductId != null;
      final failed = service.error != null;
      return _AppPage(
        title: 'Purchase status',
        children: [
          Icon(
            verified
                ? Icons.workspace_premium
                : failed
                ? Icons.error_outline
                : Icons.hourglass_top,
            size: 96,
            color: failed ? AppColors.error : AppColors.coral,
          ),
          const SizedBox(height: 18),
          Text(
            verified
                ? 'Welcome to $planName!'
                : failed
                ? 'Purchase not activated'
                : 'Verifying your purchase…',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            verified
                ? 'Your premium benefits are active on this account.'
                : failed
                ? service.error!
                : 'MapLov is securely validating the transaction with the store.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grayText),
          ),
          const SizedBox(height: 26),
          if (verified)
            _PrimaryButton(
              'Start exploring',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.home,
                (_) => false,
              ),
            )
          else if (failed)
            _PrimaryButton(
              'Back to plans',
              onPressed: () => Navigator.pop(context),
            )
          else
            const Center(child: Text('Waiting for the store confirmation…')),
        ],
      );
    },
  );
}
