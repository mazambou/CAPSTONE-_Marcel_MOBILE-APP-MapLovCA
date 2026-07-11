import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const String _skylineAsset = 'assets/splash/splash01.png';
  static const String _logoIconAsset = 'assets/logos/maplov_symbol.png';
  static const String _textLogoAsset = 'assets/logos/maplov_logo_full .png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash_screen'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final width = size.width;
          final height = size.height;
          final shortSide = size.shortestSide;
          final logoIconSize = (shortSide * 0.38)
              .clamp(132.0, 188.0)
              .toDouble();
          final textLogoWidth = (width * 0.78).clamp(270.0, 430.0).toDouble();
          final textLogoHeight = (height * 0.09).clamp(58.0, 86.0).toDouble();
          final topOffset = (height * 0.165).clamp(72.0, 145.0).toDouble();
          final skylineTop = height * 0.535;
          final skylineHeight = height * 0.285;

          return Stack(
            children: [
              const Positioned.fill(child: _GradientBackground()),
              Positioned.fill(
                child: CustomPaint(painter: _FloatingHeartsPainter()),
              ),
              Positioned.fill(
                top: height * 0.48,
                child: CustomPaint(painter: _WavePainter()),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: skylineTop,
                height: skylineHeight,
                child: const _ClippedSkyline(asset: _skylineAsset),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: topOffset,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _logoIconAsset,
                      width: logoIconSize,
                      height: logoIconSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    SizedBox(
                      height: (height * 0.012).clamp(8.0, 14.0).toDouble(),
                    ),
                    SizedBox(
                      width: textLogoWidth,
                      height: textLogoHeight,
                      child: Image.asset(
                        _textLogoAsset,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    SizedBox(
                      height: (height * 0.012).clamp(8.0, 14.0).toDouble(),
                    ),
                    const Text(
                      'Find Love Near You',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 25,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.8,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(
                      height: (height * 0.017).clamp(12.0, 18.0).toDouble(),
                    ),
                    const _TaglineRule(),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: (height * 0.045).clamp(28.0, 48.0).toDouble(),
                child: const _BottomMessage(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.palePink,
            AppColors.white,
            Color(0xFFFFEEF3),
            AppColors.softPink,
            AppColors.coral,
          ],
          stops: [0, 0.48, 0.62, 0.78, 1],
        ),
      ),
    );
  }
}

class _ClippedSkyline extends StatelessWidget {
  const _ClippedSkyline({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 0.54,
        child: Image.asset(
          asset,
          width: MediaQuery.sizeOf(context).width,
          fit: BoxFit.fitWidth,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _TaglineRule extends StatelessWidget {
  const _TaglineRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 86, height: 1.2, color: AppColors.softPink),
        const SizedBox(width: 16),
        const Icon(Icons.favorite_rounded, color: AppColors.coral, size: 24),
        const SizedBox(width: 16),
        Container(width: 86, height: 1.2, color: AppColors.softPink),
      ],
    );
  }
}

class _BottomMessage extends StatelessWidget {
  const _BottomMessage();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scriptSize = (width * 0.083).clamp(28.0, 38.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Connecting Hearts',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 27, height: 1.4, color: AppColors.white),
            const SizedBox(width: 15),
            Text(
              'Across Canada',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: scriptSize,
                fontWeight: FontWeight.w300,
                letterSpacing: 0,
                height: 1.05,
              ),
            ),
            const SizedBox(width: 15),
            Container(width: 27, height: 1.4, color: AppColors.white),
          ],
        ),
        const SizedBox(height: 18),
        const _CanadaFlag(width: 48, height: 31),
      ],
    );
  }
}

