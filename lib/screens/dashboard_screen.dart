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
    
    _liveSubscription = db.ref('bantaydagat/latest').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() {
          _latestData = Map<String, dynamic>.from(event.snapshot.value as Map);
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

  Widget _buildGlassCard({required Widget child, Color? borderColor, double borderWidth = 1.5}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55), 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.25), 
              width: borderWidth
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

    double airTemp = _parseDouble(_latestData['airTemp']);
    double waterTemp = _parseDouble(_latestData['waterTemp']);
    double humidity = _parseDouble(_latestData['humidity']);
    double ph = _parseDouble(_latestData['pH']); 
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

    return Stack(
      children: [
        // THE FIX: RepaintBoundary completely stops the background from recalculating
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800), 
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Container(
              key: ValueKey<String>(bgImagePath), 
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                image: DecorationImage(
                  image: AssetImage(bgImagePath),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.15), BlendMode.darken),
                ),
              ),
            ),
          ),
        ),
        
        // THE FIX: RepaintBoundary stops the scroll view from dropping frames
        RepaintBoundary(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16.0, 110.0, 16.0, 110.0), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildPageHeader(),
                      const SizedBox(height: 32),
                      _buildFloatingTurtleStatus(mainStatusColor, actionText, assessment['message'], turtleImagePath),
                      const SizedBox(height: 36),
                      const WeatherSummaryCard(),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('LIVE SENSOR CHECK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white60, letterSpacing: 1.2)),
                          _buildHelpGuideButton(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildResponsiveBubbleCluster(
                        maxWidth: constraints.maxWidth,
                        airTemp: airTemp, airStatus: airStatus,
                        waterTemp: waterTemp, waterStatus: waterStatus,
                        humidity: humidity, humStatus: humStatus,
                        ph: ph, phStatus: phStatus,
                        turbidity: turbidity, turbStatus: turbStatus,
                      ),
                    ],
                  ),
                );
              }
            ),
          ),
        ),
      ],
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
            const Text("Live Tracker", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))])),
            const SizedBox(height: 4),
            Text("Current sea conditions in Naic.", style: TextStyle(fontSize: 14, color: Colors.white70, shadows: [Shadow(color: Colors.black45, blurRadius: 6)])),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5), 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.6), width: 1.5)
          ),
          child: const Row(children: [
            Icon(Icons.fiber_manual_record, size: 10, color: Color(0xFFEF4444)),
            SizedBox(width: 6),
            Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
          ]),
        )
      ],
    );
  }

  Widget _buildHelpGuideButton() {
    return InkWell(
      onTap: () => _showConciseGuide(context),
      child: _buildGlassCard(
        borderColor: Colors.white.withOpacity(0.2),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.help_outline, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text("Help Guide", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingTurtleStatus(Color statusColor, String title, String subtitle, String turtleImagePath) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.45), 
                blurRadius: 60, 
                spreadRadius: 8
              )
            ]
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              turtleImagePath,
              key: ValueKey<String>(turtleImagePath), 
              height: 170,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          style: TextStyle(
            fontSize: 36, 
            fontWeight: FontWeight.w900, 
            color: statusColor, 
            height: 1.1, 
            letterSpacing: 0.5,
            shadows: const [Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 3))]
          ),
          child: Text(title, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            subtitle, 
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15, 
              color: Colors.white, 
              fontWeight: FontWeight.w600,
              height: 1.3,
              shadows: [Shadow(color: Colors.black, blurRadius: 8)]
            ),
          ),
        )
      ],
    );
  }

  // FIX: This entirely replaces the strict Positioned Stack layout
  Widget _buildResponsiveBubbleCluster({
    required double maxWidth,
    required double airTemp, required String airStatus,
    required double waterTemp, required String waterStatus,
    required double humidity, required String humStatus,
    required double ph, required String phStatus,
    required double turbidity, required String turbStatus,
  }) {
    // Calculates proportional bubble sizes based on phone width to prevent overlapping
    double largeSize = maxWidth * 0.40;
    double mediumSize = maxWidth * 0.28;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 16,
      children: [
        _buildCleanBubble(title: 'Air Temp', value: airTemp, unit: '°C', icon: Icons.air, status: airStatus, size: largeSize),
        _buildCleanBubble(title: 'Water Temp', value: waterTemp, unit: '°C', icon: Icons.thermostat, status: waterStatus, size: largeSize),
        _buildCleanBubble(title: 'pH Level', value: ph, unit: 'pH', icon: Icons.science, status: phStatus, size: mediumSize),
        _buildCleanBubble(title: 'Humidity', value: humidity, unit: '%', icon: Icons.water_drop, status: humStatus, size: mediumSize),
        _buildCleanBubble(title: 'Turbidity', value: turbidity, unit: 'NTU', icon: Icons.visibility, status: turbStatus, size: mediumSize),
      ],
    );
  }

  // FIX: Removed the white glare layer, keeping only clean frosted glass
  Widget _buildCleanBubble({
    required String title, required double value, required String unit, 
    required IconData icon, required String status, required double size
  }) {
    Color statusColor = _getStrictStatusColor(status);
    bool isSafe = statusColor == const Color(0xFF10B981);
    String badgeText = status.toUpperCase().replaceAll('NO-GO', '').replaceAll('(', '').replaceAll(')', '').trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(isSafe ? 0.2 : 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ]
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withOpacity(0.12),
              border: Border.all(
                color: isSafe ? Colors.white.withOpacity(0.2) : statusColor.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: isSafe ? Colors.white70 : statusColor, size: size * 0.16),
                  SizedBox(height: size * 0.02),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline, 
                    textBaseline: TextBaseline.alphabetic, 
                    children: [
                      Text(
                        value.toStringAsFixed(1), 
                        style: TextStyle(fontSize: size * 0.23, fontWeight: FontWeight.w900, color: Colors.white, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])
                      ),
                      const SizedBox(width: 2),
                      Text(
                        unit, 
                        style: TextStyle(fontSize: size * 0.10, color: Colors.white70, fontWeight: FontWeight.bold)
                      ),
                    ]
                  ),
                  Text(title, style: TextStyle(color: Colors.white70, fontSize: size * 0.09, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  
                  SizedBox(height: size * 0.04),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
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
                      _buildRangeChip("Air Temp", "25-32°C"),
                      _buildRangeChip("Water Temp", "26-31°C"),
                      _buildRangeChip("Humidity", "65-85%"),
                      _buildRangeChip("pH Level", "7.8-8.3"),
                      _buildRangeChip("Turbidity", "< 25 NTU"),
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
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5), 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: _isLoading ? const Center(child: Padding(padding: EdgeInsets.all(4.0), child: CircularProgressIndicator(color: Colors.white)))
              : _hasError ? const Text("Weather data unavailable.", style: TextStyle(color: Colors.white70))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text("Naic, Cavite", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)), 
                        const SizedBox(height: 2), 
                        Text(formattedDate, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))
                      ]
                    ),
                    Row(
                      children: [
                        const Icon(Icons.cloud, color: Colors.white, size: 32), 
                        const SizedBox(width: 10), 
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(_temp, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)), 
                            Text(_desc, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold))
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