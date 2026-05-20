import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'trends_tab.dart'; 
import 'alerts_tab.dart'; 
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Replace the "Coming Soon" widgets with the actual tabs
  final List<Widget> _tabs = [
    const DashboardTab(),
    const TrendsTab(),
    const AlertsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'BantayDagat',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              customBorder: const CircleBorder(),
              child: const CircleAvatar(
                backgroundColor: Color(0xFF0F82A0),
                radius: 16,
                child: Text('R', style: TextStyle(color: Colors.white, fontSize: 14)), 
              ),
            ),
          )
        ],
      ), // <-- FIX: ADDED CLOSING PARENTHESIS AND COMMA HERE
        
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF0F82A0),
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: Colors.white,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Trends'),
          BottomNavigationBarItem(icon: Icon(Icons.error_outline), label: 'Alerts'),
        ],
      ),
    );
  }
}