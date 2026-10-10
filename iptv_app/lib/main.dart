import 'package:flutter/material.dart';
import 'package:iptv_app/screens/home_screen.dart';
import 'package:iptv_app/screens/splash_screen.dart';

void main() {
  runApp(const DevZoftIptvApp());
}

class DevZoftIptvApp extends StatelessWidget {
  const DevZoftIptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DZt Tv',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          surface: Color(0xFF0A0A0F),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
