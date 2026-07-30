import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

class HistoricalTrendsTab extends StatefulWidget {
  const HistoricalTrendsTab({super.key});

  @override
  State<HistoricalTrendsTab> createState() => _HistoricalTrendsTabState();
}

class _HistoricalTrendsTabState extends State<HistoricalTrendsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";
  
  StreamSubscription<DatabaseEvent>? _trendsSubscription;
  
  // UI State Matching the Web Dashboard
  String _selectedTimeFilter = '24h'; // Default to 24 hours
  String _selectedParameter = 'waterTemp'; // Default parameter

  // Parameter Configuration Map
  final Map<String, Map<String, dynamic>> _paramConfig = {
    'waterTemp': {'name': 'Water Temperature', 'unit': '°C', 'color': const Color(0xFF0EA5E9)},
    'airTemp': {'name': 'Air Temperature', 'unit': '°C', 'color': const Color(0xFFF59E0B)},
    'humidity': {'name': 'Humidity', 'unit': '%', 'color': const Color(0xFF8B5CF6)},
    'ph': {'name': 'pH Level', 'unit': 'pH', 'color': const Color(0xFF10B981)},
    'turbidity': {'name': 'Turbidity', 'unit': 'NTU', 'color': const Color(0xFF6366F1)},
  };

  @override
  void initState() {
    super.initState();
    _setupRealtimeHistory();
  }

  @override
  void dispose() {
    _trendsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeHistory() {
    _trendsSubscription?.cancel();
    setState(() => _isLoading = true);

    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    
    int limit = _selectedTimeFilter == '24h' ? 300 : 2050; 
    
    _trendsSubscription = db.ref('bantaydagat/readings').limitToLast(limit).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map rawData = event.snapshot.value as Map;
        List<Map<String, dynamic>> updatedLogs = rawData.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
        
        DateTime now = DateTime.now();
        DateTime cutoff = _selectedTimeFilter == '24h' 
            ? now.subtract(const Duration(hours: 24))
            : now.subtract(const Duration(days: 7));

        // Filter out records older than the 24h/7d window
        updatedLogs = updatedLogs.where((log) {
          int ts = int.tryParse(log['timestamp']?.toString() ?? '0') ?? 0;
          if (ts > 0 && ts < 10000000000) ts *= 1000;
          DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
          return date.isAfter(cutoff);
        }).toList();

        // Sort chronologically (oldest first) so the graph plots correctly from left to right
        updatedLogs.sort((a, b) {
          int tsA = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
          int tsB = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
          return tsA.compareTo(tsB); 
        });

        setState(() {
          _logs = updatedLogs;
          _isLoading = false;
        });
      } else {
         setState(() {
          _logs = [];
          _isLoading = false;
        });
      }
    });
  }

  double _getParamValue(Map<String, dynamic> log, String param) {
    dynamic val;
    switch(param) {
      case 'waterTemp': val = log['temperature'] ?? log['waterTemp']; break;
      case 'airTemp': val = log['air_temperature'] ?? log['airTemp']; break;
      case 'humidity': val = log['humidity']; break;
      case 'ph': val = log['ph'] ?? log['pH']; break;
      case 'turbidity': val = log['turbidity']; break;
    }
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderAndFilters(),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF0F82A0))))
          else if (_logs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.monitor_heart_outlined, size: 48, color: Colors.blueGrey.shade200),
                    const SizedBox(height: 16),
                    Text(
                      "No data recorded in the last ${_selectedTimeFilter == '24h' ? '24 hours' : '7 days'}.", 
                      style: const TextStyle(color: Colors.grey)
                    ),
                  ],
                ),
              )
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildChartCard(),
                    const SizedBox(height: 24),
                    _buildStatsSummary(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Historical Trends", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Row(
                children: [
                  _buildTimeChip('24 Hours', '24h'),
                  const SizedBox(width: 8),
                  _buildTimeChip('7 Days', '7d'),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          // Parameter Dropdown exactly like the web
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedParameter,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedParameter = newValue);
                  }
                },
                items: _paramConfig.keys.map<DropdownMenuItem<String>>((String key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: _paramConfig[key]!['color']),
                        const SizedBox(width: 12),
                        Text(_paramConfig[key]!['name']),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String value) {
    bool isSelected = _selectedTimeFilter == value;
    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedTimeFilter = value);
          _setupRealtimeHistory(); 
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F82A0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F82A0) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    Color lineColor = _paramConfig[_selectedParameter]!['color'];
    String unit = _paramConfig[_selectedParameter]!['unit'];

    for (int i = 0; i < _logs.length; i++) {
      double val = _getParamValue(_logs[i], _selectedParameter);
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    // Add padding to Y-axis so graph doesn't hit the ceiling/floor
    if (minY == double.infinity) { minY = 0; maxY = 10; }
    double yPadding = (maxY - minY) * 0.2;
    if (yPadding == 0) yPadding = 1;

    return Container(
      width: double.infinity,
      height: 350,
      padding: const EdgeInsets.only(top: 24, right: 24, left: 8, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LineChart(
        LineChartData(
          minY: minY - yPadding,
          maxY: maxY + yPadding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yPadding > 0 ? yPadding : 1,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  // Only show specific labels to avoid crowding
                  return Center(
                    child: Text(
                      '${value.toStringAsFixed(1)}$unit', 
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final textStyle = TextStyle(color: lineColor, fontWeight: FontWeight.bold, fontSize: 14);
                  
                  int index = touchedSpot.x.toInt();
                  String timeStr = "";
                  if (index >= 0 && index < _logs.length) {
                    int ts = int.tryParse(_logs[index]['timestamp']?.toString() ?? '0') ?? 0;
                    if (ts > 0 && ts < 10000000000) ts *= 1000;
                    timeStr = DateFormat('MMM d, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(ts));
                  }
                  
                  return LineTooltipItem('${touchedSpot.y.toStringAsFixed(2)}$unit\n', textStyle, children: [
                    TextSpan(text: timeStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70))
                  ]);
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    double minVal = double.infinity, maxVal = double.negativeInfinity, sum = 0;
    
    for (var log in _logs) {
      double val = _getParamValue(log, _selectedParameter);
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
      sum += val;
    }
    
    double avgVal = _logs.isEmpty ? 0 : (sum / _logs.length);
    if (minVal == double.infinity) minVal = 0;
    if (maxVal == double.negativeInfinity) maxVal = 0;

    String paramName = _paramConfig[_selectedParameter]!['name'];
    String unit = _paramConfig[_selectedParameter]!['unit'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$paramName Summary", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSummaryBox("Minimum", minVal, unit, const Color(0xFF0F82A0))),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryBox("Average", avgVal, unit, const Color(0xFFF59E0B))),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryBox("Maximum", maxVal, unit, const Color(0xFFEF4444))),
          ],
        )
      ],
    );
  }

  Widget _buildSummaryBox(String label, double value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.grey.shade200)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value.toStringAsFixed(1), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(width: 2),
                Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}