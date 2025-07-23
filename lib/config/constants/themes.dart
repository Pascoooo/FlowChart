import 'package:flutter/material.dart';

// Palette di colori personalizzata
class AppColors {
  // Colori principali per light mode
  static const Color primaryBlue = Color(0xFF03256C);
  static const Color secondaryBlue = Color(0xFF2541B2);
  static const Color accent = Color(0xFF06BEE1);
  static const Color lightBlue = Color(0xFF1768AC);

  // Colori neutri per il tema chiaro
  static const Color lightBackground = Color(0xFFFCFCFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF5F7FA);
  static const Color lightBorder = Color(0xFFE5E9F0);
}

ThemeData lightmode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,

  colorScheme: const ColorScheme.light(
    primary: AppColors.primaryBlue,
    secondary: AppColors.secondaryBlue,
    tertiary: AppColors.accent,
    surface: AppColors.lightSurface,
    surfaceVariant: AppColors.lightSurfaceVariant,
    background: AppColors.lightBackground,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    onSurface: AppColors.primaryBlue,
    onBackground: AppColors.primaryBlue,
    outline: AppColors.lightBorder,
    shadow: Colors.black12,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightBackground,
    foregroundColor: AppColors.primaryBlue,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: AppColors.primaryBlue,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: AppColors.primaryBlue),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 2,
      shadowColor: AppColors.primaryBlue.withOpacity(0.3),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryBlue,
      side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      backgroundColor: AppColors.lightSurface,
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.secondaryBlue,
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
    ),
    labelStyle: const TextStyle(
      color: AppColors.secondaryBlue,
      fontSize: 16,
    ),
    prefixIconColor: AppColors.secondaryBlue,
    suffixIconColor: AppColors.secondaryBlue,
  ),

  dividerTheme: const DividerThemeData(
    color: AppColors.lightBorder,
    thickness: 1,
  ),

  cardTheme: CardTheme(
    color: AppColors.lightSurface,
    elevation: 2,
    shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.lightBorder, width: 0.5),
    ),
  ),

  scaffoldBackgroundColor: AppColors.lightBackground,
);

// Dark mode con colori delle label più chiari
ThemeData darkmode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    background: Color(0xFF181818),      // Grigio scuro
    primary: Color(0xFF06BEE1),         // Testo principale
    secondary: Color(0xFF1768AC),       // Link, accent secondario
    surface: Color(0xFF222222),         // Card / fondo più chiaro
    onBackground: Color(0xFF06BEE1),    // Testo su sfondo
    onPrimary: Color(0xFF181818),       // Testo su button primary
    onSecondary: Color(0xFF181818),     // Testo su secondary
    onSurface: Color(0xFF06BEE1),       // Testo su card
    error: Colors.red,
    outline: Color(0xFF333333),         // Bordi sottili
    shadow: Colors.black54,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF181818),
    foregroundColor: Color(0xFF06BEE1),
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: Color(0xFF06BEE1),
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: Color(0xFF06BEE1)),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF06BEE1),
      foregroundColor: const Color(0xFF181818),
      elevation: 2,
      shadowColor: const Color(0xFF06BEE1).withOpacity(0.3),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF06BEE1),
      side: const BorderSide(color: Color(0xFF333333), width: 1.5),
      backgroundColor: const Color(0xFF222222),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  // TextButton con colore più chiaro per "Problemi con l'accesso"
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF06BEE1), // Azzurro più chiaro per migliore leggibilità
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),

  // InputDecoration con label più chiare
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF222222),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF333333)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF333333)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF06BEE1), width: 2),
    ),
    // Label più chiare per "Email" e "Password"
    labelStyle: const TextStyle(
      color: Color(0xFF06BEE1), // Azzurro molto più chiaro per le label
      fontSize: 16,
    ),
    prefixIconColor: const Color(0xFF06BEE1), // Icone più chiare
    suffixIconColor: const Color(0xFF06BEE1), // Icone più chiare
  ),

  dividerTheme: const DividerThemeData(
    color: Color(0xFF333333),
    thickness: 1,
  ),

  cardTheme: CardTheme(
    color: const Color(0xFF222222),
    elevation: 2,
    shadowColor: Colors.black54,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF333333), width: 0.5),
    ),
  ),

  scaffoldBackgroundColor: const Color(0xFF181818),
);