import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String databaseUrl = "https://bantaydagat-4b8b6-default-rtdb.firebaseio.com/"; //
    
    final DatabaseReference historyRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: databaseUrl
    ).ref('history_logs'); //

    return StreamBuilder(
      stream: historyRef.limitToLast(30).onValue, //
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F82A0)), //
          );
        }

        List<Map<String, dynamic>> incidentAlerts = [];
        int totalCautionCount = 0;
        int totalDangerCount = 0;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final Map<dynamic, dynamic> logs = snapshot.data!.snapshot.value as Map; //
          final sortedKeys = logs.keys.toList()..sort((a, b) => b.compareTo(a)); //

          for (var key in sortedKeys) {
            final log = Map<String, dynamic>.from(logs[key] as Map); //
            
            int ts = log['timestamp'] ?? 0; //
            DateTime date = DateTime.fromMillisecondsSinceEpoch(ts).toLocal(); //
            String timeStr = DateFormat('MMM dd, hh:mm a').format(date);

            double airTemp = (log['air_temp'] ?? 0.0).toDouble();
            double waterTemp = (log['water_temp'] ?? 0.0).toDouble();
            double ph = (log['ph'] ?? 7.0).toDouble();
            double turbidity = (log['turbidity'] ?? 0.0).toDouble();

            // Evaluate thresholds matching your web system rules
            if (waterTemp < 25.0 || waterTemp > 30.0) {
              totalCautionCount++;
              incidentAlerts.add({
                'type': 'CAUTION',
                'param': 'Water Temp',
                'desc': 'Abnormal water heating detected: ${waterTemp.toStringAsFixed(1)}°C',
                'time': timeStr,
                'color': const Color(0xFFE65100),
                'icon': Icons.thermostat,
              });
            }
            if (ph < 6.5 || ph > 8.5) {
              totalDangerCount++;
              incidentAlerts.add({
                'type': 'DANGER',
                'param': 'pH Level',
                'desc': 'Critical level drop or spike: ${ph.toStringAsFixed(1)} pH',
                'time': timeStr,
                'color': const Color(0xFFC62828),
                'icon': Icons.science_outlined,
              });
            }
            if (turbidity >= 5.0) {
              totalDangerCount++;
              incidentAlerts.add({
                'type': 'DANGER',
                'param': 'Turbidity',
                'desc': 'High water cloudiness/silt content: ${turbidity.toStringAsFixed(1)} NTU',
                'time': timeStr,
                'color': const Color(0xFFC62828),
                'icon': Icons.visibility_outlined,
              });
            }
          }
        }

        return Column(
          children: [
            // 1. TOP TOTALS SUMMARY CARDS (Matches Web Header Layout)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCounter(
                      title: "TOTAL CAUTIONS",
                      count: totalCautionCount.toString(),
                      color: const Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCounter(
                      title: "TOTAL DANGERS",
                      count: totalDangerCount.toString(),
                      color: const Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
            ),

            // 2. SCROLLABLE ALERT LIST LOG
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade200), //
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: alert['color'].withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(alert['icon'], color: alert['color'], size: 22),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  alert['param'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: alert['color'].withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    alert['type'],
                                    style: TextStyle(color: alert['color'], fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(alert['desc'], style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(alert['time'], style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCounter({required String title, required String count, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
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