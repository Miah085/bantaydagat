import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../config/sensor_constants.dart';

class HistoricalTrendsTab extends StatefulWidget {
  const HistoricalTrendsTab({super.key});

  @override
  State<HistoricalTrendsTab> createState() => _HistoricalTrendsTabState();
}

class _HistoricalTrendsTabState extends State<HistoricalTrendsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
  
  StreamSubscription<DatabaseEvent>? _trendsSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeHistory();
  }

  @override
  void dispose() {
    _trendsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeHistory() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    
    // Live pipeline for the last 50 logs
    _trendsSubscription = db.ref('bantaydagat/readings').limitToLast(50).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map rawData = event.snapshot.value as Map;
        List<Map<String, dynamic>> updatedLogs = rawData.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
        
        // Sort newest first
        updatedLogs.sort((a, b) {
          int tsA = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
          int tsB = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
          return tsB.compareTo(tsA); 
        });

        setState(() {
          _logs = updatedLogs;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F82A0)));
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: _logs.isEmpty 
          ? const Center(child: Text("No historical data available.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                int ts = int.tryParse(log['timestamp']?.toString() ?? '0') ?? 0;
                if (ts > 0 && ts < 10000000000) ts *= 1000;
                
                DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
                String formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(date);

                double air = (log['air_temperature'] ?? log['airTemp'] ?? 0.0).toDouble();
                double water = (log['temperature'] ?? log['waterTemp'] ?? 0.0).toDouble();
                double hum = (log['humidity'] ?? 0.0).toDouble();
                double ph = (log['ph'] ?? log['pH'] ?? 7.8).toDouble();
                double turb = (log['turbidity'] ?? 0.0).toDouble();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLogParam('Air', air, '°C', 'airTemp'),
                            _buildLogParam('Water', water, '°C', 'waterTemp'),
                            _buildLogParam('Hum', hum, '%', 'humidity'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildLogParam('pH', ph, '', 'ph'),
                            const SizedBox(width: 48),
                            _buildLogParam('Turb', turb, ' NTU', 'turbidity'),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLogParam(String label, double value, String unit, String sensorKey) {
    String status = SensorConstants.getStatus(value, sensorKey);
    Color statusColor = SensorConstants.getStatusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Row(
          children: [
            Text('${value.toStringAsFixed(1)}$unit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(width: 6),
            Icon(Icons.circle, size: 8, color: statusColor),
          ],
        )
      ],
    );
  }
}