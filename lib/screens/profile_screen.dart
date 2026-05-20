import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mock settings state
  bool _pushNotifications = true;
  bool _soundAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ranger Profile',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildIdentityHeader(),
          const SizedBox(height: 24),
          _buildSectionHeader('PREFERENCES'),
          _buildSettingsCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('SYSTEM STATUS'),
          _buildSystemCard(),
          const SizedBox(height: 32),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader() {
    return Column(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFF0F82A0),
          radius: 40,
          child: Text('R', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Active Ranger',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 4),
        Text(
          'Pawikan Sanctuary • Brgy. Labac',
          style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'CONNECTED',
            style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.2),
      ),
    );
  }

 Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SwitchListTile(
            // Explicit colors to prevent disappearing
            activeTrackColor: const Color(0xFF0F82A0),
            activeColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
            
            title: const Text('Danger Alerts (Push)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text('Receive notifications for critical water levels', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            value: _pushNotifications,
            onChanged: (bool value) {
              setState(() => _pushNotifications = value);
            },
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          SwitchListTile(
            // Explicit colors to prevent disappearing
            activeTrackColor: const Color(0xFF0F82A0),
            activeColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
            
            title: const Text('Sound Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text('Play alarm sound on critical danger', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            value: _soundAlerts,
            onChanged: (bool value) {
              setState(() => _soundAlerts = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.memory, color: Color(0xFF546E7A)),
            title: const Text('ESP32 Sensor Node', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            trailing: const Text('Online', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ListTile(
            leading: const Icon(Icons.update, color: Color(0xFF546E7A)),
            title: const Text('Data Sync Rate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            trailing: Text('Every 3 seconds', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          // TODO: Implement Firebase Auth signOut
        },
        icon: const Icon(Icons.logout, color: Color(0xFFC62828)),
        label: const Text('Log Out', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFFEF9A9A)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFFFFEBEE),
        ),
      ),
    );
  }
}