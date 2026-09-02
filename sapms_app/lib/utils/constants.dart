import 'package:flutter/material.dart';

class AppConstants {
  // ── API ──────────────────────────────────────────────────
  // Change this to your server IP if testing on a real phone
  // For Chrome/Windows desktop, localhost works fine
  static const String baseUrl = 'http://10.169.211.32:5000/api';

  // ── App Info ─────────────────────────────────────────────
  static const String appName = 'SAPMS';
  static const String appFullName = 'Student Attendance & Performance Monitoring System';
  static const String university = 'University of Kigali';

  // ── Colors ───────────────────────────────────────────────
  static const Color primaryColor   = Color(0xFF1B5E20); // Deep green (Rwanda flag)
  static const Color secondaryColor = Color(0xFF388E3C);
  static const Color accentColor    = Color(0xFFFDD835); // Yellow (Rwanda flag)
  static const Color dangerColor    = Color(0xFFD32F2F);
  static const Color warningColor   = Color(0xFFF57C00);
  static const Color successColor   = Color(0xFF2E7D32);
  static const Color bgColor        = Color(0xFFF5F5F5);
  static const Color cardColor      = Colors.white;

  // ── Risk Colors ──────────────────────────────────────────
  static Color riskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':     return dangerColor;
      case 'moderate': return warningColor;
      default:         return successColor;
    }
  }

  static IconData riskIcon(String level) {
    switch (level.toLowerCase()) {
      case 'high':     return Icons.warning_rounded;
      case 'moderate': return Icons.info_rounded;
      default:         return Icons.check_circle_rounded;
    }
  }
}
