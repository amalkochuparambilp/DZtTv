import 'package:flutter/material.dart';
import 'package:iptv_app/models/channel.dart';
import 'package:iptv_app/services/iptv_service.dart';
import 'search_screen.dart';
import 'package:iptv_app/widgets/content_row.dart';
import 'package:iptv_app/widgets/hero_carousel.dart';
import 'package:iptv_app/widgets/skeleton_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Channel> _all = [];
  List<Channel> _featured = [];
  Map<String, List<Channel>> _grouped = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final channels = await IptvService.fetchChannels();
      final grouped = <String, List<Channel>>{};
      for (final c in channels) {
        grouped.putIfAbsent(c.group, () => []).add(c);
      }
      final sortedGroups = grouped.keys.toList()
        ..sort((a, b) => grouped[b]!.length.compareTo(grouped[a]!.length));
      setState(() {
        _all = channels;
        _featured = channels.where((c) => c.logo.isNotEmpty).take(10).toList();
        _grouped = {for (final g in sortedGroups) g: grouped[g]!};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: _loading
          ? const SkeletonLoading()
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.wifi_off, size: 48, color: Colors.white24),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load channels',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: HeroCarousel(channels: _featured)),
            if (_all.isNotEmpty)
              SliverToBoxAdapter(
                child: ContentRow(
                  title: 'Top 10 Channels',
                  channels: _all.take(10).toList(),
                  showRank: true,
                ),
              ),
            for (final entry in _grouped.entries)
              SliverToBoxAdapter(
                child: ContentRow(title: entry.key, channels: entry.value),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A0A0F).withValues(alpha: 0.95),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                      ).createShader(bounds),
                      child: const Text(
                        'DZt Tv',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchScreen(allChannels: _all),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      onPressed: () => showAboutDialog(
                        context: context,
                        applicationName: 'DZt Tv',
                        applicationVersion: '1.0.0',
                        applicationLegalese: 'Developed by DevZoft Amal K P',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
