import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'login_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushNotifications = true;
  bool _soundAlerts = true;

  // Node Status Tracking
  DateTime? _lastSeen;
  StreamSubscription<DatabaseEvent>? _nodeSubscription;
  Timer? _statusTimer;
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";

  @override
  void initState() {
    super.initState();
    _loadSettings(); 
    _trackNodeStatus();
    // Re-evaluate node status every minute just in case the node dies while looking at the screen
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {}); 
    });
  }

  @override
  void dispose() {
    _nodeSubscription?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _soundAlerts = prefs.getBool('sound_alerts') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _trackNodeStatus() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    _nodeSubscription = db.ref('bantaydagat/readings').limitToLast(1).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map rawWrapper = event.snapshot.value as Map;
        final latestData = rawWrapper.values.first as Map;
        
        int ts = int.tryParse(latestData['timestamp']?.toString() ?? '0') ?? 0;
        if (ts > 0 && ts < 10000000000) ts *= 1000;
        
        setState(() {
          _lastSeen = DateTime.fromMillisecondsSinceEpoch(ts);
        });
      }
    });
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false, 
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
    // Determine overall connection status based on node status
    bool isNodeOnline = _lastSeen != null && DateTime.now().difference(_lastSeen!).inMinutes < 10;

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
            color: isNodeOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isNodeOnline ? 'CONNECTED TO NODE' : 'DISCONNECTED FROM NODE',
            style: TextStyle(
              color: isNodeOnline ? const Color(0xFF2E7D32) : const Color(0xFFC62828), 
              fontSize: 12, 
              fontWeight: FontWeight.bold
            ),
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
            activeTrackColor: const Color(0xFF0F82A0),
            activeThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
            title: const Text('Danger Alerts (Push)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text('Receive notifications for critical water levels', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            value: _pushNotifications,
            onChanged: (bool value) async {
              setState(() => _pushNotifications = value);
              _saveSetting('push_notifications', value); 
              
              // THE FIX: Actually tell the Firebase Cloud Messaging server to subscribe/unsubscribe
              if (value) {
                await FirebaseMessaging.instance.subscribeToTopic('emergency_alerts');
                debugPrint("Subscribed to emergency_alerts");
              } else {
                await FirebaseMessaging.instance.unsubscribeFromTopic('emergency_alerts');
                debugPrint("Unsubscribed from emergency_alerts");
              }
            },
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          SwitchListTile(
            activeTrackColor: const Color(0xFF0F82A0),
            activeThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
            title: const Text('Sound Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text('Play loud alarm on critical danger', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            value: _soundAlerts,
            onChanged: (bool value) {
              setState(() => _soundAlerts = value);
              _saveSetting('sound_alerts', value); 
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemCard() {
    // If the last ping was more than 10 minutes ago, the ESP32 is offline/dead
    bool isOnline = _lastSeen != null && DateTime.now().difference(_lastSeen!).inMinutes < 10;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(Icons.memory, color: isOnline ? const Color(0xFF546E7A) : const Color(0xFFC62828)),
        title: const Text('ESP32 Sensor Node', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'ONLINE' : 'OFFLINE', 
                style: TextStyle(
                  color: isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626), 
                  fontWeight: FontWeight.bold,
                  fontSize: 11
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout, 
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