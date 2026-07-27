import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart'; // NEW: The loud alarm package

import '../config/sensor_constants.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _alertsFeed = [];
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
  
  StreamSubscription<DatabaseEvent>? _alertsSubscription;
  String? _lastAlertId;

  @override
  void initState() {
    super.initState();
    _setupIncidentStream();
  }

  @override
  void dispose() {
    _alertsSubscription?.cancel();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  void _setupIncidentStream() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    
    // Listen to the last 100 logs to build a solid history of events
    _alertsSubscription = db.ref('bantaydagat/readings').limitToLast(100).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map<dynamic, dynamic> rawData = event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> sortedLogs = rawData.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
        
        // Sort chronologically so we can trace when things broke and when they fixed
        sortedLogs.sort((a, b) {
          int tsA = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
          int tsB = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
          return tsA.compareTo(tsB);
        });

        List<Map<String, dynamic>> newFeed = _generateEventFeed(sortedLogs);
        
        // --- THE PROFILE-CONNECTED ALARM LOGIC ---
        if (newFeed.isNotEmpty) {
          var newestAlert = newFeed.first; 
          String topId = "${newestAlert['time']}_${newestAlert['title']}";
          
          if (_lastAlertId != null && _lastAlertId != topId && newestAlert['isPositive'] == false) {
             _triggerLoudAlarm(newestAlert);
          }
          _lastAlertId = topId;
        }

        setState(() {
          _alertsFeed = newFeed;
          _isLoading = false;
        });
      }
    });
  }

  void _triggerLoudAlarm(Map<String, dynamic> alert) async {
    final prefs = await SharedPreferences.getInstance();
    // Connects directly to the toggle in your Profile Tab
    bool soundEnabled = prefs.getBool('sound_alerts') ?? true;

    if (soundEnabled) {
      if (alert['badgeText'] == 'CRITICAL') {
        HapticFeedback.heavyImpact();
        // This bypasses silent mode on most phones and plays the loud default alarm clock sound
        FlutterRingtonePlayer().playAlarm(volume: 1.0, looping: false); 
      } else if (alert['badgeText'] == 'WARNING') {
        HapticFeedback.mediumImpact();
        // Plays a standard loud notification ping
        FlutterRingtonePlayer().playNotification();
      }
    }
  }

  // Analyzes the history and ONLY returns an item when a sensor crosses a boundary
  List<Map<String, dynamic>> _generateEventFeed(List<Map<String, dynamic>> logs) {
    List<Map<String, dynamic>> feed = [];
    
    Map<String, String> lastKnownState = {
      'airTemp': 'SAFE', 'waterTemp': 'SAFE', 'humidity': 'SAFE', 'ph': 'SAFE', 'turbidity': 'SAFE'
    };

    for (var log in logs) {
      int ts = int.tryParse(log['timestamp']?.toString() ?? '0') ?? 0;
      if (ts > 0 && ts < 10000000000) ts *= 1000;
      DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
      String timeStr = DateFormat('MMM d, yyyy • h:mm a').format(date);

      double air = _parseDouble(log['air_temperature'] ?? log['airTemp']);
      double water = _parseDouble(log['temperature'] ?? log['waterTemp']);
      double hum = _parseDouble(log['humidity']);
      double ph = _parseDouble(log['ph'] ?? log['pH']);
      double turb = _parseDouble(log['turbidity']);

      void checkThreshold(String name, String brainKey, double val, String unit) {
        String currentState = SensorConstants.getStatus(val, brainKey);
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
            message = 'Level spiked to ${val.toStringAsFixed(2)}$unit. Immediate intervention required.';
            color = const Color(0xFFE11D48); // Rose/Red
            icon = Icons.warning_amber_rounded;
            badgeText = 'CRITICAL';
            isPositive = false;
          } else if (currentState == 'CAUTION') {
            title = '$name Warning';
            message = 'Level shifted to ${val.toStringAsFixed(2)}$unit. Monitor closely.';
            color = const Color(0xFFD97706); // Amber/Orange
            icon = Icons.error_outline;
            badgeText = 'WARNING';
            isPositive = false;
          } else if (currentState == 'SAFE' && (prevState == 'DANGER' || prevState == 'CAUTION')) {
            title = '$name Stabilized';
            message = 'Returned to safe baseline (${val.toStringAsFixed(2)}$unit).';
            color = const Color(0xFF059669); // Emerald/Green
            icon = Icons.check_circle_outline;
            badgeText = 'RESOLVED';
            isPositive = true;
          }

          if (title.isNotEmpty) {
            feed.add({
              'title': title,
              'message': message,
              'time': timeStr,
              'color': color,
              'icon': icon,
              'badgeText': badgeText,
              'isPositive': isPositive 
            });
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

    // Add a connection event at the very beginning of the timeline
    feed.insert(0, {
      'title': 'System Stream Initiated', 
      'message': 'Connected to live database. Listening for anomalies.', 
      'time': DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now()), 
      'color': const Color(0xFF3B82F6), 
      'icon': Icons.wifi_tethering,
      'badgeText': 'SYSTEM',
      'isPositive': true
    });

    // Reverse it so the newest event is at the top
    return feed.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9), // Different background color from Dashboard to emphasize separation
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Notification Center", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text("Chronological log of environmental triggers.", style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400)),
              ],
            ),
          ),
          
          // Feed Section
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F82A0)))
                : _alertsFeed.isEmpty 
                    ? const Center(child: Text("No events recorded.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        itemCount: _alertsFeed.length,
                        itemBuilder: (context, index) {
                          return _buildNotificationInboxItem(_alertsFeed[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Looks like an iOS/Android push notification inbox item
  Widget _buildNotificationInboxItem(Map<String, dynamic> alert) {
    bool isCritical = alert['badgeText'] == 'CRITICAL';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // Give critical alerts a faint red border so they pop
        border: Border.all(color: isCritical ? alert['color'].withOpacity(0.5) : Colors.transparent, width: isCritical ? 1.5 : 0),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Pill
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: alert['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(alert['icon'], color: alert['color'], size: 22),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          alert['title'],
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.bold, 
                            color: isCritical ? alert['color'] : const Color(0xFF0F172A)
                          ),
                        ),
                      ),
                      Text(
                        alert['badgeText'],
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: alert['color'], letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert['message'],
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert['time'],
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}