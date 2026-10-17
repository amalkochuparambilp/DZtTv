import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/services/iptv_service.dart';

void main() {
  group('IptvService.parse', () {
    test('extracts headers, group metadata, and stream attributes from real M3U content', () {
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

    test('falls back to Uncategorized when no group metadata is supplied', () {
      const content = '''
#EXTM3U
#EXTINF:-1 tvg-logo="https://example.com/logo.png",No Group
https://example.com/stream.m3u8
''';

      final channels = IptvService.parse(content);

      expect(channels, hasLength(1));
      expect(channels[0].group, 'Uncategorized');
    });
  });
}
