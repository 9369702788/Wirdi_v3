import 'package:flutter/material.dart';

import '../../core/models/quran_models.dart';
import '../../core/services/quran_repository.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late Future<List<SurahModel>> _future;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = QuranRepository.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF6),
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<SurahModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _ErrorView(
              message: 'تعذر تحميل القرآن الكريم. تأكد من اتصال الإنترنت.',
              onRetry: () => setState(() => _future = QuranRepository.load(forceRefresh: true)),
            );
          }

          final allSurahs = snapshot.data!;
          final query = _searchController.text.trim();

          final filtered = allSurahs.where((surah) {
            if (query.isEmpty) return true;
            return surah.name.contains(query) ||
                surah.number.toString() == query ||
                surah.englishName.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم السورة أو رقمها',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final surah = filtered[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE6F3F1),
                          child: Text(
                            '${surah.number}',
                            style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(surah.name, textAlign: TextAlign.right, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        subtitle: Text('${surah.englishName} - ${surah.ayahs.length} آية', textAlign: TextAlign.right),
                        trailing: const Icon(Icons.menu_book),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SurahReaderScreen(surah: surah)),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SurahReaderScreen extends StatefulWidget {
  final SurahModel surah;

  const SurahReaderScreen({super.key, required this.surah});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  Set<String> _favoriteAyahs = {};

  String _uid(int ayahNumber) => '${widget.surah.number}_$ayahNumber';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await UserProgressService.favoriteAyahs();
    setState(() => _favoriteAyahs = favs);
  }

  Future<void> _toggleFavorite(int ayahNumber) async {
    await UserProgressService.toggleFavoriteAyah(_uid(ayahNumber));
    final favs = await UserProgressService.favoriteAyahs();
    setState(() => _favoriteAyahs = favs);
  }

  Future<void> _bookmark(int ayahNumber) async {
    await UserProgressService.saveLastReading(
      surahNumber: widget.surah.number,
      surahName: widget.surah.name,
      ayahNumber: ayahNumber,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ آخر قراءة: سورة ${widget.surah.name} - آية $ayahNumber')),
    );
  }

  Future<void> _markSurahReadToday() async {
    await UserProgressService.markPageRead();
    await UserProgressService.registerStreakCheckpoint();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أُضيفت هذه القراءة إلى وردك اليومي 🌿')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surah = widget.surah;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF6),
      appBar: AppBar(
        title: Text('سورة ${surah.name}'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'أضف إلى الورد اليومي',
            onPressed: _markSurahReadToday,
            icon: const Icon(Icons.playlist_add_check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primaryEmerald, Color(0xFF115E56)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text('سورة ${surah.name}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${surah.ayahs.length} آية', style: const TextStyle(color: AppColors.goldAccent, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...surah.ayahs.map((ayah) {
            final isFavorite = _favoriteAyahs.contains(_uid(ayah.number));

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${ayah.text}  ﴿${ayah.number}﴾',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 24, height: 2, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _bookmark(ayah.number),
                          icon: const Icon(Icons.bookmark_border, color: AppColors.mutedText),
                        ),
                        IconButton(
                          onPressed: () => _toggleFavorite(ayah.number),
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? AppColors.goldAccent : AppColors.mutedText,
                          ),
                        ),
                        const Spacer(),
                        Text('آية ${ayah.number}', style: const TextStyle(color: AppColors.mutedText, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.mutedText),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
