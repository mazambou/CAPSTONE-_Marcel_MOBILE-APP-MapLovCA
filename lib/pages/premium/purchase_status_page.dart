part of '../../app.dart';

class PurchaseStatusScreen extends StatelessWidget {
  const PurchaseStatusScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Purchase complete',
    children: [
      const Icon(Icons.workspace_premium, size: 96, color: AppColors.coral),
      const SizedBox(height: 18),
      const Text(
        'Welcome to Premium Plus!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      const Text(
        'Your premium benefits are now active on this account.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 26),
      _PrimaryButton(
        'Start exploring',
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        ),
      ),
    ],
  );
}
