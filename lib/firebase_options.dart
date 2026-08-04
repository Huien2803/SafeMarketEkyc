// Project: safemarketekyc-38009
// Realtime Database: https://safemarketekyc-38009-default-rtdb.asia-southeast1.firebasedatabase.app/
//
// Đồng bộ từ android/app/google-services.json (project mới của bạn)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String projectId = 'safemarketekyc-38009';
  static const String databaseURL =
      'https://safemarketekyc-38009-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String storageBucket = 'safemarketekyc-38009.firebasestorage.app';

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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCnf4WljQz31GFOXHQYX_H49jZ1zK7_HXc',
    appId: '1:833721447738:android:566f802cde298e4e504c03',
    messagingSenderId: '833721447738',
    projectId: 'safemarketekyc-38009',
    databaseURL:
        'https://safemarketekyc-38009-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'safemarketekyc-38009.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCnf4WljQz31GFOXHQYX_H49jZ1zK7_HXc',
    appId: '1:833721447738:android:566f802cde298e4e504c03',
    messagingSenderId: '833721447738',
    projectId: projectId,
    databaseURL: databaseURL,
    storageBucket: 'safemarketekyc-38009.firebasestorage.app',
    iosBundleId: 'com.example.safemarketApp',
  );

  /// Web/Chrome: dùng cùng key Android (đủ cho Realtime Database demo).
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCnf4WljQz31GFOXHQYX_H49jZ1zK7_HXc',
    appId: '1:833721447738:android:566f802cde298e4e504c03',
    messagingSenderId: '833721447738',
    projectId: projectId,
    databaseURL: databaseURL,
    authDomain: 'safemarketekyc-38009.firebaseapp.com',
    storageBucket: 'safemarketekyc-38009.firebasestorage.app',
  );
}
