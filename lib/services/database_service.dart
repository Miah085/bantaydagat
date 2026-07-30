import 'package:firebase_database/firebase_database.dart';

class SensorData {
  final double airTemp;
  final double waterTemp;
  final double humidity;
  final double ph;
  final double turbidity;
  final String status;
  final int timestamp;

  SensorData({
    required this.airTemp,
    required this.waterTemp,
    required this.humidity,
    required this.ph,
    required this.turbidity,
    required this.status,
    required this.timestamp,
  });
}

class DatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Stream for the Live Gauges matching the exact Firebase screenshot schema
  Stream<Map<String, dynamic>> get liveDataStream {
    return _db.child('bantaydagat/latest').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        return {
          'airTemp': 0.0,
          'waterTemp': 0.0,
          'humidity': 0.0,
          'pH': 0.0,
          'turbidity': 0.0,
          'status': 'UNKNOWN',
        };
      }
      return {
        'airTemp': (data['airTemp'] as num?)?.toDouble() ?? 0.0,
        'waterTemp': (data['waterTemp'] as num?)?.toDouble() ?? 0.0,
        'humidity': (data['humidity'] as num?)?.toDouble() ?? 0.0,
        'pH': (data['pH'] as num?)?.toDouble() ?? 0.0,
        'turbidity': (data['turbidity'] as num?)?.toDouble() ?? 0.0,
        'status': data['status']?.toString() ?? 'UNKNOWN',
      };
    });
  }

  // Stream for the History Log List matching the exact schema
  Stream<List<SensorData>> get historyStream {
    return _db.child('bantaydagat/readings').onValue.map((event) {
      final Map<dynamic, dynamic>? logs = event.snapshot.value as Map<dynamic, dynamic>?;
      if (logs == null) return [];

      return logs.entries.map((e) {
        final val = e.value as Map<dynamic, dynamic>;
        return SensorData(
          airTemp: (val['airTemp'] as num?)?.toDouble() ?? 0.0,
          waterTemp: (val['waterTemp'] as num?)?.toDouble() ?? 0.0,
          humidity: (val['humidity'] as num?)?.toDouble() ?? 0.0,
          ph: (val['pH'] as num?)?.toDouble() ?? 0.0,
          turbidity: (val['turbidity'] as num?)?.toDouble() ?? 0.0,
          status: val['status']?.toString() ?? 'UNKNOWN',
          timestamp: (val['timestamp'] as num?)?.toInt() ?? 0,
        );
      }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort newest first
    });
  }
}