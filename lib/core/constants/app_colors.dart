import 'package:flutter/material.dart';

/// Beon Cosmetic — Ultra-Premium Dark Tech Color System
class AppColors {
  AppColors._();

  // ─── Base Surfaces ─────────────────────────────────────
  static const Color background = Color(0xFF07090E); // Deep midnight tech slate
  static const Color surface = Color(0xFF0F131D); // Glassmorphic card surface
  static const Color surfaceVariant = Color(
    0xFF161B28,
  ); // Elevated container fill
  static const Color surfaceHover = Color(0xFF1E2538); // Hover highlight state
  static const Color surfaceBright = Color(
    0xFF262E44,
  ); // Active input & modal background

  // ─── Borders ──────────────────────────────────────────
  static const Color border = Color(0xFF1F2A3E); // Precision card border
  static const Color borderLight = Color(
    0xFF2D3B57,
  ); // Secondary divider border
  static const Color borderHover = Color(
    0xFF3E5075,
  ); // Interactive hover border

  // ─── Text Hierarchy ───────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9); // High contrast white
  static const Color textSecondary = Color(0xFF94A3B8); // Muted subtext
  static const Color textTertiary = Color(0xFF64748B); // De-emphasized details
  static const Color textMuted = Color(0xFF475569); // Subtle placeholder

  // ─── Brand Accents ────────────────────────────────────
  static const Color primary = Color(0xFF6366F1); // Vibrant Electric Indigo
  static const Color primaryHover = Color(0xFF818CF8); // Bright Violet Glow
  static const Color primaryMuted = Color(0xFF312E81); // Deep Accent Background
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan Highlight
  static const Color accentPurple = Color(0xFFA855F7); // Neon Purple

  // ─── Status Colors ────────────────────────────────────
  static const Color pending = Color(0xFFF59E0B); // Amber Gold
  static const Color confirmed = Color(0xFF3B82F6); // Royal Blue
  static const Color dispatched = Color(0xFFA855F7); // Neon Purple
  static const Color inTransit = Color(0xFF06B6D4); // Electric Cyan
  static const Color delivered = Color(0xFF10B981); // Emerald Green
  static const Color returned = Color(0xFFEF4444); // Vibrant Crimson
  static const Color cancelled = Color(0xFF64748B); // Slate Muted
  static const Color hold = Color(0xFFF97316); // Bright Orange

  // ─── Status Backgrounds (Soft Muted Fill) ─────────────
  static const Color pendingBg = Color(0xFF261D0C);
  static const Color confirmedBg = Color(0xFF0D1B36);
  static const Color dispatchedBg = Color(0xFF211036);
  static const Color inTransitBg = Color(0xFF0A2230);
  static const Color deliveredBg = Color(0xFF0B291E);
  static const Color returnedBg = Color(0xFF331416);
  static const Color cancelledBg = Color(0xFF161B28);
  static const Color holdBg = Color(0xFF2E170A);

  // ─── Semantic ─────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Chart Palette ────────────────────────────────────
  static const List<Color> chartPalette = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFA855F7),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
  ];

  // ─── Sidebar ──────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF0B0E16);
  static const Color sidebarItemHover = Color(0xFF161C2A);
  static const Color sidebarItemActive = Color(0xFF1E2638);
  static const Color sidebarDivider = Color(0xFF1A2232);
}
