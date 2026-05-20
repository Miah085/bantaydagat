import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart'; // <-- Imports the core tool
import 'firebase_options.dart'; // <-- Imports your newly created keys
import 'screens/home_screen.dart'; 

// Change main() to be async
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BantayDagat',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto', // Or your system generic font family selection
      ),
      home: const HomeScreen(), // Pushes straight to the wrapper containing your logo toolbar
    );
  }
}