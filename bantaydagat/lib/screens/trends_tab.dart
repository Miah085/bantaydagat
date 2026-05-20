import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TrendsTab extends StatelessWidget {
  const TrendsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historical Water Quality Trends',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 16),
          _buildChartCard('Temperature (°C)', const Color(0xFF1E88E5), _mockTempData()),
          const SizedBox(height: 16),
          _buildChartCard('pH Level', const Color(0xFFFDD835), _mockPhData()),
          const SizedBox(height: 16),
          _buildChartCard('Turbidity (NTU)', const Color(0xFFE53935), _mockTurbidityData()),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Color lineColor, List<FlSpot> spots) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF546E7A)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}:00', style: TextStyle(color: Colors.grey.shade500, fontSize: 10));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: TextStyle(color: Colors.grey.shade500, fontSize: 10));
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
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mock data functions (X = hour, Y = value)
  List<FlSpot> _mockTempData() => const [
    FlSpot(0, 26), FlSpot(4, 27.5), FlSpot(8, 28), FlSpot(12, 29.5),
    FlSpot(16, 28), FlSpot(20, 26.5), FlSpot(24, 25),
  ];
  List<FlSpot> _mockPhData() => const [
    FlSpot(0, 7.0), FlSpot(4, 7.1), FlSpot(8, 7.3), FlSpot(12, 7.5),
    FlSpot(16, 7.4), FlSpot(20, 7.2), FlSpot(24, 7.1),
  ];
  List<FlSpot> _mockTurbidityData() => const [
    FlSpot(0, 2.1), FlSpot(4, 5.5), FlSpot(8, 8.2), FlSpot(12, 6.0),
    FlSpot(16, 3.5), FlSpot(20, 2.5), FlSpot(24, 2.0),
  ];
}