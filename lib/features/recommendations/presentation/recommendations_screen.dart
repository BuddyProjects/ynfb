import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/book_card.dart';
import '../../../core/widgets/cozy_button.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../library/domain/book.dart';
import '../../library/presentation/library_provider.dart';
import '../domain/recommendation.dart';
import 'recommendations_provider.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  RecommendationMode _selectedMode = RecommendationMode.surpriseMe;
  UserBook? _selectedBook;
  String? _selectedGenre;
  bool _showHistory = false;

  final List<String> _genres = [
    'Fiction',
    'Fantasy',
    'Science Fiction',
    'Mystery',
    'Romance',
    'Thriller',
    'Non-Fiction',
    'Biography',
    'Self-Help',
    'History',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(
          _showHistory ? 'Recommendation History' : 'Get Recommendations',
          style: AppTypography.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showHistory ? Icons.add_rounded : Icons.history_rounded,
              color: AppColors.textMedium,
            ),
            onPressed: () => setState(() => _showHistory = !_showHistory),
            tooltip: _showHistory ? 'New Recommendation' : 'View History',
          ),
        ],
      ),
      body: Consumer2<RecommendationsProvider, LibraryProvider>(
        builder: (context, recsProvider, libraryProvider, _) {
          if (recsProvider.isLoading) {
            return _buildLoadingState();
          }

          if (_showHistory) {
            return _buildHistoryView(recsProvider);
          }

          if (recsProvider.currentRecommendations.isNotEmpty) {
            return _buildResults(recsProvider);
          }

          return _buildModeSelection(libraryProvider);
        },
      ),
    );
  }

  Widget _buildHistoryView(RecommendationsProvider provider) {
    if (provider.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 64, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text('No history yet', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Your past recommendations will appear here.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CozyButton(
                label: 'Get Recommendations',
                onPressed: () => setState(() => _showHistory = false),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.history.length,
      itemBuilder: (context, index) {
        final session = provider.history[index];
        return _buildHistoryCard(session, provider);
      },
    );
  }

  Widget _buildHistoryCard(RecommendationSession session, RecommendationsProvider provider) {
    final modeLabel = switch (session.mode) {
      RecommendationMode.surpriseMe => '🎁 Surprise Me',
      RecommendationMode.moreLike => '📚 More Like...',
      RecommendationMode.genrePick => '🎯 Genre Pick',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          provider.selectSession(session);
          setState(() => _showHistory = false);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(modeLabel, style: AppTypography.titleMedium),
                  ),
                  Text(
                    _formatDate(session.createdAt),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textLight),
                  ),
                ],
              ),
              if (session.genreFilter != null) ...[
                const SizedBox(height: 4),
                Text('Genre: ${session.genreFilter}', style: AppTypography.bodySmall),
              ],
              const SizedBox(height: 8),
              Text(
                '${session.recommendations.length} books recommended',
                style: AppTypography.bodySmall.copyWith(color: AppColors.forestGreen),
              ),
              const SizedBox(height: 8),
              // Preview of book covers
              SizedBox(
                height: 50,
                child: Row(
                  children: session.recommendations.take(4).map((rec) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: rec.book.coverUrl != null
                            ? Image.network(rec.book.coverUrl!, width: 35, height: 50, fit: BoxFit.cover)
                            : Container(width: 35, height: 50, color: AppColors.beige),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.burntOrange.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AppColors.burntOrange,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Finding your next favourite book...',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Our AI is analyzing your reading taste',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelection(LibraryProvider libraryProvider) {
    final hasEnoughRatings = libraryProvider.ratedBooks >= 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning if not enough ratings
          if (!hasEnoughRatings) _buildRatingsWarning(libraryProvider),
          
          Text(
            'How would you like your recommendation?',
            style: AppTypography.headlineSmall,
          ),
          const SizedBox(height: 24),
          
          // Surprise Me
          _buildModeCard(
            mode: RecommendationMode.surpriseMe,
            title: 'Surprise Me! 🎁',
            description: 'Based on all your ratings, discover something new.',
            icon: Icons.auto_awesome_rounded,
            color: AppColors.burntOrange,
          ),
          const SizedBox(height: 16),
          
          // More Like X
          _buildModeCard(
            mode: RecommendationMode.moreLike,
            title: 'More Like... 📚',
            description: 'Pick a book you loved, and find similar gems.',
            icon: Icons.favorite_rounded,
            color: AppColors.forestGreen,
            child: _selectedMode == RecommendationMode.moreLike
                ? _buildBookSelector(libraryProvider)
                : null,
          ),
          const SizedBox(height: 16),
          
          // Genre Pick
          _buildModeCard(
            mode: RecommendationMode.genrePick,
            title: 'Genre Pick 🎯',
            description: 'In the mood for a specific genre?',
            icon: Icons.category_rounded,
            color: AppColors.burntOrange,
            child: _selectedMode == RecommendationMode.genrePick
                ? _buildGenreSelector()
                : null,
          ),
          
          const SizedBox(height: 32),
          
          // Get Recommendations button
          CozyButton(
            label: 'Get Recommendations',
            icon: Icons.auto_awesome_rounded,
            onPressed: hasEnoughRatings ? _getRecommendations : null,
            isFullWidth: true,
          ),
          
          if (!hasEnoughRatings)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Rate at least 3 books to get personalized recommendations.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingsWarning(LibraryProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(51)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate more books',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  'You\'ve rated ${provider.ratedBooks}/3 books. Rate more for better recommendations!',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required RecommendationMode mode,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    Widget? child,
  }) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(51),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(description, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                Radio<RecommendationMode>(
                  value: mode,
                  groupValue: _selectedMode,
                  onChanged: (value) => setState(() => _selectedMode = value!),
                  activeColor: color,
                ),
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookSelector(LibraryProvider libraryProvider) {
    final ratedBooks =
        libraryProvider.allBooks.where((b) => b.isRated).toList();

    if (ratedBooks.isEmpty) {
      return Text(
        'No rated books yet. Rate some books first!',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textLight,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a book you loved:',
          style: AppTypography.labelMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ratedBooks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final book = ratedBooks[index];
              final isSelected = _selectedBook?.id == book.id;

              return GestureDetector(
                onTap: () => setState(() => _selectedBook = book),
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.forestGreen : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: book.book.coverUrl != null
                            ? Image.network(
                                book.book.coverUrl!,
                                width: 76,
                                height: 90,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 76,
                                height: 90,
                                color: AppColors.beige,
                                child: const Icon(Icons.book),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.book.title,
                        style: AppTypography.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenreSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _genres.map((genre) {
        final isSelected = _selectedGenre == genre;

        return FilterChip(
          label: Text(genre),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedGenre = genre),
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
      }).toList(),
    );
  }

  Widget _buildResults(RecommendationsProvider provider) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.burntOrange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your Recommendations',
                  style: AppTypography.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => provider.clearCurrentSession(),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
        // Recommendations list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: provider.currentRecommendations.length,
            itemBuilder: (context, index) {
              final rec = provider.currentRecommendations[index];
              final authProvider = context.read<AuthProvider>();
              final affiliatePref = authProvider.user?.affiliatePreference ?? AffiliatePreference.amazon;
              return RecommendationBookCard(
                book: rec.book,
                reason: rec.reason,
                affiliatePreference: affiliatePref,
                onWishlist: () => provider.updateRecommendationStatus(
                  rec.id,
                  RecommendationStatus.wishlisted,
                ),
                onNotInterested: () => provider.updateRecommendationStatus(
                  rec.id,
                  RecommendationStatus.notInterested,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _getRecommendations() {
    final libraryProvider = context.read<LibraryProvider>();
    final recsProvider = context.read<RecommendationsProvider>();

    // Validate mode-specific requirements
    if (_selectedMode == RecommendationMode.moreLike && _selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a book first')),
      );
      return;
    }

    if (_selectedMode == RecommendationMode.genrePick &&
        _selectedGenre == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a genre first')),
      );
      return;
    }

    recsProvider.getRecommendations(
      userId: 'demo-user', // TODO: Get from auth
      ratedBooks: libraryProvider.allBooks,
      mode: _selectedMode,
      referenceBook: _selectedBook,
      genre: _selectedGenre,
    );
  }
}
