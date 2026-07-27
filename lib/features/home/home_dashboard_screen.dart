import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/daily_quotes.dart';
import '../../core/models/prayer_models.dart';
import '../../core/services/prayer_service.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';
import '../azkar/azkar_screen.dart';
import '../prayer/prayer_times_screen.dart';
import '../quran/quran_screen.dart';
import '../settings/settings_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  PrayerTimesResult? _prayer;
  bool _prayerFailed = false;
  Timer? _timer;
  String _countdown = '--:--:--';

  Map<String, dynamic>? _lastReading;
  int _favoritesCount = 0;
  int _pagesToday = 0;
  int _wirdTarget = 5;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    unawaited(_loadPrayer());

    final lastReading = await UserProgressService.lastReading();
    final favCount = await UserProgressService.totalFavoritesCount();
    final pagesToday = await UserProgressService.pagesReadToday();
    final target = await UserProgressService.dailyWirdTarget();
    final streak = await UserProgressService.wirdStreak();

    if (!mounted) return;
    setState(() {
      _lastReading = lastReading;
      _favoritesCount = favCount;
      _pagesToday = pagesToday;
      _wirdTarget = target;
      _streak = streak;
    });
  }

  Future<void> _loadPrayer() async {
    try {
      final result = await PrayerService.fetchPrayerTimes();
      if (!mounted) return;
      setState(() {
        _prayer = result;
        _prayerFailed = false;
      });
      _startCountdown();
    } catch (_) {
      if (!mounted) return;
      setState(() => _prayerFailed = true);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final prayer = _prayer;
    if (prayer == null) return;
    final diff = prayer.next.dateTime.difference(DateTime.now());
    if (diff.isNegative) {
      _loadPrayer();
      return;
    }
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    if (mounted) setState(() => _countdown = '$h:$m:$s');
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'ليلة مباركة 🌙';
    if (hour < 12) return 'صباح الخير 👋';
    if (hour < 17) return 'نهارك سعيد ☀️';
    return 'مساء الخير 👋';
  }

  @override
  Widget build(BuildContext context) {
    final wirdProgress = _wirdTarget == 0 ? 0.0 : (_pagesToday / _wirdTarget).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('وردي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_greeting(), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              _streak > 0 ? 'متتالية الورد: $_streak يوم 🔥' : 'واصل ما بدأته اليوم',
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 20),

            // Next prayer — real data from PrayerService, or a clear
            // "unavailable" state, never a hardcoded placeholder.
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerTimesScreen())),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryEmerald, Color(0xFF115E56)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الصلاة القادمة', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    if (_prayer != null) ...[
                      Text(_prayer!.next.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('بعد $_countdown', style: const TextStyle(color: AppColors.goldAccent, fontSize: 16)),
                      if (_prayer!.isFromCache)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('آخر مواقيت محفوظة (بدون اتصال)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ),
                    ] else if (_prayerFailed)
                      const Text('فعّل الموقع لعرض الصلاة القادمة', style: TextStyle(color: Colors.white70, fontSize: 15))
                    else
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _DashboardCard(
              icon: Icons.donut_large,
              title: 'الورد اليومي',
              subtitle: _pagesToday >= _wirdTarget
                  ? 'أتممت وردك اليوم، بارك الله فيك 🎉'
                  : '$_pagesToday من $_wirdTarget صفحات/سور',
              trailing: _MiniProgress(value: wirdProgress),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranScreen())),
            ),
            const SizedBox(height: 12),

            _DashboardCard(
              icon: Icons.bookmark_outline,
              title: 'متابعة القراءة',
              subtitle: _lastReading == null
                  ? 'لم يتم تحديد آخر قراءة بعد'
                  : 'سورة ${_lastReading!['surahName']} — آية ${_lastReading!['ayahNumber']}',
              trailing: const Icon(Icons.chevron_left, color: AppColors.mutedText),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranScreen())),
            ),
            const SizedBox(height: 12),

            _DashboardCard(
              icon: Icons.favorite_outline,
              title: 'المفضلة',
              subtitle: _favoritesCount == 0 ? 'لا توجد عناصر مفضلة بعد' : '$_favoritesCount عنصر محفوظ',
              trailing: const Icon(Icons.chevron_left, color: AppColors.mutedText),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarScreen())),
            ),
            const SizedBox(height: 12),

            _DashboardCard(
              icon: Icons.format_quote,
              title: 'وقفة اليوم',
              subtitle: DailyQuotes.forToday(),
              trailing: const SizedBox.shrink(),
              onTap: null,
            ),
            const SizedBox(height: 20),

            Text('إجراءات سريعة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.favorite_outline,
                    label: 'الأذكار',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.fingerprint,
                    label: 'التسبيح',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasbeehScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.access_time,
                    label: 'الصلاة',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerTimesScreen())),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primaryEmerald),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: AppColors.mutedText, fontSize: 14)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final double value;
  const _MiniProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 4,
            backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(AppColors.goldAccent),
          ),
          Text('${(value * 100).round()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryEmerald.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryEmerald),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
