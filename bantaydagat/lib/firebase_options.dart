// File: lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // --- ANDROID CONFIGURATION ---
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDq2bF0WCXhSpFgRxyF7JIcYGwApigRoMU",
    appId: '1:417512950497:android:4012d55506824ba74b45a0',
    messagingSenderId: '417512950497',
    projectId: 'bantaydagat-4b8b6',
    storageBucket: "bantaydagat-4b8b6.firebasestorage.app"
  );

  // --- IOS CONFIGURATION ---
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBCsPGsMYp3c8LahQxDwbJ0fNsPIrKGXsw',
    appId: '1:417512950497:ios:2b9395e6eb2c74cc4b45a0',
    messagingSenderId: '417512950497',
    projectId: 'bantaydagat-4b8b6',
    storageBucket: "bantaydagat-4b8b6.firebasestorage.app",
    iosBundleId: 'com.example.bantaydagat', 
  );
}