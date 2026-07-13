part of '../../app.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Forgot password',
    children: [
      const Icon(Icons.lock_reset, size: 84, color: AppColors.coral),
      const SizedBox(height: 18),
      Text(
        'Reset your password',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter the email connected to your MapLov account. We will send you a secure reset link.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 28),
      const _Field('Email address', Icons.email_outlined),
      const SizedBox(height: 20),
      _PrimaryButton(
        'Send reset link',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.resetPassword),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to login'),
      ),
    ],
  );
}
