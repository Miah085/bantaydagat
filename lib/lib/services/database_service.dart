import 'package:firebase_database/firebase_database.dart';

class SensorData {
  final double temp;
  final double humidity;
  final String time;

  SensorData({required this.temp, required this.humidity, required this.time});
}

class DatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Stream for the Live Gauges
  Stream<Map<String, double>> get liveDataStream {
    return _db.child('live_readings').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return {'temp': 0.0, 'hum': 0.0};
      return {
        'temp': (data['temperature'] as num).toDouble(),
        'hum': (data['humidity'] as num).toDouble(),
      };
    });
  }

  // Stream for the History Log List
  Stream<List<SensorData>> get historyStream {
    return _db.child('history_logs').onValue.map((event) {
      final Map<dynamic, dynamic>? logs = event.snapshot.value as Map<dynamic, dynamic>?;
      if (logs == null) return [];

      return logs.entries.map((e) {
        final val = e.value as Map<dynamic, dynamic>;
        return SensorData(
          temp: (val['temp'] as num).toDouble(),
          humidity: (val['hum'] as num).toDouble(),
          time: val['timestamp'].toString(), // You can format this later
        );
      }).toList().reversed.toList(); // Newest at the top
    });
  }
}