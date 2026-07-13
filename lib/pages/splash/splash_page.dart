import 'dart:async';

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

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
    _navigationTimer = Timer(const Duration(seconds: 3), _goToOnboarding);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  void _goToOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash_screen'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/splash/splash01.png', fit: BoxFit.cover),
          SafeArea(
            child: Align(
              alignment: const Alignment(0, -0.56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 42),
                child: Image.asset(
                  'assets/logos/maplov_logo_full .png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
