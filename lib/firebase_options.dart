// firebase_options.dart
// Generated from the existing Firebase project: wedding-invitation-site-ed481

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCJOcPM230-FIwIJyvdVbOMD3ukSKenDZ8',
    appId: '1:445590917284:web:b9e3404f457be517775631',
    messagingSenderId: '445590917284',
    projectId: 'wedding-dashboard-169f8',
    authDomain: 'wedding-dashboard-169f8.firebaseapp.com',
    databaseURL: 'https://wedding-dashboard-169f8-default-rtdb.firebaseio.com',
    storageBucket: 'wedding-dashboard-169f8.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCJOcPM230-FIwIJyvdVbOMD3ukSKenDZ8',
    appId: '1:445590917284:android:5dee2227aefc5aa5775631',
    messagingSenderId: '445590917284',
    projectId: 'wedding-dashboard-169f8',
    databaseURL: 'https://wedding-dashboard-169f8-default-rtdb.firebaseio.com',
    storageBucket: 'wedding-dashboard-169f8.firebasestorage.app',
  );
}
