import 'package:flutter/material.dart';
import 'dart:ui';

// Make sure these match your exact file names in the lib/screens folder
import 'dashboard_screen.dart'; 
import 'trends_tab.dart'; 
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

  // FIXED: No more text placeholders. This now loads your actual custom screens.
  final List<Widget> _tabs = [
    const DashboardTab(),
    const TrendsTab(),
    const AlertsTab(), 
    const EnvironmentalDataTab(), 
    const ProfileScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: const Color(0xFF0F172A), 
      
      // --- FROSTED GLASS TOP BAR ---
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.35), 
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Row(
          children: [
            Image.asset('assets/images/bantay-dagat.png', height: 32),
            const SizedBox(width: 12),
            const Text(
              'BantayDagat', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 0.5)
            ),
          ],
        ),
      ),
      
      // Render the actively selected tab
      body: _tabs[_currentIndex],
      
      // --- FROSTED GLASS BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.18), width: 1)),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent, 
              elevation: 0,
              type: BottomNavigationBarType.fixed, 
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white38,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.insert_chart_outlined), activeIcon: Icon(Icons.insert_chart), label: 'Trends'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications_none), activeIcon: Icon(Icons.notifications), label: 'Alerts'),
                BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), activeIcon: Icon(Icons.eco), label: 'Eco Data'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}