import 'package:flutter/material.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({Key? key}) : super(key: key);

  // Mock state for the Ranger's view
  final bool isGoRecommendation = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. The Core Mobile Feature: GO / NO-GO Recommendation
          _buildGoNoGoCard(),
          const SizedBox(height: 24),
          
          // 2. Real-Time Readings Section
          const Text(
            'Live Sensor Data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 16),

          // Sensor Grid (Retaining the beautiful web-style cards and sparklines)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.9,
            children: [
              _buildSensorCard(
                title: 'Temperature',
                value: '28.5',
                unit: '°C',
                icon: Icons.cloud_queue,
                status: 'SAFE',
                statusColor: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
              ),
              _buildSensorCard(
                title: 'Humidity',
                value: '65',
                unit: '%',
                icon: Icons.water_drop_outlined,
                status: 'SAFE',
                statusColor: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
              ),
              _buildSensorCard(
                title: 'pH Level',
                value: '7.2',
                unit: 'pH',
                icon: Icons.science_outlined,
                status: 'SAFE',
                statusColor: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
              ),
              _buildSensorCard(
                title: 'Turbidity',
                value: '8.5',
                unit: 'NTU',
                icon: Icons.visibility_outlined,
                status: 'CAUTION', // Example of a non-safe status matching web visual logic
                statusColor: const Color(0xFFE65100), // Orange text
                bgColor: const Color(0xFFFFF3E0), // Light orange bg
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Data updates every 3 seconds. Last updated: Just now',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  // The focused GO / NO-GO feature tailored for the Ranger
  Widget _buildGoNoGoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: isGoRecommendation ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGoRecommendation ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A), 
          width: 2
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            'PRE-RELEASE RECOMMENDATION',
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w700, 
              letterSpacing: 1.2,
              color: isGoRecommendation ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGoRecommendation ? 'GO' : 'NO-GO',
            style: TextStyle(
              fontSize: 64, // Massive text so the ranger can see it clearly outdoors
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: isGoRecommendation ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGoRecommendation 
              ? 'Water parameters are within safe thresholds.'
              : 'Unsafe conditions detected. Do not release.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isGoRecommendation ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // Sensor cards utilizing the styling from your web dashboard screenshots
  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required String status,
    required Color statusColor,
    required Color bgColor,
  }) {
    return Container(
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
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: const Color(0xFF546E7A), size: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(title, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Text(unit, style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400)),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Keep the web-style sparkline curve at the bottom
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: CustomPaint(
              size: const Size(double.infinity, 15),
              painter: SparklinePainter(color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Updated CustomPainter to accept colors dynamically based on safety status
class SparklinePainter extends CustomPainter {
  final Color color;

  SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}