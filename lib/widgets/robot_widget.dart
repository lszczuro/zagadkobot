import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class RobotWidget extends StatelessWidget {
  const RobotWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/lottie/bot.json',
      fit: BoxFit.contain,
      repeat: true,
    );
  }
}
