import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  Timer? _timer;
  bool _isLoading = true;
  Map<dynamic, dynamic> _historyLogs = {};

  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) => _fetchAlerts());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAlerts() async {
    try {
      final query = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl).ref('bantaydagat/readings').limitToLast(30);
      final snapshot = await query.get();

      if (mounted) {
        setState(() {
          if (snapshot.value != null) {
            _historyLogs = snapshot.value as Map<dynamic, dynamic>;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F82A0)));
    }

    List<Map<String, dynamic>> incidentAlerts = [];
    int totalCautionCount = 0;
    int totalDangerCount = 0;

    if (_historyLogs.isNotEmpty) {
      final sortedKeys = _historyLogs.keys.toList()..sort((a, b) => b.compareTo(a));

      for (var key in sortedKeys) {
        final log = Map<String, dynamic>.from(_historyLogs[key] as Map);
        int ts = log['timestamp'] ?? 0;
        DateTime date = DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
        String timeStr = DateFormat('MMM dd, hh:mm a').format(date);

        double waterTemp = (log['waterTemp'] ?? 0.0).toDouble();
        double ph = (log['pH'] ?? 7.0).toDouble();
        double turbidity = (log['turbidity'] ?? 0.0).toDouble();

        if (waterTemp < 24.0 || waterTemp > 30.0) {
          totalCautionCount++;
          incidentAlerts.add({'type': 'CAUTION', 'param': 'Water Temp', 'desc': 'Abnormal water heating detected: ${waterTemp.toStringAsFixed(1)}°C', 'time': timeStr, 'color': const Color(0xFFE65100), 'icon': Icons.thermostat});
        }
        if (ph < 7.8 || ph > 8.3) {
          totalDangerCount++;
          incidentAlerts.add({'type': 'DANGER', 'param': 'pH Level', 'desc': 'Critical level drop or spike: ${ph.toStringAsFixed(1)} pH', 'time': timeStr, 'color': const Color(0xFFC62828), 'icon': Icons.science_outlined});
        }
        if (turbidity >= 25.0) {
          totalDangerCount++;
          incidentAlerts.add({'type': 'DANGER', 'param': 'Turbidity', 'desc': 'High water cloudiness/silt content: ${turbidity.toStringAsFixed(1)} NTU', 'time': timeStr, 'color': const Color(0xFFC62828), 'icon': Icons.visibility_outlined});
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(child: _buildSummaryCounter(title: "TOTAL CAUTIONS", count: totalCautionCount.toString(), color: const Color(0xFFE65100))),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCounter(title: "TOTAL DANGERS", count: totalDangerCount.toString(), color: const Color(0xFFC62828))),
            ],
          ),
        ),
        Expanded(
          child: incidentAlerts.isEmpty
              ? const Center(child: Text("No exceptional water parameter alerts logged."))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: incidentAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = incidentAlerts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: alert['color'].withOpacity(0.1), shape: BoxShape.circle), child: Icon(alert['icon'], color: alert['color'], size: 22)),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(alert['param'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: alert['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(alert['type'], style: TextStyle(color: alert['color'], fontSize: 9, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(alert['desc'], style: TextStyle(color: Colors.grey.shade700, fontSize: 12)), const SizedBox(height: 4), Text(alert['time'], style: TextStyle(color: Colors.grey.shade400, fontSize: 11))]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCounter({required String title, required String count, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(count, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}