class _CanadaFlag extends StatelessWidget {
  const _CanadaFlag({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkText.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: width * 0.28,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.coral),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: width * 0.28,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.coral),
            ),
          ),
          Center(
            child: CustomPaint(
              size: Size(height * 0.58, height * 0.58),
              painter: const _MapleLeafPainter(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingHeartsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hearts = <_HeartSpec>[
      _HeartSpec(
        0.24,
        0.13,
        30,
        -0.16,
        AppColors.softPink.withValues(alpha: 0.78),
      ),
      _HeartSpec(
        0.73,
        0.12,
        22,
        0.17,
        AppColors.softPink.withValues(alpha: 0.45),
      ),
      _HeartSpec(0.83, 0.24, 40, 0.22, AppColors.coral.withValues(alpha: 0.82)),
      _HeartSpec(0.14, 0.35, 50, 0.22, AppColors.coral.withValues(alpha: 0.72)),
      _HeartSpec(
        0.21,
        0.26,
        23,
        -0.2,
        AppColors.softPink.withValues(alpha: 0.5),
      ),
      _HeartSpec(
        0.82,
        0.36,
        22,
        -0.2,
        AppColors.softPink.withValues(alpha: 0.52),
      ),
      _HeartSpec(
        0.87,
        0.44,
        42,
        -0.18,
        AppColors.coral.withValues(alpha: 0.72),
      ),
      _HeartSpec(
        0.23,
        0.51,
        22,
        0.12,
        AppColors.softPink.withValues(alpha: 0.48),
      ),
      _HeartSpec(
        0.34,
        0.57,
        32,
        0.14,
        AppColors.softPink.withValues(alpha: 0.78),
      ),
      _HeartSpec(
        0.71,
        0.56,
        22,
        -0.08,
        AppColors.softPink.withValues(alpha: 0.55),
      ),
    ];

    for (final heart in hearts) {
      final side = (heart.size * (size.width / 390))
          .clamp(16.0, 58.0)
          .toDouble();
      final offset = Offset(size.width * heart.x, size.height * heart.y);
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(heart.rotation);
      canvas.drawPath(
        _heartPath(Size(side, side)).shift(Offset(-side / 2, -side / 2)),
        Paint()..color = heart.color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final washPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.softPink.withValues(alpha: 0.18),
          AppColors.softPink.withValues(alpha: 0.5),
          AppColors.coral.withValues(alpha: 0.95),
        ],
      ).createShader(rect);

    final softWave = Path()
      ..moveTo(0, size.height * 0.28)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.4,
        size.width * 0.49,
        size.height * 0.1,
        size.width,
        size.height * 0.22,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(softWave, washPaint);

    final middleWave = Path()
      ..moveTo(0, size.height * 0.54)
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.65,
        size.width * 0.56,
        size.height * 0.36,
        size.width,
        size.height * 0.46,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      middleWave,
      Paint()..color = AppColors.softCoral.withValues(alpha: 0.72),
    );

    final deepWave = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.84,
        size.width * 0.6,
        size.height * 0.56,
        size.width,
        size.height * 0.62,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(deepWave, Paint()..color = AppColors.deepPink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapleLeafPainter extends CustomPainter {
  const _MapleLeafPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_mapleLeafPath(size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeartSpec {
  const _HeartSpec(this.x, this.y, this.size, this.rotation, this.color);

  final double x;
  final double y;
  final double size;
  final double rotation;
  final Color color;
}

Path _heartPath(Size size) {
  return Path()
    ..moveTo(size.width / 2, size.height * 0.88)
    ..cubicTo(
      size.width * 0.08,
      size.height * 0.57,
      0,
      size.height * 0.28,
      size.width * 0.22,
      size.height * 0.13,
    )
    ..cubicTo(
      size.width * 0.38,
      size.height * 0.01,
      size.width * 0.5,
      size.height * 0.16,
      size.width / 2,
      size.height * 0.28,
    )
    ..cubicTo(
      size.width * 0.5,
      size.height * 0.16,
      size.width * 0.62,
      size.height * 0.01,
      size.width * 0.78,
      size.height * 0.13,
    )
    ..cubicTo(
      size.width,
      size.height * 0.28,
      size.width * 0.92,
      size.height * 0.57,
      size.width / 2,
      size.height * 0.88,
    )
    ..close();
}

Path _mapleLeafPath(Size size) {
  final points = <Offset>[
    const Offset(0.50, 0.02),
    const Offset(0.59, 0.25),
    const Offset(0.73, 0.17),
    const Offset(0.69, 0.36),
    const Offset(0.9, 0.33),
    const Offset(0.77, 0.48),
    const Offset(0.96, 0.56),
    const Offset(0.69, 0.61),
    const Offset(0.73, 0.8),
    const Offset(0.56, 0.7),
    const Offset(0.53, 0.98),
    const Offset(0.47, 0.98),
    const Offset(0.44, 0.7),
    const Offset(0.27, 0.8),
    const Offset(0.31, 0.61),
    const Offset(0.04, 0.56),
    const Offset(0.23, 0.48),
    const Offset(0.1, 0.33),
    const Offset(0.31, 0.36),
    const Offset(0.27, 0.17),
    const Offset(0.41, 0.25),
  ];

  final path = Path()
    ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx * size.width, point.dy * size.height);
  }
  return path..close();
}
