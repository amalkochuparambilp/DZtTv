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

      if (line.startsWith('#EXTGRP:')) {
        pendingGroup = line.substring('#EXTGRP:'.length).trim();
        continue;
      }

      if (line.startsWith('#EXTINF')) {
        pendingUserAgent = null;
        pendingReferer = null;
        pendingLogo = _extractAttr(line, 'tvg-logo');
        final groupFromLine = _extractAttr(line, 'group-title') ?? pendingGroup;
        pendingGroup = groupFromLine?.split(';').first.trim();
        pendingUserAgent = _extractAttr(line, 'http-user-agent');
        pendingReferer = _extractAttr(line, 'http-referrer');
        final commaIndex = line.lastIndexOf(',');
        pendingName = commaIndex >= 0 ? line.substring(commaIndex + 1).trim() : 'Unknown';
      } else if (line.startsWith('#EXTVLCOPT:')) {
        final opt = line.substring('#EXTVLCOPT:'.length);
        final eq = opt.indexOf('=');
        if (eq > 0) {
          final key = opt.substring(0, eq).trim().toLowerCase();
          final value = _stripQuotes(opt.substring(eq + 1).trim());
          if (key == 'http-user-agent') pendingUserAgent = value;
          if (key == 'http-referrer') pendingReferer = value;
        }
      } else if (!line.startsWith('#') && pendingName != null) {
        final groupName = pendingGroup;
        channels.add(Channel(
          name: pendingName,
          url: line,
          logo: pendingLogo ?? '',
          group: (groupName == null || groupName.isEmpty)
              ? 'Uncategorized'
              : groupName,
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
    final attrName = attr.toLowerCase();
    final haystack = line.toLowerCase();
    final index = haystack.indexOf('$attrName="');
    if (index >= 0) {
      final start = index + attrName.length + 2;
      final end = line.indexOf('"', start);
      if (end > start) {
        return _stripQuotes(line.substring(start, end));
      }
    }

    final singleQuoteIndex = haystack.indexOf('$attrName=\'');
    if (singleQuoteIndex >= 0) {
      final start = singleQuoteIndex + attrName.length + 2;
      final end = line.indexOf('\'', start);
      if (end > start) {
        return _stripQuotes(line.substring(start, end));
      }
    }

    final bareIndex = haystack.indexOf('$attrName=');
    if (bareIndex >= 0) {
      final start = bareIndex + attrName.length + 1;
      final value = line.substring(start).trim();
      final normalized = value.split(RegExp(r'[\s,]')).firstWhere(
        (segment) => segment.isNotEmpty,
        orElse: () => '',
      );
      if (normalized.isNotEmpty) {
        return _stripQuotes(normalized);
      }
    }

    return null;
  }

  static String _stripQuotes(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2 &&
        ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
            (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }
}
