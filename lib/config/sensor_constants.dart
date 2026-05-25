import 'package:flutter/material.dart';

class SensorConstants {
  // 1. THE SINGLE SOURCE OF TRUTH FOR ALL THRESHOLDS
  static final Map<String, Map<String, List<double>>> thresholds = {
    'airTemp': { 'safe': [21.0, 37.0], 'caution': [0.0, 60.0] }, 
    'waterTemp': { 'safe': [26.0, 31.0], 'caution': [24.0, 33.0] },
    'humidity': { 'safe': [60.0, 85.0], 'caution': [50.0, 95.0] },
    'ph': { 'safe': [7.5, 8.3], 'caution': [7.0, 8.5] },
    'turbidity': { 'safe': [0.0, 8.0], 'caution': [0.0, 15.0] },
  };

  // 2. UNIVERSAL STATUS CALCULATOR
  static String getStatus(double value, String sensorKey) {
    final safe = thresholds[sensorKey]!['safe']!;
    final caution = thresholds[sensorKey]!['caution']!;
    
    if (value >= safe[0] && value <= safe[1]) return "SAFE";
    if (value >= caution[0] && value <= caution[1]) return "CAUTION";
    return "DANGER";
  }

  // 3. UNIVERSAL COLOR CODING
  static Color getStatusColor(String status) {
    if (status == "SAFE") return const Color(0xFF2E7D32); // Green
    if (status == "CAUTION") return const Color(0xFFE65100); // Orange
    return const Color(0xFFC62828); // Red
  }

  static Color getStatusBgColor(String status) {
    if (status == "SAFE") return const Color(0xFFE8F5E9);
    if (status == "CAUTION") return const Color(0xFFFFF3E0);
    return const Color(0xFFFFEBEE); 
  }
}