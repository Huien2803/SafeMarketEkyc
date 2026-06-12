// Project: safemarketekyc
// Realtime Database: https://safemarketekyc-default-rtdb.firebaseio.com/
//
// apiKey + appId: lấy từ Firebase Console → Project settings → Your apps → Android
// hoặc tải google-services.json thật → android/app/google-services.json
// rồi chạy: flutterfire configure --project=safemarketekyc --yes

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String projectId = 'safemarketekyc';
  static const String databaseURL =
      'https://safemarketekyc-default-rtdb.firebaseio.com';
  static const String storageBucket = 'safemarketekyc.appspot.com';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  /// Điền apiKey + appId từ google-services.json (client/api_key, mobilesdk_app_id)

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyANG0nWA34BBllZqVOrXsL4eEjBKkDG-uc',
    appId: '1:968535993886:android:9f7ca688df4c5627d6880f',
    messagingSenderId: '968535993886',
    projectId: 'safemarketekyc',
    databaseURL: 'https://safemarketekyc-default-rtdb.firebaseio.com',
    storageBucket: 'safemarketekyc.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPLACEHOLDER_REPLACE_FROM_CONSOLE',
    appId: '1:PLACEHOLDER:ios:PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: projectId,
    databaseURL: databaseURL,
    storageBucket: storageBucket,
    iosBundleId: 'com.example.safemarketApp',
  );

  /// Web/Chrome: dùng cùng key Android (đủ cho Realtime Database demo).
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyANG0nWA34BBllZqVOrXsL4eEjBKkDG-uc',
    appId: '1:968535993886:android:9f7ca688df4c5627d6880f',
    messagingSenderId: '968535993886',
    projectId: projectId,
    databaseURL: databaseURL,
    authDomain: 'safemarketekyc.firebaseapp.com',
    storageBucket: 'safemarketekyc.firebasestorage.app',
  );
}
