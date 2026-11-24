import 'package:flutter/material.dart';
import 'cores.dart';

/// Configuração do ThemeData da aplicação conforme as seções 3 a 6 do guia de design.
class TemaApp {
  static ThemeData get tema {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    return base.copyWith(
      scaffoldBackgroundColor: CoresApp.bg,
      colorScheme: const ColorScheme.light(
        primary: CoresApp.orange500,
        onPrimary: CoresApp.ink, // WCAG 5,91:1 - NUNCA branco sobre orange-500
        secondary: CoresApp.orange700,
        onSecondary: CoresApp.surface,
        surface: CoresApp.surface,
        onSurface: CoresApp.ink,
        error: CoresApp.error,
        onError: CoresApp.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CoresApp.bg,
        foregroundColor: CoresApp.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: CoresApp.ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: CoresApp.ink,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: CoresApp.ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: CoresApp.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: CoresApp.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: CoresApp.ink,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: CoresApp.inkSoft,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: CoresApp.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CoresApp.surface,
        indicatorColor: CoresApp.orange100,
        elevation: 2,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: CoresApp.orange700, size: 26);
          }
          return const IconThemeData(color: CoresApp.inkSoft, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: CoresApp.orange700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            color: CoresApp.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CoresApp.orange500,
          foregroundColor: CoresApp.ink,
          disabledBackgroundColor: CoresApp.disabledBg,
          disabledForegroundColor: CoresApp.disabled,
          minimumSize: const Size(48, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: CoresApp.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: CoresApp.line, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CoresApp.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CoresApp.lineStrong, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CoresApp.lineStrong, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CoresApp.orange800, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CoresApp.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: CoresApp.inkSoft),
        hintStyle: const TextStyle(color: CoresApp.disabled),
      ),
    );
  }
}
