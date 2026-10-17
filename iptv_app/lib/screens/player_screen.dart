import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/channel.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  final Map<VideoPlayerController, VoidCallback> _controllerListeners = {};
  final Map<VideoPlayerController, Future<void>> _initializations = {};
  bool _initializing = true;
  bool _showControls = true;
  bool _isBuffering = false;
  bool _isFullscreen = true;
  bool _wasPlayingBeforePause = false;
  String? _error;
  int _seekForward = 0;
  int _seekBackward = 0;
  int _loadGeneration = 0;
  Timer? _bufferingTimer;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final generation = ++_loadGeneration;
    final headers = <String, String>{
      'User-Agent': widget.channel.userAgent ?? 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    };
    final referer = widget.channel.referer;
    if (referer != null && referer.isNotEmpty) {
      headers['Referer'] = referer;
    }
    final uri = Uri.tryParse(widget.channel.url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'This channel has an invalid stream URL.';
        });
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: headers,
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    );
    _controller = controller;
    void onControllerUpdate() => _onControllerUpdate(controller);
    _controllerListeners[controller] = onControllerUpdate;
    controller.addListener(onControllerUpdate);
    final initialization = controller.initialize();
    _initializations[controller] = initialization;
    try {
      await initialization.timeout(const Duration(seconds: 30));
      if (!mounted || generation != _loadGeneration) {
        await _releaseController(controller);
        return;
      }
      if (controller.value.hasError) {
        throw StateError(
          controller.value.errorDescription ?? 'Unknown player error',
        );
      }
      await controller.play();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _initializing = false);
    } catch (e) {
      if (generation != _loadGeneration) {
        await _releaseController(controller);
        return;
      }
      await _releaseController(controller);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _initializing = false;
        _error = e is TimeoutException
            ? 'The stream did not start in time. Check your connection and retry.'
            : e is PlatformException && e.message != null
            ? 'Playback failed: ${e.message}'
            : 'Could not start this stream. It may be unavailable or unsupported.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.paused) {
      _wasPlayingBeforePause = controller?.value.isPlaying ?? false;
      if (_wasPlayingBeforePause && controller != null) {
        unawaited(_pausePlayback(controller));
      }
    } else if (state == AppLifecycleState.resumed && _wasPlayingBeforePause) {
      _wasPlayingBeforePause = false;
      if (controller != null) unawaited(_resumePlayback(controller));
    }
  }

  Future<void> _resumePlayback(VideoPlayerController controller) async {
    try {
      await controller.play();
    } catch (error) {
      _showPlaybackError(error.toString());
    }
  }

  Future<void> _pausePlayback(VideoPlayerController controller) async {
    try {
      await controller.pause();
    } catch (error) {
      _showPlaybackError(error.toString());
    }
  }

  void _onControllerUpdate(VideoPlayerController controller) {
    if (!mounted || !identical(controller, _controller)) return;
    final value = controller.value;
    if (value.hasError) {
      _showPlaybackError(value.errorDescription);
      return;
    }
    final isBuffering = value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }
    if (isBuffering) {
      _bufferingTimer ??= Timer(const Duration(seconds: 30), () {
        _showPlaybackError('The stream is stuck buffering. Retry the stream.');
      });
    } else {
      _bufferingTimer?.cancel();
      _bufferingTimer = null;
    }
  }

  void _showPlaybackError(String? description) {
    if (!mounted || _error != null) return;
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
    setState(() {
      _initializing = false;
      _isBuffering = false;
      _error = (description == null || description.isEmpty)
          ? 'Playback failed. Check the stream and retry.'
          : 'Playback failed: $description';
    });
    final controller = _controller;
    if (controller != null) {
      unawaited(_releaseController(controller));
    }
  }

  Future<void> _releaseController(VideoPlayerController controller) async {
    final listener = _controllerListeners.remove(controller);
    if (listener != null) controller.removeListener(listener);
    final initialization = _initializations[controller];
    if (identical(_controller, controller)) {
      _controller = null;
    }
    _initializations.remove(controller);
    await _disposeWhenReady(controller, initialization);
  }

  Future<void> _disposeWhenReady(
    VideoPlayerController controller,
    Future<void>? initialization,
  ) async {
    if (_hasPlatformPlayer(controller)) {
      await controller.dispose();
    } else if (initialization != null) {
      unawaited(
        initialization.then<void>(
          (_) async {
            if (_hasPlatformPlayer(controller)) await controller.dispose();
          },
          onError: (Object _) async {
            if (_hasPlatformPlayer(controller)) await controller.dispose();
          },
        ),
      );
    }
  }

  bool _hasPlatformPlayer(VideoPlayerController controller) {
    // Avoid dispose waiting forever if native player creation failed before it received an ID.
    // ignore: invalid_use_of_visible_for_testing_member
    return controller.playerId >= 0;
  }

  Future<void> _retry() async {
    if (_retrying) return;
    _retrying = true;
    final oldController = _controller;
    ++_loadGeneration;
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
    try {
      if (oldController != null) {
        await _releaseController(oldController);
      }
      if (!mounted) return;
      setState(() {
        _error = null;
        _initializing = true;
        _isBuffering = false;
      });
      await _initPlayer();
    } finally {
      _retrying = false;
    }
  }

  Future<void> _setFullscreen(bool fullscreen) async {
    setState(() => _isFullscreen = fullscreen);
    await SystemChrome.setPreferredOrientations(
      fullscreen
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
    await SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _shareStream() async {
    try {
      await Share.share(
        'Watch ${widget.channel.name}: ${widget.channel.url}',
        subject: widget.channel.name,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to share this stream.')),
        );
      }
    }
  }

  @override
  void dispose() {
    ++_loadGeneration;
    _bufferingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final controller = _controller;
    if (controller != null) {
      _controller = null;
      final listener = _controllerListeners.remove(controller);
      if (listener != null) controller.removeListener(listener);
      final initialization = _initializations.remove(controller);
      unawaited(_disposeWhenReady(controller, initialization));
    }
    for (final pendingController in _controllerListeners.keys.toList()) {
      final listener = _controllerListeners.remove(pendingController)!;
      pendingController.removeListener(listener);
      final initialization = _initializations.remove(pendingController);
      unawaited(_disposeWhenReady(pendingController, initialization));
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _seekBy(Duration duration) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.duration <= Duration.zero) {
      return;
    }
    final newPosition = controller.value.position + duration;
    final clamped = newPosition < Duration.zero
        ? Duration.zero
        : newPosition > controller.value.duration
        ? controller.value.duration
        : newPosition;
    try {
      await controller.seekTo(clamped);
    } catch (error) {
      _showPlaybackError(error.toString());
      return;
    }
    if (!mounted) return;
    setState(() {
      if (duration.isNegative) {
        _seekBackward = duration.inSeconds.abs();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _seekBackward = 0);
        });
      } else {
        _seekForward = duration.inSeconds;
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _seekForward = 0);
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showPlaybackError(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;
    final hasDuration = value != null && value.duration > Duration.zero;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_initializing &&
                _error == null &&
                controller != null &&
                value != null)
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio <= 0
                      ? 16 / 9
                      : value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            if (_initializing)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFE50914)),
                    SizedBox(height: 16),
                    Text(
                      'Loading stream...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            if (_isBuffering && !_initializing)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              ),
            if (_error != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                      ),
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            if (_seekForward > 0)
              const Positioned(
                left: 80,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SeekIndicator(forward: true, seconds: 10),
                ),
              ),
            if (_seekBackward > 0)
              const Positioned(
                right: 80,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SeekIndicator(forward: false, seconds: 10),
                ),
              ),
            if (_showControls && _error == null)
              SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.channel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Share stream',
                            icon: const Icon(Icons.share, color: Colors.white),
                            onPressed: _shareStream,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!_initializing && controller != null && value != null)
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 56,
                            icon: Icon(
                              value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayback,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (!_initializing && controller != null && value != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Column(
                          children: [
                            if (hasDuration)
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(value.position),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 12,
                                            ),
                                        activeTrackColor: const Color(
                                          0xFFE50914,
                                        ),
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: const Color(0xFFE50914),
                                      ),
                                      child: Slider(
                                        value: value.position.inMilliseconds
                                            .clamp(
                                              0,
                                              value.duration.inMilliseconds,
                                            )
                                            .toDouble(),
                                        max: value.duration.inMilliseconds
                                            .toDouble(),
                                        onChanged: (position) {
                                          controller.seekTo(
                                            Duration(
                                              milliseconds: position.toInt(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(value.duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (hasDuration)
                                  IconButton(
                                    tooltip: 'Rewind 10 seconds',
                                    icon: const Icon(
                                      Icons.replay_10,
                                      color: Colors.white,
                                    ),
                                    onPressed: () =>
                                        _seekBy(const Duration(seconds: -10)),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  onPressed: _togglePlayback,
                                ),
                                if (hasDuration)
                                  IconButton(
                                    tooltip: 'Forward 10 seconds',
                                    icon: const Icon(
                                      Icons.forward_10,
                                      color: Colors.white,
                                    ),
                                    onPressed: () =>
                                        _seekBy(const Duration(seconds: 10)),
                                  ),
                                IconButton(
                                  tooltip: _isFullscreen
                                      ? 'Exit fullscreen'
                                      : 'Enter fullscreen',
                                  icon: Icon(
                                    _isFullscreen
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _setFullscreen(!_isFullscreen),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeekIndicator extends StatelessWidget {
  final bool forward;
  final int seconds;

  const _SeekIndicator({required this.forward, required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.forward_10 : Icons.replay_10,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            '$seconds s',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
