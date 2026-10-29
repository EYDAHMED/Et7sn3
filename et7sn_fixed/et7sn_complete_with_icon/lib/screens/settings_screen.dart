import 'package:flutter/material.dart';

import '../main.dart' show LocaleController;
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.authService,
    required this.localeController,
  });

  final AuthService authService;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String t(String ar, String en) => isArabic ? ar : en;
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(t('الإعدادات', 'Settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user?.email ?? '—'),
                subtitle: Text(t('الحساب', 'Account')),
              ),
            ),
            const SizedBox(height: 16),
            Text(t('اللغة', 'Language'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: localeController,
              builder: (context, _) => SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {localeController.locale.languageCode},
                onSelectionChanged: (s) => localeController.setLocale(Locale(s.first)),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: authService.signOut,
              icon: const Icon(Icons.logout),
              label: Text(t('تسجيل الخروج', 'Sign out')),
            ),
          ],
        ),
      ),
    );
  }
}
