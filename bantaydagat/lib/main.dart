import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const BantayDagatApp());
}

class BantayDagatApp extends StatelessWidget {
  const BantayDagatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BantayDagat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F7F6), // Matches the light grey web bg
        primaryColor: const Color(0xFF0F82A0), // The teal-blue from your sidebar
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF0F82A0),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}