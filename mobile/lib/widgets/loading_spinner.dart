import 'package:flutter/material.dart';

class LoadingSpinner extends StatefulWidget {
  final double size;

  const LoadingSpinner({super.key, this.size = 72}); // 기존 48의 150%

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/images/loading_leaves.png',
        width: widget.size,
        height: widget.size,
      ),
    );
  }
}