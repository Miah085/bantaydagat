import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart'; // <-- Imports the core tool
import 'firebase_options.dart'; // <-- Imports your newly created keys
import 'screens/home_screen.dart'; 

// Change main() to be async
void main() async {
  // Ensure the app waits for Firebase to connect before starting
  WidgetsFlutterBinding.ensureInitialized();
  
  // This is the magic line that uses your keys to log in to the cloud
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        primaryColor: const Color(0xFF0F82A0),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF0F82A0),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}