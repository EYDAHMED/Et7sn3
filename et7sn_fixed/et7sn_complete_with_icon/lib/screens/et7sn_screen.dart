import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/prayer_service.dart';

class Et7snScreen extends StatefulWidget {
  const Et7snScreen({
    super.key,
    required this.locationService,
    required this.prayerService,
  });

  final LocationService locationService;
  final PrayerService prayerService;

  @override
  State<Et7snScreen> createState() => _Et7snScreenState();
}

class _Et7snScreenState extends State<Et7snScreen> {
  Timer? _timer;

  AppLocation? _location;
  PrayerSchedule? _schedule;
  PrayerEntry? _next;
  PrayerEntry? _tomorrowFajr; // cached for the stretch after Isha
  DateTime _now = DateTime.now();

  bool _loading = true;
  bool _usingCached = false;
  LocationFailure? _failure;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_schedule != null && mounted) {
        setState(() => _computeNext(DateTime.now()));
      }
    });
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  // ── Loading ────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    // Show cached times instantly while GPS warms up.
    if (_location == null) {
      final cached = await widget.locationService.cachedLocation();
      if (cached != null && mounted) {
        setState(() => _apply(cached));
      }
    }

    try {
      final fresh = await widget.locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _usingCached = false;
        _loading = false;
        _apply(fresh);
      });
    } on LocationFailure catch (e) {
      _onLocationError(e);
    } catch (_) {
      _onLocationError(const LocationFailure(LocationIssue.unavailable));
    }
  }

  void _onLocationError(LocationFailure failure) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (_location == null) {
        _failure = failure;
      } else {
        _usingCached = true; // keep showing the last known position
      }
    });
  }

  void _useFallback() {
    setState(() {
      _failure = null;
      _loading = false;
      _usingCached = false;
      _apply(LocationService.cairoFallback);
    });
  }

  void _apply(AppLocation location) {
    _location = location;
    _tomorrowFajr = null;
    final now = DateTime.now();
    _schedule = widget.prayerService.scheduleFor(location.latitude, location.longitude, now);
    _computeNext(now);
  }

  /// Finds the next prayer; rolls over to the next day's Fajr after Isha and
  /// recomputes the schedule when midnight passes.
  void _computeNext(DateTime now) {
    final loc = _location!;
    var schedule = _schedule!;

    if (!_sameDay(schedule.date, now)) {
      schedule = widget.prayerService.scheduleFor(loc.latitude, loc.longitude, now);
      _schedule = schedule;
      _tomorrowFajr = null;
    }

    var next = schedule.nextPrayer(now);
    if (next == null) {
      _tomorrowFajr ??= widget.prayerService
          .scheduleFor(loc.latitude, loc.longitude, now.add(const Duration(days: 1)))
          .entry(PrayerName.fajr);
      next = _tomorrowFajr;
    }

    _now = now;
    _next = next;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Formatting ─────────────────────────────────────────────────────────────

  String _fmtTime(DateTime t) {
    var h = t.hour % 12;
    if (h == 0) h = 12;
    final m = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour < 12 ? _t('ص', 'AM') : _t('م', 'PM');
    return '$h:$m $suffix';
  }

  String _fmtCountdown(Duration d) {
    if (d.isNegative) d = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('مواقيت الصلاة', 'Prayer Times')),
        actions: [
          IconButton(
            tooltip: _t('تحديث الموقع', 'Refresh location'),
            icon: const Icon(Icons.my_location),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_schedule == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return _errorView(context);
    }

    final schedule = _schedule!;
    final next = _next!;
    final remaining = next.time.difference(_now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _countdownCard(context, next, remaining),
        const SizedBox(height: 16),
        for (final e in schedule.entries) _row(context, e, isNext: e.name == next.name && _sameDay(e.time, next.time)),
        const SizedBox(height: 12),
        _footer(context),
      ],
    );
  }

  Widget _countdownCard(BuildContext context, PrayerEntry next, Duration remaining) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              _t('الصلاة القادمة', 'Next prayer'),
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimary.withOpacity(0.85)),
            ),
            const SizedBox(height: 4),
            Text(
              next.name.label(isArabic: _isArabic),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            // Digits stay left-to-right in both languages.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                _fmtCountdown(remaining),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t('عند ${_fmtTime(next.time)}', 'at ${_fmtTime(next.time)}'),
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, PrayerEntry entry, {required bool isNext}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final passed = entry.time.isBefore(_now);

    final textColor = isNext
        ? scheme.onPrimaryContainer
        : passed
            ? Colors.black38
            : scheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isNext ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNext ? scheme.primary : Colors.black12,
          width: isNext ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            entry.name == PrayerName.sunrise ? Icons.wb_twilight : Icons.access_time,
            color: isNext ? scheme.primary : textColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            entry.name.label(isArabic: _isArabic),
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            _fmtTime(entry.time),
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54);
    final loc = _location!;

    String where;
    if (loc.isFallback) {
      where = _t('المواقيت حسب القاهرة (موقع افتراضي)', 'Times for Cairo (default location)');
    } else if (_usingCached) {
      where = _t('المواقيت حسب آخر موقع معروف', 'Times for your last known location');
    } else {
      where = _t('المواقيت حسب موقعك الحالي', 'Times for your current location');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(where, style: style),
        const SizedBox(height: 2),
        Text(
          _t('طريقة الحساب: الهيئة المصرية العامة للمساحة',
              'Method: Egyptian General Authority of Survey'),
          style: style,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _errorView(BuildContext context) {
    final failure = _failure ?? const LocationFailure(LocationIssue.unavailable);

    Widget? settingsButton;
    if (failure.issue == LocationIssue.serviceDisabled) {
      settingsButton = OutlinedButton(
        onPressed: widget.locationService.openLocationSettings,
        child: Text(_t('فتح إعدادات الموقع', 'Open location settings')),
      );
    } else if (failure.issue == LocationIssue.permissionDeniedForever) {
      settingsButton = OutlinedButton(
        onPressed: widget.locationService.openAppSettings,
        child: Text(_t('فتح إعدادات التطبيق', 'Open app settings')),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              failure.message(isArabic: _isArabic),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _load, child: Text(_t('إعادة المحاولة', 'Try again'))),
            if (settingsButton != null) ...[const SizedBox(height: 12), settingsButton],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _useFallback,
              child: Text(_t('استخدم مواقيت القاهرة', 'Use Cairo times instead')),
            ),
          ],
        ),
      ),
    );
  }
}
