import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';


import '../config/sensor_constants.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _alertsList = [];
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) => _fetchAlerts());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> _fetchAlerts() async {
    try {
      final query = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl)
          .ref('bantaydagat/readings')
          .limitToLast(50);
          
      final snapshot = await query.get();

      if (mounted) {
        setState(() {
          if (snapshot.value != null) {
            final Map<dynamic, dynamic> rawData = snapshot.value as Map<dynamic, dynamic>;
            List<Map<String, dynamic>> sortedLogs = rawData.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
            
            sortedLogs.sort((a, b) {
              int tsA = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
              int tsB = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
              return tsA.compareTo(tsB);
            });

            _alertsList = _generateStateChangeAlerts(sortedLogs);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _generateStateChangeAlerts(List<Map<String, dynamic>> logs) {
    List<Map<String, dynamic>> generatedAlerts = [];
    
    Map<String, String> lastStatus = {
      'airTemp': 'SAFE', 'waterTemp': 'SAFE', 'humidity': 'SAFE', 'ph': 'SAFE', 'turbidity': 'SAFE'
    };

    for (var log in logs) {
      int ts = int.tryParse(log['timestamp'].toString()) ?? 0;
      if (ts > 0 && ts < 10000000000) ts *= 1000;
      DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
      String timeStr = DateFormat('MMM d, h:mm a').format(date);

      double air = _parseDouble(log['air_temperature'] ?? log['airTemp']);
      double water = _parseDouble(log['temperature'] ?? log['waterTemp']);
      double hum = _parseDouble(log['humidity']);
      double ph = _parseDouble(log['ph'] ?? log['pH']);
      double turb = _parseDouble(log['turbidity']);

      void evaluateSensor(String name, String brainKey, double val, String unit) {
        String currentStatus = SensorConstants.getStatus(val, brainKey);
        String prevStatus = lastStatus[brainKey]!;

        if (currentStatus != prevStatus) {
          String title = '';
          String message = '';
          IconData icon = Icons.info;
          Color iconColor = Colors.grey;
          Color bgColor = Colors.grey.shade100;
          String badgeText = '';

          if (currentStatus == 'DANGER') {
            title = 'CRITICAL: $name Limit Exceeded';
            message = 'Recorded ${val.toStringAsFixed(2)}$unit. Immediate action recommended.';
            iconColor = const Color(0xFFEF4444);
            bgColor = const Color(0xFFFEF2F2);
            icon = Icons.warning_amber_rounded;
            badgeText = 'CRITICAL';
          } else if (currentStatus == 'CAUTION') {
            title = 'WARNING: $name Shift';
            message = 'Recorded ${val.toStringAsFixed(2)}$unit. Nearing critical limits.';
            iconColor = const Color(0xFFF59E0B);
            bgColor = const Color(0xFFFFFBEB);
            icon = Icons.error_outline;
            badgeText = 'WARNING';
          } else if (currentStatus == 'SAFE' && (prevStatus == 'DANGER' || prevStatus == 'CAUTION')) {
            title = 'RESOLVED: $name Stabilized';
            message = 'Returned to optimal range (${val.toStringAsFixed(2)}$unit).';
            iconColor = const Color(0xFF10B981);
            bgColor = const Color(0xFFECFDF5);
            icon = Icons.check_circle_outline;
            badgeText = 'RESOLVED';
          }

          if (title.isNotEmpty) {
            generatedAlerts.add({
              'title': title,
              'message': message,
              'time': timeStr,
              'iconColor': iconColor,
              'bgColor': bgColor,
              'icon': icon,
              'badgeText': badgeText
            });
          }
          lastStatus[brainKey] = currentStatus;
        }
      }

      evaluateSensor('Air Temp', 'airTemp', air, '°C');
      evaluateSensor('Water Temp', 'waterTemp', water, '°C');
      evaluateSensor('Humidity', 'humidity', hum, '%');
      evaluateSensor('pH Level', 'ph', ph, 'pH');
      evaluateSensor('Turbidity', 'turbidity', turb, 'NTU');
    }

    generatedAlerts.add({
      'title': 'SYSTEM: Monitoring Active', 
      'message': 'Connected to ESP32 node. Awaiting shifts.', 
      'time': DateFormat('MMM d, h:mm a').format(DateTime.now().subtract(const Duration(hours: 4))), 
      'iconColor': const Color(0xFF3B82F6), 
      'bgColor': const Color(0xFFEFF6FF), 
      'icon': Icons.info_outline,
      'badgeText': 'ONLINE'
    });

    return generatedAlerts.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF0F82A0))));

    return Container(
      color: const Color(0xFFF8FAFC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 900;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _alertsList.isEmpty 
                      ? const Center(child: Text("No alerts found in the current log.", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _alertsList.length,
                          itemBuilder: (context, index) {
                            return _buildAlertCard(_alertsList[index]);
                          },
                        ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // THE FIX: Cleanly removed the TextButton and simplified the layout.
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("System Alerts", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text("Live notifications for critical environmental shifts.", style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400)),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: alert['bgColor'],
              shape: BoxShape.circle,
            ),
            child: Icon(alert['icon'], color: alert['iconColor'], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        alert['title'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: alert['bgColor'],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        alert['badgeText'],
                        style: TextStyle(color: alert['iconColor'], fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert['message'],
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  alert['time'],
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}