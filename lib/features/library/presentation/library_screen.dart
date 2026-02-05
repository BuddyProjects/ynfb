import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/book_card.dart';
import '../domain/book.dart';
import 'library_provider.dart';

class LibraryScreen extends StatefulWidget {
  final VoidCallback onImportTap;
  final Function(UserBook) onBookTap;

  const LibraryScreen({
    super.key,
    required this.onImportTap,
    required this.onBookTap,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(
          'My Library',
          style: AppTypography.headlineMedium,
        ),
        actions: [
          // View toggle
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppColors.textMedium,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          // Import button
          IconButton(
            icon: const Icon(
              Icons.add_rounded,
              color: AppColors.burntOrange,
            ),
            onPressed: widget.onImportTap,
          ),
        ],
      ),
      body: Consumer<LibraryProvider>(
        builder: (context, libraryProvider, _) {
          if (libraryProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.burntOrange,
              ),
            );
          }

          return Column(
            children: [
              // Stats & Filters
              _buildHeader(libraryProvider),
              // Filter chips
              _buildFilterChips(libraryProvider),
              // Books
              Expanded(
                child: libraryProvider.books.isEmpty
                    ? _buildEmptyState()
                    : _buildBookList(libraryProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(LibraryProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(
            label: 'Total Books',
            value: provider.totalBooks.toString(),
            icon: Icons.menu_book_rounded,
            color: AppColors.forestGreen,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: 'Rated',
            value: provider.ratedBooks.toString(),
            icon: Icons.star_rounded,
            color: AppColors.burntOrange,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: 'Unrated',
            value: provider.unratedBooks.toString(),
            icon: Icons.star_border_rounded,
            color: AppColors.textLight,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.titleLarge.copyWith(color: color),
            ),
            Text(
              label,
              style: AppTypography.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(LibraryProvider provider) {
    final filters = [
      (LibraryFilter.all, 'All'),
      (LibraryFilter.rated, 'Rated'),
      (LibraryFilter.unrated, 'Unrated'),
      (LibraryFilter.audible, 'Audible'),
      (LibraryFilter.kindle, 'Kindle'),
      (LibraryFilter.goodreads, 'Goodreads'),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = filters[index];
          final isSelected = provider.currentFilter == filter;

          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => provider.setFilter(filter),
            backgroundColor: AppColors.cardBackground,
            selectedColor: AppColors.burntOrangeLight.withAlpha(51),
            labelStyle: AppTypography.labelMedium.copyWith(
              color: isSelected ? AppColors.burntOrange : AppColors.textMedium,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppColors.burntOrange : AppColors.divider,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.beige,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.library_books_rounded,
                size: 48,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your library is empty',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import your books from Audible, Kindle, Goodreads, or add them manually.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onImportTap,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Import Books'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burntOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList(LibraryProvider provider) {
    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: provider.books.length,
        itemBuilder: (context, index) {
          final userBook = provider.books[index];
          return BookCard(
            book: userBook.book,
            rating: userBook.rating,
            onTap: () => widget.onBookTap(userBook),
            onRatingChanged: (rating) {
              provider.updateRating(userBook.id, rating);
            },
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final userBook = provider.books[index];
        return BookCard(
          book: userBook.book,
          rating: userBook.rating,
          onTap: () => widget.onBookTap(userBook),
          onRatingChanged: (rating) {
            provider.updateRating(userBook.id, rating);
          },
          isCompact: true,
        );
      },
    );
  }
}
