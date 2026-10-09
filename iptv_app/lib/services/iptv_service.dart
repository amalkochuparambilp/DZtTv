import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class IptvService {
  static const String _encodedUrl =
      'aHR0cHM6Ly9pcHR2LW9yZy5naXRodWIuaW8vaXB0di9pbmRleC5tM3U=';

  static String get _playlistUrl => utf8.decode(base64.decode(_encodedUrl));

  static Future<List<Channel>> fetchChannels() async {
    final response = await http.get(Uri.parse(_playlistUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load playlist: ${response.statusCode}');
    }
    return parse(response.body);
  }

  static List<Channel> parse(String content) {
    final channels = <Channel>[];
    final lines = content.split('\n');
    String? pendingName;
    String? pendingLogo;
    String? pendingGroup;
    String? pendingUserAgent;
    String? pendingReferer;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        pendingUserAgent = null;
        pendingReferer = null;
        pendingLogo = _extractAttr(line, 'tvg-logo');
        pendingGroup = _extractAttr(line, 'group-title')?.split(';').first.trim();
        pendingUserAgent = _extractAttr(line, 'http-user-agent');
        pendingReferer = _extractAttr(line, 'http-referrer');
        final commaIndex = line.lastIndexOf(',');
        pendingName = commaIndex >= 0 ? line.substring(commaIndex + 1).trim() : 'Unknown';
      } else if (line.startsWith('#EXTVLCOPT:')) {
        final opt = line.substring('#EXTVLCOPT:'.length);
        final eq = opt.indexOf('=');
        if (eq > 0) {
          final key = opt.substring(0, eq).trim().toLowerCase();
          final value = opt.substring(eq + 1).trim();
          if (key == 'http-user-agent') pendingUserAgent = value;
          if (key == 'http-referrer') pendingReferer = value;
        }
      } else if (!line.startsWith('#') && pendingName != null) {
        channels.add(Channel(
          name: pendingName,
          url: line,
          logo: pendingLogo ?? '',
          group: (pendingGroup == null || pendingGroup.isEmpty) ? 'Uncategorized' : pendingGroup,
          userAgent: pendingUserAgent,
          referer: pendingReferer,
        ));
        pendingName = null;
        pendingLogo = null;
        pendingGroup = null;
        pendingUserAgent = null;
        pendingReferer = null;
      }
    }
    return channels;
  }

  static String? _extractAttr(String line, String attr) {
    final index = line.indexOf('$attr="');
    if (index < 0) return null;
    final start = index + attr.length + 2;
    final end = line.indexOf('"', start);
    if (end < 0) return null;
    return line.substring(start, end);
  }
}
