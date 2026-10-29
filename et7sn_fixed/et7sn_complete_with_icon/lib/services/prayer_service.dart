import 'package:adhan/adhan.dart';

enum PrayerName { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerNameX on PrayerName {
  /// Sunrise is shown in the list but isn't a prayer to count down to.
  bool get isPrayer => this != PrayerName.sunrise;

  String label({required bool isArabic}) {
    switch (this) {
      case PrayerName.fajr:
        return isArabic ? 'الفجر' : 'Fajr';
      case PrayerName.sunrise:
        return isArabic ? 'الشروق' : 'Sunrise';
      case PrayerName.dhuhr:
        return isArabic ? 'الظهر' : 'Dhuhr';
      case PrayerName.asr:
        return isArabic ? 'العصر' : 'Asr';
      case PrayerName.maghrib:
        return isArabic ? 'المغرب' : 'Maghrib';
      case PrayerName.isha:
        return isArabic ? 'العشاء' : 'Isha';
    }
  }
}

class PrayerEntry {
  const PrayerEntry(this.name, this.time);
  final PrayerName name;
  final DateTime time; // local time
}

class PrayerSchedule {
  const PrayerSchedule({required this.date, required this.entries});

  final DateTime date;
  final List<PrayerEntry> entries; // fajr → isha, in order

  PrayerEntry entry(PrayerName name) => entries.firstWhere((e) => e.name == name);

  /// First prayer (not sunrise) that is still ahead of [now], or null if all passed.
  PrayerEntry? nextPrayer(DateTime now) {
    for (final e in entries) {
      if (e.name.isPrayer && e.time.isAfter(now)) return e;
    }
    return null;
  }
}

/// Calculates prayer times on-device (no internet needed) using the
/// Egyptian General Authority of Survey method.
class PrayerService {
  PrayerSchedule scheduleFor(double latitude, double longitude, DateTime date) {
    final params = CalculationMethod.egyptian.getParameters()
      ..madhab = Madhab.shafi; // standard Asr (Egypt)

    final times = PrayerTimes(
      Coordinates(latitude, longitude),
      DateComponents.from(date),
      params,
    );

    DateTime local(DateTime? v) => v!.toLocal();

    return PrayerSchedule(
      date: DateTime(date.year, date.month, date.day),
      entries: [
        PrayerEntry(PrayerName.fajr, local(times.fajr)),
        PrayerEntry(PrayerName.sunrise, local(times.sunrise)),
        PrayerEntry(PrayerName.dhuhr, local(times.dhuhr)),
        PrayerEntry(PrayerName.asr, local(times.asr)),
        PrayerEntry(PrayerName.maghrib, local(times.maghrib)),
        PrayerEntry(PrayerName.isha, local(times.isha)),
      ],
    );
  }
}
