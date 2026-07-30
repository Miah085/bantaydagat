import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../config/sensor_constants.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _alertsFeed = [];
  String _mainBgImagePath = 'assets/images/bg_safe.jpg';
  int _activeCriticalCount = 0;
  
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
  StreamSubscription<DatabaseEvent>? _alertsSubscription;
  StreamSubscription<DatabaseEvent>? _liveSubscription; 
  String? _lastAlertId;

  @override
  void initState() {
    super.initState();
    _setupRealtimeBackgroundSync();
    _setupIncidentStream();
  }

  @override
  void dispose() {
    _alertsSubscription?.cancel();
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

  void _setupIncidentStream() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    
    _alertsSubscription = db.ref('bantaydagat/readings').limitToLast(100).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map<dynamic, dynamic> rawData = event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> sortedLogs = rawData.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
        
        sortedLogs.sort((a, b) {
          int tsA = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
          int tsB = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
          return tsA.compareTo(tsB);
        });

        List<Map<String, dynamic>> newFeed = _generateEventFeed(sortedLogs);
        int criticals = newFeed.where((item) => item['badgeText'] == 'CRITICAL').length;

        if (newFeed.isNotEmpty) {
          var newestAlert = newFeed.first; 
          String topId = "${newestAlert['time']}_${newestAlert['title']}";
          
          if (_lastAlertId != null && _lastAlertId != topId) {
             _triggerDynamicSoundAlert(newestAlert);
          }
          _lastAlertId = topId;
        }

        setState(() {
          _alertsFeed = newFeed;
          _activeCriticalCount = criticals;
          _isLoading = false;
        });
      }
    });
  }

  void _triggerDynamicSoundAlert(Map<String, dynamic> alert) async {
    final prefs = await SharedPreferences.getInstance();
    bool soundEnabled = prefs.getBool('sound_alerts') ?? true;

    if (soundEnabled) {
      String badge = alert['badgeText'];
      
      if (badge == 'CRITICAL') {
        HapticFeedback.heavyImpact();
        FlutterRingtonePlayer().playAlarm(volume: 1.0, looping: false); 
      } else if (badge == 'WARNING') {
        HapticFeedback.mediumImpact();
        FlutterRingtonePlayer().playNotification();
      } else if (badge == 'RESOLVED') {
        HapticFeedback.lightImpact();
        FlutterRingtonePlayer().play(
          android: AndroidSounds.notification,
          ios: IosSounds.glass,
          looping: false,
          volume: 0.6,
        );
      }
    }
  }

  List<Map<String, dynamic>> _generateEventFeed(List<Map<String, dynamic>> logs) {
    List<Map<String, dynamic>> feed = [];
    Map<String, String> lastKnownState = {'airTemp': 'SAFE', 'waterTemp': 'SAFE', 'humidity': 'SAFE', 'ph': 'SAFE', 'turbidity': 'SAFE'};

    for (var log in logs) {
      int ts = int.tryParse(log['timestamp']?.toString() ?? '0') ?? 0;
      if (ts > 0 && ts < 10000000000) ts *= 1000;
      DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
      String timeStr = DateFormat('MMM d • h:mm a').format(date);

      double air = _parseDouble(log['airTemp']);
      double water = _parseDouble(log['waterTemp']);
      double hum = _parseDouble(log['humidity']);
      double ph = _parseDouble(log['pH']);
      double turb = _parseDouble(log['turbidity']);

      void checkThreshold(String name, String brainKey, double val, String unit) {
        String currentState = SensorConstants.getStatus(brainKey, val);
        String prevState = lastKnownState[brainKey]!;

        if (currentState != prevState) {
          String title = '';
          String message = '';
          IconData icon = Icons.info;
          Color color = Colors.grey;
          String badgeText = '';
          bool isPositive = true;

          if (currentState == 'DANGER') {
            title = '$name Critical Breach';
            message = 'Level spiked to ${val.toStringAsFixed(1)}$unit. Release protocol halted.';
            color = const Color(0xFFEF4444); 
            icon = Icons.warning_amber_rounded;
            badgeText = 'CRITICAL';
            isPositive = false;
          } else if (currentState == 'CAUTION') {
            title = '$name Warning';
            message = 'Level shifted to ${val.toStringAsFixed(1)}$unit. Visual inspection required.';
            color = const Color(0xFFF59E0B); 
            icon = Icons.error_outline;
            badgeText = 'WARNING';
            isPositive = false;
          } else if (currentState == 'SAFE' && (prevState == 'DANGER' || prevState == 'CAUTION')) {
            title = '$name Stabilized';
            message = 'Returned to safe baseline (${val.toStringAsFixed(1)}$unit). Sanctuary secure.';
            color = const Color(0xFF10B981); 
            icon = Icons.check_circle_outline;
            badgeText = 'RESOLVED';
            isPositive = true;
          }

          if (title.isNotEmpty) {
            feed.add({'title': title, 'message': message, 'time': timeStr, 'color': color, 'icon': icon, 'badgeText': badgeText, 'isPositive': isPositive});
          }
          lastKnownState[brainKey] = currentState;
        }
      }

      checkThreshold('Air Temp', 'airTemp', air, '°C');
      checkThreshold('Water Temp', 'waterTemp', water, '°C');
      checkThreshold('Humidity', 'humidity', hum, '%');
      checkThreshold('pH Level', 'ph', ph, '');
      checkThreshold('Turbidity', 'turbidity', turb, ' NTU');
    }

    feed.insert(0, {
      'title': 'Tactical Telemetry Online', 
      'message': 'Naic coastal monitoring sensors linked successfully.', 
      'time': DateFormat('MMM d • h:mm a').format(DateTime.now()), 
      'color': const Color(0xFF3B82F6), 
      'icon': Icons.security,
      'badgeText': 'SYSTEM',
      'isPositive': true
    });

    return feed.reversed.toList();
  }

  Color _getStrictStatusColor(String status) {
    String s = status.toUpperCase();
    if (s.contains('SAFE') || s == 'GO') return const Color(0xFF10B981); 
    if (s.contains('CAUTION') || s.contains('WARNING')) return const Color(0xFFF59E0B); 
    if (s.contains('DANGER') || s.contains('NO-GO')) return const Color(0xFFEF4444); 
    return const Color(0xFF94A3B8); 
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
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
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
                  padding: const EdgeInsets.fromLTRB(16.0, 120.0, 16.0, 120.0),
                  itemCount: _alertsFeed.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildTacticalHeader();
                    return _buildTacticalIncidentCard(_alertsFeed[index - 1]);
                  },
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildTacticalHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // FIX: Wrapped header text in Expanded so it never pushes the Threat Badge off screen
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Incident Feed", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))])),
                SizedBox(height: 4),
                // FIX: Shortened description text to prevent overcrowding
                Text("Coastal Security Log", style: TextStyle(fontSize: 14, color: Colors.white70, shadows: [Shadow(color: Colors.black45, blurRadius: 6)])),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _activeCriticalCount > 0 ? const Color(0xFFEF4444).withOpacity(0.85) : const Color(0xFF10B981).withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)]
            ),
            child: Row(
              children: [
                Icon(_activeCriticalCount > 0 ? Icons.warning_rounded : Icons.verified_user, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _activeCriticalCount > 0 ? "$_activeCriticalCount THREATS" : "SECURE", 
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTacticalIncidentCard(Map<String, dynamic> alert) {
    bool isCritical = alert['badgeText'] == 'CRITICAL';
    Color pillColor = alert['color'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isCritical ? pillColor : Colors.white.withOpacity(0.2), width: isCritical ? 2.0 : 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: pillColor.withOpacity(0.25), shape: BoxShape.circle, border: Border.all(color: pillColor.withOpacity(0.5))),
                    child: Icon(alert['icon'], color: pillColor, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(alert['title'], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isCritical ? pillColor : Colors.white, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
                            ),
                            // FIX: Added horizontal spacing buffer to prevent badge from touching the text
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: pillColor.withOpacity(0.25), borderRadius: BorderRadius.circular(8), border: Border.all(color: pillColor.withOpacity(0.6))),
                              child: Text(alert['badgeText'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: pillColor, letterSpacing: 0.8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(alert['message'], style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4, shadows: [Shadow(color: Colors.black45, blurRadius: 2)])),
                        const SizedBox(height: 8),
                        Text(alert['time'], style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}