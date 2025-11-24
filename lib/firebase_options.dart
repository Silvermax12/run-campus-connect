import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Temporary Firebase configuration placeholder.
/// Replace the values below with the real configuration generated via FlutterFire CLI.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBeujxn7tzsbrsdDlNcUxMpqE9iqsYhX0M',
    appId: '1:393087881528:web:17c82c11cdaa7240cfb1cd',
    messagingSenderId: '393087881528',
    projectId: 'run-campus-connect',
    authDomain: 'run-campus-connect.firebaseapp.com',
    storageBucket: 'run-campus-connect.firebasestorage.app',
    measurementId: 'G-LFR99F85WG',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQfsKDnGOzg3OoydhWBvyEboGMAT2fcaI',
    appId: '1:393087881528:android:aad5868349f6156fcfb1cd',
    messagingSenderId: '393087881528',
    projectId: 'run-campus-connect',
    storageBucket: 'run-campus-connect.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCTP2GeyEtjvPtc-1W-ZHCMFbM2w2k95YA',
    appId: '1:393087881528:ios:182d8bc00a09a2f8cfb1cd',
    messagingSenderId: '393087881528',
    projectId: 'run-campus-connect',
    storageBucket: 'run-campus-connect.firebasestorage.app',
    iosBundleId: 'com.example.runCampusConnect',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCTP2GeyEtjvPtc-1W-ZHCMFbM2w2k95YA',
    appId: '1:393087881528:ios:c0d93d698c5197d1cfb1cd',
    messagingSenderId: '393087881528',
    projectId: 'run-campus-connect',
    storageBucket: 'run-campus-connect.firebasestorage.app',
    iosBundleId: 'com.run-campus-connect.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBeujxn7tzsbrsdDlNcUxMpqE9iqsYhX0M',
    appId: '1:393087881528:web:ae6ed1b8f0cb915dcfb1cd',
    messagingSenderId: '393087881528',
    projectId: 'run-campus-connect',
    authDomain: 'run-campus-connect.firebaseapp.com',
    storageBucket: 'run-campus-connect.firebasestorage.app',
    measurementId: 'G-H8JSTYFKFF',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_LINUX_API_KEY',
    appId: 'YOUR_LINUX_APP_ID',
    messagingSenderId: 'YOUR_LINUX_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );
}