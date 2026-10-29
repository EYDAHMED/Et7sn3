import '../models/user_profile.dart';

enum DietGoal { lose, maintain, gain }

class NutritionTargets {
  const NutritionTargets({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int bmr;
  final int tdee;
  final int targetCalories;
  final int proteinG;
  final int carbsG;
  final int fatG;
}

class NutritionCalculator {
  const NutritionCalculator._();

  /// Mifflin-St Jeor equation (kcal/day at rest).
  static double bmr({
    required Gender gender,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return gender == Gender.male ? base + 5 : base - 161;
  }

  static double activityFactor(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }

  static double tdee(UserProfile p) =>
      bmr(
        gender: p.gender,
        weightKg: p.weightKg,
        heightCm: p.heightCm,
        age: p.age,
      ) *
      activityFactor(p.activityLevel);

  static NutritionTargets targetsFor(UserProfile p, DietGoal goal) {
    final bmrValue = bmr(
      gender: p.gender,
      weightKg: p.weightKg,
      heightCm: p.heightCm,
      age: p.age,
    );
    final tdeeValue = bmrValue * activityFactor(p.activityLevel);

    double target;
    switch (goal) {
      case DietGoal.lose:
        target = tdeeValue * 0.80; // ~20% deficit
        break;
      case DietGoal.maintain:
        target = tdeeValue;
        break;
      case DietGoal.gain:
        target = tdeeValue * 1.10; // ~10% surplus
        break;
    }

    // Safety floor: never plan below commonly advised minimums.
    final floor = p.gender == Gender.male ? 1500.0 : 1200.0;
    if (target < floor) target = floor;

    // Macros: protein by body weight (capped at 35% of calories),
    // fat 25% of calories, carbs fill the rest.
    final proteinPerKg = goal == DietGoal.lose ? 1.8 : 1.6;
    var proteinG = p.weightKg * proteinPerKg;
    final proteinCap = target * 0.35 / 4;
    if (proteinG > proteinCap) proteinG = proteinCap;

    final fatG = target * 0.25 / 9;
    final carbsG = (target - proteinG * 4 - fatG * 9) / 4;

    return NutritionTargets(
      bmr: bmrValue.round(),
      tdee: tdeeValue.round(),
      targetCalories: target.round(),
      proteinG: proteinG.round(),
      carbsG: carbsG.round(),
      fatG: fatG.round(),
    );
  }
}
