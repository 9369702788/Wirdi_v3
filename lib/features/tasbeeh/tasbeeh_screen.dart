import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

class _TasbeehPhrase {
  final String id;
  final String text;
  final int target;
  const _TasbeehPhrase(this.id, this.text, this.target);
}

const _phrases = [
  _TasbeehPhrase('subhanallah', 'سبحان الله', 33),
  _TasbeehPhrase('alhamdulillah', 'الحمد لله', 33),
  _TasbeehPhrase('allahuakbar', 'الله أكبر', 33),
  _TasbeehPhrase('la_ilaha', 'لا إله إلا الله', 100),
  _TasbeehPhrase('astaghfirullah', 'أستغفر الله', 100),
  _TasbeehPhrase('salawat', 'اللهم صل على محمد', 100),
];

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  _TasbeehPhrase _selected = _phrases.first;
  int _today = 0;
  int _total = 0;

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDay = prefs.getString('tasbeeh_day_${_selected.id}');
    final todayCount = storedDay == _todayKey() ? (prefs.getInt('tasbeeh_today_${_selected.id}') ?? 0) : 0;

    setState(() {
      _today = todayCount;
      _total = prefs.getInt('tasbeeh_total_${_selected.id}') ?? 0;
    });
  }

  Future<void> _increment() async {
    HapticFeedback.mediumImpact();

    final prefs = await SharedPreferences.getInstance();
    final next = _today + 1;
    final nextTotal = _total + 1;

    await prefs.setInt('tasbeeh_today_${_selected.id}', next);
    await prefs.setString('tasbeeh_day_${_selected.id}', _todayKey());
    await prefs.setInt('tasbeeh_total_${_selected.id}', nextTotal);

    setState(() {
      _today = next;
      _total = nextTotal;
    });

    if (_today == _selected.target) {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tasbeeh_today_${_selected.id}', 0);
    await prefs.setString('tasbeeh_day_${_selected.id}', _todayKey());
    setState(() => _today = 0);
  }

  void _selectPhrase(_TasbeehPhrase phrase) {
    setState(() => _selected = phrase);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_today / _selected.target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التسبيح'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _reset, icon: const Icon(Icons.refresh), tooltip: 'إعادة تعيين اليوم'),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _phrases.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final phrase = _phrases[index];
                final isSelected = phrase.id == _selected.id;
                return ChoiceChip(
                  label: Text(phrase.text),
                  selected: isSelected,
                  onSelected: (_) => _selectPhrase(phrase),
                  selectedColor: AppColors.primaryEmerald.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primaryEmerald : null,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatChip(label: 'اليوم', value: '$_today'),
                _StatChip(label: 'الهدف', value: '${_selected.target}'),
                _StatChip(label: 'الإجمالي', value: '$_total'),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _increment,
                child: Container(
                  width: 230,
                  height: 230,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.primaryEmerald, Color(0xFF115E56)]),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryEmerald.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 210,
                        height: 210,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(AppColors.goldAccent),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_today', style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w700)),
                          Text(_selected.text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 32),
            child: Text('اضغط للتسبيح', style: TextStyle(color: AppColors.mutedText)),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(label, style: const TextStyle(color: AppColors.mutedText, fontSize: 11)),
        ],
      ),
    );
  }
}
