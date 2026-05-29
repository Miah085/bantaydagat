import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../config/sensor_constants.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _isLoading = true;
  
  Map<String, dynamic> _latestData = {};
  Map<dynamic, dynamic> _historyLogs = {};

  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
  
  // Real-time Database Listeners
  StreamSubscription<DatabaseEvent>? _liveSubscription;
  StreamSubscription<DatabaseEvent>? _historySubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeStreams(); 
  }

  @override
  void dispose() {
    // Always cancel streams when leaving the screen to save memory
    _liveSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  // THIS IS THE FIX: Opens a live pipeline to Firebase instead of asking every 5 minutes
  void _setupRealtimeStreams() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);

    // 1. Listen for the absolute newest reading instantly
    _liveSubscription = db.ref('bantaydagat/readings').limitToLast(1).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map rawWrapper = event.snapshot.value as Map;
        setState(() {
          _latestData = Map<String, dynamic>.from(rawWrapper.values.first as Map);
          _isLoading = false;
        });
      }
    });

    // 2. Keep the recent history logs synced
    _historySubscription = db.ref('bantaydagat/readings').limitToLast(15).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() {
          _historyLogs = event.snapshot.value as Map<dynamic, dynamic>;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF0F82A0))));
    }

    double airTemp = (_latestData['air_temperature'] ?? _latestData['airTemp'] ?? 0.0).toDouble();
    double waterTemp = (_latestData['temperature'] ?? _latestData['waterTemp'] ?? 0.0).toDouble();
    double humidity = (_latestData['humidity'] ?? 0.0).toDouble();
    double ph = (_latestData['ph'] ?? _latestData['pH'] ?? 7.8).toDouble();
    double turbidity = (_latestData['turbidity'] ?? 0.0).toDouble();

    String airStatus = SensorConstants.getStatus(airTemp, 'airTemp');
    String waterStatus = SensorConstants.getStatus(waterTemp, 'waterTemp');
    String humStatus = SensorConstants.getStatus(humidity, 'humidity');
    String phStatus = SensorConstants.getStatus(ph, 'ph');
    String turbStatus = SensorConstants.getStatus(turbidity, 'turbidity');

    Map<String, dynamic> assessment = SensorConstants.getOverallAssessment(airTemp, waterTemp, humidity, ph, turbidity);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 900;

          Widget mainContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(),
              const SizedBox(height: 24),
              _buildGoNoGoCard(assessment),
              const SizedBox(height: 24),
              const WeatherSummaryCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('Sensor Data', isActive: true),
              const SizedBox(height: 16),
              _buildSensorGrid(
                isDesktop: isDesktop,
                airTemp: airTemp, airStatus: airStatus,
                waterTemp: waterTemp, waterStatus: waterStatus,
                humidity: humidity, humStatus: humStatus,
                ph: ph, phStatus: phStatus,
                turbidity: turbidity, turbStatus: turbStatus,
              ),
              if (!isDesktop) ...[
                const SizedBox(height: 32),
                _buildSectionHeader('History Logs', isActive: true),
                const SizedBox(height: 16),
                _buildHistoryLogs(),
              ]
            ],
          );

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: SingleChildScrollView(padding: const EdgeInsets.all(32.0), child: mainContent)),
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: Colors.grey.shade200))),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('History Logs', isActive: true),
                          const SizedBox(height: 16),
                          _buildHistoryLogs(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: mainContent);
        },
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Overview", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text("Live sensor feeds and automated action recommendations.", style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400)),
      ],
    );
  }

  Widget _buildGoNoGoCard(Map<String, dynamic> assessment) {
    Color mainColor = assessment['color'];
    Color bgColor = mainColor.withOpacity(0.1);
    
    String subtext = assessment['status'].contains('GO WITH CAUTION') 
        ? 'One parameter is near limits. Proceed with visual checks.'
        : assessment['status'].contains('NO-GO') 
            ? 'Water quality conditions have halted release protocols.' 
            : 'All water parameters are strictly within physiological thresholds.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mainColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRE-RELEASE RECOMMENDATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: mainColor)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(assessment['icon'], color: mainColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  assessment['status'], 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: mainColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtext, style: TextStyle(fontSize: 14, color: mainColor.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool isActive}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.wifi_tethering, size: 12, color: Color(0xFF166534)), // Changed icon to represent live connection
              SizedBox(width: 4),
              Text('LIVE SYNC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
            ]),
          )
      ],
    );
  }

  Widget _buildSensorGrid({
    required bool isDesktop,
    required double airTemp, required String airStatus,
    required double waterTemp, required String waterStatus,
    required double humidity, required String humStatus,
    required double ph, required String phStatus,
    required double turbidity, required String turbStatus,
  }) {
    return GridView.count(
      crossAxisCount: isDesktop ? 3 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5, 
      children: [
        _buildSensorCard(title: 'Air Temp', value: airTemp.toStringAsFixed(2), unit: '°C', icon: Icons.air, status: airStatus),
        _buildSensorCard(title: 'Water Temp', value: waterTemp.toStringAsFixed(2), unit: '°C', icon: Icons.thermostat_outlined, status: waterStatus),
        _buildSensorCard(title: 'Humidity', value: humidity.toStringAsFixed(2), unit: '%', icon: Icons.water_drop_outlined, status: humStatus),
        _buildSensorCard(title: 'pH Level', value: ph.toStringAsFixed(2), unit: 'pH', icon: Icons.science_outlined, status: phStatus),
        _buildSensorCard(title: 'Turbidity', value: turbidity.toStringAsFixed(2), unit: 'NTU', icon: Icons.visibility_outlined, status: turbStatus),
      ],
    );
  }

  Widget _buildSensorCard({required String title, required String value, required String unit, required IconData icon, required String status}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: const Color(0xFF64748B), size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                decoration: BoxDecoration(color: SensorConstants.getStatusBgColor(status), borderRadius: BorderRadius.circular(12)), 
                child: Text(status, style: TextStyle(color: SensorConstants.getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold))
              ),
            ],
          ),
          Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline, 
            textBaseline: TextBaseline.alphabetic, 
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ]
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryLogs() {
    if (_historyLogs.isEmpty) return const Text("No history data found.");
    final sortedKeys = _historyLogs.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final log = Map<String, dynamic>.from(_historyLogs[sortedKeys[index]] as Map);
        int ts = log['timestamp'] ?? 0;
        DateTime date = DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
        String formattedDateTime = DateFormat('MMM d, yyyy • hh:mm a').format(date);

        String logAir = (log['air_temperature'] ?? log['airTemp'] ?? '--').toString();
        String logHum = (log['humidity'] ?? '--').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle), child: const Icon(Icons.history, color: Color(0xFF64748B), size: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Air: $logAir°C | Hum: $logHum%", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
                    Text(formattedDateTime, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
            ],
          ),
        );
      },
    );
  }
}

