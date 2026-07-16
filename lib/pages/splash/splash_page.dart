import 'dart:async';

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(seconds: 3), _leaveSplash);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  Future<void> _leaveSplash() async {
    if (!mounted) return;
    var profileComplete = true;
    if (AuthService.instance.hasActiveSession) {
      try {
        await AuthService.instance.validateCurrentAccount();
        profileComplete = await AuthService.instance.isCurrentProfileComplete();
      } catch (_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        return;
      }
    }
    if (!mounted) return;
    final signedInDestination = !profileComplete
        ? AppRoutes.profileSetup
        : AuthService.instance.requiresPreferencesCompletion
        ? AppRoutes.preferences
        : AuthService.instance.requiresPhoneVerification
        ? AppRoutes.verifyPhone
        : AppRoutes.home;
    Navigator.of(context).pushReplacementNamed(
      AuthService.instance.hasActiveSession
          ? signedInDestination
          : AppRoutes.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash_screen'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/splash/splash01.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          SafeArea(
            child: Align(
              alignment: const Alignment(0, -0.56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 42),
                child: Image.asset(
                  'assets/logos/maplov_logo_full .png',
                  fit: BoxFit.contain,
                  semanticLabel: 'MapLov',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
