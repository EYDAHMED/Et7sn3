import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.authService,
    required this.profileService,
    required this.onCompleted,
  });

  final AuthService authService;
  final ProfileService profileService;

  /// Called after the profile is saved (e.g. navigate to the home screen).
  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  ActivityLevel _activity = ActivityLevel.moderate;
  Gender _gender = Gender.male;
  int _workoutDays = 3;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.authService.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  /// Accepts Arabic-Indic digits too (٠١٢٣…) and a decimal comma/dot.
  double? _parse(String raw) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final ch in raw.trim().split('')) {
      final i = arabic.indexOf(ch);
      if (i >= 0) {
        buffer.write(i);
      } else if (ch == '٫' || ch == ',') {
        buffer.write('.');
      } else {
        buffer.write(ch);
      }
    }
    return double.tryParse(buffer.toString());
  }

  String? _requiredNumber(String? v, {required double min, required double max}) {
    if (v == null || v.trim().isEmpty) return _t('هذا الحقل مطلوب', 'Required');
    final n = _parse(v);
    if (n == null) return _t('أدخل رقماً صحيحاً', 'Enter a valid number');
    if (n < min || n > max) {
      return _t('القيمة بين ${min.toInt()} و ${max.toInt()}',
          'Must be between ${min.toInt()} and ${max.toInt()}');
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = widget.authService.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final profile = UserProfile(
        uid: user.uid,
        gender: _gender,
        name: _nameCtrl.text.trim(),
        age: _parse(_ageCtrl.text)!.round(),
        heightCm: _parse(_heightCtrl.text)!,
        weightKg: _parse(_weightCtrl.text)!,
        activityLevel: _activity,
        targetWorkoutDays: _workoutDays,
      );
      await widget.profileService.saveProfile(profile);
      if (!mounted) return;
      widget.onCompleted();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('تعذر حفظ البيانات، حاول مرة أخرى',
              'Could not save your data. Please try again.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_t('لنبدأ بالتعرف عليك', 'Let\'s get to know you'))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text(
                _t('أخبرنا عن نفسك لنصمم خطتك', 'Tell us about yourself to personalize your plan'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _t('الاسم', 'Name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? _t('أدخل اسمك', 'Enter your name')
                    : null,
              ),
              const SizedBox(height: 16),

              // Gender (needed for the BMR formula)
              SegmentedButton<Gender>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: Gender.male,
                    icon: const Icon(Icons.male),
                    label: Text(_t('ذكر', 'Male')),
                  ),
                  ButtonSegment(
                    value: Gender.female,
                    icon: const Icon(Icons.female),
                    label: Text(_t('أنثى', 'Female')),
                  ),
                ],
                selected: {_gender},
                onSelectionChanged: (s) => setState(() => _gender = s.first),
              ),
              const SizedBox(height: 16),

              // Age
              _numberField(
                controller: _ageCtrl,
                label: _t('العمر', 'Age'),
                suffix: _t('سنة', 'yrs'),
                icon: Icons.cake_outlined,
                allowDecimal: false,
                validator: (v) => _requiredNumber(v, min: 10, max: 100),
              ),
              const SizedBox(height: 16),

              // Height & Weight
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _numberField(
                      controller: _heightCtrl,
                      label: _t('الطول', 'Height'),
                      suffix: _t('سم', 'cm'),
                      icon: Icons.height,
                      validator: (v) => _requiredNumber(v, min: 100, max: 250),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberField(
                      controller: _weightCtrl,
                      label: _t('الوزن', 'Weight'),
                      suffix: _t('كجم', 'kg'),
                      icon: Icons.monitor_weight_outlined,
                      validator: (v) => _requiredNumber(v, min: 25, max: 300),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Activity level
              DropdownButtonFormField<ActivityLevel>(
                value: _activity,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('مستوى النشاط', 'Activity level'),
                  prefixIcon: const Icon(Icons.bolt_outlined),
                ),
                items: ActivityLevel.values
                    .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.label(isArabic: _isArabic)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _activity = v ?? _activity),
              ),
              const SizedBox(height: 24),

              // Target workout days
              Text(
                _t('أيام التمرين المستهدفة أسبوعياً', 'Target workout days per week'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  return ChoiceChip(
                    label: Text('$day'),
                    selected: _workoutDays == day,
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _workoutDays == day
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _workoutDays = day),
                  );
                }),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_t('متابعة', 'Continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
    required String? Function(String?) validator,
    bool allowDecimal = true,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}
