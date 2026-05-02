// splash_screen.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/constants.dart';
import '../utils/app_routes.dart';
import 'front_page_stub.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });

    _controller
      ..setLooping(false)
      ..setVolume(1.0);

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (!_controller.value.isInitialized || _navigated) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

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
        builder: (_) => FrontPage(
          onEmployeeLogin: () {
            Navigator.pushNamed(context, AppRoutes.login);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
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
