enum MealSlot { breakfast, lunch, dinner, snack }

extension MealSlotX on MealSlot {
  /// Share of the daily calorie target given to this slot.
  double get share {
    switch (this) {
      case MealSlot.breakfast:
        return 0.25;
      case MealSlot.lunch:
        return 0.35;
      case MealSlot.dinner:
        return 0.25;
      case MealSlot.snack:
        return 0.15;
    }
  }

  String label({required bool isArabic}) {
    switch (this) {
      case MealSlot.breakfast:
        return isArabic ? 'الفطور' : 'Breakfast';
      case MealSlot.lunch:
        return isArabic ? 'الغداء' : 'Lunch';
      case MealSlot.dinner:
        return isArabic ? 'العشاء' : 'Dinner';
      case MealSlot.snack:
        return isArabic ? 'سناك' : 'Snack';
    }
  }
}

/// Rough cost bracket (prices change, so we avoid exact EGP figures).
enum PriceTier { budget, standard, premium }

extension PriceTierX on PriceTier {
  String label({required bool isArabic}) {
    switch (this) {
      case PriceTier.budget:
        return isArabic ? 'اقتصادي' : 'Budget';
      case PriceTier.standard:
        return isArabic ? 'متوسط' : 'Mid-range';
      case PriceTier.premium:
        return isArabic ? 'أغلى' : 'Pricier';
    }
  }
}

class Meal {
  const Meal({
    required this.id,
    required this.slot,
    required this.nameAr,
    required this.nameEn,
    required this.portionAr,
    required this.portionEn,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.tier,
  });

  final String id;
  final MealSlot slot;
  final String nameAr;
  final String nameEn;

  /// What one serving is (e.g. "1 plate + 1 baladi bread").
  final String portionAr;
  final String portionEn;

  /// Per ONE serving. Approximate values.
  final int kcal;
  final int protein;
  final int carbs;
  final int fat;
  final PriceTier tier;

  String name({required bool isArabic}) => isArabic ? nameAr : nameEn;
  String portion({required bool isArabic}) => isArabic ? portionAr : portionEn;
}
