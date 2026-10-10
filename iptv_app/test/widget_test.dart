import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows branding and navigates home',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const Scaffold(body: Text('home')),
        },
      ),
    );

    expect(find.text('DZt Tv'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
