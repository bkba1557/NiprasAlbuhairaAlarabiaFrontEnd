// splash_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/constants.dart';
import '../utils/app_routes.dart';
import 'front_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _navigated = false;
  String? _assetPath;

  static const double _largeScreenBreakpoint = 700;
  static const String _phoneSplashAsset = 'assets/videos/splash.mp4';
  static const String _largeSplashAsset = 'assets/videos/splash_large.mp4';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final nextAssetPath = screenWidth >= _largeScreenBreakpoint
        ? _largeSplashAsset
        : _phoneSplashAsset;

    if (_assetPath == nextAssetPath) return;

    _assetPath = nextAssetPath;
    _controller?.removeListener(_videoListener);
    _controller?.dispose();

    final controller = VideoPlayerController.asset(nextAssetPath);
    controller.addListener(_videoListener);
    _controller = controller;
    unawaited(_initializeController(controller));
  }

  Future<void> _initializeController(VideoPlayerController controller) async {
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;

      await controller.setLooping(false);
      await controller.setVolume(1.0);

      if (!mounted || _controller != controller) return;
      setState(() {});
      await controller.play();
    } catch (_) {
      if (mounted && _controller == controller) {
        _goNext();
      }
    }
  }

  void _videoListener() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _navigated) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;

    if (duration != Duration.zero && position >= duration) {
      _goNext();
    }
  }

  void _goNext() {
    if (!mounted || _navigated) return;

    _navigated = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (frontContext) => FrontPage(
          onEmployeeLogin: () {
            Navigator.pushNamed(frontContext, AppRoutes.login);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: controller != null && controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          : const SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              ),
            ),
    );
  }
}
