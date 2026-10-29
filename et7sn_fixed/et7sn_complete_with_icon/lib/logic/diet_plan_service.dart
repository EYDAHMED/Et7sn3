import 'dart:math';

import '../data/egyptian_meals.dart';
import '../models/meal.dart';

/// A meal placed in the plan, scaled to hit its slot's calorie target.
class PlannedMeal {
  const PlannedMeal({
    required this.meal,
    required this.servings,
    required this.targetKcal,
  });

  final Meal meal;
  final double servings; // in 0.25 steps
  final int targetKcal;

  int get kcal => (meal.kcal * servings).round();
  int get protein => (meal.protein * servings).round();
  int get carbs => (meal.carbs * servings).round();
  int get fat => (meal.fat * servings).round();
}

class DietPlan {
  const DietPlan({required this.targetCalories, required this.meals});

  final int targetCalories;
  final List<PlannedMeal> meals; // ordered: breakfast, lunch, dinner, snack

  int get totalKcal => meals.fold(0, (s, m) => s + m.kcal);
  int get totalProtein => meals.fold(0, (s, m) => s + m.protein);
  int get totalCarbs => meals.fold(0, (s, m) => s + m.carbs);
  int get totalFat => meals.fold(0, (s, m) => s + m.fat);

  DietPlan withMealAt(int index, PlannedMeal replacement) {
    final copy = [...meals];
    copy[index] = replacement;
    return DietPlan(targetCalories: targetCalories, meals: copy);
  }
}

class DietPlanService {
  DietPlanService({Random? random, List<Meal>? catalog})
      : _random = random ?? Random(),
        _catalog = catalog ?? egyptianMeals;

  final Random _random;
  final List<Meal> _catalog;

  /// Meals already swapped out per slot, so repeated taps cycle through options.
  final Map<MealSlot, Set<String>> _seen = {};

  static const _servingsMin = 0.5;
  static const _servingsMax = 2.0;

  /// Servings (in quarter steps) that bring [meal] closest to [targetKcal].
  static double servingsFor(Meal meal, int targetKcal) {
    final raw = targetKcal / meal.kcal;
    final stepped = (raw * 4).round() / 4;
    return stepped.clamp(_servingsMin, _servingsMax).toDouble();
  }

  DietPlan generate(int targetCalories) {
    _seen.clear();
    final meals = <PlannedMeal>[];
    for (final slot in MealSlot.values) {
      final slotTarget = (targetCalories * slot.share).round();
      final pick = _pickBest(
        _catalog.where((m) => m.slot == slot).toList(),
        slotTarget,
      );
      meals.add(_plan(pick, slotTarget));
    }
    return DietPlan(targetCalories: targetCalories, meals: meals);
  }

  /// Returns an equivalent alternative for the meal at [index]:
  /// same slot, same calorie target, similar protein, not already in the plan.
  /// Returns the same meal if the slot has no other options.
  PlannedMeal replaceMeal(DietPlan plan, int index) {
    final current = plan.meals[index];
    final slot = current.meal.slot;
    final seen = _seen.putIfAbsent(slot, () => {});
    seen.add(current.meal.id);

    final inPlan = plan.meals.map((m) => m.meal.id).toSet();

    List<Meal> candidates() => _catalog
        .where((m) =>
            m.slot == slot && !inPlan.contains(m.id) && !seen.contains(m.id))
        .toList();

    var options = candidates();
    if (options.isEmpty) {
      // Went through everything — start the cycle again (except the current one).
      seen
        ..clear()
        ..add(current.meal.id);
      options = candidates();
    }
    if (options.isEmpty) return current;

    final pick = _pickBest(
      options,
      current.targetKcal,
      referenceProtein: current.protein,
    );
    return _plan(pick, current.targetKcal);
  }

  PlannedMeal _plan(Meal meal, int targetKcal) => PlannedMeal(
        meal: meal,
        servings: servingsFor(meal, targetKcal),
        targetKcal: targetKcal,
      );

  /// Scores how well a meal fits: calories after scaling, how much scaling is
  /// needed, and (optionally) how close its protein is to what's being replaced.
  double _score(Meal meal, int targetKcal, int? referenceProtein) {
    final servings = servingsFor(meal, targetKcal);
    final kcalError = (meal.kcal * servings - targetKcal).abs() / targetKcal;
    final scalingPenalty = 0.15 * (servings - 1).abs();
    var proteinPenalty = 0.0;
    if (referenceProtein != null) {
      final p = meal.protein * servings;
      proteinPenalty =
          0.3 * (p - referenceProtein).abs() / max(referenceProtein, 1);
    }
    return kcalError + scalingPenalty + proteinPenalty;
  }

  /// Picks randomly among the 3 best-fitting meals for variety.
  Meal _pickBest(List<Meal> options, int targetKcal, {int? referenceProtein}) {
    final ranked = [...options]..sort((a, b) => _score(a, targetKcal, referenceProtein)
        .compareTo(_score(b, targetKcal, referenceProtein)));
    final top = ranked.take(3).toList();
    return top[_random.nextInt(top.length)];
  }
}
