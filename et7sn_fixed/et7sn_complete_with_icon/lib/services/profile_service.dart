import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// Stores the onboarding profile at `users/{uid}`.
class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> saveProfile(UserProfile profile) =>
      _doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));

  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return UserProfile.fromMap(uid, data);
  }

  Future<bool> hasCompletedOnboarding(String uid) async {
    final snap = await _doc(uid).get();
    return snap.data()?['onboardingCompleted'] == true;
  }
}
