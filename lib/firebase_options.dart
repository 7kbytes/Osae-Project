import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAnrI4pr4q6Xa7kC9YtQn9phlYw4hY2Lxg',
    appId: '1:212011996599:web:36fb8496989886781cc432',
    messagingSenderId: '212011996599',
    projectId: 'local-job-connector-gh',
    authDomain: 'local-job-connector-gh.firebaseapp.com',
    storageBucket: 'local-job-connector-gh.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBiKhEKSj-FPhD455P4SaCIJVKkYsyljbA',
    appId: '1:212011996599:android:1a2ec707dc0188cd1cc432',
    messagingSenderId: '212011996599',
    projectId: 'local-job-connector-gh',
    storageBucket: 'local-job-connector-gh.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAnrI4pr4q6Xa7kC9YtQn9phlYw4hY2Lxg',
    appId: '1:212011996599:ios:placeholder',
    messagingSenderId: '212011996599',
    projectId: 'local-job-connector-gh',
    storageBucket: 'local-job-connector-gh.firebasestorage.app',
    iosBundleId: 'com.osae.localjobconnector.localJobConnector',
  );
}
