import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart'; // Added for timestamp formatting

class DashboardTab extends StatelessWidget {
  const DashboardTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
    
    final DatabaseReference liveRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: databaseUrl
    ).ref('live_readings');
    
    final DatabaseReference historyRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: databaseUrl
    ).ref('history_logs');

    return StreamBuilder(
      stream: liveRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xFF0F82A0)),
            ),
          );
        }

        // 1. Setup default fallback parameters matching your updated fields
        double airTemp = 0.0;
        double waterTemp = 0.0;
        double humidity = 0.0;
        double ph = 7.0;
        double turbidity = 0.0;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final rawData = snapshot.data!.snapshot.value;
          debugPrint("Hardware Data Received: $rawData");
          final data = Map<String, dynamic>.from(rawData as Map);
          
          // Updated matching keys from your live production database
          airTemp = (data['air_temp'] ?? 0.0).toDouble();
          waterTemp = (data['water_temp'] ?? 0.0).toDouble();
          humidity = (data['humidity'] ?? 0.0).toDouble();
          ph = (data['ph'] ?? 7.0).toDouble();
          turbidity = (data['turbidity'] ?? 0.0).toDouble();
        }

        // --- BANTAYDAGAT ECO-THRESHOLD LOGIC ---
        bool isAirSafe = airTemp <= 32.0;
        bool isWaterSafe = waterTemp >= 25.0 && waterTemp <= 30.0;
        bool isPhSafe = ph >= 6.5 && ph <= 8.5;
        bool isTurbiditySafe = turbidity < 5.0;

        // Calculate Caution and Danger tallies to render the top dashboard blocks dynamically
        int cautionCount = (!isWaterSafe || (airTemp > 30.0 && airTemp <= 32.0)) ? 1 : 0;
        int dangerCount = (!isPhSafe ? 1 : 0) + (!isTurbiditySafe ? 1 : 0);
        bool isGoRecommendation = cautionCount == 0 && dangerCount == 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NEW ADDITION: Web-matched Warning Summary Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: "CAUTION",
                      count: cautionCount.toString(),
                      label: "Warning level",
                      color: const Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: "DANGER",
                      count: dangerCount.toString(),
                      label: "Critical level",
                      color: const Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Existing Release Alert card styled to match the new web warnings
              _buildGoNoGoCard(isGoRecommendation),
              const SizedBox(height: 24),
              
              _buildSectionHeader('Live Sensor Data', isLive: true),
              const SizedBox(height: 16),
              
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.9,
                children: [
                  _buildSensorCard(
                    title: 'Air Temp',
                    value: airTemp.toStringAsFixed(1),
                    unit: '°C',
                    icon: Icons.air,
                    status: isAirSafe ? 'SAFE' : 'CAUTION',
                    statusColor: isAirSafe ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    bgColor: isAirSafe ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  ),
                  _buildSensorCard(
                    title: 'Water Temp',
                    value: waterTemp.toStringAsFixed(1),
                    unit: '°C',
                    icon: Icons.thermostat_outlined,
                    status: isWaterSafe ? 'SAFE' : 'CAUTION',
                    statusColor: isWaterSafe ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    bgColor: isWaterSafe ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  ),
                  _buildSensorCard(
                    title: 'Humidity',
                    value: humidity.toStringAsFixed(0),
                    unit: '%',
                    icon: Icons.water_drop_outlined,
                    status: 'SAFE', 
                    statusColor: const Color(0xFF2E7D32),
                    bgColor: const Color(0xFFE8F5E9),
                  ),
                  _buildSensorCard(
                    title: 'pH Level',
                    value: ph.toStringAsFixed(1),
                    unit: 'pH',
                    icon: Icons.science_outlined,
                    status: isPhSafe ? 'SAFE' : 'DANGER',
                    statusColor: isPhSafe ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    bgColor: isPhSafe ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  ),
                  _buildSensorCard(
                    title: 'Turbidity',
                    value: turbidity.toStringAsFixed(1),
                    unit: 'NTU',
                    icon: Icons.visibility_outlined,
                    status: isTurbiditySafe ? 'SAFE' : 'DANGER',
                    statusColor: isTurbiditySafe ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    bgColor: isTurbiditySafe ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('History Logs', isLive: false),
              const SizedBox(height: 16),

              // --- SECTION 2: HISTORY LOGS LIST (With Time Conversion) ---
              StreamBuilder(
                stream: historyRef.limitToLast(15).onValue, 
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    final Map<dynamic, dynamic> logs = snapshot.data!.snapshot.value as Map;
                    final sortedKeys = logs.keys.toList()..sort((a, b) => b.compareTo(a));

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedKeys.length,
                      itemBuilder: (context, index) {
                        final log = Map<String, dynamic>.from(logs[sortedKeys[index]] as Map);
                        
                        // TIMESTAMP CONVERSION LOGIC
                        int ts = log['timestamp'] ?? 0;
                        DateTime date = DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
                        String formattedTime = DateFormat('hh:mm:ss a').format(date);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F82A0).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history, color: Color(0xFF0F82A0), size: 20),
                            ),
                            title: Text(
                              "T: ${log['temp'] ?? '--'}°C | H: ${log['hum'] ?? '--'}%",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text("Recorded at $formattedTime", style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: Text("No history data found."));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HELPER WIDGETS ---
  
  // New helper for summary counters at the top
  Widget _buildSummaryCard({required String title, required String count, required String label, required Color color}) {
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
          Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool isLive}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        if (isLive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.link, size: 12, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text('LIVE NODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            ]),
          )
      ],
    );
  }

  Widget _buildGoNoGoCard(bool isGoRecommendation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: isGoRecommendation ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isGoRecommendation ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'PRE-RELEASE RECOMMENDATION', 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w700, 
              letterSpacing: 1.2, 
              color: isGoRecommendation ? const Color(0xFF2E7D32) : const Color(0xFFC62828)
            )
          ),
          const SizedBox(height: 8),
          Text(
            isGoRecommendation ? 'SAFE TO RELEASE' : 'DO NOT RELEASE', 
            style: TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.w900, 
              color: isGoRecommendation ? const Color(0xFF2E7D32) : const Color(0xFFC62828), 
              letterSpacing: 0.5
            )
          ),
          const SizedBox(height: 8),
          Text(
            isGoRecommendation ? 'Water parameters are within safe thresholds.' : 'Water quality conditions are not suitable for safe release. Review alerts below.', 
            textAlign: TextAlign.center, 
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500, 
              color: isGoRecommendation ? Colors.green.shade800 : Colors.red.shade800
            )
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({required String title, required String value, required String unit, required IconData icon, required String status, required Color statusColor, required Color bgColor}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: const Color(0xFF546E7A), size: 20),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 16),
                Text(title, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(unit, style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400)),
                ]),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Positioned(bottom: 12, left: 16, right: 16, child: CustomPaint(size: const Size(double.infinity, 15), painter: SparklinePainter(color: statusColor))),
        ],
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final Color color;
  SparklinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.2);
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}