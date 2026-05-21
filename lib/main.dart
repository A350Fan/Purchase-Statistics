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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101418),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A2027),
          elevation: 0,
          margin: EdgeInsets.symmetric(vertical: 4),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101418),
          foregroundColor: Color(0xFFE7ECEF),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF151B21),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1A2027)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
