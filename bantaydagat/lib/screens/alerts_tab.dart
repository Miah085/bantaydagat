import 'package:flutter/material.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mocking the alerts you showed in your web screenshot
    final List<Map<String, dynamic>> alerts = [
      {'parameter': 'Temperature', 'value': '30.04 °C', 'status': 'DANGER', 'desc': 'Abnormal spike detected', 'time': '5:10 PM'},
      {'parameter': 'Turbidity', 'value': '34.14 NTU', 'status': 'CAUTION', 'desc': 'Approaching danger zone', 'time': '5:00 PM'},
      {'parameter': 'Humidity', 'value': '28.88 %', 'status': 'DANGER', 'desc': 'Exceeded safe upper threshold', 'time': '4:40 PM'},
      {'parameter': 'pH Level', 'value': '9.00 pH', 'status': 'DANGER', 'desc': 'Exceeded safe upper threshold', 'time': '3:50 PM'},
      {'parameter': 'Turbidity', 'value': '8.21 NTU', 'status': 'CAUTION', 'desc': 'Approaching danger zone', 'time': '3:20 PM'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: alerts.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Recent Alert Logs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
          );
        }

        final alert = alerts[index - 1];
        final isDanger = alert['status'] == 'DANGER';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isDanger ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
              child: Icon(
                isDanger ? Icons.warning_rounded : Icons.error_outline,
                color: isDanger ? const Color(0xFFC62828) : const Color(0xFFE65100),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  alert['parameter'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  alert['time'],
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(alert['desc'], style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDanger ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert['status'],
                        style: TextStyle(
                          color: isDanger ? const Color(0xFFC62828) : const Color(0xFFE65100),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reading: ${alert['value']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}