import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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
              onRetry: () => setState(
                () => _future = QuranRepository.load(forceRefresh: true),
              ),
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
                            style: const TextStyle(
                              color: Color(0xFF0F766E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          surah.name,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${surah.englishName} - ${surah.ayahs.length} آية',
                          textAlign: TextAlign.right,
                        ),
                        trailing: const Icon(Icons.menu_book),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SurahReaderScreen(surah: surah),
                            ),
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

  const SurahReaderScreen({
    super.key,
    required this.surah,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final StreamSubscription<void> _audioCompleteSubscription;

  Set<String> _favoriteAyahs = {};

  bool _isPlaying = false;
  bool _isAudioLoading = false;

  String _uid(int ayahNumber) => '${widget.surah.number}_$ayahNumber';

  String get _surahAudioUrl {
    final surahNumber = widget.surah.number.toString().padLeft(3, '0');
    return 'https://server8.mp3quran.net/afs/$surahNumber.mp3';
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();

    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isAudioLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _audioCompleteSubscription.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favs = await UserProgressService.favoriteAyahs();
    if (!mounted) return;
    setState(() => _favoriteAyahs = favs);
  }

  Future<void> _toggleFavorite(int ayahNumber) async {
    await UserProgressService.toggleFavoriteAyah(_uid(ayahNumber));
    final favs = await UserProgressService.favoriteAyahs();
    if (!mounted) return;
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
      SnackBar(
        content: Text(
          'تم حفظ آخر قراءة: سورة ${widget.surah.name} - آية $ayahNumber',
        ),
      ),
    );
  }

  Future<void> _markSurahReadToday() async {
    await UserProgressService.markPageRead();
    await UserProgressService.registerStreakCheckpoint();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('أُضيفت هذه القراءة إلى وردك اليومي 🌿'),
      ),
    );
  }

  Future<void> _toggleAudio() async {
    if (_isAudioLoading) return;

    setState(() {
      _isAudioLoading = true;
    });

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();

        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isAudioLoading = false;
        });
      } else {
        await _audioPlayer.play(
          UrlSource(_surahAudioUrl),
        );

        if (!mounted) return;
        setState(() {
          _isPlaying = true;
          _isAudioLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isPlaying = false;
        _isAudioLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تشغيل التلاوة. تأكد من اتصال الإنترنت.'),
        ),
      );
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();

      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isAudioLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isAudioLoading = false;
      });
    }
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
            tooltip: _isPlaying ? 'إيقاف التلاوة مؤقتاً' : 'تشغيل التلاوة',
            onPressed: _isAudioLoading ? null : _toggleAudio,
            icon: _isAudioLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
          ),
          IconButton(
            tooltip: 'إيقاف التلاوة',
            onPressed: _isPlaying || _isAudioLoading ? _stopAudio : 
