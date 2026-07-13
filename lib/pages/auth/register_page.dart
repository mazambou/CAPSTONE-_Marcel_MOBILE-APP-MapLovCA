part of '../../app.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Create your account',
      subtitle: 'Tell us a little about yourself.',
      image: 'assets/register/register.png',
      fields: const [
        _Field('Full name', Icons.badge_outlined),
        _Field('Email', Icons.email_outlined),
        _Field('Password', Icons.lock_outline, secret: true),
        _Field('Confirm password', Icons.lock_outline, secret: true),
        _Field('Country', Icons.public),
        _Field('City', Icons.location_city_outlined),
      ],
      primaryLabel: 'Create Account',
      onPrimary: () =>
          Navigator.pushReplacementNamed(context, AppRoutes.verifyEmail),
    );
  }
}
