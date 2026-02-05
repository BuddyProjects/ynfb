import 'dart:convert';
import 'package:http/http.dart' as http;
import '../features/library/domain/book.dart';
import 'package:uuid/uuid.dart';

/// Service to fetch book metadata from Open Library API
/// Free, no key required
class OpenLibraryService {
  static const String _baseUrl = 'https://openlibrary.org';
  static const String _coversUrl = 'https://covers.openlibrary.org';
  
  final http.Client _client;
  final _uuid = const Uuid();

  OpenLibraryService({http.Client? client}) : _client = client ?? http.Client();

  /// Search for books by query (title, author, etc.)
  Future<List<Book>> searchBooks(String query, {int limit = 20}) async {
    final uri = Uri.parse('$_baseUrl/search.json').replace(
      queryParameters: {
        'q': query,
        'limit': limit.toString(),
        'fields': 'key,title,author_name,isbn,cover_i,subject,first_publish_year,number_of_pages_median',
      },
    );

    final response = await _client.get(uri);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to search books: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final docs = data['docs'] as List<dynamic>;

    return docs.map((doc) => _parseSearchResult(doc)).toList();
  }

  /// Get book details by ISBN
  Future<Book?> getBookByIsbn(String isbn) async {
    final uri = Uri.parse('$_baseUrl/isbn/$isbn.json');
    
    final response = await _client.get(uri);
    
    if (response.statusCode == 404) {
      return null;
    }
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch book: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    return _parseBookDetail(data, isbn);
  }

  /// Get book details by Open Library key
  Future<Book?> getBookByKey(String key) async {
    final uri = Uri.parse('$_baseUrl$key.json');
    
    final response = await _client.get(uri);
    
    if (response.statusCode == 404) {
      return null;
    }
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch book: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    return _parseBookDetail(data, null);
  }

  /// Get cover URL for a book
  String? getCoverUrl(int? coverId, {String size = 'M'}) {
    if (coverId == null) return null;
    // Size can be S, M, or L
    return '$_coversUrl/b/id/$coverId-$size.jpg';
  }

  /// Get cover URL by ISBN
  String getCoverUrlByIsbn(String isbn, {String size = 'M'}) {
    return '$_coversUrl/b/isbn/$isbn-$size.jpg';
  }

  Book _parseSearchResult(Map<String, dynamic> doc) {
    final key = doc['key'] as String?;
    final coverId = doc['cover_i'] as int?;
    final isbns = doc['isbn'] as List<dynamic>?;
    final authors = doc['author_name'] as List<dynamic>?;
    final subjects = doc['subject'] as List<dynamic>?;

    return Book(
      id: _uuid.v4(),
      title: doc['title'] as String? ?? 'Unknown Title',
      author: authors?.isNotEmpty == true 
          ? authors!.first as String 
          : 'Unknown Author',
      isbn: isbns?.isNotEmpty == true ? isbns!.first as String : null,
      coverUrl: getCoverUrl(coverId, size: 'M'),
      genres: subjects?.take(5).map((s) => s as String).toList() ?? [],
      goodreadsId: null,
      amazonAsin: null,
      description: null,
      pageCount: doc['number_of_pages_median'] as int?,
      publishYear: doc['first_publish_year'] as int?,
    );
  }

  Future<Book> _parseBookDetail(Map<String, dynamic> data, String? isbn) async {
    String? coverUrl;
    
    // Try to get cover from covers array
    final covers = data['covers'] as List<dynamic>?;
    if (covers?.isNotEmpty == true) {
      coverUrl = getCoverUrl(covers!.first as int, size: 'M');
    } else if (isbn != null) {
      coverUrl = getCoverUrlByIsbn(isbn);
    }

    // Get author name (need to fetch separately)
    String authorName = 'Unknown Author';
    final authors = data['authors'] as List<dynamic>?;
    if (authors?.isNotEmpty == true) {
      final authorRef = authors!.first;
      final authorKey = authorRef is Map ? authorRef['key'] as String : authorRef as String;
      authorName = await _getAuthorName(authorKey);
    }

    // Get description
    String? description;
    final descData = data['description'];
    if (descData is String) {
      description = descData;
    } else if (descData is Map) {
      description = descData['value'] as String?;
    }

    // Get subjects/genres
    final subjects = data['subjects'] as List<dynamic>?;

    return Book(
      id: _uuid.v4(),
      title: data['title'] as String? ?? 'Unknown Title',
      author: authorName,
      isbn: isbn,
      coverUrl: coverUrl,
      genres: subjects?.take(5).map((s) => s as String).toList() ?? [],
      goodreadsId: null,
      amazonAsin: null,
      description: description,
      pageCount: data['number_of_pages'] as int?,
      publishYear: _extractYear(data['publish_date']),
    );
  }

  Future<String> _getAuthorName(String authorKey) async {
    try {
      final uri = Uri.parse('$_baseUrl$authorKey.json');
      final response = await _client.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['name'] as String? ?? 'Unknown Author';
      }
    } catch (_) {}
    return 'Unknown Author';
  }

  int? _extractYear(dynamic publishDate) {
    if (publishDate == null) return null;
    if (publishDate is int) return publishDate;
    
    final str = publishDate.toString();
    final match = RegExp(r'\d{4}').firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }
}
