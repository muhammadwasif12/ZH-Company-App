import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system using Outfit font — Premium Dark Tech
class AppTypography {
  AppTypography._();

  static TextStyle get _baseStyle => GoogleFonts.outfit();

  // ─── Display ──────────────────────────────────────────
  static TextStyle displayLarge = _baseStyle.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle displayMedium = _baseStyle.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.2,
  );

  // ─── Headings ─────────────────────────────────────────
  static TextStyle h1 = _baseStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static TextStyle h2 = _baseStyle.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static TextStyle h3 = _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static TextStyle h4 = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ─── Body ─────────────────────────────────────────────
  static TextStyle bodyLarge = _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle body = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle bodySmall = _baseStyle.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ─── Caption / Label ──────────────────────────────────
  static TextStyle caption = _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle label = _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static TextStyle labelLarge = _baseStyle.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.4,
  );

  // ─── Button ───────────────────────────────────────────
  static TextStyle button = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  static TextStyle buttonSmall = _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  // ─── Mono (for codes, IDs) ────────────────────────────
  static TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle monoSmall = GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
}
