import 'package:bantaydagat/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; 

// --- BACKGROUND NOTIFICATION LISTENER ---
// Must be a top-level function outside of any class
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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

  // --- Register the background listener ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // --- NEW: Request permissions & subscribe to the cloud function's topic ---
  await _initializeCloudMessaging();

  runApp(const MyApp());
}

// Helper function to handle push notification permissions and topic subscription
Future<void> _initializeCloudMessaging() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request user permission for notifications (essential for Android 13+ and iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions.');
      
      // CRITICAL: Links this device to the Cloud Function's notification topic
      await messaging.subscribeToTopic('emergency_alerts');
      debugPrint('Successfully subscribed to "emergency_alerts" topic.');
    } else {
      debugPrint('User declined or skipped notification permissions.');
    }
  } catch (e) {
    debugPrint('Error initializing Firebase Cloud Messaging: $e');
  }
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