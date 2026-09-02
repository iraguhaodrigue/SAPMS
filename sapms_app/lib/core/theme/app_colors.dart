import 'package:flutter/material.dart';

/// =======================================================
/// SAPMS Secure Color Palette
/// Version: 1.0.0
/// =======================================================

class AppColors {
  AppColors._();

  // =========================
  // Brand Colors
  // =========================

  static const Color primary = Color(0xFF0F6D3C);

  static const Color secondary = Color(0xFF1565C0);

  static const Color accent = Color(0xFF26A69A);

  // =========================
  // Status Colors
  // =========================

  static const Color success = Color(0xFF2E7D32);

  static const Color warning = Color(0xFFF9A825);

  static const Color danger = Color(0xFFD32F2F);

  static const Color info = Color(0xFF0288D1);

  // =========================
  // Background
  // =========================

  static const Color background = Color(0xFFF5F7FA);

  static const Color surface = Colors.white;

  static const Color scaffold = Color(0xFFF7F8FA);

  // =========================
  // Text
  // =========================

  static const Color textPrimary = Color(0xFF1F2937);

  static const Color textSecondary = Color(0xFF6B7280);

  static const Color textLight = Color(0xFFFFFFFF);

  // =========================
  // Borders
  // =========================

  static const Color border = Color(0xFFE5E7EB);

  static const Color divider = Color(0xFFEEEEEE);

  // =========================
  // Dashboard Cards
  // =========================

  static const Color cardBlue = Color(0xFF1976D2);

  static const Color cardGreen = Color(0xFF2E7D32);

  static const Color cardOrange = Color(0xFFF57C00);

  static const Color cardPurple = Color(0xFF7B1FA2);

  static const Color cardRed = Color(0xFFD32F2F);

  // =========================
  // Attendance
  // =========================

  static const Color present = success;

  static const Color absent = danger;

  static const Color late = warning;

  // =========================
  // Analytics
  // =========================

  static const List<Color> chartColors = [
    cardBlue,
    cardGreen,
    cardOrange,
    cardPurple,
    danger,
    info,
  ];
}