import 'package:flutter/material.dart';

ThemeData lightmode = ThemeData(
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    background: Color(0xFFF6FBFF),      // Azzurro molto chiaro
    primary: Color(0xFF4FC3F7),         // Azzurro medio
    secondary: Color(0xFF81D4FA),       // Azzurro chiaro
    surface: Color(0xFFE3F2FD),         // Superfici azzurre chiare
    onBackground: Color(0xFF1976D2),    // Blu più chiaro per testo su sfondo
    onPrimary: Color(0xFFFFFFFF),       // Testo su button primary
    onSecondary: Color(0xFF1976D2),     // Testo su secondary, blu chiaro
    onSurface: Color(0xFF1976D2),       // Testo su card, blu chiaro
    error: Colors.red,
  ),
);

ThemeData darkmode = ThemeData(
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
  ),
);
