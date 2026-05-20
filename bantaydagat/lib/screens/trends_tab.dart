import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

class HistoricalTrendsTab extends StatelessWidget {
  const HistoricalTrendsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/"; //
    
    final DatabaseReference historyRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: databaseUrl
    ).ref('history_logs'); //

    return StreamBuilder(
      stream: historyRef.limitToLast(50).onValue, // Pulling last 50 data blocks for deep trend analysis //
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F82A0)), //
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(
            child: Text("No historical records found in production database."), //
          );
        }

        final Map<dynamic, dynamic> rawLogs = snapshot.data!.snapshot.value as Map; //
        final sortedKeys = rawLogs.keys.toList()..sort((a, b) => b.compareTo(a)); // Newest records at top //

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final log = Map<String, dynamic>.from(rawLogs[sortedKeys[index]] as Map); //
            
            // Format time parameters cleanly
            int ts = log['timestamp'] ?? 0; //
            DateTime date = DateTime.fromMillisecondsSinceEpoch(ts).toLocal(); //
            String formattedDate = DateFormat('MMM dd, yyyy').format(date);
            String formattedTime = DateFormat('hh:mm:ss a').format(date); //

            // Synchronized values coming from hardware nodes
            double airTemp = (log['air_temp'] ?? log['temp'] ?? 0.0).toDouble();
            double waterTemp = (log['water_temp'] ?? 0.0).toDouble();
            double humidity = (log['humidity'] ?? log['hum'] ?? 0.0).toDouble();
            double ph = (log['ph'] ?? 7.0).toDouble();
            double turbidity = (log['turbidity'] ?? 0.0).toDouble();

            // Match safety colors directly with your web layout specifications
            bool isPhSafe = ph >= 6.5 && ph <= 8.5; //
            bool isTurbiditySafe = turbidity < 5.0; //

            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200), //
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row containing logging metadata timeline
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF0F82A0)),
                            const SizedBox(width: 6),
                            Text(
                              formattedDate,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2C3E50)),
                            ),
                          ],
                        ),
                        Text(
                          formattedTime,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 1),
                    
                    // Comprehensive parameter readout block
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTrendMetric("Air", "${airTemp.toStringAsFixed(1)}°C", Colors.blueGrey),
                        _buildTrendMetric("Water", "${waterTemp.toStringAsFixed(1)}°C", Colors.orange),
                        _buildTrendMetric("Hum", "${humidity.toStringAsFixed(0)}%", Colors.teal),
                        _buildTrendMetric(
                          "pH", 
                          ph.toStringAsFixed(1), 
                          isPhSafe ? const Color(0xFF2E7D32) : const Color(0xFFC62828)
                        ),
                        _buildTrendMetric(
                          "NTU", 
                          turbidity.toStringAsFixed(1), 
                          isTurbiditySafe ? const Color(0xFF2E7D32) : const Color(0xFFC62828)
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrendMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade400, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}