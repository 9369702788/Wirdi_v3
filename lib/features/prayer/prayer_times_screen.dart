import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/prayer_models.dart';
import '../../core/services/prayer_service.dart';
import '../../core/theme/app_theme.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  bool _loading = true;
  PrayerAvailability? _availabilityError;
  PrayerTimesResult? _result;
  String _countdown = '--:--:--';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _availabilityError = null;
    });

    try {
      final result = await PrayerService.fetchPrayerTimes();
      setState(() {
        _result = result;
        _loading = false;
      });
      _startCountdown();
    } on PrayerAvailability catch (e) {
      setState(() {
        _availabilityError = e;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _availabilityError = PrayerAvailability.networkErrorNoCache;
        _loading = false;
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final result = _result;
    if (result == null) return;

    final diff = result.next.dateTime.difference(DateTime.now());
    if (diff.isNegative) {
      _load();
      return;
    }

    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    if (mounted) setState(() => _countdown = '$hours:$minutes:$seconds');
  }

  String _availabilityMessage(PrayerAvailability e) => switch (e) {
        PrayerAvailability.locationServiceDisabled =>
          'خدمة الموقع غير مفعّلة على جهازك. فعّلها لعرض مواقيت الصلاة.',
        PrayerAvailability.permissionDenied =>
          'التطبيق يحتاج إذن الوصول إلى الموقع لعرض مواقيت صلاة دقيقة.',
        PrayerAvailability.permissionDeniedForever =>
          'تم رفض إذن الموقع بشكل دائم. فعّله من إعدادات النظام لهذا التطبيق.',
        PrayerAvailability.networkErrorNoCache =>
          'تعذر الاتصال بالإنترنت ولا توجد مواقيت محفوظة مسبقًا.',
        PrayerAvailability.ok => '',
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_availabilityError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('مواقيت الصلاة'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_outlined, size: 52, color: AppColors.mutedText),
                const SizedBox(height: 16),
                Text(_availabilityMessage(_availabilityError!),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.mutedText)),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      );
    }

    final result = _result!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (result.isFromCache)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.goldAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.goldAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('لا يوجد اتصال — تُعرض آخر مواقيت محفوظة', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryEmerald, Color(0xFF115E56)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text('الصلاة القادمة', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 10),
                Text(result.next.name, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(_countdown, style: const TextStyle(color: AppColors.goldAccent, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                const Text('الوقت المتبقي', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...result.prayers.map((prayer) {
            final isNext = prayer.name == result.next.name;
            return Card(
              color: isNext ? AppColors.primaryEmerald.withValues(alpha: 0.08) : null,
              child: ListTile(
                leading: Icon(Icons.mosque_outlined, color: isNext ? AppColors.primaryEmerald : AppColors.mutedText),
                title: Text(prayer.name, style: TextStyle(fontWeight: isNext ? FontWeight.bold : FontWeight.w600)),
                trailing: Text(prayer.timeText, style: TextStyle(fontWeight: FontWeight.bold, color: isNext ? AppColors.primaryEmerald : null)),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            'ملاحظة: المواقيت تعتمد على موقع الهاتف وخدمة AlAdhan بطريقة الحساب المصرية.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}
