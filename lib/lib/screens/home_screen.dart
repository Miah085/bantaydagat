import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dashboard_screen.dart';
import 'trends_tab.dart'; // Make sure this matches your actual filename (e.g., historical_trends_tab.dart if you renamed it)
import 'alerts_tab.dart';
import 'environmental_data_tab.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const DashboardTab(),
    const HistoricalTrendsTab(), // Update this class name if yours is named TrendsTab
    const AlertsTab(),
    const EnvironmentalDataTab(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted permission for notifications');
      
      String? token = await messaging.getToken();
      debugPrint("📱 FCM DEVICE TOKEN: $token");

      // CRITICAL FIX: Subscribing to the exact channel the server broadcasts to
      await messaging.subscribeToTopic('emergency_alerts');
      debugPrint('✅ Subscribed to emergency_alerts topic');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        if (message.notification != null && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text("🚨 ${message.notification?.title}: ${message.notification?.body}", style: const TextStyle(fontWeight: FontWeight.bold)),
               backgroundColor: Colors.red.shade800,
               behavior: SnackBarBehavior.floating,
               margin: const EdgeInsets.all(16),
               duration: const Duration(seconds: 5),
             )
           );
        }
      });
    } else {
      debugPrint('❌ User declined or has not accepted permission');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false, 
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Image.asset(
              'assets/images/bantay-dagat.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain, 
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.waves, color: Color(0xFF0F82A0), size: 28);
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'BantayDagat',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0F82A0),
        unselectedItemColor: Colors.blueGrey.shade300,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Trends'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.eco), activeIcon: Icon(Icons.eco), label: 'Eco Data'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}