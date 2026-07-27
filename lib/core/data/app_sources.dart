class AppSources {
  AppSources._();

  static const String quranJsonUrl =
      'https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/quran.json';

  static const String azkarJsonUrl =
      'https://raw.githubusercontent.com/YousefAsalya/Islamic-Pro-azkar-API/main/data/ar.json';

  static String prayerTimesUrl({
    required double latitude,
    required double longitude,
  }) {
    return 'https://api.aladhan.com/v1/timings?latitude=$latitude&longitude=$longitude&method=5';
  }

  static const String sourcesAndLicenses = '''
المصادر والتراخيص

نص القرآن الكريم:
Quran JSON
https://github.com/risan/quran-json

مصدر نص القرآن:
Tanzil Project
https://tanzil.net

الأذكار:
Hisn Al-Muslim / Islamic Pro Azkar API
https://github.com/YousefAsalya/Islamic-Pro-azkar-API

مواقيت الصلاة:
AlAdhan Prayer Times API
https://aladhan.com/prayer-times-api

ملاحظات مهمة:
- يجب عدم تعديل نص القرآن الكريم.
- يجب ذكر مصدر Tanzil داخل صفحة المصادر والتراخيص.
- مواقيت الصلاة قد تختلف عن توقيت المسجد المحلي إذا كانت هناك تعديلات محلية.
''';
}
