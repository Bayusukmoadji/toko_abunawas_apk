import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AnimatedSplashPage extends StatefulWidget {
  final Widget nextPage;

  const AnimatedSplashPage({
    super.key,
    required this.nextPage,
  });

  @override
  State<AnimatedSplashPage> createState() => _AnimatedSplashPageState();
}

class _AnimatedSplashPageState extends State<AnimatedSplashPage> {
  late final VideoPlayerController _videoController;

  Timer? _fallbackTimer;

  bool _isInitialized = false;
  bool _hasVideoError = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset(
      'assets/branding/splash_video.mp4',
    );

    _initializeVideo();

    _fallbackTimer = Timer(
      const Duration(seconds: 8),
      _goToNextPage,
    );
  }

  Future<void> _initializeVideo() async {
    try {
      await _videoController.initialize();

      await _videoController.setLooping(false);
      await _videoController.setVolume(0);

      _videoController.addListener(_handleVideoState);

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitialized = true;
      });

      await _videoController.play();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasVideoError = true;
      });

      Future<void>.delayed(
        const Duration(milliseconds: 1200),
        _goToNextPage,
      );
    }
  }

  void _handleVideoState() {
    final value = _videoController.value;

    if (value.isInitialized && value.isCompleted) {
      _goToNextPage();
    }
  }

  void _goToNextPage() {
    if (!mounted || _isNavigating) {
      return;
    }

    _isNavigating = true;
    _fallbackTimer?.cancel();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => widget.nextPage,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _videoController.removeListener(_handleVideoState);
    _videoController.dispose();
    super.dispose();
  }

  Widget _buildFallback() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _hasVideoError ? 0.75 : 1,
          child: Image.asset(
            'assets/branding/app_icon.png',
            width: 170,
            height: 170,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final size = _videoController.value.size;

    if (size.width <= 0 || size.height <= 0) {
      return _buildFallback();
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(_videoController),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isInitialized ? _buildVideo() : _buildFallback(),
    );
  }
}
