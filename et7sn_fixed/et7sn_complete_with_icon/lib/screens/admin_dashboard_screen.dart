import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.adminService});

  final AdminService adminService;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<bool> _adminCheck;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _adminCheck = widget.adminService.isAdmin();
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('لوحة المشرف', 'Admin Dashboard'))),
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: _adminCheck,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data != true) return _accessDenied(context);
            return _dashboard(context);
          },
        ),
      ),
    );
  }

  Widget _accessDenied(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              _t('هذه الصفحة للمشرف فقط', 'This page is for admins only'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() => _adminCheck = widget.adminService.isAdmin()),
              child: Text(_t('إعادة التحقق', 'Re-check access')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboard(BuildContext context) {
    return StreamBuilder<List<UserProfile>>(
      stream: widget.adminService.watchAllUsers(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _t('تعذر تحميل المستخدمين (تحقق من قواعد Firestore)',
                    'Could not load users (check your Firestore rules)'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final users = [...snap.data!]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final stats = _Stats.from(users);

        final q = _query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? users
            : users.where((u) => u.name.toLowerCase().contains(q)).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _overview(context, stats),
            const SizedBox(height: 16),
            _activityBreakdown(context, stats),
            const SizedBox(height: 20),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: _t('ابحث بالاسم', 'Search by name'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t('المستخدمون (${filtered.length})', 'Users (${filtered.length})'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_t('لا يوجد مستخدمون', 'No users found'), textAlign: TextAlign.center),
              )
            else
              for (final u in filtered) _userCard(context, u),
          ],
        );
      },
    );
  }

  // ── Overview ───────────────────────────────────────────────────────────────

  Widget _overview(BuildContext context, _Stats s) {
    final tiles = [
      (_t('إجمالي المستخدمين', 'Total users'), '${s.total}', Icons.groups_outlined),
      (_t('متوسط العمر', 'Avg. age'), s.avgAge.toStringAsFixed(1), Icons.cake_outlined),
      (_t('متوسط الوزن (كجم)', 'Avg. weight (kg)'), s.avgWeight.toStringAsFixed(1),
          Icons.monitor_weight_outlined),
      (_t('متوسط BMI', 'Avg. BMI'), s.avgBmi.toStringAsFixed(1), Icons.insights_outlined),
      (_t('ذكور / إناث', 'Male / Female'), '${s.male} / ${s.female}', Icons.wc),
      (_t('أيام التمرين (متوسط)', 'Avg. workout days'), s.avgWorkoutDays.toStringAsFixed(1),
          Icons.fitness_center),
    ];

    return LayoutBuilder(builder: (context, c) {
      final width = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final t in tiles)
            SizedBox(
              width: width,
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(t.$3, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        t.$2,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(t.$1, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _activityBreakdown(BuildContext context, _Stats s) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('توزيع مستوى النشاط', 'Activity level breakdown'),
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final level in ActivityLevel.values) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(level.label(isArabic: _isArabic),
                        style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${s.activity[level] ?? 0}', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: s.total == 0 ? 0 : (s.activity[level] ?? 0) / s.total,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  Widget _userCard(BuildContext context, UserProfile u) {
    final theme = Theme.of(context);
    final bmi = _bmi(u);
    final genderLabel = u.gender == Gender.male ? _t('ذكر', 'Male') : _t('أنثى', 'Female');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(u.name.isNotEmpty ? u.name.characters.first.toUpperCase() : '?'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.name.isEmpty ? _t('بدون اسم', 'Unnamed') : u.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$genderLabel • ${u.age} ${_t('سنة', 'yrs')} • '
                    '${u.heightCm.toStringAsFixed(0)} ${_t('سم', 'cm')} • '
                    '${u.weightKg.toStringAsFixed(1)} ${_t('كجم', 'kg')}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(context, 'BMI ${bmi.toStringAsFixed(1)}'),
                      _chip(context, u.activityLevel.label(isArabic: _isArabic)),
                      _chip(context,
                          _t('${u.targetWorkoutDays} أيام/أسبوع', '${u.targetWorkoutDays} days/wk')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
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

double _bmi(UserProfile u) {
  final m = u.heightCm / 100;
  return m <= 0 ? 0 : u.weightKg / (m * m);
}

class _Stats {
  _Stats({
    required this.total,
    required this.avgAge,
    required this.avgWeight,
    required this.avgBmi,
    required this.avgWorkoutDays,
    required this.male,
    required this.female,
    required this.activity,
  });

  final int total;
  final double avgAge;
  final double avgWeight;
  final double avgBmi;
  final double avgWorkoutDays;
  final int male;
  final int female;
  final Map<ActivityLevel, int> activity;

  factory _Stats.from(List<UserProfile> users) {
    final n = users.length;
    double avg(double Function(UserProfile) f) =>
        n == 0 ? 0 : users.map(f).reduce((a, b) => a + b) / n;

    final activity = <ActivityLevel, int>{};
    for (final u in users) {
      activity[u.activityLevel] = (activity[u.activityLevel] ?? 0) + 1;
    }

    return _Stats(
      total: n,
      avgAge: avg((u) => u.age.toDouble()),
      avgWeight: avg((u) => u.weightKg),
      avgBmi: avg(_bmi),
      avgWorkoutDays: avg((u) => u.targetWorkoutDays.toDouble()),
      male: users.where((u) => u.gender == Gender.male).length,
      female: users.where((u) => u.gender == Gender.female).length,
      activity: activity,
    );
  }
}
