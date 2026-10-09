import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:iptv_app/models/channel.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _initializing = true;
  bool _showControls = true;
  bool _isBuffering = false;
  String? _error;
  int _seekForward = 0;
  int _seekBackward = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final headers = <String, String>{
      'User-Agent': widget.channel.userAgent ??
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    };
    if (widget.channel.referer != null) {
      headers['Referer'] = widget.channel.referer!;
    }
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
      httpHeaders: headers,
    );
    _controller.addListener(_onControllerUpdate);
    try {
      await _controller.initialize();
      _controller.play();
      setState(() => _initializing = false);
    } catch (e) {
      setState(() {
        _initializing = false;
        _error = 'Could not load stream';
      });
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final isBuffering = _controller.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
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

  void _seekBy(Duration duration) {
    final newPosition = _controller.value.position + duration;
    final clamped = newPosition < Duration.zero
        ? Duration.zero
        : newPosition > _controller.value.duration
            ? _controller.value.duration
            : newPosition;
    _controller.seekTo(clamped);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_initializing && _error == null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio == 0
                      ? 16 / 9
                      : _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            if (_initializing)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFE50914)),
                    SizedBox(height: 16),
                    Text('Loading stream...',
                        style: TextStyle(color: Colors.white54)),
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
                    const Icon(Icons.error_outline, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE50914)),
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _initializing = true;
                        });
                        _controller.dispose();
                        _initPlayer();
                      },
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back',
                          style: TextStyle(color: Colors.white54)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                            icon: const Icon(Icons.cast, color: Colors.white),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!_initializing)
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 56,
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _controller.value.isPlaying
                                    ? _controller.pause()
                                    : _controller.play();
                              });
                            },
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (!_initializing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_controller.value.position),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 12,
                                      ),
                                      activeTrackColor: const Color(0xFFE50914),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: const Color(0xFFE50914),
                                    ),
                                    child: Slider(
                                      value: _controller.value.position
                                          .inMilliseconds
                                          .clamp(
                                            0,
                                            _controller.value.duration
                                                .inMilliseconds
                                                .toDouble(),
                                          )
                                          .toDouble(),
                                      max: _controller.value.duration.inMilliseconds
                                          .toDouble(),
                                      onChanged: (v) {
                                        _controller.seekTo(
                                          Duration(milliseconds: v.toInt()),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(_controller.value.duration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.replay_10,
                                      color: Colors.white),
                                  onPressed: () => _seekBy(const Duration(seconds: -10)),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _controller.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _controller.value.isPlaying
                                          ? _controller.pause()
                                          : _controller.play();
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.forward_10,
                                      color: Colors.white),
                                  onPressed: () => _seekBy(const Duration(seconds: 10)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_up,
                                      color: Colors.white),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fullscreen,
                                      color: Colors.white),
                                  onPressed: () {},
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
