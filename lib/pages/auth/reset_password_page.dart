part of '../../app.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Create new password',
    children: [
      const Icon(
        Icons.verified_user_outlined,
        size: 76,
        color: AppColors.coral,
      ),
      const SizedBox(height: 18),
      const Text(
        'Choose a strong password with at least 8 characters, one number and one symbol.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 26),
      const _Field('New password', Icons.lock_outline, secret: true),
      const SizedBox(height: 14),
      const _Field('Confirm new password', Icons.lock_outline, secret: true),
      const SizedBox(height: 22),
      _PrimaryButton(
        'Update password',
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        ),
      ),
    ],
  );
}
