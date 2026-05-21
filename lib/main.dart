import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const SteamStatsApp());
}

class SteamStatsApp extends StatelessWidget {
  const SteamStatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steam Stats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}