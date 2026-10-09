// File generated for SocialPulse Firebase integration
// Run `flutterfire configure` to connect your active production Firebase project
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with SocialPulse.
class DefaultFirebaseOptions {
  /// Returns true if production Firebase configuration has been provided
  static bool get isConfigured {
    try {
      return !currentPlatform.apiKey.contains('Placeholder');
    } catch (_) {
      return false;
    }
  }

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderWebApiKeyForSocialPulse123',
    appId: '1:1234567890:web:socialpulse1234567890',
    messagingSenderId: '1234567890',
    projectId: 'socialpulse-prod',
    authDomain: 'socialpulse-prod.firebaseapp.com',
    storageBucket: 'socialpulse-prod.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderAndroidApiKeyForSocialPulse123',
    appId: '1:1234567890:android:socialpulse1234567890',
    messagingSenderId: '1234567890',
    projectId: 'socialpulse-prod',
    storageBucket: 'socialpulse-prod.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderIosApiKeyForSocialPulse123',
    appId: '1:1234567890:ios:socialpulse1234567890',
    messagingSenderId: '1234567890',
    projectId: 'socialpulse-prod',
    storageBucket: 'socialpulse-prod.appspot.com',
    iosBundleId: 'com.example.socialpulse',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderMacosApiKeyForSocialPulse123',
    appId: '1:1234567890:ios:socialpulse1234567890',
    messagingSenderId: '1234567890',
    projectId: 'socialpulse-prod',
    storageBucket: 'socialpulse-prod.appspot.com',
    iosBundleId: 'com.example.socialpulse',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderWindowsApiKeyForSocialPulse123',
    appId: '1:1234567890:web:socialpulse1234567890',
    messagingSenderId: '1234567890',
    projectId: 'socialpulse-prod',
    authDomain: 'socialpulse-prod.firebaseapp.com',
    storageBucket: 'socialpulse-prod.appspot.com',
  );
}
