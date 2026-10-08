import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7DCDKfm-LsJMGnStGhM8CIsEso3ogtg8',
    appId: '1:395682274992:android:5e51a3efa8049784b22575',
    messagingSenderId: '395682274992',
    projectId: 'xwxwx-e5728',
    storageBucket: 'xwxwx-e5728.firebasestorage.app',
  );
}
