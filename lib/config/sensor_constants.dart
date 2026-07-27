import 'package:flutter/material.dart';

class SensorConstants {
  static const Map<String, Map<String, List<double>>> thresholds = {
    'airTemp': { 'safe': [25.0, 32.0], 'caution': [22.0, 35.0] },
    'waterTemp': { 'safe': [26.0, 31.0], 'caution': [24.0, 33.0] },
    'humidity': { 'safe': [65.0, 85.0], 'caution': [55.0, 90.0] },
    'ph': { 'safe': [7.8, 8.3], 'caution': [7.5, 8.5] },
  };

  static String getStatus(double value, String key) {
    // CORRECTED TURBIDITY LIMITS
    if (key == 'turbidity') {
      if (value > 50.00) return 'DANGER';
      if (value > 25.00) return 'CAUTION';
      return 'SAFE';
    }
    
    List<double> safe = thresholds[key]!['safe']!;
    List<double> caution = thresholds[key]!['caution']!;

    if (value < caution[0] || value > caution[1]) return 'DANGER';
    if (value >= safe[0] && value <= safe[1]) return 'SAFE';
    return 'CAUTION';
  }

  // The Master GO/NO-GO Matrix
  static Map<String, dynamic> getOverallAssessment(double air, double water, double hum, double ph, double turb) {
    List<String> statuses = [
      getStatus(air, 'airTemp'),
      getStatus(water, 'waterTemp'),
      getStatus(hum, 'humidity'),
      getStatus(ph, 'ph'),
      getStatus(turb, 'turbidity')
    ];

    int cautionCount = statuses.where((s) => s == 'CAUTION').length;
    int dangerCount = statuses.where((s) => s == 'DANGER').length;

    if (dangerCount >= 1) {
      return {'status': 'NO-GO: DO NOT RELEASE (DANGER)', 'color': const Color(0xFFEF4444), 'icon': Icons.block};
    }
    if (cautionCount >= 2) {
      return {'status': 'NO-GO: DO NOT RELEASE (CAUTION)', 'color': const Color(0xFFF97316), 'icon': Icons.warning_amber};
    }
    if (cautionCount == 1) {
      return {'status': 'GO WITH CAUTION: SAFE TO RELEASE', 'color': const Color(0xFFEAB308), 'icon': Icons.info_outline};
    }
    return {'status': 'GO: SAFE TO RELEASE', 'color': const Color(0xFF10B981), 'icon': Icons.check_circle};
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'SAFE': return const Color(0xFF10B981);
      case 'CAUTION': return const Color(0xFFF59E0B);
      case 'DANGER': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }

  static Color getStatusBgColor(String status) {
    switch (status) {
      case 'SAFE': return const Color(0xFFECFDF5);
      case 'CAUTION': return const Color(0xFFFFFBEB);
      case 'DANGER': return const Color(0xFFFEF2F2);
      default: return const Color(0xFFF1F5F9);
    }
  }
}