import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/book.dart';
import 'library_provider.dart';

/// WebView-based Kindle library import
/// Opens read.amazon.com, lets user log in, then extracts their library
class KindleWebViewImport extends StatefulWidget {
  const KindleWebViewImport({super.key});

  @override
  State<KindleWebViewImport> createState() => _KindleWebViewImportState();
}

class _KindleWebViewImportState extends State<KindleWebViewImport> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isExtracting = false;
  bool _isOnLibraryPage = false;
  String _statusMessage = 'Loading Kindle...';
  int _extractAttempts = 0;

  // JavaScript to extract library data from Kindle Cloud Reader
  static const String _extractionScript = '''
(function() {
  var books = [];
  
  // Method 1: Kindle Cloud Reader library grid
  var items = document.querySelectorAll('.book_container, .book-item, [class*="BookItem"], [class*="book-cell"]');
  if (items.length > 0) {
    items.forEach(function(item) {
      var titleEl = item.querySelector('[id^="title-"], .book_title, [class*="title"], .title');
      var authorEl = item.querySelector('[id^="author-"], .book_author, [class*="author"], .author');
      
      if (titleEl) {
        books.push({
          title: titleEl.textContent.trim(),
          author: authorEl ? authorEl.textContent.replace(/^By:?\\s*/i, '').trim() : 'Unknown'
        });
      }
    });
  }
  
  // Method 2: Amazon digital content library
  if (books.length === 0) {
    var rows = document.querySelectorAll('[class*="DigitalItem"], .item-row, [class*="content-item"]');
    rows.forEach(function(row) {
      var titleEl = row.querySelector('[class*="title"], h2, h3, .itemTitle');
      var authorEl = row.querySelector('[class*="author"], .itemAuthor');
      
      if (titleEl && titleEl.textContent.trim().length > 0) {
        books.push({
          title: titleEl.textContent.trim(),
          author: authorEl ? authorEl.textContent.replace(/^By:?\\s*/i, '').trim() : 'Unknown'
        });
      }
    });
  }
  
  // Method 3: Generic content library selectors
  if (books.length === 0) {
    var cards = document.querySelectorAll('[class*="card"], [class*="Card"], .library-item');
    cards.forEach(function(card) {
      var title = card.querySelector('h2, h3, [class*="title"], [class*="Title"]');
      var author = card.querySelector('[class*="author"], [class*="Author"], .subtitle');
      
      if (title && title.textContent.trim().length > 0) {
        var titleText = title.textContent.trim();
        // Filter out navigation items
        if (titleText.length > 2 && titleText.length < 200) {
          books.push({
            title: titleText,
            author: author ? author.textContent.replace(/^By:?\\s*/i, '').trim() : 'Unknown'
          });
        }
      }
    });
  }
  
  // Method 4: List-based layouts
  if (books.length === 0) {
    var listItems = document.querySelectorAll('li[class*="book"], li[class*="item"], tr[class*="book"]');
    listItems.forEach(function(li) {
      var title = li.querySelector('[class*="title"], td:first-child, .name');
      var author = li.querySelector('[class*="author"], td:nth-child(2)');
      
      if (title && title.textContent.trim().length > 0) {
        books.push({
          title: title.textContent.trim(),
          author: author ? author.textContent.replace(/^By:?\\s*/i, '').trim() : 'Unknown'
        });
      }
    });
  }
  
  // Deduplicate by title
  var seen = {};
  books = books.filter(function(b) {
    if (seen[b.title]) return false;
    seen[b.title] = true;
    return true;
  });
  
  return JSON.stringify({
    success: true,
    count: books.length,
    books: books,
    url: window.location.href,
    debug: {
      method1: document.querySelectorAll('.book_container, .book-item').length,
      method2: document.querySelectorAll('[class*="DigitalItem"]').length,
      method3: document.querySelectorAll('[class*="card"]').length,
      method4: document.querySelectorAll('li[class*="book"]').length
    }
  });
})();
''';

  // Script to check if we're on the library page and logged in
  static const String _checkPageScript = '''
(function() {
  var url = window.location.href;
  var isLibrary = url.includes('/kindle-library') || url.includes('/library') || url.includes('/content');
  var isLogin = url.includes('/signin') || url.includes('/ap/signin') || url.includes('/login');
  var hasContent = document.querySelectorAll('.book_container, .book-item, [class*="BookItem"], [class*="DigitalItem"], [class*="content-item"]').length > 0;
  
  // Also check for any substantial content
  if (!hasContent) {
    hasContent = document.querySelectorAll('[class*="card"], [class*="Card"]').length > 3;
  }
  
  return JSON.stringify({
    url: url,
    isLibrary: isLibrary,
    isLogin: isLogin,
    hasContent: hasContent
  });
})();
''';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _statusMessage = 'Loading...';
            });
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            await _checkCurrentPage();
          },
          onNavigationRequest: (request) {
            // Allow all navigation within Amazon domains
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse('https://read.amazon.com/kindle-library'));
  }

  Future<void> _checkCurrentPage() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(_checkPageScript);
      final data = json.decode(result.toString().replaceAll(r'\"', '"').replaceAll("'", '"'));
      
      final bool isLibrary = data['isLibrary'] ?? false;
      final bool isLogin = data['isLogin'] ?? false;
      final bool hasContent = data['hasContent'] ?? false;
      
      setState(() {
        _isOnLibraryPage = isLibrary && hasContent;
        
        if (isLogin) {
          _statusMessage = 'Please log in to your Amazon account';
        } else if (isLibrary && !hasContent) {
          _statusMessage = 'Waiting for library to load...';
          // Try again after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isExtracting) _checkCurrentPage();
          });
        } else if (isLibrary && hasContent) {
          _statusMessage = 'Library found! Tap "Import Library" below';
        } else {
          _statusMessage = 'Navigate to your Kindle library to import';
        }
      });
    } catch (e) {
      debugPrint('Check page error: $e');
    }
  }

  Future<void> _extractLibrary() async {
    if (_isExtracting) return;
    
    setState(() {
      _isExtracting = true;
      _statusMessage = 'Extracting your library...';
    });

    try {
      // First, scroll to load all books (Kindle uses lazy loading)
      await _scrollToLoadAll();
      
      // Now extract
      final result = await _controller.runJavaScriptReturningResult(_extractionScript);
      
      // Parse the result - handle escaped JSON
      String jsonStr = result.toString();
      if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
        jsonStr = jsonStr.substring(1, jsonStr.length - 1);
        jsonStr = jsonStr.replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
      }
      
      final data = json.decode(jsonStr);
      
      if (data['success'] != true || data['count'] == 0) {
        _extractAttempts++;
        if (_extractAttempts < 3) {
          setState(() {
            _statusMessage = 'No books found, retrying... ($_extractAttempts/3)';
          });
          await Future.delayed(const Duration(seconds: 2));
          await _extractLibrary();
          return;
        }
        
        setState(() {
          _isExtracting = false;
          _statusMessage = 'Could not find books. Make sure you\'re on your library page.';
        });
        return;
      }
      
      final List<dynamic> books = data['books'];
      final bookData = books.map<Map<String, String>>((b) => {
        'title': b['title']?.toString() ?? '',
        'author': b['author']?.toString() ?? 'Unknown',
      }).where((b) => b['title']!.isNotEmpty).toList();
      
      if (bookData.isEmpty) {
        setState(() {
          _isExtracting = false;
          _statusMessage = 'No valid books found in extraction';
        });
        return;
      }

      if (!mounted) return;

      // Import the books
      final libraryProvider = context.read<LibraryProvider>();
      final importedCount = await libraryProvider.importBooks(
        bookData: bookData,
        userId: 'demo-user',
        source: BookSource.kindle,
      );

      if (!mounted) return;

      // Show success and navigate back
      final skipped = bookData.length - importedCount;
      final message = skipped > 0
          ? 'Imported $importedCount books! ($skipped already in library)'
          : 'Imported $importedCount books!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.forestGreen,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Extraction error: $e');
      setState(() {
        _isExtracting = false;
        _statusMessage = 'Error extracting library. Please try again.';
      });
    }
  }

  Future<void> _scrollToLoadAll() async {
    // Scroll down to trigger lazy loading
    for (var i = 0; i < 5; i++) {
      await _controller.runJavaScript('''
        window.scrollTo(0, document.body.scrollHeight);
      ''');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    // Scroll back to top
    await _controller.runJavaScript('window.scrollTo(0, 0);');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Import from Kindle', style: AppTypography.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
            tooltip: 'Reload page',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _isOnLibraryPage 
                ? AppColors.forestGreen.withAlpha(30)
                : AppColors.forestGreen.withAlpha(15),
            child: Row(
              children: [
                if (_isLoading || _isExtracting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.forestGreen,
                    ),
                  )
                else
                  Icon(
                    _isOnLibraryPage ? Icons.check_circle : Icons.info_outline,
                    size: 18,
                    color: _isOnLibraryPage 
                        ? AppColors.forestGreen 
                        : AppColors.textMedium,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: AppTypography.bodyMedium.copyWith(
                      color: _isOnLibraryPage 
                          ? AppColors.forestGreen 
                          : AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          
          // Import button
          if (_isOnLibraryPage && !_isExtracting)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _extractLibrary,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Import Library'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Extracting indicator
          if (_isExtracting)
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.cardBackground,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.forestGreen,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Extracting your library...',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This may take a moment',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