class WeatherSummaryCard extends StatefulWidget {
  const WeatherSummaryCard({super.key});
  @override
  State<WeatherSummaryCard> createState() => _WeatherSummaryCardState();
}

class _WeatherSummaryCardState extends State<WeatherSummaryCard> {
  bool _isLoading = true, _hasError = false;
  String _temp = "--", _desc = "--", _wind = "--";
  Timer? _timer;
  final String _apiKey = "06b809ea65b4948afce76db133756173"; 
  final String _city = "Naic,PH";

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    // Weather APIs should still be polled via timer so we don't spam the free tier limit
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) => _fetchWeather());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    if (!mounted) return;
    try {
      final response = await http.get(Uri.parse("https://api.openweathermap.org/data/2.5/weather?q=$_city&units=metric&appid=$_apiKey"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _temp = "${data['main']['temp'].round()}°C";
            _desc = data['weather'][0]['main']; 
            _wind = "${data['wind']['speed']}";
            _isLoading = false; _hasError = false;
          });
        }
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEEE, MMM d, yyyy, h:mm a').format(DateTime.now());
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
      child: _isLoading ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFF0F82A0))))
          : _hasError ? const Text("Weather data unavailable.", style: TextStyle(color: Colors.grey))
          : LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 500;
                Widget locationData = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Naic, Cavite, PH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))), const SizedBox(height: 4), Text(formattedDate, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500))]);
                Widget weatherData = Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud, color: Color(0xFF94A3B8), size: 32), const SizedBox(width: 24), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_temp, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))), Text(_desc, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))]), const SizedBox(width: 32), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_wind, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))), const Text("m/s Wind", style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))])]);
                if (isMobile) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [locationData, const SizedBox(height: 16), weatherData]);
                return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [locationData, weatherData]);
              },
            ),
    );
  }
}