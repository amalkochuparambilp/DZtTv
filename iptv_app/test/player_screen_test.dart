import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/models/channel.dart';
import 'package:iptv_app/screens/player_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as platform;

void main() {
  late platform.VideoPlayerPlatform originalPlatform;
  late _FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    originalPlatform = platform.VideoPlayerPlatform.instance;
  });

  tearDown(() {
    platform.VideoPlayerPlatform.instance = originalPlatform;
  });

  Future<void> pumpPlayer(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          channel: Channel(
            name: 'Test Channel',
            url: 'https://example.com/live.m3u8',
            logo: '',
            group: 'Test',
          ),
        ),
      ),
    );
    for (var index = 0; index < 30; index++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('LIVE').evaluate().isNotEmpty ||
          find.byType(Slider).evaluate().isNotEmpty ||
          find.text('Retry').evaluate().isNotEmpty) {
        break;
      }
    }
  }

  testWidgets('shows a LIVE timeline for streams with unknown duration', (
    tester,
  ) async {
    fakePlatform = _FakeVideoPlayerPlatform(duration: Duration.zero);
    platform.VideoPlayerPlatform.instance = fakePlatform;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await pumpPlayer(tester);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byTooltip('Exit fullscreen'), findsOneWidget);

    await tester.tap(find.byTooltip('Exit fullscreen'));
    await tester.pump();
    expect(find.byTooltip('Enter fullscreen'), findsOneWidget);
  });

  testWidgets('shows playback errors and recovers on retry without leaking', (
    tester,
  ) async {
    fakePlatform = _FakeVideoPlayerPlatform(
      duration: const Duration(minutes: 1),
    );
    platform.VideoPlayerPlatform.instance = fakePlatform;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await pumpPlayer(tester);
    fakePlatform.emitError(
      1,
      PlatformException(code: 'stream-error', message: 'decoder failed'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Playback failed: decoder failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text('Retry'));
    await tester.pump();
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Retry'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(fakePlatform.createdPlayers, 2);
  });

  testWidgets('shows buffering state and clears it after buffering ends', (
    tester,
  ) async {
    fakePlatform = _FakeVideoPlayerPlatform(
      duration: const Duration(minutes: 1),
    );
    platform.VideoPlayerPlatform.instance = fakePlatform;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await pumpPlayer(tester);
    fakePlatform.emit(
      1,
      platform.VideoEvent(eventType: platform.VideoEventType.bufferingStart),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fakePlatform.emit(
      1,
      platform.VideoEvent(eventType: platform.VideoEventType.bufferingEnd),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shares the selected stream', (tester) async {
    fakePlatform = _FakeVideoPlayerPlatform(
      duration: const Duration(minutes: 1),
    );
    platform.VideoPlayerPlatform.instance = fakePlatform;
    final shareChannel = const MethodChannel('dev.fluttercommunity.plus/share');
    Map<dynamic, dynamic>? sharedArguments;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (call) async {
        sharedArguments = call.arguments as Map<dynamic, dynamic>;
        return 'success';
      },
    );
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        null,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await pumpPlayer(tester);
    await tester.tap(find.byTooltip('Share stream'));
    await tester.pump();

    expect(sharedArguments?['text'], contains('Test Channel'));
    expect(sharedArguments?['text'], contains('https://example.com/live.m3u8'));
  });
}

class _FakeVideoPlayerPlatform extends platform.VideoPlayerPlatform {
  _FakeVideoPlayerPlatform({required this.duration});

  final Duration duration;
  int createdPlayers = 0;
  int disposedPlayers = 0;
  int _nextId = 0;
  final Map<int, StreamController<platform.VideoEvent>> _eventControllers = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<int?> createWithOptions(platform.VideoCreationOptions options) async {
    createdPlayers++;
    final id = ++_nextId;
    _eventControllers[id] = StreamController<platform.VideoEvent>.broadcast();
    return id;
  }

  @override
  Stream<platform.VideoEvent> videoEventsFor(int playerId) async* {
    yield platform.VideoEvent(
      eventType: platform.VideoEventType.initialized,
      duration: duration,
      size: const Size(1280, 720),
    );
    yield* _eventControllers[playerId]!.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposedPlayers++;
    await _eventControllers.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(platform.VideoViewOptions options) {
    return const SizedBox.expand();
  }

  void emit(int playerId, platform.VideoEvent event) {
    _eventControllers[playerId]!.add(event);
  }

  void emitError(int playerId, Object error) {
    final events = _eventControllers[playerId]!;
    events.addError(error);
    unawaited(events.close());
  }
}
