import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/profile_service.dart';
import '../utils/number_parser.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.authService,
    required this.profileService,
    required this.leaderboardService,
  });

  final AuthService authService;
  final ProfileService profileService;
  final LeaderboardService leaderboardService;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  UserProfile? _profile;

  String? get _uid => widget.authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final p = await widget.profileService.getProfile(uid);
      if (mounted) setState(() => _profile = p);
    } catch (_) {/* leaderboard still works; name falls back to auth name */}
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  String _weekRange() {
    final now = DateTime.now();
    final s = LeaderboardService.weekStart(now);
    final e = LeaderboardService.weekEnd(now);
    const arMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final months = _isArabic ? arMonths : enMonths;
    return '${s.day} ${months[s.month - 1]} – ${e.day} ${months[e.month - 1]}';
  }

  int _daysLeft() {
    final now = DateTime.now();
    final e = LeaderboardService.weekEnd(now);
    return DateTime(e.year, e.month, e.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  String _lossText(double lossKg) {
    final abs = lossKg.abs().toStringAsFixed(1);
    if (lossKg > 0) return _t('−$abs كجم', '−$abs kg');
    if (lossKg < 0) return _t('+$abs كجم', '+$abs kg');
    return _t('0.0 كجم', '0.0 kg');
  }

  // ── Update weight sheet ────────────────────────────────────────────────────

  Future<void> _openUpdateSheet(LeaderboardEntry? mine) async {
    final uid = _uid;
    if (uid == null) return;

    final fallbackStart = _profile?.weightKg ?? 0;
    final initial = mine?.currentWeightKg ?? _profile?.weightKg;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _UpdateWeightSheet(
        initialWeight: initial,
        isArabic: _isArabic,
        onSave: (weight) async {
          final name = (_profile?.name.isNotEmpty ?? false)
              ? _profile!.name
              : (widget.authService.currentUser?.displayName ?? _t('مستخدم', 'User'));
          await widget.leaderboardService.updateWeight(
            uid: uid,
            name: name,
            newWeightKg: weight,
            fallbackStartKg: fallbackStart > 0 ? fallbackStart : weight,
          );
        },
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('تم تحديث وزنك', 'Your weight was updated'))),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      appBar: AppBar(title: Text(_t('لوحة المتصدرين الأسبوعية', 'Weekly Leaderboard'))),
      body: SafeArea(
        child: uid == null
            ? Center(child: Text(_t('سجّل الدخول أولاً', 'Please sign in first')))
            : StreamBuilder<LeaderboardEntry?>(
                stream: widget.leaderboardService.watchMine(uid),
                builder: (context, mineSnap) {
                  final mine = mineSnap.data;
                  return StreamBuilder<List<LeaderboardEntry>>(
                    stream: widget.leaderboardService.watchTop(),
                    builder: (context, topSnap) => _content(context, uid, mine, topSnap),
                  );
                },
              ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    String uid,
    LeaderboardEntry? mine,
    AsyncSnapshot<List<LeaderboardEntry>> topSnap,
  ) {
    final theme = Theme.of(context);
    final entries = topSnap.data ?? const <LeaderboardEntry>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Week header
        Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_weekRange(), style: theme.textTheme.titleMedium),
            ),
            Text(
              _t('متبقي ${_daysLeft()} يوم', '${_daysLeft()} days left'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),

        _myProgressCard(context, mine, entries.indexWhere((e) => e.uid == uid)),
        const SizedBox(height: 20),

        Text(
          _t('الترتيب (حسب نسبة خسارة الوزن)', 'Ranking (by % of body weight lost)'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),

        if (topSnap.hasError)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _t('تعذر تحميل الترتيب', 'Could not load the leaderboard'),
              textAlign: TextAlign.center,
            ),
          )
        else if (topSnap.connectionState == ConnectionState.waiting && entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _t('لا أحد سجّل تقدمه هذا الأسبوع بعد. كن الأول!',
                  'No one has logged progress this week yet. Be the first!'),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (var i = 0; i < entries.length; i++)
            _entryRow(context, i + 1, entries[i], isMe: entries[i].uid == uid),
      ],
    );
  }

  Widget _myProgressCard(BuildContext context, LeaderboardEntry? mine, int topIndex) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('تقدمك هذا الأسبوع', 'Your progress this week'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (mine == null)
              Text(
                _t('لم تسجل وزنك هذا الأسبوع بعد.', 'You haven\'t logged your weight this week yet.'),
                style: theme.textTheme.bodyMedium,
              )
            else
              Row(
                children: [
                  _miniStat(context, _t('البداية', 'Start'),
                      '${mine.startWeightKg.toStringAsFixed(1)} ${_t('كجم', 'kg')}'),
                  _miniStat(context, _t('الآن', 'Now'),
                      '${mine.currentWeightKg.toStringAsFixed(1)} ${_t('كجم', 'kg')}'),
                  _miniStat(context, _t('الفرق', 'Change'), _lossText(mine.lossKg),
                      highlight: true),
                  _miniStat(
                    context,
                    _t('ترتيبك', 'Rank'),
                    topIndex >= 0 ? '#${topIndex + 1}' : '50+',
                  ),
                ],
              ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _openUpdateSheet(mine),
              icon: const Icon(Icons.edit_outlined),
              label: Text(mine == null
                  ? _t('سجّل وزنك', 'Log your weight')
                  : _t('تحديث الوزن', 'Update weight')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value, {bool highlight = false}) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _entryRow(BuildContext context, int rank, LeaderboardEntry e, {required bool isMe}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Color? medal;
    if (rank == 1) medal = const Color(0xFFD4AF37);
    if (rank == 2) medal = const Color(0xFF9E9E9E);
    if (rank == 3) medal = const Color(0xFFB87333);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? scheme.primary : Colors.black12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: medal != null
                ? Icon(Icons.workspace_premium, color: medal, size: 28)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? '${e.name} ${_t('(أنت)', '(you)')}' : e.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _lossText(e.lossKg),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: e.lossKg > 0 ? scheme.primary : null,
                ),
              ),
              Text(
                '${e.lossPercent.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _UpdateWeightSheet extends StatefulWidget {
  const _UpdateWeightSheet({
    required this.initialWeight,
    required this.isArabic,
    required this.onSave,
  });

  final double? initialWeight;
  final bool isArabic;
  final Future<void> Function(double weightKg) onSave;

  @override
  State<_UpdateWeightSheet> createState() => _UpdateWeightSheetState();
}

class _UpdateWeightSheetState extends State<_UpdateWeightSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialWeight?.toStringAsFixed(1) ?? '',
  );
  bool _saving = false;

  String _t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(parseLocalizedNumber(_ctrl.text)!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('تعذر الحفظ، حاول مرة أخرى', 'Could not save. Please try again.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('وزنك الحالي', 'Your current weight'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _t('أدخل وزنك الحقيقي. الترتيب يعتمد على أمانتك.',
                  'Enter your real weight — the leaderboard runs on honesty.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _t('الوزن', 'Weight'),
                suffixText: _t('كجم', 'kg'),
                prefixIcon: const Icon(Icons.monitor_weight_outlined),
              ),
              validator: (v) {
                final n = parseLocalizedNumber(v ?? '');
                if (n == null) return _t('أدخل رقماً صحيحاً', 'Enter a valid number');
                if (n < 25 || n > 300) {
                  return _t('القيمة بين 25 و 300', 'Must be between 25 and 300');
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(_t('حفظ', 'Save')),
            ),
          ],
        ),
      ),
    );
  }
}
