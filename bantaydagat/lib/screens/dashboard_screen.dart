import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart'; 
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

// =========================================================================
// ARCHITECTURE UPDATE: 
// Importing the "Rulebook" and the "Data Model"
// =========================================================================
import '../config/sensor_constants.dart';
import '../models/sensor_reading.dart'; 

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Timer? _timer;
  bool _isLoading = true;
  
  Map<String, dynamic> _latestData = {};
  Map<dynamic, dynamic> _historyLogs = {};

  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";

  @override
  void initState() {
    super.initState();
    _fetchFirebaseData(); 
    
    // --- 5-MINUTE POLLING LOGIC ---
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _fetchFirebaseData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); 
    super.dispose();
  }

  Future<void> _fetchFirebaseData() async {
    try {
      final liveQuery = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl).ref('bantaydagat/readings').limitToLast(1); 
      final historyQuery = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl).ref('bantaydagat/readings').limitToLast(15);

      final liveSnapshot = await liveQuery.get();
      final historySnapshot = await historyQuery.get();

      if (mounted) {
        setState(() {
          if (liveSnapshot.value != null) {
            final Map rawWrapper = liveSnapshot.value as Map;
            _latestData = Map<String, dynamic>.from(rawWrapper.values.first as Map);
          }
          if (historySnapshot.value != null) {
            _historyLogs = historySnapshot.value as Map<dynamic, dynamic>;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ ERROR FETCHING FIREBASE DATA: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to map the String from SensorConstants to your Enum model
  SafetyLevel _parseSafetyLevel(String statusString) {
    if (statusString == "SAFE") return SafetyLevel.safe;
    if (statusString == "CAUTION") return SafetyLevel.caution;
    return SafetyLevel.danger;
  }

  // Helper for background colors based on your Enum
  Color _getBgColor(SafetyLevel level) {
    if (level == SafetyLevel.safe) return Colors.green.shade50;
    if (level == SafetyLevel.caution) return Colors.orange.shade50;
    return Colors.red.shade50;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF0F82A0))));
    }

    // 1. Fetch raw numerical data
    double rawAir = (_latestData['airTemp'] ?? 0.0).toDouble();
    double rawWater = (_latestData['waterTemp'] ?? 0.0).toDouble();
    double rawHum = (_latestData['humidity'] ?? 0.0).toDouble();
    double rawPh = (_latestData['pH'] ?? 7.0).toDouble();
    double rawTurb = (_latestData['turbidity'] ?? 0.0).toDouble();

    // 2. Package everything into your SensorReading Data Models
    SensorReading airData = SensorReading(
      parameter: 'Air Temp',
      value: rawAir,
      unit: '°C',
      status: _parseSafetyLevel(SensorConstants.getStatus(rawAir, 'airTemp')),
    );

    SensorReading waterData = SensorReading(
      parameter: 'Water Temp',
      value: rawWater,
      unit: '°C',
      status: _parseSafetyLevel(SensorConstants.getStatus(rawWater, 'waterTemp')),
    );

    SensorReading humData = SensorReading(
      parameter: 'Humidity',
      value: rawHum,
      unit: '%',
      status: _parseSafetyLevel(SensorConstants.getStatus(rawHum, 'humidity')),
    );

    SensorReading phData = SensorReading(
      parameter: 'pH Level',
      value: rawPh,
      unit: 'pH',
      status: _parseSafetyLevel(SensorConstants.getStatus(rawPh, 'ph')),
    );

    SensorReading turbData = SensorReading(
      parameter: 'Turbidity',
      value: rawTurb,
      unit: 'NTU',
      status: _parseSafetyLevel(SensorConstants.getStatus(rawTurb, 'turbidity')),
    );

    // 3. Evaluate overall system health
    List<SensorReading> allSensors = [airData, waterData, humData, phData, turbData];
    int cautionCount = allSensors.where((s) => s.status == SafetyLevel.caution).length;
    int dangerCount = allSensors.where((s) => s.status == SafetyLevel.danger).length;
    bool isGoRecommendation = (cautionCount == 0 && dangerCount == 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildSummaryCard(title: "CAUTION", count: cautionCount.toString(), label: "Warning level", color: Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard(title: "DANGER", count: dangerCount.toString(), label: "Critical level", color: Colors.red)),
            ],
          ),
          const SizedBox(height: 20),

          _buildGoNoGoCard(isGoRecommendation),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Naic, Cavite Weather', isLive: true),
          const SizedBox(height: 16),
          const WeatherSummaryCard(),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Sensor Data (5m Sync)', isLive: true),
          const SizedBox(height: 16),
          
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.9,
            children: [
              // Notice how clean these are now! We just pass the Model.
              _buildSensorCard(reading: airData, icon: Icons.air),
              _buildSensorCard(reading: waterData, icon: Icons.thermostat_outlined),
              _buildSensorCard(reading: humData, icon: Icons.water_drop_outlined),
              _buildSensorCard(reading: phData, icon: Icons.science_outlined),
              _buildSensorCard(reading: turbData, icon: Icons.visibility_outlined),
            ],
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('History Logs', isLive: false),
          const SizedBox(height: 16),

          _buildHistoryLogs(),
        ],
      ),
    );
  }

  // The UI card now takes a single SensorReading object instead of 7 different parameters
  Widget _buildSensorCard({required SensorReading reading, required IconData icon}) {
    Color bgColor = _getBgColor(reading.status);
    
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), 
                      // Pulling text and color directly from your data model!
                      child: Text(reading.statusText, style: TextStyle(color: reading.statusColor, fontSize: 10, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(reading.parameter, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(reading.value.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(reading.unit, style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400)),
                ]),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Positioned(bottom: 12, left: 16, right: 16, child: CustomPaint(size: const Size(double.infinity, 15), painter: SparklinePainter(color: reading.statusColor))),
        ],
      ),
    );
  }

  Widget _buildHistoryLogs() {
    if (_historyLogs.isEmpty) return const Center(child: Text("No history data found."));
    
    final sortedKeys = _historyLogs.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final log = Map<String, dynamic>.from(_historyLogs[sortedKeys[index]] as Map);
        int ts = log['timestamp'] ?? 0;
        DateTime date = DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
        String formattedTime = DateFormat('hh:mm:ss a').format(date);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0F82A0).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.history, color: Color(0xFF0F82A0), size: 20)),
            title: Text("Air: ${log['airTemp'] ?? '--'}°C | Hum: ${log['humidity'] ?? '--'}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Recorded at $formattedTime", style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({required String title, required String count, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
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
              Icon(Icons.sync, size: 12, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
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
          Text('PRE-RELEASE RECOMMENDATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isGoRecommendation ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
          const SizedBox(height: 8),
          Text(isGoRecommendation ? 'SAFE TO RELEASE' : 'DO NOT RELEASE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isGoRecommendation ? const Color(0xFF2E7D32) : const Color(0xFFC62828), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(isGoRecommendation ? 'Water parameters are within safe thresholds.' : 'Water quality conditions are not suitable for safe release. Review alerts below.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isGoRecommendation ? Colors.green.shade800 : Colors.red.shade800)),
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

// =========================================================================
// OPENWEATHERMAP API WIDGET 
// =========================================================================

class WeatherSummaryCard extends StatefulWidget {
  const WeatherSummaryCard({super.key});

  @override
  State<WeatherSummaryCard> createState() => _WeatherSummaryCardState();
}

class _WeatherSummaryCardState extends State<WeatherSummaryCard> {
  bool _isLoading = true;
  bool _hasError = false;
  String _temp = "--";
  String _desc = "--";
  String _wind = "--";
  Timer? _timer;

  final String _apiKey = "06b809ea65b4948afce76db133756173"; 
  final String _city = "Naic,PH";

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _timer = Timer.periodic(const Duration(minutes: 10), (timer) => _fetchWeather());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    if (!mounted) return;
    
    try {
      final response = await http.get(Uri.parse(
          "https://api.openweathermap.org/data/2.5/weather?q=$_city&units=metric&appid=$_apiKey"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _temp = "${data['main']['temp'].round()}°C";
            _desc = data['weather'][0]['main']; 
            _wind = "${data['wind']['speed']} m/s";
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        throw Exception("API Connection Failed");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: _isLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFF0F82A0))))
          : _hasError
              ? Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text("API Weather data currently unavailable.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.cloud, color: Colors.blue, size: 28)),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_temp, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            Text(_desc, style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(Icons.air, color: Color(0xFF546E7A), size: 20),
                        const SizedBox(height: 4),
                        Text(_wind, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                        Text("Wind", style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade400)),
                      ],
                    ),
                  ],
                ),
    );
  }
}