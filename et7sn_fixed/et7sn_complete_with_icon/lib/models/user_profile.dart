import 'package:cloud_firestore/cloud_firestore.dart';

enum Gender { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension ActivityLevelX on ActivityLevel {
  String label({required bool isArabic}) {
    switch (this) {
      case ActivityLevel.sedentary:
        return isArabic ? 'خامل (عمل مكتبي)' : 'Sedentary (desk job)';
      case ActivityLevel.light:
        return isArabic ? 'نشاط خفيف (1-3 أيام)' : 'Lightly active (1-3 days)';
      case ActivityLevel.moderate:
        return isArabic ? 'نشاط متوسط (3-5 أيام)' : 'Moderately active (3-5 days)';
      case ActivityLevel.active:
        return isArabic ? 'نشيط (6-7 أيام)' : 'Active (6-7 days)';
      case ActivityLevel.veryActive:
        return isArabic ? 'نشيط جداً (عمل بدني)' : 'Very active (physical job)';
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.targetWorkoutDays,
  });

  final String uid;
  final String name;
  final Gender gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final int targetWorkoutDays; // per week, 1-7

  Map<String, dynamic> toMap() => {
        'name': name,
        'gender': gender.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel.name,
        'targetWorkoutDays': targetWorkoutDays,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      gender: Gender.values.firstWhere(
        (g) => g.name == map['gender'],
        orElse: () => Gender.male,
      ),
      age: (map['age'] as num?)?.toInt() ?? 0,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      activityLevel: ActivityLevel.values.firstWhere(
        (e) => e.name == map['activityLevel'],
        orElse: () => ActivityLevel.light,
      ),
      targetWorkoutDays: (map['targetWorkoutDays'] as num?)?.toInt() ?? 3,
    );
  }
}
