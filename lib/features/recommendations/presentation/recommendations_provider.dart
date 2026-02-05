import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../domain/recommendation.dart';
import '../../library/domain/book.dart';
import '../../../services/supabase_service.dart';
import '../../../services/ai_recommendation_service.dart';

class RecommendationsProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final AIRecommendationService _aiService;
  final _uuid = const Uuid();

  List<RecommendationSession> _history = [];
  RecommendationSession? _currentSession;
  bool _isLoading = false;
  String? _errorMessage;

  RecommendationsProvider(this._supabaseService, this._aiService);

  List<RecommendationSession> get history => _history;
  RecommendationSession? get currentSession => _currentSession;
  List<BookRecommendation> get currentRecommendations =>
      _currentSession?.recommendations ?? [];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _history = await _supabaseService.getRecommendationHistory(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load history: $e';
      notifyListeners();
    }
  }

  Future<void> getRecommendations({
    required String userId,
    required List<UserBook> ratedBooks,
    required RecommendationMode mode,
    UserBook? referenceBook,
    String? genre,
  }) async {
    if (ratedBooks.where((b) => b.isRated).length < 3) {
      _errorMessage = 'Please rate at least 3 books to get recommendations.';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final recommendations = await _aiService.getRecommendations(
        ratedBooks: ratedBooks,
        mode: mode,
        referenceBook: referenceBook,
        genre: genre,
      );

      _currentSession = RecommendationSession(
        id: _uuid.v4(),
        userId: userId,
        mode: mode,
        inputBookId: referenceBook?.book.id,
        genreFilter: genre,
        recommendations: recommendations,
        createdAt: DateTime.now(),
      );

      // Save to history
      await _supabaseService.saveRecommendation(_currentSession!);
      _history.insert(0, _currentSession!);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to get recommendations: $e';
      notifyListeners();
    }
  }

  Future<void> updateRecommendationStatus(
    String recommendationId,
    RecommendationStatus status,
  ) async {
    if (_currentSession == null) return;

    final index = _currentSession!.recommendations
        .indexWhere((r) => r.id == recommendationId);
    
    if (index != -1) {
      final updatedRecs = List<BookRecommendation>.from(
          _currentSession!.recommendations);
      updatedRecs[index] = updatedRecs[index].copyWith(status: status);

      _currentSession = RecommendationSession(
        id: _currentSession!.id,
        userId: _currentSession!.userId,
        mode: _currentSession!.mode,
        inputBookId: _currentSession!.inputBookId,
        genreFilter: _currentSession!.genreFilter,
        recommendations: updatedRecs,
        createdAt: _currentSession!.createdAt,
      );

      notifyListeners();
    }
  }

  void selectSession(RecommendationSession session) {
    _currentSession = session;
    notifyListeners();
  }

  void clearCurrentSession() {
    _currentSession = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
