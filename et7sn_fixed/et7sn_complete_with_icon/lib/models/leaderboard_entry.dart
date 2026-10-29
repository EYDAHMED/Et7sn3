import 'package:cloud_firestore/cloud_firestore.dart';

/// One user's weight-loss progress for a given week.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.startWeightKg,
    required this.currentWeightKg,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final double startWeightKg;
  final double currentWeightKg;
  final DateTime? updatedAt;

  /// Positive = lost weight, negative = gained.
  double get lossKg => startWeightKg - currentWeightKg;

  /// Ranking uses % of body weight so smaller and larger people compete fairly.
  double get lossPercent => startWeightKg > 0 ? lossKg / startWeightKg * 100 : 0;

  Map<String, dynamic> toMap() => {
        'name': name,
        'startWeightKg': startWeightKg,
        'currentWeightKg': currentWeightKg,
        'lossKg': double.parse(lossKg.toStringAsFixed(2)),
        'lossPercent': double.parse(lossPercent.toStringAsFixed(2)),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory LeaderboardEntry.fromMap(String uid, Map<String, dynamic> map) {
    final ts = map['updatedAt'];
    return LeaderboardEntry(
      uid: uid,
      name: map['name'] as String? ?? '',
      startWeightKg: (map['startWeightKg'] as num?)?.toDouble() ?? 0,
      currentWeightKg: (map['currentWeightKg'] as num?)?.toDouble() ?? 0,
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
