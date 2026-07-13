part of '../../app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.palePink,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pageWidth = constraints.maxWidth.clamp(320.0, 420.0);
          final contentWidth = (pageWidth - 52).clamp(286.0, 360.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/login/login_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              SafeArea(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: pageWidth,
                      height: 850,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            left: 10,
                            right: 10,
                            height: 198,
                            child: Image.asset(
                              'assets/login/login_couple_placeholder.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                          const Positioned(
                            top: 204,
                            left: 20,
                            right: 20,
                            child: _LoginBrand(),
                          ),
                          Positioned(
                            top: 310,
                            left: (pageWidth - contentWidth) / 2,
                            width: contentWidth,
                            child: _LoginCard(
                              rememberMe: _rememberMe,
                              obscurePassword: _obscurePassword,
                              onRememberChanged: (value) {
                                setState(() => _rememberMe = value ?? false);
                              },
                              onPasswordVisibilityChanged: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              onLogin: () => Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.home,
                              ),
                              onRegister: () => Navigator.pushNamed(
                                context,
                                AppRoutes.ageGate,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logos/splash_logo.png',
                width: 66,
                height: 66,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Map',
                      style: TextStyle(color: AppColors.darkText),
                    ),
                    TextSpan(
                      text: 'Lov',
                      style: TextStyle(color: AppColors.deepPink),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 45,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BrandRule(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.favorite,
                  color: AppColors.softPink,
                  size: 13,
                ),
              ),
              Text(
                'Find Love Near You',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: _BrandRule(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandRule extends StatelessWidget {
  const _BrandRule();

  @override
  Widget build(BuildContext context) {
    return Container(width: 38, height: 1, color: AppColors.softPink);
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.rememberMe,
    required this.obscurePassword,
    required this.onRememberChanged,
    required this.onPasswordVisibilityChanged,
    required this.onLogin,
    required this.onRegister,
  });

  final bool rememberMe;
  final bool obscurePassword;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepPink.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Welcome Back',
            style: TextStyle(
              color: AppColors.deepPink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sign in to continue your journey',
            style: TextStyle(color: AppColors.grayText, fontSize: 15),
          ),
          const SizedBox(height: 14),
          const _LoginField(
            hintText: 'Email or Phone',
            icon: Icons.person,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _LoginField(
            hintText: 'Password',
            icon: Icons.lock,
            obscureText: obscurePassword,
            suffixIcon: IconButton(
              onPressed: onPasswordVisibilityChanged,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.grayText,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              SizedBox(
                width: 30,
                height: 34,
                child: Checkbox(
                  value: rememberMe,
                  onChanged: onRememberChanged,
                  activeColor: AppColors.deepPink,
                  side: const BorderSide(color: AppColors.softPink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Remember me',
                  style: TextStyle(color: AppColors.grayText),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.forgotPassword),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: AppColors.deepPink, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.softCoral, AppColors.deepPink],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Log In',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          const Row(
            children: [
              Expanded(child: Divider(color: AppColors.divider)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('or', style: TextStyle(color: AppColors.grayText)),
              ),
              Expanded(child: Divider(color: AppColors.divider)),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _RoundSocialButton(
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              const _RoundSocialButton(
                child: Icon(Icons.apple, color: Colors.black, size: 30),
              ),
              const SizedBox(width: 18),
              _RoundSocialButton(
                onPressed: onRegister,
                child: const Icon(
                  Icons.favorite,
                  color: AppColors.deepPink,
                  size: 29,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onRegister,
            child: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'New to MapLov? ',
                    style: TextStyle(color: AppColors.grayText),
                  ),
                  TextSpan(
                    text: 'Create Account',
                    style: TextStyle(
                      color: AppColors.deepPink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.grayText),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: EdgeInsets.zero,
        prefixIcon: Container(
          width: 58,
          margin: const EdgeInsets.only(right: 12),
          decoration: const BoxDecoration(
            color: AppColors.palePink,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
          ),
          child: Icon(icon, color: AppColors.deepPink),
        ),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.softPink.withValues(alpha: 0.28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.deepPink, width: 1.5),
        ),
      ),
    );
  }
}

class _RoundSocialButton extends StatelessWidget {
  const _RoundSocialButton({required this.child, this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: AppColors.deepPink.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onPressed ?? () {},
        customBorder: const CircleBorder(),
        child: SizedBox(width: 50, height: 50, child: Center(child: child)),
      ),
    );
  }
}
