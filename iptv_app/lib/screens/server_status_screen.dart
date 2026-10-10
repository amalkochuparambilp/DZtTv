import 'package:flutter/material.dart';

class ServerStatusScreen extends StatefulWidget {
  const ServerStatusScreen({super.key});

  @override
  State<ServerStatusScreen> createState() => _ServerStatusScreenState();
}

class _ServerStatusScreenState extends State<ServerStatusScreen> {
  final List<Map<String, dynamic>> _servers = [
    {
      'name': 'Pluto TV',
      'url': 'https://images.pluto.tv/channels/62ba60f059624e000781c436/colorLogoPNG.png',
      'status': 'online',
      'latency': 120,
      'bitrate': '2.5 Mbps',
      'uptime': '99.9%',
    },
    {
      'name': 'Dash2 Antik',
      'url': 'https://i.imgur.com/LOY0rtp.png',
      'status': 'online',
      'latency': 85,
      'bitrate': '3.2 Mbps',
      'uptime': '98.5%',
    },
    {
      'name': 'Akamai',
      'url': 'https://2gblive.akamaized.net/hls/live/2033805/2GB/index.m3u8',
      'status': 'warning',
      'latency': 200,
      'bitrate': '1.8 Mbps',
      'uptime': '95.2%',
    },
    {
      'name': 'Backup Server',
      'url': 'https://jmp2.uk/plu-62ba60f059624e000781c436.m3u8',
      'status': 'offline',
      'latency': 0,
      'bitrate': 'N/A',
      'uptime': '0.0%',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Server Status Monitor'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _refreshServers(),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _servers.length,
        itemBuilder: (context, index) {
          final server = _servers[index];
          return _buildServerCard(server, index);
        },
      ),
    );
  }

  Widget _buildServerCard(Map<String, dynamic> server, int index) {
    final statusColor = server['status'] == 'online'
        ? const Color(0xFF4CAF50)
        : server['status'] == 'warning'
            ? const Color(0xFFFF9800)
            : const Color(0xFFF44336);
    final statusIcon = server['status'] == 'online'
        ? Icons.check_circle
        : server['status'] == 'warning'
            ? Icons.warning
            : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        server['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          server['status'].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusInfo(Icons.speed, 'Latency: ${server['latency']}ms'),
                      const SizedBox(width: 12),
                      _buildStatusInfo(Icons.upload_file, 'Bitrate: ${server['bitrate']}'),
                      const SizedBox(width: 12),
                      _buildStatusInfo(Icons.timeline, 'Uptime: ${server['uptime']}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: server['status'] == 'online'
                        ? 1.0
                        : server['status'] == 'warning'
                            ? 0.5
                            : 0.0,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  void _refreshServers() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing server status...'),
        backgroundColor: Color(0xFFE50914),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _servers[3]['status'] = 'online';
        _servers[3]['latency'] = 150;
        _servers[3]['bitrate'] = '2.0 Mbps';
        _servers[3]['uptime'] = '99.8%';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server status updated!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    });
  }
}
