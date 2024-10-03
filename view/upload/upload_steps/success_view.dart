import 'package:flutter/material.dart';

class SuccessScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  const SuccessScreen({super.key, required this.onAnimationComplete});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool animationComplete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            animationComplete = true;
          });
        }
      });

    _controller.forward();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (animationComplete && mounted) {
        widget.onAnimationComplete();
      }
    });
    return Scaffold(
      body: Center(
        child: ScaleTransition(
          scale: _controller.drive(
            Tween<double>(
              begin: 0.1,
              end: 1.5,
            ),
          ),
          child: const Icon(
            Icons.check_circle,
            size: 100,
            color: Colors.green,
          ),
        ),
      ),
    );
  }
}
