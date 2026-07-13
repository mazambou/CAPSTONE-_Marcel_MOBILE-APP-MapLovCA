part of '../../app.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.dateOfBirth});

  final DateTime? dateOfBirth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) return;
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final result = await AuthService.instance.signUp(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        country: _countryController.text,
        city: _cityController.text,
        dateOfBirth: widget.dateOfBirth!,
      );
      if (!mounted) return;
      if (result.requiresEmailConfirmation) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              email: _emailController.text.trim().toLowerCase(),
            ),
          ),
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.profileSetup,
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorText = AuthService.instance.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validate() {
    if (widget.dateOfBirth == null) {
      return 'Confirm your date of birth before creating an account.';
    }
    if (_fullNameController.text.trim().length < 2) {
      return 'Enter your full name.';
    }
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    final password = _passwordController.text;
    if (password.length < 8 ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Use at least 8 characters, including a number and a symbol.';
    }
    if (password != _confirmPasswordController.text) {
      return 'Passwords do not match.';
    }
    if (_countryController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      return 'Enter your country and city.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Create your account',
      subtitle: 'Tell us a little about yourself.',
      image: 'assets/register/register.png',
      fields: [
        _Field(
          'Full name',
          Icons.badge_outlined,
          controller: _fullNameController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          enabled: !_isLoading,
        ),
        _Field(
          'Email',
          Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          enabled: !_isLoading,
        ),
        _Field(
          'Password',
          Icons.lock_outline,
          secret: true,
          controller: _passwordController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !_isLoading,
        ),
        _Field(
          'Confirm password',
          Icons.lock_outline,
          secret: true,
          controller: _confirmPasswordController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !_isLoading,
        ),
        _Field(
          'Country',
          Icons.public,
          controller: _countryController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.countryName],
          enabled: !_isLoading,
        ),
        _Field(
          'City',
          Icons.location_city_outlined,
          controller: _cityController,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.addressCity],
          enabled: !_isLoading,
          onSubmitted: (_) => _register(),
        ),
      ],
      primaryLabel: 'Create Account',
      onPrimary: _register,
      errorText: _errorText,
      isLoading: _isLoading,
    );
  }
}
