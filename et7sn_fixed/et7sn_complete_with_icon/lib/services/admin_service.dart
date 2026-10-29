import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

/// Admin access is decided by a Firebase **custom claim** (`admin: true`) that can
/// only be set from a trusted server/CLI (see scripts/set_admin.js). The client
/// check below only controls the UI — the real protection is in firestore.rules.
class AdminService {
  AdminService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Forces a token refresh by default so a freshly granted claim is picked up
  /// without the admin having to sign out and back in.
  Future<bool> isAdmin({bool forceRefresh = true}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims?['admin'] == true;
  }

  /// Real-time stream of every user who finished onboarding.
  Stream<List<UserProfile>> watchAllUsers() {
    return _db
        .collection('users')
        .where('onboardingCompleted', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => UserProfile.fromMap(d.id, d.data())).toList());
  }
}
