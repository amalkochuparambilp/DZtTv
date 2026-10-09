import 'package:flutter/material.dart';
import 'package:iptv_app/models/channel.dart';
import 'package:iptv_app/screens/player_screen.dart';
import 'channel_card.dart';

class ContentRow extends StatelessWidget {
  final String title;
  final List<Channel> channels;
  final bool showRank;

  const ContentRow({
    super.key,
    required this.title,
    required this.channels,
    this.showRank = false,
  });

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: showRank
                      ? _RankedCard(
                          channel: channel,
                          rank: index + 1,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(channel: channel),
                            ),
                          ),
                        )
                      : ChannelCard(
                          channel: channel,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(channel: channel),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RankedCard extends StatelessWidget {
  final Channel channel;
  final int rank;
  final VoidCallback onTap;

  const _RankedCard({
    required this.channel,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 220,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 60,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  height: 0.8,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = Colors.white24,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      channel.logo.isNotEmpty
                          ? Image.network(
                              channel.logo,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                color: const Color(0xFF1A1A2E),
                                child: const Center(
                                  child: Icon(Icons.live_tv, color: Colors.white24),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1A1A2E),
                              child: const Center(
                                child: Icon(Icons.live_tv, color: Colors.white24),
                              ),
                            ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
