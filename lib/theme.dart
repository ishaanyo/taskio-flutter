import 'package:flutter/material.dart';

const taskioRed = Color(0xFFDB4C3F);
const ink = Color(0xFF202020);
const sidebar = Color(0xFFF6F4F1);

ThemeData taskioTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: taskioRed, primary: taskioRed),
    scaffoldBackgroundColor: const Color(0xFFFAF9F7),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFAF9F7),
      foregroundColor: ink,
      elevation: 0,
    ),
  );
}

Color priorityColor(int priority) {
  switch (priority) {
    case 4:
      return const Color(0xFFD1453B);
    case 3:
      return const Color(0xFFEB8909);
    case 2:
      return const Color(0xFF246FE0);
    default:
      return const Color(0xFF666666);
  }
}

Color parseHex(String hex) {
  final value = hex.replaceAll('#', '');
  return Color(int.parse('FF$value', radix: 16));
}
