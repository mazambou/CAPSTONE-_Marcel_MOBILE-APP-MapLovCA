part of '../../app.dart';

/// Web fallback shown while Supabase exchanges the PKCE code.
///
/// Installed Android and iOS builds normally leave this screen immediately
/// because the verified HTTPS link is delivered straight to the application.
class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  Timer? _fallbackTimer;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _fallbackTimer = Timer(const Duration(seconds: 3), _finishIfNeeded);
  }

  Future<void> _finishIfNeeded() async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (!AuthService.instance.hasActiveSession) {
      setState(() => _failed = true);
      return;
    }
    final intent = AuthService.instance.pendingAuthIntent;
    if (intent == MapLovAuthIntent.passwordRecovery) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.resetPassword,
        (_) => false,
      );
      return;
    }
    final destination = intent == MapLovAuthIntent.emailChange
        ? AppRoutes.security
        : await _authenticatedLandingRoute();
    await AuthService.instance.clearPendingAuthIntent();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link_off_outlined,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This authentication link is invalid, expired, or was opened on a different device.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.login,
                        (_) => false,
                      ),
                      child: const Text('Return to login'),
                    ),
                  ],
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 18),
                    Text('Completing secure authentication…'),
                  ],
                ),
        ),
      ),
    ),
  );
}
