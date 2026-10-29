import 'package:flutter/material.dart';

import '../logic/diet_plan_service.dart';
import '../logic/nutrition_calculator.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({
    super.key,
    required this.authService,
    required this.profileService,
  });

  final AuthService authService;
  final ProfileService profileService;

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  final _planner = DietPlanService();

  UserProfile? _profile;
  NutritionTargets? _targets;
  DietPlan? _plan;
  DietGoal _goal = DietGoal.maintain;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final uid = widget.authService.currentUser?.uid;
      final profile = uid == null ? null : await widget.profileService.getProfile(uid);
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _loading = false;
          _error = true;
        });
        return;
      }
      _profile = profile;
      _rebuildPlan();
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _rebuildPlan() {
    final targets = NutritionCalculator.targetsFor(_profile!, _goal);
    _targets = targets;
    _plan = _planner.generate(targets.targetCalories);
  }

  void _replace(int index) {
    final plan = _plan!;
    final previous = plan.meals[index];
    final replacement = _planner.replaceMeal(plan, index);

    if (replacement.meal.id == previous.meal.id) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(_t('لا توجد بدائل أخرى لهذه الوجبة', 'No other alternatives for this meal')),
        ));
      return;
    }

    setState(() => _plan = plan.withMealAt(index, replacement));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_t('تم الاستبدال', 'Meal replaced')),
        action: SnackBarAction(
          label: _t('تراجع', 'Undo'),
          onPressed: () {
            if (!mounted) return;
            setState(() => _plan = _plan!.withMealAt(index, previous));
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('خطة الأكل اليومية', 'Daily Diet Plan'))),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error || _profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t('تعذر تحميل بياناتك. أكمل التسجيل أو حاول مرة أخرى.',
                    'Could not load your profile. Finish onboarding or try again.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: Text(_t('إعادة المحاولة', 'Retry'))),
            ],
          ),
        ),
      );
    }

    final plan = _plan!;
    final targets = _targets!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SummaryCard(targets: targets, plan: plan, t: _t),
        const SizedBox(height: 16),
        _goalSelector(),
        const SizedBox(height: 20),
        for (var i = 0; i < plan.meals.length; i++) ...[
          _MealCard(
            planned: plan.meals[i],
            isArabic: _isArabic,
            onReplace: () => _replace(i),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        Text(
          _t('القيم تقريبية وللإرشاد فقط وليست نصيحة طبية. استشر أخصائي تغذية عند وجود حالة صحية.',
              'Values are approximate and for guidance only, not medical advice. See a dietitian if you have a health condition.'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _goalSelector() {
    return SegmentedButton<DietGoal>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: DietGoal.lose, label: Text(_t('تخسيس', 'Lose'))),
        ButtonSegment(value: DietGoal.maintain, label: Text(_t('ثبات', 'Maintain'))),
        ButtonSegment(value: DietGoal.gain, label: Text(_t('زيادة', 'Gain'))),
      ],
      selected: {_goal},
      onSelectionChanged: (s) {
        setState(() {
          _goal = s.first;
          _rebuildPlan();
        });
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.targets, required this.plan, required this.t});

  final NutritionTargets targets;
  final DietPlan plan;
  final String Function(String ar, String en) t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _stat(context, t('معدل الحرق (BMR)', 'BMR'), '${targets.bmr}'),
                _stat(context, t('إجمالي الحرق (TDEE)', 'TDEE'), '${targets.tdee}'),
                _stat(context, t('هدفك اليومي', 'Your target'), '${targets.targetCalories}',
                    highlight: true),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (plan.totalKcal / targets.targetCalories).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('خطة اليوم: ${plan.totalKcal} من ${targets.targetCalories} سعر',
                  'Today\'s plan: ${plan.totalKcal} of ${targets.targetCalories} kcal'),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              t('بروتين ${plan.totalProtein} / ${targets.proteinG} جم  •  '
                    'كارب ${plan.totalCarbs} / ${targets.carbsG} جم  •  '
                    'دهون ${plan.totalFat} / ${targets.fatG} جم',
                'Protein ${plan.totalProtein}/${targets.proteinG} g  •  '
                    'Carbs ${plan.totalCarbs}/${targets.carbsG} g  •  '
                    'Fat ${plan.totalFat}/${targets.fatG} g'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, {bool highlight = false}) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.planned,
    required this.isArabic,
    required this.onReplace,
  });

  final PlannedMeal planned;
  final bool isArabic;
  final VoidCallback onReplace;

  IconData get _icon {
    switch (planned.meal.slot) {
      case MealSlot.breakfast:
        return Icons.free_breakfast_outlined;
      case MealSlot.lunch:
        return Icons.lunch_dining_outlined;
      case MealSlot.dinner:
        return Icons.dinner_dining_outlined;
      case MealSlot.snack:
        return Icons.apple_outlined;
    }
  }

  String _servingsText() {
    final s = planned.servings;
    if (s == 1) return '';
    final text = s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString();
    return ' × $text';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meal = planned.meal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  meal.slot.label(isArabic: isArabic),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${planned.kcal} ${isArabic ? 'سعر' : 'kcal'}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Animated swap
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, axisAlignment: -1, child: child),
              ),
              child: Column(
                key: ValueKey('${meal.id}_${planned.servings}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name(isArabic: isArabic),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.portion(isArabic: isArabic)}${_servingsText()}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(context, '${isArabic ? 'بروتين' : 'P'} ${planned.protein}g'),
                      _chip(context, '${isArabic ? 'كارب' : 'C'} ${planned.carbs}g'),
                      _chip(context, '${isArabic ? 'دهون' : 'F'} ${planned.fat}g'),
                      _chip(context, meal.tier.label(isArabic: isArabic), outlined: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: onReplace,
                icon: const Icon(Icons.swap_horiz),
                label: Text(isArabic ? 'استبدال / تخطي' : 'Skip / Replace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, {bool outlined = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? null : scheme.primaryContainer,
        border: outlined ? Border.all(color: scheme.primary.withOpacity(0.5)) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
