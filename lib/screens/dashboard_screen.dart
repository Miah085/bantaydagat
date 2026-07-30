import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
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
  
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
  StreamSubscription<DatabaseEvent>? _liveSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeStream(); 
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  void _setupRealtimeStream() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    // LOGIC FIX: Forced orderByChild('timestamp') to ensure exact sync with web dashboard.
    _liveSubscription = db.ref('bantaydagat/readings')
        .orderByChild('timestamp')
        .limitToLast(1)
        .onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map rawWrapper = event.snapshot.value as Map;
        setState(() {
          _latestData = Map<String, dynamic>.from(rawWrapper.values.first as Map);
          _isLoading = false;
        });
      }
    });
  }

  Color _getStrictStatusColor(String status) {
    String s = status.toUpperCase();
    if (s.contains('SAFE') || s == 'GO') return const Color(0xFF10B981); 
    if (s.contains('CAUTION') || s.contains('WARNING')) return const Color(0xFFF59E0B); 
    if (s.contains('DANGER') || s.contains('NO-GO')) return const Color(0xFFEF4444); 
    return const Color(0xFF94A3B8); 
  }

  // --- GLASSMORPHISM CARD BUILDER ---
  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5), // Stronger dark tint to guarantee text visibility
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.2), 
              width: 1.5
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // LOGIC FIX: Removed the fake 7.8 fallback. If sensor breaks, it reads 0.0 and correctly flags DANGER.
    double airTemp = _parseDouble(_latestData['air_temperature'] ?? _latestData['airTemp']);
    double waterTemp = _parseDouble(_latestData['temperature'] ?? _latestData['waterTemp']);
    double humidity = _parseDouble(_latestData['humidity']);
    double ph = _parseDouble(_latestData['ph'] ?? _latestData['pH']); 
    double turbidity = _parseDouble(_latestData['turbidity']);

    String airStatus = SensorConstants.getStatus('airTemp', airTemp);
    String waterStatus = SensorConstants.getStatus('waterTemp', waterTemp);
    String humStatus = SensorConstants.getStatus('humidity', humidity);
    String phStatus = SensorConstants.getStatus('ph', ph);
    String turbStatus = SensorConstants.getStatus('turbidity', turbidity);

    Map<String, dynamic> assessment = SensorConstants.calculateOverallReleaseStatus([
      airStatus, waterStatus, humStatus, phStatus, turbStatus
    ]);
    
    Color mainStatusColor = _getStrictStatusColor(assessment['status'].toString());
    
    String actionText = "SAFE TO RELEASE";
    String bgImagePath = 'assets/images/bg_safe.jpg'; 
    String turtleImagePath = 'assets/images/turtle_safe.png';
    
    if (mainStatusColor == const Color(0xFFEF4444)) {
      actionText = "DO NOT RELEASE";
      bgImagePath = 'assets/images/bg_danger.png'; 
      turtleImagePath = 'assets/images/turtle_danger.png'; 
    } else if (mainStatusColor == const Color(0xFFF59E0B)) {
      actionText = "HOLD & CHECK WATER";
      bgImagePath = 'assets/images/bg_caution.png'; 
      turtleImagePath = 'assets/images/turtle_caution.png'; 
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        image: DecorationImage(
          image: AssetImage(bgImagePath),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
        ),
      ),
      // We do NOT use SafeArea here so the background stretches fully behind the transparent app bar
      child: SingleChildScrollView(
        // Massive padding at the top and bottom clears the custom App Bar and Bottom Nav
        padding: const EdgeInsets.fromLTRB(16.0, 120.0, 16.0, 120.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPageHeader(),
            const SizedBox(height: 40),
            
            _buildFloatingTurtleStatus(mainStatusColor, actionText, assessment['message'], turtleImagePath),
            const SizedBox(height: 40),
            
            const WeatherSummaryCard(),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('LIVE SENSOR CHECK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.9), letterSpacing: 1)),
                _buildHelpGuideButton(),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildVisualSensorGrid(
              airTemp: airTemp, airStatus: airStatus,
              waterTemp: waterTemp, waterStatus: waterStatus,
              humidity: humidity, humStatus: humStatus,
              ph: ph, phStatus: phStatus,
              turbidity: turbidity, turbStatus: turbStatus,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Live Tracker", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
            const SizedBox(height: 4),
            Text("Current sea conditions in Naic.", style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.95), shadows: const [Shadow(color: Colors.black87, blurRadius: 8)])),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6), 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.8))
          ),
          child: const Row(children: [
            Icon(Icons.fiber_manual_record, size: 10, color: Color(0xFFEF4444)),
            SizedBox(width: 6),
            Text('LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        )
      ],
    );
  }

  Widget _buildHelpGuideButton() {
    return InkWell(
      onTap: () => _showConciseGuide(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4), 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: Colors.white30)
            ),
            child: const Row(
              children: [
                Icon(Icons.help_outline, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text("Help Guide", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingTurtleStatus(Color statusColor, String title, String subtitle, String turtleImagePath) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.5), 
                blurRadius: 60, 
                spreadRadius: 5
              )
            ]
          ),
          child: Image.asset(
            turtleImagePath,
            height: 180, // Made the turtle larger and more prominent
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        
        Text(
          title, 
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 38, 
            fontWeight: FontWeight.w900, 
            color: statusColor, 
            height: 1.1, 
            letterSpacing: 1,
            shadows: const [Shadow(color: Colors.black, blurRadius: 15, offset: Offset(0, 4))]
          ),
        ),
        const SizedBox(height: 12),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            subtitle, 
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16, 
              color: Colors.white, 
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 10)]
            ),
          ),
        )
      ],
    );
  }

  Widget _buildVisualSensorGrid({
    required double airTemp, required String airStatus,
    required double waterTemp, required String waterStatus,
    required double humidity, required String humStatus,
    required double ph, required String phStatus,
    required double turbidity, required String turbStatus,
  }) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 130, 
      ),
      children: [
        _buildVisualSensorCard(title: 'Air', value: airTemp, unit: '°C', icon: Icons.air, status: airStatus),
        _buildVisualSensorCard(title: 'Water', value: waterTemp, unit: '°C', icon: Icons.thermostat, status: waterStatus),
        _buildVisualSensorCard(title: 'Humid', value: humidity, unit: '%', icon: Icons.water_drop, status: humStatus),
        _buildVisualSensorCard(title: 'pH', value: ph, unit: 'pH', icon: Icons.science, status: phStatus),
        _buildVisualSensorCard(title: 'Turbid', value: turbidity, unit: 'NTU', icon: Icons.visibility, status: turbStatus),
      ],
    );
  }

  Widget _buildVisualSensorCard({required String title, required double value, required String unit, required IconData icon, required String status}) {
    Color statusColor = _getStrictStatusColor(status);
    
    String simpleStatus = "SAFE";
    if (statusColor == const Color(0xFFEF4444)) simpleStatus = "DANGER";
    if (statusColor == const Color(0xFFF59E0B)) simpleStatus = "CAUTION";

    return _buildGlassCard(
      borderColor: simpleStatus != 'SAFE' ? statusColor : Colors.white.withOpacity(0.3),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.85),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2)))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(simpleStatus, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline, 
                  textBaseline: TextBaseline.alphabetic, 
                  children: [
                    Text(
                      value.toStringAsFixed(1), 
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit, 
                      style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)
                    ),
                  ]
                ),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConciseGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.85),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 24),
                  const Text("Quick Action Guide", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text("What the colors mean for turtle releases.", style: TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 24),
                  
                  _buildGuideRow(Icons.check_circle, const Color(0xFF10B981), "GREEN: Safe to Release", "Water is perfect. Proceed immediately."),
                  _buildGuideRow(Icons.warning_amber_rounded, const Color(0xFFF59E0B), "YELLOW: Caution", "One sensor is off. Visually inspect the water before releasing."),
                  _buildGuideRow(Icons.block, const Color(0xFFEF4444), "RED: Do Not Release", "Toxic conditions! Hold turtles in tanks. Immediate danger."),
                  
                  const Divider(height: 32, color: Colors.white24),
                  
                  const Text("Target Safe Ranges", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _buildRangeChip("Air", "25-32°C"),
                      _buildRangeChip("Water", "26-31°C"),
                      _buildRangeChip("Hum", "65-85%"),
                      _buildRangeChip("pH", "7.8-8.3"),
                      _buildRangeChip("Turb", "< 25 NTU"),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Understood", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideRow(IconData icon, Color color, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.5))),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRangeChip(String label, String range) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
      child: Text("$label: $range", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
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
  String _temp = "--", _desc = "--";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
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
      const String apiUrl = "https://api.open-meteo.com/v1/forecast?latitude=14.3025&longitude=120.7617&current=temperature_2m,weather_code,wind_speed_10m&timezone=Asia%2FManila";
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _temp = "${data['current']['temperature_2m'].round()}°C";
            _desc = _getWeatherCondition(data['current']['weather_code']); 
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

  String _getWeatherCondition(int code) {
    switch(code) {
      case 0: return "Clear Sky";
      case 1: return "Mainly Clear";
      case 2: return "Partly Cloudy";
      case 3: return "Overcast";
      case 45: case 48: return "Fog";
      case 51: case 53: case 55: return "Drizzle";
      case 61: case 63: case 65: return "Rain";
      case 80: case 81: case 82: return "Showers";
      case 95: case 96: case 99: return "Storm";
      default: return "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('MMM d, yyyy').format(DateTime.now());
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5), 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: _isLoading ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white)))
              : _hasError ? const Text("Weather data unavailable.", style: TextStyle(color: Colors.white70))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text("Naic, Cavite", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)), 
                        const SizedBox(height: 4), 
                        Text(formattedDate, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold))
                      ]
                    ),
                    Row(
                      children: [
                        const Icon(Icons.cloud, color: Colors.white, size: 36), 
                        const SizedBox(width: 12), 
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(_temp, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)), 
                            Text(_desc, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))
                          ]
                        )
                      ]
                    )
                  ]
                ),
        ),
      ),
    );
  }
}