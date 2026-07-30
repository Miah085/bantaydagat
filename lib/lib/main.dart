import 'package:bantaydagat/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; // <-- NEW: FCM Import
import 'firebase_options.dart'; 

// --- NEW: BACKGROUND NOTIFICATION LISTENER ---
// Must be a top-level function outside of any class
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🚨 DANGER ALERT RECEIVED IN BACKGROUND: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // --- NEW: Register the background listener before running the app ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BantayDagat',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto', 
      ),
      home: const LoginScreen(), 
    );
  }
}