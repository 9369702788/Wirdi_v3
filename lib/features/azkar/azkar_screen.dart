import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/azkar_models.dart';
import '../../core/services/azkar_repository.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';

class AzkarScreen extends StatefulWidget {
  const AzkarScreen({super.key});

  @override
  State<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreen> {
  late Future<List<AzkarCategoryModel>> _future;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = AzkarRepository.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأذكار'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'المفضلة',
            icon: const Icon(Icons.favorite_outline),
            onPressed: () async {
              final categories = await _future.catchError((_) => <AzkarCategoryModel>[]);
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _AzkarFavoritesScreen(allCategories: categories),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<AzkarCategoryModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return _ErrorView(
              message: 'تعذر تحميل الأذكار. تأكد من اتصال الإنترنت.',
              onRetry: () => setState(() => _future = AzkarRepository.load(forceRefresh: true)),
            );
          }

          final categories = snapshot.data!;
          final query = _searchController.text.trim();

          final filtered = query.isEmpty
              ? categories
              : categories
                  .where((c) =>
                      c.category.contains(query) ||
                      c.items.any((i) => i.text.contains(query)))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'ابحث في الأذكار',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final category = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(category.category, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${category.items.length} ذكر'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AzkarDetailsScreen(category: category),
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

class AzkarDetailsScreen extends StatefulWidget {
  final AzkarCategoryModel category;

  const AzkarDetailsScreen({super.key, required this.category});

  @override
  State<AzkarDetailsScreen> createState() => _AzkarDetailsScreenState();
}

class _AzkarDetailsScreenState extends State<AzkarDetailsScreen> {
  final Map<String, int> _counts = {};
  Set<String> _favorites = {};
  Set<String> _completedToday = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final item in widget.category.items) {
      _counts[item.uid] = await UserProgressService.azkarCount(item.uid);
    }
    _favorites = await UserProgressService.favoriteAzkar();
    _completedToday = await UserProgressService.completedAzkarToday();
    if (mounted) setState(() {});
  }

  Future<void> _increment(AzkarItemModel item) async {
    HapticFeedback.lightImpact();
    final next = await UserProgressService.incrementAzkarCount(item.uid);
    setState(() => _counts[item.uid] = next);

    if (next >= item.targetCount && !_completedToday.contains(item.uid)) {
      HapticFeedback.mediumImpact();
      await UserProgressService.markAzkarCompleted(item.uid);
      _completedToday.add(item.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أحسنت 🌿 تم إكمال هذا الذكر'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _toggleFavorite(AzkarItemModel item) async {
    await UserProgressService.toggleFavoriteAzkar(item.uid);
    final favs = await UserProgressService.favoriteAzkar();
    setState(() => _favorites = favs);
  }

  void _share(AzkarItemModel item) {
    Clipboard.setData(ClipboardData(text: item.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الذكر — يمكنك لصقه للمشاركة')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.category), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.category.items.length,
        itemBuilder: (context, index) {
          final item = widget.category.items[index];
          final current = _counts[item.uid] ?? 0;
          final isDone = current >= item.targetCount;
          final isFavorite = _favorites.contains(item.uid);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isDone ? AppColors.primaryEmerald.withValues(alpha: 0.06) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    item.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 19, height: 1.9, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _toggleFavorite(item),
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? AppColors.goldAccent : AppColors.mutedText,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _share(item),
                        icon: const Icon(Icons.share_outlined, color: AppColors.mutedText),
                      ),
                      const Spacer(),
                      if (isDone)
                        const Icon(Icons.check_circle, color: AppColors.primaryEmerald)
                      else
                        Text('$current / ${item.targetCount}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _increment(item),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text('+1'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AzkarFavoritesScreen extends StatelessWidget {
  final List<AzkarCategoryModel> allCategories;
  const _AzkarFavoritesScreen({required this.allCategories});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأذكار المفضلة'), centerTitle: true),
      body: FutureBuilder<Set<String>>(
        future: UserProgressService.favoriteAzkar(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final favUids = snapshot.data!;
          final items = <AzkarItemModel>[];
          for (final cat in allCategories) {
            items.addAll(cat.items.where((i) => favUids.contains(i.uid)));
          }

          if (items.isEmpty) {
            return const Center(child: Text('لا توجد أذكار مفضلة بعد'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    item.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 17, height: 1.8),
                  ),
                ),
              );
            },
          );
        },
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
