import 'package:flutter/material.dart';

class SensorConstants {
  // === THRESHOLD DEFINITIONS (Strictly matched to Web UI) ===
  
  static String getAirTempStatus(double value) {
    if (value >= 25.0 && value <= 32.0) return 'SAFE';
    if ((value >= 22.0 && value < 25.0) || (value > 32.0 && value <= 35.0)) return 'CAUTION';
    return 'DANGER';
  }

  static String getWaterTempStatus(double value) {
    if (value >= 26.0 && value <= 31.0) return 'SAFE';
    if ((value >= 24.0 && value < 26.0) || (value > 31.0 && value <= 33.0)) return 'CAUTION';
    return 'DANGER';
  }

  static String getHumidityStatus(double value) {
    if (value >= 65.0 && value <= 85.0) return 'SAFE';
    if ((value >= 55.0 && value < 65.0) || (value > 85.0 && value <= 90.0)) return 'CAUTION';
    return 'DANGER';
  }

  static String getPhStatus(double value) {
    if (value >= 7.8 && value <= 8.3) return 'SAFE';
    if ((value >= 7.5 && value < 7.8) || (value > 8.3 && value <= 8.5)) return 'CAUTION';
    return 'DANGER';
  }

  static String getTurbidityStatus(double value) {
    if (value >= 0.0 && value <= 25.0) return 'SAFE';
    if (value > 25.0 && value <= 50.0) return 'CAUTION';
    return 'DANGER';
  }

  // === GENERIC METHOD FOR ALERTS & LOOPING (Clears your red compilation lines) ===
  static String getStatus(String parameter, double value) {
    final key = parameter.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    if (key.contains('air')) return getAirTempStatus(value);
    if (key.contains('water')) return getWaterTempStatus(value);
    if (key.contains('humid')) return getHumidityStatus(value);
    if (key.contains('ph')) return getPhStatus(value);
    if (key.contains('turbid')) return getTurbidityStatus(value);
    return 'SAFE';
  }

  // === HELPERS FOR UI COLORING AND SUBTITLES ===
  static Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SAFE':
        return Colors.green;
      case 'CAUTION':
        return Colors.orange;
      case 'DANGER':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  static String getSubtitleForStatus(String status) {
    switch (status.toUpperCase()) {
      case 'SAFE':
        return 'Supports GO';
      case 'CAUTION':
        return 'Contributes to Caution';
      case 'DANGER':
        return 'Triggers NO-GO';
      default:
        return 'Unknown';
    }
  }

  // === OVERALL LEGISLATIVE PROTOCOL LOGIC ===
  static Map<String, dynamic> calculateOverallReleaseStatus(List<String> statuses) {
    int dangerCount = statuses.where((s) => s == 'DANGER').length;
    int cautionCount = statuses.where((s) => s == 'CAUTION').length;

    if (dangerCount >= 1) {
      return {
        'status': 'NO-GO: DO NOT RELEASE (DANGER)',
        'message': 'One or more parameters are at critical danger levels. Release is strictly prohibited.',
        'color': Colors.red,
      };
    } else if (cautionCount >= 2) {
      return {
        'status': 'NO-GO: DO NOT RELEASE (CAUTION)',
        'message': '2 or more parameters are within their Caution Ranges (suboptimal release conditions).',
        'color': Colors.orange[800],
      };
    } else if (cautionCount == 1) {
      return {
        'status': 'GO WITH CAUTION: SAFE TO RELEASE',
        'message': 'Exactly 1 parameter is within its Caution Range, and the other 4 are Safe.',
        'color': Colors.amber,
      };
    } else {
      return {
        'status': 'GO: SAFE TO RELEASE',
        'message': 'All 5 environmental parameters are within their Safe Ranges.',
        'color': Colors.green,
      };
    }
  }
}