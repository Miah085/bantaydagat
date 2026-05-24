import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class HistoricalTrendsTab extends StatelessWidget {
  const HistoricalTrendsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/"; 
    
    // Pull the last 20 readings to keep the graph clean on a mobile screen
    final Query historyQuery = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: databaseUrl
    ).ref('bantaydagat/readings').limitToLast(20); 

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Historical Water Quality Trends", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text("Swipe down to view 24-hour sensor timelines.", style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade400)),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder(
            stream: historyQuery.onValue, 
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0F82A0))); 
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: Text("No historical records found.")); 
              }

              final Map<dynamic, dynamic> rawLogs = snapshot.data!.snapshot.value as Map; 
              
              // Sort oldest to newest so the graph flows left to right
              final sortedKeys = rawLogs.keys.toList()..sort((a, b) {
                final logA = rawLogs[a] as Map;
                final logB = rawLogs[b] as Map;
                return (logA['timestamp'] ?? 0).compareTo(logB['timestamp'] ?? 0);
              });

              // Prepare lists for plotting (X = index, Y = sensor value)
              List<FlSpot> airSpots = [];
              List<FlSpot> waterSpots = [];
              List<FlSpot> humSpots = [];
              List<FlSpot> phSpots = [];
              List<FlSpot> turbSpots = [];
              List<String> timeLabels = [];

              for (int i = 0; i < sortedKeys.length; i++) {
                final log = Map<String, dynamic>.from(rawLogs[sortedKeys[i]] as Map);
                
                int ts = log['timestamp'] ?? 0;
                DateTime date = DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
                timeLabels.add(DateFormat('hh:mm a').format(date)); // X-axis labels

                airSpots.add(FlSpot(i.toDouble(), (log['airTemp'] ?? 0.0).toDouble()));
                waterSpots.add(FlSpot(i.toDouble(), (log['waterTemp'] ?? 0.0).toDouble()));
                humSpots.add(FlSpot(i.toDouble(), (log['humidity'] ?? 0.0).toDouble()));
                phSpots.add(FlSpot(i.toDouble(), (log['pH'] ?? 0.0).toDouble()));
                turbSpots.add(FlSpot(i.toDouble(), (log['turbidity'] ?? 0.0).toDouble()));
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                children: [
                  _buildGraphCard("Air Temperature (°C)", airSpots, timeLabels, 15, 45, Colors.orange, []),
                  
                  _buildGraphCard("Water Temperature (°C)", waterSpots, timeLabels, 20, 40, Colors.blue, [
                    HorizontalLine(y: 30, color: Colors.orange.withOpacity(0.8), dashArray: [5, 5], strokeWidth: 1.5, label: HorizontalLineLabel(show: true, labelResolver: (_) => "Caution (30°C)")),
                    HorizontalLine(y: 25, color: Colors.green.withOpacity(0.8), dashArray: [5, 5], strokeWidth: 1.5, label: HorizontalLineLabel(show: true, labelResolver: (_) => "Safe Min (25°C)")),
                  ]),
                  
                  _buildGraphCard("Humidity (%)", humSpots, timeLabels, 40, 100, Colors.teal, []),
                  
                  _buildGraphCard("pH Level", phSpots, timeLabels, 4, 12, Colors.purple, [
                    HorizontalLine(y: 8.5, color: Colors.red.withOpacity(0.8), dashArray: [5, 5], strokeWidth: 1.5, label: HorizontalLineLabel(show: true, labelResolver: (_) => "Max (8.5)")),
                    HorizontalLine(y: 6.5, color: Colors.red.withOpacity(0.8), dashArray: [5, 5], strokeWidth: 1.5, label: HorizontalLineLabel(show: true, labelResolver: (_) => "Min (6.5)")),
                  ]),
                  
                  _buildGraphCard("Turbidity (NTU)", turbSpots, timeLabels, 0, 20, Colors.brown, [
                    HorizontalLine(y: 5.0, color: Colors.red.withOpacity(0.8), dashArray: [5, 5], strokeWidth: 1.5, label: HorizontalLineLabel(show: true, labelResolver: (_) => "Danger (>5.0)")),
                  ]),
                  
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // HELPER: Generates a beautiful white card with a line chart inside
  // HELPER: Generates a beautiful white card with a line chart inside
  Widget _buildGraphCard(String title, List<FlSpot> spots, List<String> timeLabels, double minY, double maxY, Color lineColor, List<HorizontalLine> thresholdLines) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20.0),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50))),
            const SizedBox(height: 24),
            SizedBox(
              height: 180, // Height of the graph
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  minX: 0,
                  maxX: (spots.length - 1).toDouble().clamp(0, double.infinity),
                  
                  // --- THE FIX IS RIGHT HERE ---
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.blueGrey.shade800,
                      fitInsideHorizontally: true, // Forces edge tooltips to shift inward
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            spot.y.toStringAsFixed(1),
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  // ------------------------------

                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false), 
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withOpacity(0.1), 
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(horizontalLines: thresholdLines), 
                  gridData: FlGridData(
                    show: true, 
                    drawVerticalLine: false, 
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (spots.length > 5) ? (spots.length / 4).floorToDouble() : 1, 
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < timeLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(timeLabels[index], style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toStringAsFixed(0), style: TextStyle(color: Colors.grey.shade500, fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false), 
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}