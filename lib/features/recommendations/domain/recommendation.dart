import 'package:flutter/foundation.dart';
import '../../library/domain/book.dart';

enum RecommendationMode {
  surpriseMe,
  moreLike,
  genrePick,
}

enum RecommendationStatus {
  pending,
  read,
  notInterested,
  wishlisted,
}

@immutable
class BookRecommendation {
  final String id;
  final Book book;
  final String reason; // Why it's recommended
  final RecommendationStatus status;
  final String? amazonUrl;
  final String? bookshopUrl;

  const BookRecommendation({
    required this.id,
    required this.book,
    required this.reason,
    this.status = RecommendationStatus.pending,
    this.amazonUrl,
    this.bookshopUrl,
  });

  BookRecommendation copyWith({
    String? id,
    Book? book,
    String? reason,
    RecommendationStatus? status,
    String? amazonUrl,
    String? bookshopUrl,
  }) {
    return BookRecommendation(
      id: id ?? this.id,
      book: book ?? this.book,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      amazonUrl: amazonUrl ?? this.amazonUrl,
      bookshopUrl: bookshopUrl ?? this.bookshopUrl,
    );
  }

  factory BookRecommendation.fromJson(Map<String, dynamic> json) {
    return BookRecommendation(
      id: json['id'] as String,
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      reason: json['reason'] as String,
      status: RecommendationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RecommendationStatus.pending,
      ),
      amazonUrl: json['amazon_url'] as String?,
      bookshopUrl: json['bookshop_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book': book.toJson(),
      'reason': reason,
      'status': status.name,
      'amazon_url': amazonUrl,
      'bookshop_url': bookshopUrl,
    };
  }
}

@immutable
class RecommendationSession {
  final String id;
  final String userId;
  final RecommendationMode mode;
  final String? inputBookId; // For "more like" mode
  final String? genreFilter; // For "genre pick" mode
  final List<BookRecommendation> recommendations;
  final DateTime createdAt;

  const RecommendationSession({
    required this.id,
    required this.userId,
    required this.mode,
    this.inputBookId,
    this.genreFilter,
    required this.recommendations,
    required this.createdAt,
  });

  factory RecommendationSession.fromJson(Map<String, dynamic> json) {
    return RecommendationSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mode: RecommendationMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => RecommendationMode.surpriseMe,
      ),
      inputBookId: json['input_book_id'] as String?,
      genreFilter: json['genre_filter'] as String?,
      recommendations: (json['results'] as List<dynamic>)
          .map((e) => BookRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'mode': mode.name,
      'input_book_id': inputBookId,
      'genre_filter': genreFilter,
      'results': recommendations.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
