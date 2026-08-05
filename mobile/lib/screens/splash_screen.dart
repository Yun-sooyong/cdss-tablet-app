import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  final AuthService authService;

  const SplashScreen({super.key, required this.authService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _LeafConfig {
  final double left;
  final double size;
  final Duration duration;
  final double delaySeconds;

  _LeafConfig({
    required this.left,
    required this.size,
    required this.duration,
    required this.delaySeconds,
  });
}

class _SplashScreenState extends State<SplashScreen> {
  final _random = Random();
  late final List<_LeafConfig> _leafConfigs;

  @override
  void initState() {
    super.initState();
    _leafConfigs = List.generate(
      7,
      (_) => _LeafConfig(
        left: _random.nextDouble(),
        size: 16 + _random.nextDouble() * 14,
        duration: Duration(milliseconds: 4500 + _random.nextInt(3000)),
        delaySeconds: _random.nextDouble() * 3,
      ),
    );
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final stopwatch = Stopwatch()..start();
    final isLoggedIn = await widget.authService.tryAutoLogin();

    const minDisplayMs = 2500;
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < minDisplayMs) {
      await Future.delayed(Duration(milliseconds: minDisplayMs - elapsed));
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLoggedIn
            ? MainShell(authService: widget.authService)
            : LoginScreen(authService: widget.authService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.lightBackground,
        child: Stack(
          children: [
            ..._leafConfigs.map((c) => _DriftingLeaf(
                  left: c.left,
                  size: c.size,
                  duration: c.duration,
                  delaySeconds: c.delaySeconds,
                )),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/vtree_login_logo.png',
                        width: 180),
                    const SizedBox(height: 8),
                    const Text(
                      '건강한 오늘, 더 나은 내일',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 56),
                    const _LeafRingLoader(),
                    const SizedBox(height: 20),
                    const Text('로딩 중입니다...',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('잠시만 기다려주세요.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriftingLeaf extends StatefulWidget {
  final double left;
  final double size;
  final Duration duration;
  final double delaySeconds;

  const _DriftingLeaf({
    required this.left,
    required this.size,
    required this.duration,
    required this.delaySeconds,
  });

  @override
  State<_DriftingLeaf> createState() => _DriftingLeafState();
}

class _DriftingLeafState extends State<_DriftingLeaf>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    Future.delayed(Duration(milliseconds: (widget.delaySeconds * 1000).round()),
        () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final top = -80 + t * (screenSize.height + 160);
        final sway = sin(t * 2 * pi * 2) * 20;
        double opacity;
        if (t < 0.1) {
          opacity = t / 0.1;
        } else if (t > 0.85) {
          opacity = (1 - t) / 0.15;
        } else {
          opacity = 1.0;
        }
        return Positioned(
          top: top,
          left: (widget.left * screenSize.width + sway)
              .clamp(0, screenSize.width - widget.size),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: t * 2 * pi,
              child: Image.asset('assets/images/vtree_leaf_primary.png',
                  width: widget.size),
            ),
          ),
        );
      },
    );
  }
}

class _LeafRingLoader extends StatefulWidget {
  final double size;
  const _LeafRingLoader({this.size = 140});

  @override
  State<_LeafRingLoader> createState() => _LeafRingLoaderState();
}

class _LeafRingLoaderState extends State<_LeafRingLoader>
    with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final AnimationController _percentController;
  late final Animation<double> _percent;

  @override
  void initState() {
    super.initState();
    _rotateController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    _percentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _percent = Tween<double>(begin: 0, end: 100).animate(
        CurvedAnimation(parent: _percentController, curve: Curves.easeOut));
    _percentController.forward();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const leafCount = 16;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _rotateController,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(leafCount, (i) {
                final angle = (2 * pi / leafCount) * i;
                final radius = widget.size / 2 - 10;
                return Transform.translate(
                  offset: Offset(radius * cos(angle), radius * sin(angle)),
                  child: Transform.rotate(
                    angle: angle + pi / 2,
                    child: Image.asset('assets/images/vtree_leaf_primary.png',
                        width: 16),
                  ),
                );
              }),
            ),
          ),
          AnimatedBuilder(
            animation: _percent,
            builder: (context, _) => Text(
              '${_percent.value.round()}%',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
