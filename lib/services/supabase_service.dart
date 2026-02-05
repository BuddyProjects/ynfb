import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/domain/user.dart';
import '../features/library/domain/book.dart';
import '../features/recommendations/domain/recommendation.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // Initialize Supabase
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  // Auth methods
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInWithGoogle() async {
    return await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.ynfb.ynfb_app://login-callback/',
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  User? get currentUser => client.auth.currentUser;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // User profile methods
  Future<AppUser?> getUserProfile(String userId) async {
    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return AppUser.fromJson(response);
  }

  Future<void> updateUserProfile(AppUser user) async {
    await client.from('users').upsert(user.toJson());
  }

  // Book methods
  Future<Book?> getBookById(String bookId) async {
    final response = await client
        .from('books')
        .select()
        .eq('id', bookId)
        .maybeSingle();
    
    if (response == null) return null;
    return Book.fromJson(response);
  }

  Future<Book?> getBookByIsbn(String isbn) async {
    final response = await client
        .from('books')
        .select()
        .eq('isbn', isbn)
        .maybeSingle();
    
    if (response == null) return null;
    return Book.fromJson(response);
  }

  Future<Book> upsertBook(Book book) async {
    final response = await client
        .from('books')
        .upsert(book.toJson())
        .select()
        .single();
    return Book.fromJson(response);
  }

  // User books methods
  Future<List<UserBook>> getUserBooks(String userId) async {
    final response = await client
        .from('user_books')
        .select('*, books(*)')
        .eq('user_id', userId)
        .order('added_at', ascending: false);
    
    return (response as List).map((item) {
      final book = Book.fromJson(item['books'] as Map<String, dynamic>);
      return UserBook.fromJson(item, book);
    }).toList();
  }

  Future<void> addUserBook(UserBook userBook) async {
    await client.from('user_books').insert({
      'id': userBook.id,
      'user_id': userBook.userId,
      'book_id': userBook.book.id,
      'source': userBook.source.name,
      'rating': userBook.rating,
      'added_at': userBook.addedAt.toIso8601String(),
      'rated_at': userBook.ratedAt?.toIso8601String(),
    });
  }

  Future<void> updateBookRating(String userBookId, double rating) async {
    await client.from('user_books').update({
      'rating': rating,
      'rated_at': DateTime.now().toIso8601String(),
    }).eq('id', userBookId);
  }

  Future<void> deleteUserBook(String userBookId) async {
    await client.from('user_books').delete().eq('id', userBookId);
  }

  // Recommendations methods
  Future<List<RecommendationSession>> getRecommendationHistory(
      String userId) async {
    final response = await client
        .from('recommendations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((item) => RecommendationSession.fromJson(item))
        .toList();
  }

  Future<void> saveRecommendation(RecommendationSession session) async {
    await client.from('recommendations').insert(session.toJson());
  }

  Future<void> updateRecommendationStatus(
    String recommendationId,
    RecommendationStatus status,
  ) async {
    // This would require a more complex query to update nested JSON
    // For MVP, we'll handle this client-side
  }
}
