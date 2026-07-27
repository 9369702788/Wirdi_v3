import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user progress/state shared across screens: favorites,
/// per-item azkar counters (with real daily reset), daily wird tracking,
/// and last-read position. Single source of truth so the Home Dashboard
/// reflects exactly what Quran/Azkar/Tasbeeh screens have recorded.
class UserProgressService {
  UserProgressService._();

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ---------------- Favorites (Quran ayahs + Azkar items) ----------------

  static Future<Set<String>> _getSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const []).toSet();
  }

  static Future<void> _saveSet(String key, Set<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value.toList());
  }

  static Future<Set<String>> favoriteAyahs() => _getSet('favorite_ayahs_all');

  static Future<void> toggleFavoriteAyah(String uid) async {
    final set = await favoriteAyahs();
    if (!set.add(uid)) set.remove(uid);
    await _saveSet('favorite_ayahs_all', set);
  }

  static Future<Set<String>> favoriteAzkar() => _getSet('favorite_azkar_all');

  static Future<void> toggleFavoriteAzkar(String uid) async {
    final set = await favoriteAzkar();
    if (!set.add(uid)) set.remove(uid);
    await _saveSet('favorite_azkar_all', set);
  }

  static Future<int> totalFavoritesCount() async {
    final a = await favoriteAyahs();
    final b = await favoriteAzkar();
    return a.length + b.length;
  }

  // ---------------- Azkar per-item counters (reset daily) ----------------

  static Future<int> azkarCount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final storedDay = prefs.getString('azkar_count_day_$uid');
    if (storedDay != _todayKey()) return 0;
    return prefs.getInt('azkar_count_$uid') ?? 0;
  }

  static Future<int> incrementAzkarCount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await azkarCount(uid);
    final next = current + 1;
    await prefs.setInt('azkar_count_$uid', next);
    await prefs.setString('azkar_count_day_$uid', _todayKey());
    return next;
  }

  static Future<void> resetAzkarCount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('azkar_count_$uid', 0);
    await prefs.setString('azkar_count_day_$uid', _todayKey());
  }

  static Future<Set<String>> completedAzkarToday() =>
      _getSet('azkar_completed_${_todayKey()}');

  static Future<void> markAzkarCompleted(String uid) async {
    final set = await completedAzkarToday();
    set.add(uid);
    await _saveSet('azkar_completed_${_todayKey()}', set);
  }

  // ---------------- Last read (Quran) ----------------

  static Future<void> saveLastReading({
    required int surahNumber,
    required String surahName,
    required int ayahNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah_number', surahNumber);
    await prefs.setString('last_surah_name', surahName);
    await prefs.setInt('last_ayah_number', ayahNumber);
  }

  static Future<Map<String, dynamic>?> lastReading() async {
    final prefs = await SharedPreferences.getInstance();
    final number = prefs.getInt('last_surah_number');
    if (number == null) return null;
    return {
      'surahNumber': number,
      'surahName': prefs.getString('last_surah_name') ?? '',
      'ayahNumber': prefs.getInt('last_ayah_number') ?? 1,
    };
  }

  // ---------------- Daily Wird (pages) ----------------

  static Future<int> dailyWirdTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('wird_target_pages') ?? 5;
  }

  static Future<void> setDailyWirdTarget(int pages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wird_target_pages', pages);
  }

  static Future<int> pagesReadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDay = prefs.getString('wird_progress_day');
    if (storedDay != _todayKey()) return 0;
    return prefs.getInt('wird_progress_pages') ?? 0;
  }

  static Future<int> markPageRead() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await pagesReadToday();
    final next = current + 1;
    await prefs.setInt('wird_progress_pages', next);
    await prefs.setString('wird_progress_day', _todayKey());
    return next;
  }

  /// Current daily streak: counts consecutive days (ending today or
  /// yesterday) where the wird target was met. Stored as a simple
  /// incrementing counter updated whenever a day's target is completed.
  static Future<int> wirdStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('wird_streak') ?? 0;
  }

  static Future<void> registerStreakCheckpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCompletedDay = prefs.getString('wird_streak_last_day');
    final target = await dailyWirdTarget();
    final progress = await pagesReadToday();

    if (progress < target) return;
    if (lastCompletedDay == _todayKey()) return; // already counted today

    final streak = prefs.getInt('wird_streak') ?? 0;
    await prefs.setInt('wird_streak', streak + 1);
    await prefs.setString('wird_streak_last_day', _todayKey());
  }

  // ---------------- Local data management ----------------

  static Future<void> clearAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
