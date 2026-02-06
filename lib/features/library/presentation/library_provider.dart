import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../domain/book.dart';
import '../../../services/supabase_service.dart';
import '../../../services/open_library_service.dart';

enum LibraryFilter {
  all,
  rated,
  unrated,
  audible,
  kindle,
  goodreads,
  manual,
}

class LibraryProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final OpenLibraryService _openLibraryService;
  final _uuid = const Uuid();

  List<UserBook> _books = [];
  List<Book> _searchResults = [];
  LibraryFilter _currentFilter = LibraryFilter.all;
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  LibraryProvider(this._supabaseService, this._openLibraryService);

  List<UserBook> get books => _filterBooks(_books);
  List<UserBook> get allBooks => _books;
  List<Book> get searchResults => _searchResults;
  LibraryFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  int get totalBooks => _books.length;
  int get ratedBooks => _books.where((b) => b.isRated).length;
  int get unratedBooks => _books.where((b) => !b.isRated).length;

  bool get hasEnoughRatings => ratedBooks >= 10;

  List<UserBook> _filterBooks(List<UserBook> books) {
    switch (_currentFilter) {
      case LibraryFilter.all:
        return books;
      case LibraryFilter.rated:
        return books.where((b) => b.isRated).toList();
      case LibraryFilter.unrated:
        return books.where((b) => !b.isRated).toList();
      case LibraryFilter.audible:
        return books.where((b) => b.source == BookSource.audible).toList();
      case LibraryFilter.kindle:
        return books.where((b) => b.source == BookSource.kindle).toList();
      case LibraryFilter.goodreads:
        return books.where((b) => b.source == BookSource.goodreads).toList();
      case LibraryFilter.manual:
        return books.where((b) => b.source == BookSource.manual).toList();
    }
  }

  void setFilter(LibraryFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  Future<void> loadBooks(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _books = await _supabaseService.getUserBooks(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load books: $e';
      notifyListeners();
    }
  }

  Future<void> searchBooks(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      _isSearching = true;
      notifyListeners();

      _searchResults = await _openLibraryService.searchBooks(query, limit: 15);
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _isSearching = false;
      _errorMessage = 'Search failed: $e';
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  Future<void> addBook(Book book, String userId, BookSource source) async {
    try {
      // First, ensure the book exists in the global books table
      final savedBook = await _supabaseService.upsertBook(book);

      // Create user book entry
      final userBook = UserBook(
        id: _uuid.v4(),
        userId: userId,
        book: savedBook,
        source: source,
        addedAt: DateTime.now(),
      );

      await _supabaseService.addUserBook(userBook);
      _books.insert(0, userBook);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to add book: $e';
      notifyListeners();
    }
  }

  Future<void> updateRating(String userBookId, double rating) async {
    // Update locally first for instant feedback
    final index = _books.indexWhere((b) => b.id == userBookId);
    if (index != -1) {
      _books[index] = _books[index].copyWith(
        rating: rating,
        ratedAt: DateTime.now(),
      );
      notifyListeners();
    }
    
    // Then sync to Supabase (fire and forget for now)
    try {
      await _supabaseService.updateBookRating(userBookId, rating);
    } catch (e) {
      // Silently fail - local update already happened
      debugPrint('Failed to sync rating to Supabase: $e');
    }
  }

  Future<void> removeBook(String userBookId) async {
    try {
      await _supabaseService.deleteUserBook(userBookId);
      _books.removeWhere((b) => b.id == userBookId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to remove book: $e';
      notifyListeners();
    }
  }

  /// Import books from a parsed CSV or JSON
  Future<int> importBooks({
    required List<Map<String, String>> bookData,
    required String userId,
    required BookSource source,
  }) async {
    int importedCount = 0;
    
    for (final data in bookData) {
      final title = data['title'];
      final author = data['author'];
      
      if (title == null || author == null) continue;
      
      // Check if book already exists in user's library
      if (_books.any((b) => 
          b.book.title.toLowerCase() == title.toLowerCase() &&
          b.book.author.toLowerCase() == author.toLowerCase())) {
        continue;
      }

      // Search Open Library for book metadata
      try {
        final searchResults = await _openLibraryService.searchBooks(
          '$title $author',
          limit: 1,
        );

        Book book;
        if (searchResults.isNotEmpty) {
          book = searchResults.first;
        } else {
          // Create basic book entry if not found
          book = Book(
            id: _uuid.v4(),
            title: title,
            author: author,
          );
        }

        await addBook(book, userId, source);
        importedCount++;
        
        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Continue with next book on error
        continue;
      }
    }

    return importedCount;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Demo: Add some sample books for testing
  void addDemoBooks(String userId) {
    final demoBooks = [
      UserBook(
        id: _uuid.v4(),
        userId: userId,
        book: Book(
          id: _uuid.v4(),
          title: 'The Name of the Wind',
          author: 'Patrick Rothfuss',
          coverUrl: 'https://covers.openlibrary.org/b/isbn/9780756404741-M.jpg',
          genres: ['Fantasy', 'Epic Fantasy'],
        ),
        source: BookSource.manual,
        rating: 9.0,
        addedAt: DateTime.now(),
        ratedAt: DateTime.now(),
      ),
      UserBook(
        id: _uuid.v4(),
        userId: userId,
        book: Book(
          id: _uuid.v4(),
          title: 'Atomic Habits',
          author: 'James Clear',
          coverUrl: 'https://covers.openlibrary.org/b/isbn/9780735211292-M.jpg',
          genres: ['Self-Help', 'Psychology'],
        ),
        source: BookSource.audible,
        rating: 8.5,
        addedAt: DateTime.now(),
        ratedAt: DateTime.now(),
      ),
      UserBook(
        id: _uuid.v4(),
        userId: userId,
        book: Book(
          id: _uuid.v4(),
          title: 'The Midnight Library',
          author: 'Matt Haig',
          coverUrl: 'https://covers.openlibrary.org/b/isbn/9780525559474-M.jpg',
          genres: ['Fiction', 'Fantasy'],
        ),
        source: BookSource.kindle,
        addedAt: DateTime.now(),
      ),
    ];

    _books.addAll(demoBooks);
    notifyListeners();
  }
}
