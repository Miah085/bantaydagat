import 'package:flutter/material.dart';
import 'dart:ui';

import 'dashboard_screen.dart'; 
import 'trends_tab.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const DashboardTab(),
    const TrendsTab(),
    const Center(child: Text("Alerts", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))), 
    const Center(child: Text("Eco Data", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))), 
    const Center(child: Text("Profile", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FORCES THE TAB BACKGROUNDS TO EXPAND BEHIND THE HEADER AND NAVIGATION SLIDERS
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: const Color(0xFF0F172A), 
      
      // --- TRANS-GLASS TOP BAR ---
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
      
      body: _tabs[_currentIndex],
      
      // --- TRANS-GLASS BOTTOM NAVIGATION SLIDER ---
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.18), width: 1)),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent, // Required to make glass blurring function
              elevation: 0,
              type: BottomNavigationBarType.fixed, 
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white38,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.insert_chart_outlined), label: 'Trends'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: 'Alerts'),
                BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: 'Eco Data'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}