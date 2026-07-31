import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:async';

import '../config/sensor_constants.dart';

class TrendsTab extends StatefulWidget {
  const TrendsTab({super.key});

  @override
  State<TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<TrendsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _weeklyData = [];
  String _mainBgImagePath = 'assets/images/bg_safe.jpg';

  StreamSubscription<DatabaseEvent>? _historySubscription;
  StreamSubscription<DatabaseEvent>? _liveSubscription; 
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";

  @override
  void initState() {
    super.initState();
    _setupRealtimeBackgroundSync();
    _fetchWeeklyHistory();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _liveSubscription?.cancel();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  void _setupRealtimeBackgroundSync() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    _liveSubscription = db.ref('bantaydagat/latest').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        double airTemp = _parseDouble(data['airTemp']);
        double waterTemp = _parseDouble(data['waterTemp']);
        double humidity = _parseDouble(data['humidity']);
        double ph = _parseDouble(data['pH']);
        double turbidity = _parseDouble(data['turbidity']);

        String airStatus = SensorConstants.getStatus('airTemp', airTemp);
        String waterStatus = SensorConstants.getStatus('waterTemp', waterTemp);
        String humStatus = SensorConstants.getStatus('humidity', humidity);
        String phStatus = SensorConstants.getStatus('ph', ph);
        String turbStatus = SensorConstants.getStatus('turbidity', turbidity);

        Map<String, dynamic> assessment = SensorConstants.calculateOverallReleaseStatus([
          airStatus, waterStatus, humStatus, phStatus, turbStatus
        ]);
        
        Color statusColor = _getStrictStatusColor(assessment['status'].toString());
        String newBg = 'assets/images/bg_safe.jpg';
        
        if (statusColor == const Color(0xFFEF4444)) {
          newBg = 'assets/images/bg_danger.png';
        } else if (statusColor == const Color(0xFFF59E0B)) {
          newBg = 'assets/images/bg_caution.png';
        }

        setState(() {
          _mainBgImagePath = newBg;
        });
      }
    });
  }

  void _fetchWeeklyHistory() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    
    _historySubscription = db.ref('bantaydagat/readings')
        .orderByChild('timestamp')
        .limitToLast(100)
        .onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map<dynamic, dynamic> rawData = event.snapshot.value as Map<dynamic, dynamic>;
        _processWeeklyData(rawData);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _processWeeklyData(Map<dynamic, dynamic> rawData) {
    List<Map<String, dynamic>> allReadings = [];
    
    rawData.forEach((key, value) {
      allReadings.add(Map<String, dynamic>.from(value));
    });

    allReadings.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

    List<Map<String, dynamic>> processedDays = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      DateTime targetDate = now.subtract(Duration(days: i));
      String dateString = DateFormat('yyyy-MM-dd').format(targetDate);
      
      var readingForDay = allReadings.cast<Map<String, dynamic>?>().firstWhere((reading) {
        if (reading == null || reading['timestamp'] == null) return false;
        DateTime readingDate = DateTime.fromMillisecondsSinceEpoch(reading['timestamp']);
        return DateFormat('yyyy-MM-dd').format(readingDate) == dateString;
      }, orElse: () => null);

      if (readingForDay != null) {
        processedDays.add({'date': targetDate, 'hasData': true, 'data': readingForDay});
      } else {
        processedDays.add({'date': targetDate, 'hasData': false});
      }
    }

    setState(() {
      _weeklyData = processedDays;
      _isLoading = false;
    });
  }

  Color _getStrictStatusColor(String status) {
    String s = status.toUpperCase();
    if (s.contains('SAFE') || s == 'GO') return const Color(0xFF10B981); 
    if (s.contains('CAUTION') || s.contains('WARNING')) return const Color(0xFFF59E0B); 
    if (s.contains('DANGER') || s.contains('NO-GO')) return const Color(0xFFEF4444); 
    return const Color(0xFF94A3B8); 
  }

  String _formatDayHeader(DateTime date) {
    DateTime now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return "TODAY";
    if (date.year == now.year && date.month == now.month && date.day == now.day - 1) return "YESTERDAY";
    return DateFormat('EEEE, MMM d').format(date).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Container(
              key: ValueKey<String>(_mainBgImagePath),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                image: _isLoading 
                  ? null 
                  : DecorationImage(
                      image: AssetImage(_mainBgImagePath),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                    ),
              ),
            ),
          ),
        ),
        
        RepaintBoundary(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16.0, 110.0, 16.0, 110.0),
                  itemCount: _weeklyData.length + 1, 
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildHeader();
                    return _buildHistoryCard(_weeklyData[index - 1]);
                  },
              ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Weekly Trends", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))])),
          SizedBox(height: 4),
          Text("Quick history of water conditions for releases.", style: TextStyle(fontSize: 15, color: Colors.white70, shadows: [Shadow(color: Colors.black45, blurRadius: 6)])),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> dayData) {
    bool hasData = dayData['hasData'];
    DateTime date = dayData['date'];
    String dayHeader = _formatDayHeader(date);

    if (!hasData) return _buildNoDataCard(dayHeader);

    Map<String, dynamic> data = dayData['data'];
    
    double airTemp = _parseDouble(data['airTemp']);
    double waterTemp = _parseDouble(data['waterTemp']);
    double humidity = _parseDouble(data['humidity']);
    double ph = _parseDouble(data['pH']);
    double turbidity = _parseDouble(data['turbidity']);

    String airStatus = SensorConstants.getStatus('airTemp', airTemp);
    String waterStatus = SensorConstants.getStatus('waterTemp', waterTemp);
    String humStatus = SensorConstants.getStatus('humidity', humidity);
    String phStatus = SensorConstants.getStatus('ph', ph);
    String turbStatus = SensorConstants.getStatus('turbidity', turbidity);

    Map<String, dynamic> assessment = SensorConstants.calculateOverallReleaseStatus([
      airStatus, waterStatus, humStatus, phStatus, turbStatus
    ]);

    Color statusColor = _getStrictStatusColor(assessment['status']);
    IconData statusIcon = Icons.check_circle;
    String cardBgImage = 'assets/images/bg_safe.jpg';
    
    if (statusColor == const Color(0xFFEF4444)) {
      statusIcon = Icons.block;
      cardBgImage = 'assets/images/bg_danger.png';
    } else if (statusColor == const Color(0xFFF59E0B)) {
      statusIcon = Icons.warning_amber_rounded;
      cardBgImage = 'assets/images/bg_caution.png';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: AssetImage(cardBgImage), fit: BoxFit.cover),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), 
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55), 
                border: Border.all(color: statusColor.withOpacity(0.6), width: 2.0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 70,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        border: Border(right: BorderSide(color: statusColor.withOpacity(0.5), width: 1)),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.3),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 12)]
                          ),
                          child: Icon(statusIcon, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dayHeader, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 1.0)),
                            const SizedBox(height: 4),
                            Text(
                              assessment['status'].toString().replaceAll('NO-GO:', '').trim(), 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: statusColor, shadows: const [Shadow(color: Colors.black, blurRadius: 4)])
                            ),
                            const SizedBox(height: 12),
                            // --- RESPONSIVENESS FIX: Swapped Row for Wrap ---
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _buildMiniSensor(Icons.thermostat, waterTemp, '°C', _getStrictStatusColor(waterStatus)),
                                _buildMiniSensor(Icons.science, ph, 'pH', _getStrictStatusColor(phStatus)),
                                _buildMiniSensor(Icons.visibility, turbidity, 'NTU', _getStrictStatusColor(turbStatus)),
                              ],
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataCard(String dayHeader) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.white.withOpacity(0.4), size: 36),
                const SizedBox(width: 20),
                // --- RESPONSIVENESS FIX: Added Expanded ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dayHeader, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.6), letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Text("NO DATA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.4))),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSensor(IconData icon, double value, String unit, Color statusColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: statusColor, size: 16),
        const SizedBox(width: 4),
        Text("${value.toStringAsFixed(1)}$unit", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 2)])),
      ],
    );
  }
}