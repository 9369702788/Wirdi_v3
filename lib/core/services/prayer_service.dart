import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_sources.dart';
import '../models/prayer_models.dart';

const List<String> _kOrderedNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
const List<String> _kOrderedApiKeys = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

/// Single source of truth for prayer times: real GPS + AlAdhan API, with
/// an offline fallback to the last successful response (clearly marked
/// as cached, never presented as live). Used by both the Prayer Times
/// screen and the Home Dashboard so "next prayer" always agrees.
class PrayerService {
  PrayerService._();

  static const _cacheTimingsKey = 'cache_prayer_timings_v1';
  static const _cacheDateKey = 'cache_prayer_timings_date_v1';

  /// Throws a [PrayerAvailability] (not an Exception) on failure so the
  /// UI can render an exact, real reason rather than a generic message.
  static Future<PrayerTimesResult> fetchPrayerTimes() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final cached = await _tryLoadCache();
      if (cached != null) return cached;
      throw PrayerAvailability.locationServiceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      final cached = await _tryLoadCache();
      if (cached != null) return cached;
      throw PrayerAvailability.permissionDeniedForever;
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      final cached = await _tryLoadCache();
      if (cached != null) return cached;
      throw PrayerAvailability.permissionDenied;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      final url = AppSources.prayerTimesUrl(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final timings = decoded['data']['timings'] as Map<String, dynamic>;

      await _saveCache(timings);

      return _buildResult(timings, isFromCache: false, cachedAt: DateTime.now());
    } catch (_) {
      final cached = await _tryLoadCache();
      if (cached != null) return cached;
      throw PrayerAvailability.networkErrorNoCache;
    }
  }

  static Future<void> _saveCache(Map<String, dynamic> timings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheTimingsKey, jsonEncode(timings));
    await prefs.setString(_cacheDateKey, DateTime.now().toIso8601String());
  }

  static Future<PrayerTimesResult?> _tryLoadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheTimingsKey);
    final dateRaw = prefs.getString(_cacheDateKey);
    if (raw == null) return null;

    final timings = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt = dateRaw != null ? DateTime.tryParse(dateRaw) : null;

    // Clock times (HH:mm) are re-applied to *today's* date. This is a
    // reasonable offline approximation (times shift by only ~1-2 min/day)
    // and is always labeled isFromCache=true in the UI, never presented
    // as a live reading.
    return _buildResult(timings, isFromCache: true, cachedAt: cachedAt);
  }

  static PrayerTimesResult _buildResult(
    Map<String, dynamic> timings, {
    required bool isFromCache,
    DateTime? cachedAt,
  }) {
    final now = DateTime.now();

    final prayers = <PrayerItem>[];
    for (var i = 0; i < _kOrderedNames.length; i++) {
      final timeText = _cleanTime(timings[_kOrderedApiKeys[i]]);
      prayers.add(PrayerItem(
        name: _kOrderedNames[i],
        timeText: timeText,
        dateTime: _timeToday(timeText, now),
      ));
    }

    final next = _nextPrayer(prayers, now);

    return PrayerTimesResult(
      prayers: prayers,
      next: next,
      isFromCache: isFromCache,
      cachedAt: cachedAt,
    );
  }

  static PrayerItem _nextPrayer(List<PrayerItem> prayers, DateTime now) {
    for (final prayer in prayers) {
      if (prayer.dateTime.isAfter(now)) return prayer;
    }
    final fajrTomorrow = prayers.first.dateTime.add(const Duration(days: 1));
    return PrayerItem(
      name: prayers.first.name,
      timeText: prayers.first.timeText,
      dateTime: fajrTomorrow,
    );
  }

  static String _cleanTime(dynamic value) {
    final text = value.toString();
    if (text.contains(' ')) return text.split(' ').first;
    return text;
  }

  static DateTime _timeToday(String value, DateTime now) {
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
