import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../config/sensor_constants.dart';

class TrendsTab extends StatefulWidget {
  const TrendsTab({super.key});

  @override
  State<TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<TrendsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _readings = [];
  
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
  StreamSubscription<DatabaseEvent>? _historySubscription;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  void _fetchData() {
    setState(() => _isLoading = true);
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    
    // Pull enough readings to cover the last 7 days (approx 2000 readings if logging every 5 mins)
    _historySubscription = db.ref('bantaydagat/readings').limitToLast(2500).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map rawData = event.snapshot.value as Map;
        List<Map<String, dynamic>> updatedLogs = rawData.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
        
        DateTime cutoff = DateTime.now().subtract(const Duration(days: 7));

        updatedLogs = updatedLogs.where((log) {
          int ts = int.tryParse(log['timestamp']?.toString() ?? '0') ?? 0;
          if (ts > 0 && ts < 10000000000) ts *= 1000;
          DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
          return date.isAfter(cutoff);
        }).toList();

        setState(() {
          _readings = updatedLogs;
          _isLoading = false;
        });
      } else {
        setState(() {
          _readings = [];
          _isLoading = false;
        });
      }
    });
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // === WHITEBOARD CALENDAR LOGIC ===
  // Groups raw readings into 7 discrete days and assigns a single color/status to each day
  List<Map<String, dynamic>> _generateDailySummary() {
    // 1. Initialize the last 7 days in order (Today first, going backwards)
    List<Map<String, dynamic>> daysList = [];
    DateTime now = DateTime.now();
    
    for (int i = 0; i < 7; i++) {
      DateTime targetDay = now.subtract(Duration(days: i));
      String dateString = DateFormat('EEEE, MMM d').format(targetDay);
      
      daysList.add({
        'dateLabel': i == 0 ? 'TODAY' : (i == 1 ? 'YESTERDAY' : dateString.toUpperCase()),
        'dateString': dateString,
        'targetDay': targetDay,
        'readingsCount': 0,
        'hasDanger': false,
        'hasCaution': false,
      });
    }

    // 2. Sort readings into their respective days
    for (var log in _readings) {
      int ts = int.tryParse(log['timestamp']?.toString() ?? '0') ?? 0;
      if (ts > 0 && ts < 10000000000) ts *= 1000;
      DateTime logDate = DateTime.fromMillisecondsSinceEpoch(ts);
      String logDateString = DateFormat('EEEE, MMM d').format(logDate);

      // Find matching day in our list
      for (var day in daysList) {
        if (day['dateString'] == logDateString) {
          day['readingsCount'] = (day['readingsCount'] as int) + 1;
          
          double air = _parseDouble(log['air_temperature'] ?? log['airTemp']);
          double water = _parseDouble(log['temperature'] ?? log['waterTemp']);
          double hum = _parseDouble(log['humidity']);
          double ph = _parseDouble(log['ph'] ?? log['pH'] ?? 7.8);
          double turb = _parseDouble(log['turbidity']);

          String airStat = SensorConstants.getStatus('airTemp', air);
          String waterStat = SensorConstants.getStatus('waterTemp', water);
          String humStat = SensorConstants.getStatus('humidity', hum);
          String phStat = SensorConstants.getStatus('ph', ph);
          String turbStat = SensorConstants.getStatus('turbidity', turb);

          Map<String, dynamic> assessment = SensorConstants.calculateOverallReleaseStatus([
            airStat, waterStat, humStat, phStat, turbStat
          ]);

          if (assessment['status'].toString().contains('DANGER') || assessment['status'].toString().contains('NO-GO')) {
            day['hasDanger'] = true;
          } else if (assessment['status'].toString().contains('CAUTION')) {
            day['hasCaution'] = true;
          }
          break; // Found the day, move to next log
        }
      }
    }

    // 3. Assign final traffic-light status per day
    for (var day in daysList) {
      if (day['readingsCount'] == 0) {
        day['statusText'] = 'NO DATA';
        day['color'] = Colors.grey.shade400;
        day['icon'] = Icons.help_outline;
      } else if (day['hasDanger'] == true) {
        day['statusText'] = 'DANGER: NO RELEASE';
        day['color'] = const Color(0xFFEF4444); // Solid Red
        day['icon'] = Icons.block;
      } else if (day['hasCaution'] == true) {
        day['statusText'] = 'CAUTION';
        day['color'] = const Color(0xFFF59E0B); // Solid Yellow/Amber
        day['icon'] = Icons.warning_amber_rounded;
      } else {
        day['statusText'] = 'SAFE TO RELEASE';
        day['color'] = const Color(0xFF10B981); // Solid Green
        day['icon'] = Icons.check_circle;
      }
    }

    return daysList;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F82A0)));
    }

    List<Map<String, dynamic>> dailySummary = _generateDailySummary();

    return Container(
      color: const Color(0xFFF1F5F9), // Slightly darker background for contrast
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            color: Colors.white,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("7-Day Water Safety", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                SizedBox(height: 8),
                Text("Quick history of water conditions for releases.", style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: dailySummary.length,
              itemBuilder: (context, index) {
                final day = dailySummary[index];
                bool isToday = index == 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isToday ? day['color'] : Colors.grey.shade200, 
                      width: isToday ? 2 : 1
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Row(
                    children: [
                      // Massive Color Indicator Block on the left
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: (day['color'] as Color).withOpacity(0.15),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15))
                        ),
                        child: Center(
                          child: Icon(day['icon'], color: day['color'], size: 48),
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Simple text information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day['dateLabel'], 
                              style: TextStyle(
                                fontSize: isToday ? 18 : 14, 
                                fontWeight: FontWeight.w900, 
                                color: isToday ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                letterSpacing: 1
                              )
                            ),
                            const SizedBox(height: 4),
                            Text(
                              day['statusText'], 
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.w900, 
                                color: day['color']
                              )
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}