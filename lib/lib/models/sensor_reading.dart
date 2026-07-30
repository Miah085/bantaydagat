import 'package:flutter/material.dart';

enum SafetyLevel { safe, caution, danger }

class SensorReading {
  final String parameter;
  final double value;
  final String unit;
  final SafetyLevel status;

  SensorReading({
    required this.parameter,
    required this.value,
    required this.unit,
    required this.status,
  });

  Color get statusColor {
    switch (status) {
      case SafetyLevel.safe:
        return Colors.green;
      case SafetyLevel.caution:
        return Colors.orange;
      case SafetyLevel.danger:
        return Colors.red;
    }
  }

  String get statusText {
    switch (status) {
      case SafetyLevel.safe:
        return "SAFE";
      case SafetyLevel.caution:
        return "CAUTION";
      case SafetyLevel.danger:
        return "DANGER";
    }
  }
}