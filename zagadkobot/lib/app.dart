import 'package:flutter/material.dart';
import 'package:zagadkobot/core/theme.dart';
import 'package:zagadkobot/features/home/home_screen.dart';

class ZagadkobotApp extends StatelessWidget {
  const ZagadkobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zagadkobot',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
