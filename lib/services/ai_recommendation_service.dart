import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../features/library/domain/book.dart';
import '../features/recommendations/domain/recommendation.dart';

/// Placeholder AI Recommendation Service
/// TODO: Wire up to DeepInfra/Together.ai with Llama 3.1 70B
class AIRecommendationService {
  final http.Client _client;
  final _uuid = const Uuid();
  
  // Will be configured later
  String? _apiKey;
  String _baseUrl = 'https://api.deepinfra.com/v1/openai';
  String _model = 'meta-llama/Meta-Llama-3.1-70B-Instruct';

  AIRecommendationService({http.Client? client}) 
      : _client = client ?? http.Client();

  void configure({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) {
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
    if (model != null) _model = model;
  }

  /// Generate recommendations based on user's rated books
  Future<List<BookRecommendation>> getRecommendations({
    required List<UserBook> ratedBooks,
    required RecommendationMode mode,
    UserBook? referenceBook, // For "more like" mode
    String? genre, // For "genre pick" mode
  }) async {
    // For MVP, return placeholder recommendations
    // TODO: Implement actual AI call
    if (_apiKey == null) {
      return _getPlaceholderRecommendations(mode, referenceBook, genre);
    }

    final prompt = _buildPrompt(
      ratedBooks: ratedBooks,
      mode: mode,
      referenceBook: referenceBook,
      genre: genre,
    );

    try {
      final response = await _callAI(prompt);
      return _parseAIResponse(response);
    } catch (e) {
      // Fallback to placeholder on error
      return _getPlaceholderRecommendations(mode, referenceBook, genre);
    }
  }

  String _buildPrompt({
    required List<UserBook> ratedBooks,
    required RecommendationMode mode,
    UserBook? referenceBook,
    String? genre,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('''
You are a book recommendation expert. Based on the user's reading history and ratings, suggest 3-5 books they would love.

User's rated books:''');

    for (final userBook in ratedBooks.where((b) => b.isRated)) {
      buffer.writeln('- "${userBook.book.title}" by ${userBook.book.author} (Rating: ${userBook.rating}/10)');
    }

    buffer.writeln();
    buffer.writeln('Mode: ${mode.name}');

    if (mode == RecommendationMode.moreLike && referenceBook != null) {
      buffer.writeln('Reference book: "${referenceBook.book.title}" by ${referenceBook.book.author}');
    }

    if (mode == RecommendationMode.genrePick && genre != null) {
      buffer.writeln('Preferred genre: $genre');
    }

    buffer.writeln('''

For each recommendation, provide:
- Title and Author
- One sentence on why they'd like it based on their taste
- Genre tags

Do not recommend books they've already read.

Respond in JSON format:
{
  "recommendations": [
    {
      "title": "Book Title",
      "author": "Author Name",
      "reason": "Why they'd like it",
      "genres": ["genre1", "genre2"]
    }
  ]
}''');

    return buffer.toString();
  }

  Future<String> _callAI(String prompt) async {
    final uri = Uri.parse('$_baseUrl/chat/completions');
    
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
        'max_tokens': 1000,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI API error: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  List<BookRecommendation> _parseAIResponse(String response) {
    try {
      // Extract JSON from response (might have markdown code blocks)
      var jsonStr = response;
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }

      final data = json.decode(jsonStr);
      final recs = data['recommendations'] as List<dynamic>;

      return recs.map((rec) {
        final book = Book(
          id: _uuid.v4(),
          title: rec['title'] as String,
          author: rec['author'] as String,
          genres: (rec['genres'] as List<dynamic>?)
                  ?.map((g) => g as String)
                  .toList() ??
              [],
        );

        return BookRecommendation(
          id: _uuid.v4(),
          book: book,
          reason: rec['reason'] as String,
        );
      }).toList();
    } catch (e) {
      return _getPlaceholderRecommendations(
          RecommendationMode.surpriseMe, null, null);
    }
  }

  List<BookRecommendation> _getPlaceholderRecommendations(
    RecommendationMode mode,
    UserBook? referenceBook,
    String? genre,
  ) {
    // Return curated placeholder recommendations for demo
    final placeholders = [
      BookRecommendation(
        id: _uuid.v4(),
        book: Book(
          id: _uuid.v4(),
          title: 'Project Hail Mary',
          author: 'Andy Weir',
          coverUrl: 'https://covers.openlibrary.org/b/isbn/9780593135204-M.jpg',
          genres: ['Science Fiction', 'Adventure'],
        ),
        reason: 'If you loved problem-solving narratives, this gripping sci-fi adventure will keep you hooked with its clever protagonist and heartwarming friendship.',
      ),
      BookRecommendation(
        id: _uuid.v4(),
        book: Book(
          id: _uuid.v4(),
          title: 'The House in the Cerulean Sea',
          author: 'TJ Klune',
          coverUrl: 'https://covers.openlibrary.org/b/isbn/9781250217288-M.jpg',
          genres: ['Fantasy', 'Cozy', 'LGBTQ+'],
        ),
        reason: 'A warm, cozy fantasy that celebrates found family and acceptance — perfect for when you need a book that feels like a hug.',
      ),
      BookRecommendation(
        id: _uuid.v4(),
        book: Book(
          id: _uuid.v4(),
          title: 'Anxious People',
          author: 'Fredrik Backman',
          coverUrl: 'https://covers.openlibrary.org/b/isbn/9781501160837-M.jpg',
          genres: ['Fiction', 'Contemporary', 'Humor'],
        ),
        reason: 'Backman\'s signature blend of humor and heart explores human connection through an unlikely hostage situation that will make you laugh and cry.',
      ),
      BookRecommendation(
        id: _uuid.v4(),
        book: Book(
          id: _uuid.v4(),
          title: 'Piranesi',
          author: 'Susanna Clarke',
          coverUrl: 'https://covers.openlibrary.org/b/isbn/9781635575637-M.jpg',
          genres: ['Fantasy', 'Literary Fiction', 'Mystery'],
        ),
        reason: 'A hauntingly beautiful and mysterious tale that rewards readers who love atmospheric world-building and philosophical depth.',
      ),
    ];

    return placeholders.take(4).toList();
  }
}
