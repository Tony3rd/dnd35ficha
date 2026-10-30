import 'package:flutter/material.dart';

/// Visual "grimório": tinta escura e pergaminho, vermelho-sangue e ouro velho.
class GrimTheme {
  static const blood = Color(0xFF9E2B25);
  static const gold = Color(0xFFC9A227);
  static const ink = Color(0xFF16130F);
  static const parchment = Color(0xFFF3EBDD);

  static ThemeData build(bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: blood,
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: dark ? const Color(0xFF1C1814) : parchment,
    ).copyWith(
      secondary: gold,
      tertiary: dark ? const Color(0xFF7FA38A) : const Color(0xFF3F6B4C),
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: scheme.brightness);
    return base.copyWith(
      scaffoldBackgroundColor: dark ? ink : const Color(0xFFEDE3D1),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF231E19) : const Color(0xFFFAF5EA),
        elevation: 0,
        margin: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: dark ? const Color(0xFF3A3129) : const Color(0xFFD9CBB1)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(isDense: true, border: OutlineInputBorder()),
      dividerTheme: DividerThemeData(color: dark ? const Color(0xFF3A3129) : const Color(0xFFD9CBB1)),
      visualDensity: VisualDensity.compact,
    );
  }
}
