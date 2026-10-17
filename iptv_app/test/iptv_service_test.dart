import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_app/services/iptv_service.dart';

void main() {
  group('IptvService.parse', () {
    test('extracts headers, group metadata, and stream attributes', () {
      const content = '''
#EXTM3U
#EXTGRP:Movies
#EXTINF:-1 tvg-logo='https://example.com/logo.png' group-title="Movies" http-user-agent="Mozilla/5.0" http-referrer="https://example.com/" ,Movie One
https://example.com/stream-1.m3u8
#EXTINF:-1 tvg-logo="https://example.com/logo2.png" group-title=News,News Channel
https://example.com/stream-2.m3u8
''';

      final channels = IptvService.parse(content);

      expect(channels, hasLength(2));
      expect(channels[0].name, 'Movie One');
      expect(channels[0].group, 'Movies');
      expect(channels[0].logo, 'https://example.com/logo.png');
      expect(channels[0].userAgent, 'Mozilla/5.0');
      expect(channels[0].referer, 'https://example.com/');
      expect(channels[1].name, 'News Channel');
      expect(channels[1].group, 'News');
    });

    test('accepts a BOM and CRLF line endings', () {
      const content =
          '\uFEFF#EXTM3U\r\n#EXTINF:-1,Channel\r\nhttps://example.com/live\r\n';

      expect(IptvService.parse(content).single.name, 'Channel');
    });

    test('skips invalid stream URLs when valid channels are present', () {
      const content = '''
#EXTM3U
#EXTINF:-1,Invalid
javascript:alert(1)
#EXTINF:-1,Valid
https://example.com/live
''';

      final channels = IptvService.parse(content);

      expect(channels, hasLength(1));
      expect(channels.single.name, 'Valid');
    });

    test('reports a missing M3U header', () {
      expect(
        () => IptvService.parse('#EXTINF:-1,Channel\nhttps://example.com'),
        throwsA(
          isA<PlaylistException>().having(
            (error) => error.message,
            'message',
            contains('#EXTM3U'),
          ),
        ),
      );
    });

    test('reports playlists without valid streams', () {
      expect(
        () => IptvService.parse('#EXTM3U\n#EXTINF:-1,Channel\nnot a URL\n'),
        throwsA(
          isA<PlaylistException>().having(
            (error) => error.message,
            'message',
            contains('no valid HTTP or HTTPS streams'),
          ),
        ),
      );
    });

    test('falls back to Uncategorized when no group metadata is supplied', () {
      const content = '''
#EXTM3U
#EXTINF:-1 tvg-logo="https://example.com/logo.png",No Group
https://example.com/stream.m3u8
''';

      expect(IptvService.parse(content).single.group, 'Uncategorized');
    });
  });

  group('IptvService.fetchChannels', () {
    test('parses a successful network response', () async {
      final client = _FakeClient(
        (_) async => _response(
          200,
          '#EXTM3U\n#EXTINF:-1,Channel\nhttps://example.com/live\n',
        ),
      );

      final channels = await IptvService.fetchChannels(client: client);

      expect(channels.single.name, 'Channel');
      expect(client.requestCount, 1);
      expect(client.wasClosed, isFalse);
    });

    test('reports HTTP errors clearly', () async {
      final client = _FakeClient((_) async => _response(503, 'Unavailable'));

      await expectLater(
        IptvService.fetchChannels(client: client),
        throwsA(
          isA<PlaylistException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 503'),
          ),
        ),
      );
    });

    test('reports network failures clearly', () async {
      final client = _FakeClient((_) async {
        throw http.ClientException('connection refused');
      });

      await expectLater(
        IptvService.fetchChannels(client: client),
        throwsA(
          isA<PlaylistException>().having(
            (error) => error.message,
            'message',
            contains('connection refused'),
          ),
        ),
      );
    });

    test('times out stalled playlist requests', () async {
      final client = _FakeClient(
        (_) => Completer<http.StreamedResponse>().future,
      );

      await expectLater(
        IptvService.fetchChannels(
          client: client,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(
          isA<PlaylistException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });
}

http.StreamedResponse _response(int statusCode, String body) {
  return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;
  var requestCount = 0;
  var wasClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requestCount++;
    return _handler(request);
  }

  @override
  void close() {
    wasClosed = true;
  }
}
