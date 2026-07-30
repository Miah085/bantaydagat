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
    apiKey: "AIzaSyCiBcmASfU0Ye6Aav1wJWeuF8yIzrRG2GA",
    appId: '1:767180658587:android:8d3607af77f64497d1333e',
    messagingSenderId: '417512950497',
    projectId: 'bantaydagat',
    storageBucket: "bantaydagat.firebasestorage.app"
  );

  // --- IOS CONFIGURATION ---
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAU1Q9qrdzgG2t_eHffMpc7kDrQsPn1Lx8',
    appId: '1:767180658587:ios:a000f71b28e1c1dad1333e',
    messagingSenderId: '767180658587',
    projectId: 'bantaydagat',
    storageBucket: "bantaydagat.firebasestorage.app",
    iosBundleId: 'com.example.bantaydagat', 
  );
}