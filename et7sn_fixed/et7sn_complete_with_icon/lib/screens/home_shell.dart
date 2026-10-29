import 'package:flutter/material.dart';

import '../main.dart' show AppServices, LocaleController;
import 'admin_dashboard_screen.dart';
import 'diet_plan_screen.dart';
import 'leaderboard_screen.dart';
import 'et7sn_screen.dart';
import 'settings_screen.dart';

/// Bottom-navigation shell. The Admin tab only appears for users with the
/// `admin` custom claim.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.services, required this.localeController});

  final AppServices services;
  final LocaleController localeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final admin = await widget.services.admin.isAdmin();
      if (mounted && admin) setState(() => _isAdmin = true);
    } catch (_) {
      // Not an admin (or offline) — keep the normal tabs.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String t(String ar, String en) => isArabic ? ar : en;
    final s = widget.services;

    final pages = <Widget>[
      DietPlanScreen(authService: s.auth, profileService: s.profile),
      Et7snScreen(locationService: s.location, prayerService: s.prayer),
      LeaderboardScreen(
        authService: s.auth,
        profileService: s.profile,
        leaderboardService: s.leaderboard,
      ),
      SettingsScreen(authService: s.auth, localeController: widget.localeController),
      if (_isAdmin) AdminDashboardScreen(adminService: s.admin),
    ];

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.restaurant_menu_outlined),
        selectedIcon: const Icon(Icons.restaurant_menu),
        label: t('الأكل', 'Diet'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.access_time),
        selectedIcon: const Icon(Icons.access_time_filled),
        label: t('الصلاة', 'Prayer'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.emoji_events_outlined),
        selectedIcon: const Icon(Icons.emoji_events),
        label: t('المتصدرون', 'Leaderboard'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: t('الإعدادات', 'Settings'),
      ),
      if (_isAdmin)
        NavigationDestination(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: const Icon(Icons.admin_panel_settings),
          label: t('المشرف', 'Admin'),
        ),
    ];

    final index = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
