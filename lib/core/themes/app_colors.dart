import 'package:flutter/material.dart';

/// Paleta de colores centralizada — sincronizada con Front4 (globals.css).
///
/// Cada token aquí se corresponde 1-a-1 con una variable CSS del proyecto web
/// para garantizar coherencia visual entre plataformas.
class AppColors {
  AppColors._(); // No instanciar

  // ── Negros / Fondos ─────────────────────────────────────────────────────
  /// Fondo general de la app — negro profundo para móvil
  static const bg = Color(0xFF0A0A0A);

  /// Fondo de áreas más profundas (modales, appBar)
  static const bgDeep = Color(0xFF0A0A0A);

  /// --gray-darkest: #1a1919  →  Fondo de tarjetas
  static const card = Color(0xFF1A1919);

  /// --gray-darker: #2a2a2a  →  Superficie elevada / inputs / popovers
  static const surface = Color(0xFF2A2A2A);
  static const cardAlt = Color(0xFF2A2A2A);

  /// Fondo para tabs inactivas
  static const tabInactive = Color(0xFF2E2E2E);

  /// --gray-dark: #3a3a3a  →  Bordes, divisores
  static const divider = Color(0xFF3A3A3A);

  /// --gray-medium: #333131  →  Fondo secundario, switches
  static const greyMedium = Color(0xFF333131);

  // ── Grises / Texto secundario ───────────────────────────────────────────
  /// --gray-light: #888888  →  Texto terciario, íconos deshabilitados
  static const grey = Color(0xFF888888);

  /// --gray-lighter: #b0b0b0  →  Texto secundario
  static const greyLight = Color(0xFFB0B0B0);

  /// --gray-lightest: #d0d0d0  →  Texto de párrafo
  static const greyLightest = Color(0xFFD0D0D0);

  // ── Dorado / Acento principal ───────────────────────────────────────────
  /// --orange-primary: #d8b081  →  Color primario (botones, acentos)
  static const gold = Color(0xFFD8B081);

  /// Variante clara del dorado para gradientes
  static const goldLight = Color(0xFFE0C080);

  /// Variante intermedia del dorado para gradientes
  static const goldMid = Color(0xFFC9A96E);

  /// --orange-darker: #c4a06d  →  Hover / estados presionados
  static const goldDark = Color(0xFFC4A06D);

  /// Tono oscuro del dorado para inicio de gradientes
  static const goldDeep = Color(0xFF9A7040);

  // ── Blancos ─────────────────────────────────────────────────────────────
  /// --white-primary: #FFFFFF
  static const white = Color(0xFFFFFFFF);

  /// --white-secondary: #F5F5F5
  static const whiteSecondary = Color(0xFFF5F5F5);

  // ── Estados / Semáforo ──────────────────────────────────────────────────
  /// --destructive: #DC2626
  static const red = Color(0xFFDC2626);
  static const redDark = Color(0xFF8B1A1A);
  static const green = Color(0xFF4CAF7D);

  // ── Inputs ──────────────────────────────────────────────────────────────
  /// Fondo de campos de texto
  static const inputBg = Color(0xFF1C1C1C);

  /// Borde de campos de texto  (≈ --gray-dark)
  static const inputBorder = Color(0xFF3A3A3A);

  // ── Gradiente Premium Gold (reutilizable) ──────────────────────────────
  static const goldGradient = LinearGradient(
    colors: [goldDeep, goldMid, goldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
