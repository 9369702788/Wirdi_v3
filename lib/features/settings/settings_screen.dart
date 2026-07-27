import 'package:flutter/material.dart';

import '../../core/services/settings_service.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'sources_licenses_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _wirdTarget = 5;

  @override
  void initState() {
    super.initState();
    _loadWirdTarget();
  }

  Future<void> _loadWirdTarget() async {
    final target = await UserProgressService.dailyWirdTarget();
    if (mounted) setState(() => _wirdTarget = target);
  }

  Future<void> _setWirdTarget(int value) async {
    if (value < 1) return;
    await UserProgressService.setDailyWirdTarget(value);
    setState(() => _wirdTarget = value);
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البيانات المحلية'),
        content: const Text(
          'سيتم حذف المفضلة وإحصاءات التسبيح وتقدم الورد اليومي وكل الإعدادات المحفوظة على هذا الجهاز. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UserProgressService.clearAllLocalData();
      await appSettings.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف جميع البيانات المحلية')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: ListenableBuilder(
        listenable: appSettings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel('المظهر'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الوضع', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode_outlined)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('داكن'), icon: Icon(Icons.dark_mode_outlined)),
                          ButtonSegment(value: ThemeMode.system, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_outlined)),
                        ],
                        selected: {appSettings.themeMode},
                        onSelectionChanged: (set) => appSettings.setThemeMode(set.first),
                      ),
                      const SizedBox(height: 20),
                      const Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.w700)),
                      Slider(
                        value: appSettings.fontScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        label: '${(appSettings.fontScale * 100).round()}%',
                        onChanged: (value) => appSettings.setFontScale(value),
                      ),
                      Text(
                        'نص تجريبي لمعاينة حجم الخط',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 16 * appSettings.fontScale),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _SectionLabel('الورد اليومي'),
              Card(
                child: ListTile(
                  title: const Text('الهدف اليومي (صفحات/سور)'),
                  subtitle: Text('$_wirdTarget في اليوم'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: () => _setWirdTarget(_wirdTarget - 1), icon: const Icon(Icons.remove_circle_outline)),
                      IconButton(onPressed: () => _setWirdTarget(_wirdTarget + 1), icon: const Icon(Icons.add_circle_outline)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _SectionLabel('حول ودعم'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('عن التطبيق'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.source_outlined),
                      title: const Text('المصادر والتراخيص'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesLicensesScreen())),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('سياسة الخصوصية'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _SectionLabel('إدارة البيانات'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('حذف جميع البيانات المحلية', style: TextStyle(color: Colors.red)),
                  onTap: _confirmClearData,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.mutedText, fontSize: 13),
      ),
    );
  }
}
