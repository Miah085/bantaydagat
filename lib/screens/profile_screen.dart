import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';

import 'login_screen.dart'; 
import '../config/sensor_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _pushNotifications = true;
  bool _soundAlerts = true;

  DateTime? _lastSeen;
  StreamSubscription<DatabaseEvent>? _nodeSubscription;
  Timer? _statusTimer;
  String _bgImagePath = 'assets/images/bg_safe.jpg'; 
  
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";

  @override
  void initState() {
    super.initState();
    _loadSettings(); 
    _trackNodeStatus();
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

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Color _getStrictStatusColor(String status) {
    String s = status.toUpperCase();
    if (s.contains('SAFE') || s == 'GO') return const Color(0xFF10B981); 
    if (s.contains('CAUTION') || s.contains('WARNING')) return const Color(0xFFF59E0B); 
    if (s.contains('DANGER') || s.contains('NO-GO')) return const Color(0xFFEF4444); 
    return const Color(0xFF94A3B8); 
  }

  void _trackNodeStatus() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    
    _nodeSubscription = db.ref('bantaydagat/latest').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        int ts = int.tryParse(data['timestamp']?.toString() ?? '0') ?? 0;
        if (ts > 0 && ts < 10000000000) ts *= 1000;
        
        double airTemp = _parseDouble(data['airTemp']);
        double waterTemp = _parseDouble(data['waterTemp']);
        double humidity = _parseDouble(data['humidity']);
        double ph = _parseDouble(data['pH']);
        double turbidity = _parseDouble(data['turbidity']);

        Map<String, dynamic> assessment = SensorConstants.calculateOverallReleaseStatus([
          SensorConstants.getStatus('airTemp', airTemp),
          SensorConstants.getStatus('waterTemp', waterTemp),
          SensorConstants.getStatus('humidity', humidity),
          SensorConstants.getStatus('ph', ph),
          SensorConstants.getStatus('turbidity', turbidity)
        ]);

        Color statusColor = _getStrictStatusColor(assessment['status'].toString());
        String newBg = 'assets/images/bg_safe.jpg';
        
        if (statusColor == const Color(0xFFEF4444)) {
          newBg = 'assets/images/bg_danger.png';
        } else if (statusColor == const Color(0xFFF59E0B)) {
          newBg = 'assets/images/bg_caution.png';
        }

        setState(() {
          _lastSeen = DateTime.fromMillisecondsSinceEpoch(ts);
          _bgImagePath = newBg;
          _isLoading = false; 
        });
      }
    });
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55), 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
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
              key: ValueKey<String>(_bgImagePath),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                image: _isLoading 
                  ? null 
                  : DecorationImage(
                      image: AssetImage(_bgImagePath),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16.0, 135.0, 16.0, 120.0),
                  children: [
                    _buildIdentityHeader(),
                    const SizedBox(height: 32),
                    _buildSectionHeader('PREFERENCES'),
                    _buildSettingsCard(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('SYSTEM STATUS'),
                    _buildSystemCard(),
                    const SizedBox(height: 32),
                    _buildLogoutButton(),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityHeader() {
    bool isNodeOnline = _lastSeen != null && DateTime.now().difference(_lastSeen!).inMinutes < 10;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
          child: const CircleAvatar(
            backgroundColor: Colors.white10,
            radius: 45,
            child: Text('R', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Active Ranger',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pawikan Sanctuary • Brgy. Labac',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isNodeOnline ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isNodeOnline ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFFEF4444).withOpacity(0.5))
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isNodeOnline ? Icons.sensors : Icons.sensors_off, size: 16, color: isNodeOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(
                isNodeOnline ? 'LINKED TO SENSOR NODE' : 'SENSOR NODE OFFLINE',
                style: TextStyle(color: isNodeOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.5), letterSpacing: 1.5)),
    );
  }

  Widget _buildSettingsCard() {
    return _buildGlassCard(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            activeColor: const Color(0xFF10B981),
            inactiveTrackColor: Colors.white10,
            title: const Text('Danger Alerts (Push)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            subtitle: Text('Receive notifications for critical levels', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
            value: _pushNotifications,
            onChanged: (bool value) async {
              setState(() => _pushNotifications = value);
              _saveSetting('push_notifications', value); 
              if (value) {
                await FirebaseMessaging.instance.subscribeToTopic('emergency_alerts');
              } else {
                await FirebaseMessaging.instance.unsubscribeFromTopic('emergency_alerts');
              }
            },
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          SwitchListTile.adaptive(
            activeColor: const Color(0xFF10B981),
            inactiveTrackColor: Colors.white10,
            title: const Text('Sound Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            subtitle: Text('Play loud alarm on critical danger', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
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
    bool isOnline = _lastSeen != null && DateTime.now().difference(_lastSeen!).inMinutes < 10;
    return _buildGlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
            shape: BoxShape.circle
          ),
          child: Icon(Icons.memory, color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 24),
        ),
        title: const Text('ESP32 Sensor Array', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
        subtitle: Text('Marine monitoring hardware', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isOnline ? 'ONLINE' : 'OFFLINE', 
              style: TextStyle(color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)
            ),
            const SizedBox(height: 4),
            Text(
              _lastSeen != null ? DateFormat('h:mm a').format(_lastSeen!) : '--:--',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout, 
        icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
        label: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.6), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
        ),
      ),
    );
  }
}