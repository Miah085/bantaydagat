import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class EnvironmentalDataTab extends StatelessWidget {
  const EnvironmentalDataTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/"; 
    
    // FIXED: Point to the new nested readings folder and grab the latest 1
    final Query liveQuery = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: databaseUrl
    ).ref('bantaydagat/readings').limitToLast(1); 

    return StreamBuilder(
      stream: liveQuery.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F82A0)), 
          );
        }

        double airTemp = 0.0;
        double waterTemp = 0.0;
        double humidity = 0.0;
        double ph = 7.0;
        double turbidity = 0.0;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          // FIXED: Peel off the Push ID wrapper (-Osf...) just like the dashboard
          final Map rawWrapper = snapshot.data!.snapshot.value as Map;
          final Map latestEntry = rawWrapper.values.first as Map; 
          final data = Map<String, dynamic>.from(latestEntry);
          
          // FIXED: Use the exact camelCase spellings from the database
          airTemp = (data['airTemp'] ?? 0.0).toDouble();
          waterTemp = (data['waterTemp'] ?? 0.0).toDouble();
          humidity = (data['humidity'] ?? 0.0).toDouble();
          ph = (data['pH'] ?? 7.0).toDouble();
          turbidity = (data['turbidity'] ?? 0.0).toDouble();
        }

        bool isAirSafe = airTemp <= 32.0;
        bool isWaterSafe = waterTemp >= 25.0 && waterTemp <= 30.0;
        bool isPhSafe = ph >= 6.5 && ph <= 8.5;
        bool isTurbiditySafe = turbidity < 5.0;

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              "Current Environmental Metrics",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              "Detailed view of live factors impacting local Pawikan hatcheries.",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            _buildEnvironmentalDetailCard(
              title: "Air Temperature",
              value: "${airTemp.toStringAsFixed(1)} °C",
              status: isAirSafe ? "OPTIMAL" : "CAUTION",
              statusColor: isAirSafe ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              icon: Icons.air,
              description: "Monitors ambient atmospheric heat directly surrounding hatchery nests.",
            ),
            _buildEnvironmentalDetailCard(
              title: "Water Temperature",
              value: "${waterTemp.toStringAsFixed(1)} °C",
              status: isWaterSafe ? "OPTIMAL" : "CAUTION",
              statusColor: isWaterSafe ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              icon: Icons.thermostat_outlined,
              description: "Critical variable determining incubation safety and ecosystem release readiness.",
            ),
            _buildEnvironmentalDetailCard(
              title: "Relative Humidity",
              value: "${humidity.toStringAsFixed(0)} %",
              status: "OPTIMAL",
              statusColor: const Color(0xFF2E7D32),
              icon: Icons.water_drop_outlined,
              description: "Tracks airborne moisture content affecting coastal sand environment equilibrium.",
            ),
            _buildEnvironmentalDetailCard(
              title: "Water pH Level",
              value: "${ph.toStringAsFixed(1)} pH",
              status: isPhSafe ? "OPTIMAL" : "DANGER",
              statusColor: isPhSafe ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              icon: Icons.science_outlined,
              description: "Measures acidity/alkalinity balance. Drastic shifts jeopardize hatchling hydration.",
            ),
            _buildEnvironmentalDetailCard(
              title: "Water Turbidity",
              value: "${turbidity.toStringAsFixed(1)} NTU",
              status: isTurbiditySafe ? "OPTIMAL" : "DANGER",
              statusColor: isTurbiditySafe ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              icon: Icons.visibility_outlined,
              description: "Evaluates suspended particles and clarity levels to diagnose recent run-offs.",
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnvironmentalDetailCard({
    required String title, required String value, required String status,
    required Color statusColor, required IconData icon, required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200), 
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF0F82A0), size: 22),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(thickness: 0.5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(description, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.4))),
              const SizedBox(width: 16),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor)),
            ],
          ),
        ],
      ),
    );
  }
}