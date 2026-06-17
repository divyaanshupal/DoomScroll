import 'package:distract/dashboard.dart';
import 'package:distract/splash.dart';
import 'package:flutter/material.dart';

void main() {
  runApp( MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: SplashScreen(
        onDone: () {
          _navigatorKey.currentState?.pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        },
      ),
    );
  }
}
