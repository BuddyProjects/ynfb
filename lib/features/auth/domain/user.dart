import 'package:flutter/foundation.dart';

enum AffiliatePreference {
  amazon,
  bookshop,
}

@immutable
class AppUser {
  final String id;
  final String email;
  final DateTime createdAt;
  final bool isPremium;
  final AffiliatePreference affiliatePreference;
  final int recommendationsThisMonth;
  final int booksRated;

  const AppUser({
    required this.id,
    required this.email,
    required this.createdAt,
    this.isPremium = false,
    this.affiliatePreference = AffiliatePreference.amazon,
    this.recommendationsThisMonth = 0,
    this.booksRated = 0,
  });

  bool get canGetRecommendation => isPremium || recommendationsThisMonth < 3;
  
  int get recommendationsRemaining => isPremium ? -1 : 3 - recommendationsThisMonth;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPremium: json['is_premium'] as bool? ?? false,
      affiliatePreference: AffiliatePreference.values.firstWhere(
        (e) => e.name == json['default_affiliate'],
        orElse: () => AffiliatePreference.amazon,
      ),
      recommendationsThisMonth: json['recommendations_this_month'] as int? ?? 0,
      booksRated: json['books_rated'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'is_premium': isPremium,
      'default_affiliate': affiliatePreference.name,
      'recommendations_this_month': recommendationsThisMonth,
      'books_rated': booksRated,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    DateTime? createdAt,
    bool? isPremium,
    AffiliatePreference? affiliatePreference,
    int? recommendationsThisMonth,
    int? booksRated,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      affiliatePreference: affiliatePreference ?? this.affiliatePreference,
      recommendationsThisMonth:
          recommendationsThisMonth ?? this.recommendationsThisMonth,
      booksRated: booksRated ?? this.booksRated,
    );
  }
}
