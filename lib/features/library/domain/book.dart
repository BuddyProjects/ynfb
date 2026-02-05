import 'package:flutter/foundation.dart';

enum BookSource {
  audible,
  kindle,
  goodreads,
  manual,
}

@immutable
class Book {
  final String id;
  final String title;
  final String author;
  final String? isbn;
  final String? coverUrl;
  final List<String> genres;
  final String? goodreadsId;
  final String? amazonAsin;
  final String? description;
  final int? pageCount;
  final int? publishYear;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.isbn,
    this.coverUrl,
    this.genres = const [],
    this.goodreadsId,
    this.amazonAsin,
    this.description,
    this.pageCount,
    this.publishYear,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      isbn: json['isbn'] as String?,
      coverUrl: json['cover_url'] as String?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      goodreadsId: json['goodreads_id'] as String?,
      amazonAsin: json['amazon_asin'] as String?,
      description: json['description'] as String?,
      pageCount: json['page_count'] as int?,
      publishYear: json['publish_year'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'cover_url': coverUrl,
      'genres': genres,
      'goodreads_id': goodreadsId,
      'amazon_asin': amazonAsin,
      'description': description,
      'page_count': pageCount,
      'publish_year': publishYear,
    };
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? isbn,
    String? coverUrl,
    List<String>? genres,
    String? goodreadsId,
    String? amazonAsin,
    String? description,
    int? pageCount,
    int? publishYear,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      coverUrl: coverUrl ?? this.coverUrl,
      genres: genres ?? this.genres,
      goodreadsId: goodreadsId ?? this.goodreadsId,
      amazonAsin: amazonAsin ?? this.amazonAsin,
      description: description ?? this.description,
      pageCount: pageCount ?? this.pageCount,
      publishYear: publishYear ?? this.publishYear,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class UserBook {
  final String id;
  final String userId;
  final Book book;
  final BookSource source;
  final double? rating; // 0-10 scale
  final DateTime addedAt;
  final DateTime? ratedAt;

  const UserBook({
    required this.id,
    required this.userId,
    required this.book,
    required this.source,
    this.rating,
    required this.addedAt,
    this.ratedAt,
  });

  bool get isRated => rating != null;

  factory UserBook.fromJson(Map<String, dynamic> json, Book book) {
    return UserBook(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      book: book,
      source: BookSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => BookSource.manual,
      ),
      rating: (json['rating'] as num?)?.toDouble(),
      addedAt: DateTime.parse(json['added_at'] as String),
      ratedAt: json['rated_at'] != null
          ? DateTime.parse(json['rated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': book.id,
      'source': source.name,
      'rating': rating,
      'added_at': addedAt.toIso8601String(),
      'rated_at': ratedAt?.toIso8601String(),
    };
  }

  UserBook copyWith({
    String? id,
    String? userId,
    Book? book,
    BookSource? source,
    double? rating,
    DateTime? addedAt,
    DateTime? ratedAt,
  }) {
    return UserBook(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      book: book ?? this.book,
      source: source ?? this.source,
      rating: rating ?? this.rating,
      addedAt: addedAt ?? this.addedAt,
      ratedAt: ratedAt ?? this.ratedAt,
    );
  }
}
