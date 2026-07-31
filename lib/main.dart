import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'package:bantaydagat/screens/login_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  // Android notification channel
  const AndroidNotificationChannel channel =
      AndroidNotificationChannel(
    'emergency_alerts_channel',
    'Emergency Alerts',
    description: 'Critical BantayDagat notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const InitializationSettings initializationSettings =
      InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  await _initializeCloudMessaging();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("========== FOREGROUND MESSAGE ==========");
    print(message.notification?.title);
    print(message.notification?.body);

    if (message.notification != null) {
      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'emergency_alerts_channel',
            'Emergency Alerts',
            channelDescription: 'Critical BantayDagat notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print("Notification tapped");
  });

  final initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    print("Opened from terminated notification");
  }

  runApp(const MyApp());
}

Future<void> _initializeCloudMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  String? token = await messaging.getToken();

  print("========== FCM TOKEN ==========");
  print(token);
  print("===============================");

  await messaging.subscribeToTopic("emergency_alerts");

  print("Subscribed to emergency_alerts");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BantayDagat',
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}