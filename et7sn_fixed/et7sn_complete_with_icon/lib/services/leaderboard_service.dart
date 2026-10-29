import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

/// Weekly leaderboard stored at `leaderboards/{weekId}/entries/{uid}`.
/// Weeks run Saturday → Friday (Egypt's week) and are keyed by the Saturday's date.
class LeaderboardService {
  LeaderboardService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Week helpers ───────────────────────────────────────────────────────────

  static DateTime weekStart(DateTime date) {
    final diff = (date.weekday - DateTime.saturday) % 7;
    return DateTime(date.year, date.month, date.day - diff);
  }

  static DateTime weekEnd(DateTime date) {
    final s = weekStart(date);
    return DateTime(s.year, s.month, s.day + 6);
  }

  static String weekId(DateTime date) {
    final s = weekStart(date);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${s.year}-${two(s.month)}-${two(s.day)}';
  }

  CollectionReference<Map<String, dynamic>> _entries(String weekId) =>
      _db.collection('leaderboards').doc(weekId).collection('entries');

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Top entries for the current week, best loss % first.
  Stream<List<LeaderboardEntry>> watchTop({int limit = 50}) {
    return _entries(weekId(DateTime.now()))
        .orderBy('lossPercent', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => LeaderboardEntry.fromMap(d.id, d.data())).toList());
  }

  Stream<LeaderboardEntry?> watchMine(String uid) {
    return _entries(weekId(DateTime.now())).doc(uid).snapshots().map((snap) {
      final data = snap.data();
      return data == null ? null : LeaderboardEntry.fromMap(uid, data);
    });
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Manually records the user's current weight for this week.
  ///
  /// The week's starting weight is fixed the first time the user logs in a week:
  /// last week's latest weight if there is one, otherwise [fallbackStartKg]
  /// (their profile weight).
  Future<LeaderboardEntry> updateWeight({
    required String uid,
    required String name,
    required double newWeightKg,
    required double fallbackStartKg,
  }) {
    final now = DateTime.now();
    final thisWeek = weekId(now);
    final prevWeek = weekId(DateTime(now.year, now.month, now.day - 7));

    final ref = _entries(thisWeek).doc(uid);
    final prevRef = _entries(prevWeek).doc(uid);

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      double start;
      if (snap.exists) {
        start = (snap.data()!['startWeightKg'] as num).toDouble();
      } else {
        final prev = await tx.get(prevRef);
        start = prev.exists
            ? (prev.data()!['currentWeightKg'] as num).toDouble()
            : fallbackStartKg;
      }

      final entry = LeaderboardEntry(
        uid: uid,
        name: name,
        startWeightKg: start,
        currentWeightKg: newWeightKg,
      );
      tx.set(ref, entry.toMap());
      return entry;
    });
  }
}
