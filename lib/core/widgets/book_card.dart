import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';
import '../../features/library/domain/book.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final double? rating;
  final VoidCallback? onTap;
  final ValueChanged<double>? onRatingChanged;
  final bool showRating;
  final bool isCompact;

  const BookCard({
    super.key,
    required this.book,
    this.rating,
    this.onTap,
    this.onRatingChanged,
    this.showRating = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildFullCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: _buildCoverImage(),
              ),
            ),
            // Book info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTypography.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showRating) ...[
                    const SizedBox(height: 8),
                    _buildRatingWidget(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Row(
          children: [
            // Cover thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50,
                height: 75,
                child: _buildCoverImage(),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showRating) ...[
                    const SizedBox(height: 6),
                    _buildRatingWidget(small: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (book.coverUrl == null) {
      return Container(
        color: AppColors.beige,
        child: Center(
          child: Icon(
            Icons.menu_book_rounded,
            size: 40,
            color: AppColors.textLight,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: book.coverUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: AppColors.beige,
        highlightColor: AppColors.cream,
        child: Container(color: AppColors.beige),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.beige,
        child: Center(
          child: Icon(
            Icons.menu_book_rounded,
            size: 40,
            color: AppColors.textLight,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingWidget({bool small = false}) {
    final itemSize = small ? 14.0 : 18.0;
    
    if (rating == null && onRatingChanged == null) {
      return Text(
        'Not rated',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textLight,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return RatingBar.builder(
      initialRating: (rating ?? 0) / 2, // Convert 0-10 to 0-5 stars
      minRating: 0,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: itemSize,
      itemPadding: const EdgeInsets.symmetric(horizontal: 1),
      itemBuilder: (context, _) => const Icon(
        Icons.star_rounded,
        color: AppColors.starFilled,
      ),
      unratedColor: AppColors.starEmpty,
      onRatingUpdate: (value) {
        // Convert 0-5 stars to 0-10 scale
        onRatingChanged?.call(value * 2);
      },
      ignoreGestures: onRatingChanged == null,
    );
  }
}

/// A horizontal book card for recommendation display
class RecommendationBookCard extends StatelessWidget {
  final Book book;
  final String reason;
  final VoidCallback? onTap;
  final VoidCallback? onWishlist;
  final VoidCallback? onNotInterested;

  const RecommendationBookCard({
    super.key,
    required this.book,
    required this.reason,
    this.onTap,
    this.onWishlist,
    this.onNotInterested,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 120,
                child: _buildCoverImage(),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTypography.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: AppTypography.bodySmall.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.forestGreen,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Genres
                  if (book.genres.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: book.genres.take(3).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.beige,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            genre,
                            style: AppTypography.labelSmall,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  // Actions
                  Row(
                    children: [
                      if (onWishlist != null)
                        _ActionButton(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Save',
                          onTap: onWishlist!,
                        ),
                      if (onNotInterested != null) ...[
                        const SizedBox(width: 12),
                        _ActionButton(
                          icon: Icons.close_rounded,
                          label: 'Not for me',
                          onTap: onNotInterested!,
                          isSecondary: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (book.coverUrl == null) {
      return Container(
        color: AppColors.beige,
        child: Center(
          child: Icon(
            Icons.menu_book_rounded,
            size: 32,
            color: AppColors.textLight,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: book.coverUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: AppColors.beige,
        highlightColor: AppColors.cream,
        child: Container(color: AppColors.beige),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.beige,
        child: Center(
          child: Icon(
            Icons.menu_book_rounded,
            size: 32,
            color: AppColors.textLight,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSecondary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSecondary ? AppColors.textLight : AppColors.burntOrange,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color:
                    isSecondary ? AppColors.textLight : AppColors.burntOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
