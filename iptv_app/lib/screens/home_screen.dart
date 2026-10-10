import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/iptv_service.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'about_screen.dart';
import 'server_status_screen.dart';
import 'quick_settings_screen.dart';
import 'widgets/channel_card.dart';
import 'widgets/content_row.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/skeleton_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
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
    final pages = [
      _buildHomeContent(),
      const SearchScreen(allChannels: []),
      const ServerStatusScreen(),
      const QuickSettingsScreen(),
      const AboutScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: const Color(0xFF0A0A0F),
        selectedItemColor: const Color(0xFFE50914),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor),
            label: 'Server',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'About',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
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
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
                      onPressed: () => setState(() => _selectedIndex = 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      onPressed: () => setState(() => _selectedIndex = 4),
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
