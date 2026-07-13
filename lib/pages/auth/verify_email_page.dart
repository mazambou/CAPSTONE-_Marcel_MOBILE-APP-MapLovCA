part of '../../app.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Verify your email',
    children: [
      const Icon(
        Icons.mark_email_read_outlined,
        size: 88,
        color: AppColors.coral,
      ),
      const SizedBox(height: 20),
      Text(
        'Check your inbox',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      const Text(
        'We sent a verification link to jamie@example.com. Verify your email to continue creating your profile.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 28),
      _PrimaryButton(
        'I verified my email',
        onPressed: () =>
            Navigator.pushReplacementNamed(context, AppRoutes.profileSetup),
      ),
      OutlinedButton(
        onPressed: () {},
        child: const Text('Resend verification email'),
      ),
    ],
  );
}
