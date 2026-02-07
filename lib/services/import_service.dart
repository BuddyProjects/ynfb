import 'dart:convert';
import 'package:csv/csv.dart';

/// Service for parsing imported book data from various sources
class ImportService {
  const ImportService();

  /// Parse Audible CSV export
  /// Expected columns: Title, Author, Narrator, Duration, Purchase Date
  List<Map<String, String>> parseAudibleCsv(String csvContent) {
    final results = <Map<String, String>>[];
    
    try {
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
        allowInvalid: true,
        eol: '\n',
      ).convert(csvContent);
      
      if (rows.isEmpty) return results;
      
      // Find column indices from header row
      final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final titleIdx = _findColumnIndex(headers, ['title', 'book title', 'audiobook title']);
      final authorIdx = _findColumnIndex(headers, ['author', 'authors', 'book author']);
      
      if (titleIdx == -1 || authorIdx == -1) {
        throw FormatException(
          'Could not find required columns. Expected: Title, Author. '
          'Found headers: ${headers.join(", ")}'
        );
      }
      
      // Parse data rows (skip header)
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= titleIdx || row.length <= authorIdx) continue;
        
        final title = row[titleIdx].toString().trim();
        final author = row[authorIdx].toString().trim();
        
        if (title.isEmpty || author.isEmpty) continue;
        
        results.add({
          'title': title,
          'author': author,
        });
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Failed to parse Audible CSV: $e');
    }
    
    return results;
  }

  /// Parse Goodreads CSV export
  /// Expected columns: Title, Author, ISBN, My Rating, Date Added, Bookshelves
  List<Map<String, String>> parseGoodreadsCsv(String csvContent) {
    final results = <Map<String, String>>[];
    
    try {
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
        allowInvalid: true,
        eol: '\n',
      ).convert(csvContent);
      
      if (rows.isEmpty) return results;
      
      // Find column indices from header row
      final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final titleIdx = _findColumnIndex(headers, ['title', 'book title']);
      final authorIdx = _findColumnIndex(headers, ['author', 'authors', 'primary author']);
      final ratingIdx = _findColumnIndex(headers, ['my rating', 'rating', 'your rating']);
      
      if (titleIdx == -1 || authorIdx == -1) {
        throw FormatException(
          'Could not find required columns. Expected: Title, Author. '
          'Found headers: ${headers.join(", ")}'
        );
      }
      
      // Parse data rows (skip header)
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= titleIdx || row.length <= authorIdx) continue;
        
        final title = row[titleIdx].toString().trim();
        final author = row[authorIdx].toString().trim();
        
        if (title.isEmpty || author.isEmpty) continue;
        
        final entry = {
          'title': title,
          'author': author,
        };
        
        // Include rating if available (Goodreads uses 0-5 scale)
        if (ratingIdx != -1 && row.length > ratingIdx) {
          final ratingStr = row[ratingIdx].toString().trim();
          final rating = double.tryParse(ratingStr);
          if (rating != null && rating > 0) {
            // Convert 0-5 scale to 0-10 scale
            entry['rating'] = (rating * 2).toString();
          }
        }
        
        results.add(entry);
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Failed to parse Goodreads CSV: $e');
    }
    
    return results;
  }

  /// Parse Kindle JSON from bookmarklet
  /// Expected format: [{title: "...", author: "..."}, ...]
  List<Map<String, String>> parseKindleJson(String jsonContent) {
    final results = <Map<String, String>>[];
    
    try {
      // Clean up the input - handle common issues
      var cleaned = jsonContent.trim();
      
      // Sometimes users copy with extra whitespace or quotes
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        // Unescape any escaped quotes
        cleaned = cleaned.replaceAll(r'\"', '"');
      }
      
      final dynamic parsed = json.decode(cleaned);
      
      if (parsed is! List) {
        throw const FormatException(
          'Expected a JSON array of books. '
          'Make sure you copied the full output from the bookmarklet.'
        );
      }
      
      for (final item in parsed) {
        if (item is! Map) continue;
        
        final title = (item['title'] ?? item['Title'] ?? '').toString().trim();
        final author = (item['author'] ?? item['Author'] ?? '').toString().trim();
        
        if (title.isEmpty) continue;
        
        results.add({
          'title': title,
          'author': author.isNotEmpty ? author : 'Unknown',
        });
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException(
        'Failed to parse Kindle JSON. Make sure you copied the complete output '
        'from the bookmarklet popup. Error: $e'
      );
    }
    
    return results;
  }

  /// Helper to find a column index by trying multiple possible names
  int _findColumnIndex(List<String> headers, List<String> possibleNames) {
    for (final name in possibleNames) {
      final idx = headers.indexOf(name);
      if (idx != -1) return idx;
    }
    // Try contains as fallback
    for (var i = 0; i < headers.length; i++) {
      for (final name in possibleNames) {
        if (headers[i].contains(name)) return i;
      }
    }
    return -1;
  }
}
