import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../manager/home_controller.dart';

class SplashLoadingPage extends StatefulWidget {
  const SplashLoadingPage({
    super.key,
    required this.controller,
    required this.onCompleted,
  });

  final HomeController controller;
  final VoidCallback onCompleted;

  @override
  State<SplashLoadingPage> createState() => _SplashLoadingPageState();
}

class _SplashLoadingPageState extends State<SplashLoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final start = DateTime.now();
    await widget.controller.load();

    final elapsed = DateTime.now().difference(start);
    const minDuration = Duration(milliseconds: 1600);
    if (elapsed < minDuration) {
      await Future<void>.delayed(minDuration - elapsed);
    }

    if (mounted) {
      widget.onCompleted();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF04142D),
              AppColors.surfaceDim,
              Color(0xFF041321),
            ],
          ),
        ),
        child: Stack(
          children: [
            const _GridTexture(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final glow = 0.25 + (_pulseController.value * 0.35);
                          return Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryContainer.withValues(
                                    alpha: glow,
                                  ),
                                  blurRadius: 54,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(48),
                          ),
                          child: Image.asset('assets/images/app_icon.jpg'),
                        ),
                      ),
                      const SizedBox(height: 42),
                      Text(
                        'ShuttleX',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontSize: 58,
                              height: 0.92,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'VERSION v1.0.0',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 64),
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'INITIALIZING SYSTEMS',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.primaryContainer,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridTexture extends StatelessWidget {
  const _GridTexture();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.22,
        child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D2744)
      ..strokeWidth = 1;

    const step = 24.0;
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
