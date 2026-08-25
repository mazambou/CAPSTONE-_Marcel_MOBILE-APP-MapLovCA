import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/locale_service.dart';
import '../../shared/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _items = <_OnboardingItem>[
    _OnboardingItem(
      title: 'Find Love Near You',
      description: 'Discover meaningful connections with people near you.',
      imagePath: 'assets/onboarding/onboarding01/onboarding_01_background.png',
      imageFit: BoxFit.cover,
      imageAlignment: Alignment.center,
    ),
    _OnboardingItem(
      title: 'Smart Matching',
      description: 'Meet compatible people chosen around what matters to you.',
      imagePath: 'assets/onboarding/onboarding02/onboarding_02_background.png',
      imageFit: BoxFit.contain,
      imageAlignment: Alignment.topCenter,
    ),
    _OnboardingItem(
      title: 'Chat & Connect',
      description: 'Start a conversation and turn a match into something real.',
      imagePath: 'assets/onboarding/onboarding03/onboarding_03_background.png',
      imageFit: BoxFit.cover,
      imageAlignment: Alignment.center,
    ),
    _OnboardingItem(
      title: 'Safe & Verified Community',
      description: 'Connect confidently in a community built around trust.',
      imagePath:
          'assets/onboarding/onboarding04/onboarding_04_background_no_skip.png',
      imageFit: BoxFit.contain,
      imageAlignment: Alignment.center,
    ),
  ];

  bool get _isFirstPage => _currentPage == 0;
  bool get _isLastPage => _currentPage == _items.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int page) async {
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextPage() {
    if (_isLastPage) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }
    _goToPage(_currentPage + 1);
  }

  void _previousPage() {
    if (!_isFirstPage) _goToPage(_currentPage - 1);
  }

  void _skip() => _goToPage(_items.length - 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('onboarding_screen'),
      backgroundColor: AppColors.palePink,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: isWide ? 24 : 8,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(isWide ? 36 : 28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepPink.withValues(alpha: 0.10),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isWide ? 36 : 28),
                      child: Column(
                        children: [
                          _OnboardingHeader(
                            showSkip: !_isLastPage,
                            onSkip: _skip,
                          ),
                          Expanded(
                            child: PageView.builder(
                              key: const Key('onboarding_pages'),
                              controller: _pageController,
                              itemCount: _items.length,
                              onPageChanged: (page) {
                                setState(() => _currentPage = page);
                              },
                              itemBuilder: (context, index) => _OnboardingPage(
                                item: _items[index],
                                isWide: isWide,
                              ),
                            ),
                          ),
                          _OnboardingFooter(
                            currentPage: _currentPage,
                            pageCount: _items.length,
                            showPrevious: !_isFirstPage,
                            isLastPage: _isLastPage,
                            onPrevious: _previousPage,
                            onNext: _nextPage,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.imageFit,
    required this.imageAlignment,
  });

  final String title;
  final String description;
  final String imagePath;
  final BoxFit imageFit;
  final Alignment imageAlignment;
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
      child: Row(
        children: [
          Image.asset(
            'assets/logos/splash_logo.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            semanticLabel: 'MapLov',
          ),
          const SizedBox(width: 8),
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
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: showSkip ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !showSkip,
              child: TextButton(
                key: const Key('onboarding_skip_button'),
                onPressed: onSkip,
                child: Text(
                  context.tr('Skip'),
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item, required this.isWide});

  final _OnboardingItem item;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final illustration = _OnboardingIllustration(item: item);
    final copy = _OnboardingCopy(item: item, isWide: isWide);

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
        child: Row(
          children: [
            Expanded(flex: 6, child: illustration),
            const SizedBox(width: 48),
            Expanded(flex: 4, child: copy),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Column(
        children: [
          Expanded(flex: 6, child: illustration),
          const SizedBox(height: 16),
          Expanded(flex: 3, child: copy),
        ],
      ),
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({required this.item});

  final _OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.palePink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Image.asset(
          item.imagePath,
          key: ValueKey(item.imagePath),
          fit: item.imageFit,
          alignment: item.imageAlignment,
          width: double.infinity,
          height: double.infinity,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _OnboardingCopy extends StatelessWidget {
  const _OnboardingCopy({required this.item, required this.isWide});

  final _OnboardingItem item;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 8 : 10),
        child: Semantics(
          container: true,
          header: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(item.title),
                key: ValueKey(item.title),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: isWide ? 40 : 29,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(item.description),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.grayText,
                  fontSize: isWide ? 18 : 16,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.currentPage,
    required this.pageCount,
    required this.showPrevious,
    required this.isLastPage,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final bool showPrevious;
  final bool isLastPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '${currentPage + 1} / $pageCount',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pageCount,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Dot(isActive: index == currentPage),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AnimatedOpacity(
                opacity: showPrevious ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !showPrevious,
                  child: IconButton.filledTonal(
                    key: const Key('onboarding_previous_button'),
                    tooltip: context.tr('Back'),
                    onPressed: onPrevious,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      backgroundColor: AppColors.palePink,
                      foregroundColor: AppColors.deepPink,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    key: const Key('onboarding_next_button'),
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepPink,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Row(
                        key: ValueKey(isLastPage),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr(isLastPage ? 'Get Started' : 'Next'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: isActive ? 28 : 9,
      height: 9,
      decoration: BoxDecoration(
        color: isActive ? AppColors.deepPink : AppColors.border,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
