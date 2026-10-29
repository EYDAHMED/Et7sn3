import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase options for the Android app.
///
/// Fill these in from Firebase Console -> Project settings -> Your apps -> Android
/// (the values inside google-services.json), either by:
///   1. replacing the 'REPLACE_ME' defaults below, or
///   2. passing --dart-define=FIREBASE_API_KEY=... etc. at build time
///      (the GitHub workflow does this from repository secrets).
///
/// Mapping from google-services.json:
///   apiKey            -> client[0].api_key[0].current_key
///   appId             -> client[0].client_info.mobilesdk_app_id
///   messagingSenderId -> project_info.project_number
///   projectId         -> project_info.project_id
///   storageBucket     -> project_info.storage_bucket
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Only Android is configured for this app.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'REPLACE_ME'),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: 'REPLACE_ME'),
    messagingSenderId:
        String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: 'REPLACE_ME'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'REPLACE_ME'),
    storageBucket:
        String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'REPLACE_ME'),
  );
}
