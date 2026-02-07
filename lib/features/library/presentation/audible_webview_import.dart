import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/book.dart';
import 'library_provider.dart';

/// WebView-based Audible library import
/// Opens audible.com, lets user log in, then extracts their library
class AudibleWebViewImport extends StatefulWidget {
  const AudibleWebViewImport({super.key});

  @override
  State<AudibleWebViewImport> createState() => _AudibleWebViewImportState();
}

class _AudibleWebViewImportState extends State<AudibleWebViewImport> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isExtracting = false;
  bool _isOnLibraryPage = false;
  String _statusMessage = 'Loading Audible...';
  int _extractAttempts = 0;

  // JavaScript to extract library data from Audible's library page
  static const String _extractionScript = '''
(function() {
  var books = [];
  
  // Method 1: Try the product rows (current Audible layout)
  var rows = document.querySelectorAll('[id^="adbl-library-content-row-"]');
  if (rows.length > 0) {
    rows.forEach(function(row) {
      var titleEl = row.querySelector('.bc-heading a, .bc-text a, [class*="title"] a');
      var authorEl = row.querySelector('[class*="author"] a, .authorLabel a, .bc-color-secondary a');
      var narratorEl = row.querySelector('[class*="narrator"] a');
      
      if (titleEl) {
        books.push({
          title: titleEl.textContent.trim(),
          author: authorEl ? authorEl.textContent.trim() : 'Unknown',
          narrator: narratorEl ? narratorEl.textContent.trim() : null
        });
      }
    });
  }
  
  // Method 2: Try product list items
  if (books.length === 0) {
    var items = document.querySelectorAll('.adbl-library-content-row, .library-item, [class*="LibraryItem"]');
    items.forEach(function(item) {
      var titleEl = item.querySelector('h2 a, h3 a, .bc-heading a, [class*="title"]');
      var authorEl = item.querySelector('[class*="author"], .authorLabel');
      
      if (titleEl) {
        books.push({
          title: titleEl.textContent.trim(),
          author: authorEl ? authorEl.textContent.replace(/^By:?\\s*/i, '').trim() : 'Unknown',
          narrator: null
        });
      }
    });
  }
  
  // Method 3: More generic selectors
  if (books.length === 0) {
    var products = document.querySelectorAll('[class*="product"], [class*="Product"], .adbl-prod');
    products.forEach(function(prod) {
      var title = prod.querySelector('[class*="title"], h2, h3');
      var author = prod.querySelector('[class*="author"]');
      
      if (title && title.textContent.trim().length > 0) {
        books.push({
          title: title.textContent.trim(),
          author: author ? author.textContent.replace(/^By:?\\s*/i, '').trim() : 'Unknown',
          narrator: null
        });
      }
    });
  }
  
  // Method 4: German Audible / bc-list layout (handles "Von:" author prefix)
  // Only accept items that have BOTH a clear title AND "Von:" author pattern
  if (books.length === 0) {
    var listItems = document.querySelectorAll('li[class*="bc-list-item"], [class*="library"] li, [class*="Library"] li');
    listItems.forEach(function(item) {
      // Skip items in excluded sections
      if (item.closest('[class*="recommend"], [class*="discovery"], [class*="plus-catalog"], footer')) return;
      
      var titleEl = item.querySelector('a[class*="bc-link"], h2, h3, [class*="Title"], span[class*="bc-text"]');
      var authorText = item.textContent;
      var authorMatch = authorText.match(/(?:Von:|By:)\\s*([^\\n,]+)/i);
      
      // MUST have both title AND "Von:/By:" author to be considered a library item
      if (titleEl && authorMatch) {
        var title = titleEl.textContent.trim();
        var author = authorMatch[1].trim();
        
        // Skip navigation/UI text and items without real authors
        if (title.length > 3 && author.length > 2 && 
            !title.match(/^(Alle|All|Filter|Sort|Menu|Bibliothek|Library|Hörbücher|Podcasts)\$/i)) {
          books.push({
            title: title,
            author: author,
            narrator: null
          });
        }
      }
    });
  }
  
  // Method 5: Fallback - ONLY if other methods found nothing
  // This is very strict: requires "Von:" pattern and excludes many sections
  if (books.length === 0) {
    var librarySection = document.querySelector('[class*="library-content"], [class*="LibraryContent"], #library-content, main, [role="main"]');
    var searchRoot = librarySection || document;
    
    var excludeSelectors = ['[class*="recommend"]', '[class*="Recommend"]', '[class*="discovery"]', '[class*="Discovery"]', '[class*="similar"]', '[class*="upsell"]', '[class*="plus"]', '[class*="Plus"]', '[class*="catalog"]', '[class*="Catalog"]', 'footer', '[class*="footer"]', '[class*="banner"]'];
    
    var imgs = searchRoot.querySelectorAll('img[src*="images-na.ssl-images-amazon"], img[src*="m.media-amazon"]');
    imgs.forEach(function(img) {
      // Skip if inside excluded sections
      for (var j = 0; j < excludeSelectors.length; j++) {
        if (img.closest(excludeSelectors[j])) return;
      }
      
      var container = img.closest('li, div[class*="row"], div[class*="item"], article');
      if (container) {
        for (var k = 0; k < excludeSelectors.length; k++) {
          if (container.closest(excludeSelectors[k])) return;
        }
        
        var allText = container.textContent;
        // REQUIRE "Von:" or "By:" pattern - no author = skip
        var authorMatch = allText.match(/(?:Von:|By:)\\s*([^\\n,]+)/i);
        if (!authorMatch) return;
        
        var lines = allText.split('\\n').map(function(l) { return l.trim(); }).filter(function(l) { return l.length > 2; });
        var title = lines[0] || '';
        var author = authorMatch[1].trim();
        
        if (title.length > 3 && title.length < 150 && author.length > 2 &&
            !title.match(/^(Alle|All|Filter|Menu|Empfohlen|Recommended|Entdecken|Discover|Gratis|Free|Plus|\\d+)\$/i)) {
          books.push({
            title: title,
            author: author,
            narrator: null
          });
        }
      }
    });
  }
  
  // Deduplicate by title (case-insensitive)
  var seen = {};
  var uniqueBooks = books.filter(function(book) {
    var key = (book.title || '').toLowerCase().trim();
    if (key.length < 3 || seen[key]) return false;
    seen[key] = true;
    return true;
  });
  
  return JSON.stringify({
    success: true,
    count: uniqueBooks.length,
    books: uniqueBooks,
    url: window.location.href,
    debug: {
      method1: document.querySelectorAll('[id^="adbl-library-content-row-"]').length,
      method2: document.querySelectorAll('.adbl-library-content-row, .library-item').length,
      method3: document.querySelectorAll('[class*="product"]').length,
      totalBeforeDedup: books.length
    }
  });
})();
''';

  // Script to check if we're on the library page and logged in
  static const String _checkPageScript = '''
(function() {
  var url = window.location.href;
  var isLibrary = url.includes('/library') || url.includes('/lib') || url.includes('/Bibliothek');
  var isLogin = url.includes('/signin') || url.includes('/ap/signin') || url.includes('/login');
  
  // Check multiple selectors to handle different Audible regional layouts
  var contentSelectors = [
    '[id^="adbl-library-content-row-"]',
    '.adbl-library-content-row',
    '.library-item',
    '[class*="LibraryItem"]',
    '[class*="library-content"]',
    '[class*="productListItem"]',
    'li[class*="bc-list-item"]',
    '[data-widget="library"]'
  ];
  
  var hasContent = false;
  for (var i = 0; i < contentSelectors.length; i++) {
    if (document.querySelectorAll(contentSelectors[i]).length > 0) {
      hasContent = true;
      break;
    }
  }
  
  // Fallback: if URL is library and we see multiple images, assume content exists
  if (!hasContent && isLibrary) {
    var imgs = document.querySelectorAll('img[src*="images-na.ssl-images-amazon"], img[src*="m.media-amazon"]');
    hasContent = imgs.length >= 3;
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
            // Allow all navigation within Amazon/Audible domains
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse('https://www.audible.com/library/titles'));
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
          _statusMessage = 'Please log in to your Audible account';
        } else if (isLibrary && hasContent) {
          _statusMessage = 'Library found! Tap "Import Library" below';
        } else if (isLibrary && !hasContent) {
          _statusMessage = 'Library page detected but no books found. If you see books, tap "Force Import"';
          // Try again after a delay
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && !_isExtracting) _checkCurrentPage();
          });
        } else {
          _statusMessage = 'Navigate to your library. If you see books, tap "Force Import"';
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
      _statusMessage = 'Checking pages...';
    });

    try {
      // Get total pages
      final totalPages = await _getTotalPages();
      debugPrint('Total pages detected: $totalPages');
      
      List<Map<String, dynamic>> allBooks = [];
      
      // Extract from each page
      for (var page = 1; page <= totalPages; page++) {
        if (!mounted) return;
        
        setState(() {
          _statusMessage = 'Extracting page $page of $totalPages...';
        });
        
        // Scroll to load content on current page
        await _scrollToLoadAll();
        
        // Extract from current page
        final result = await _controller.runJavaScriptReturningResult(_extractionScript);
        
        // Parse the result
        String jsonStr = result.toString();
        if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
          jsonStr = jsonStr.substring(1, jsonStr.length - 1);
          jsonStr = jsonStr.replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
        }
        
        try {
          final data = json.decode(jsonStr);
          if (data['success'] == true && data['books'] != null) {
            final List<dynamic> pageBooks = data['books'];
            allBooks.addAll(pageBooks.cast<Map<String, dynamic>>());
            debugPrint('Page $page: found ${pageBooks.length} books');
          }
        } catch (e) {
          debugPrint('Error parsing page $page: $e');
        }
        
        // Go to next page if not last
        if (page < totalPages) {
          await _goToPage(page + 1);
        }
      }
      
      if (allBooks.isEmpty) {
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
      
      // Deduplicate by title
      final seen = <String>{};
      final bookData = allBooks
          .map<Map<String, String>>((b) => {
            'title': b['title']?.toString() ?? '',
            'author': b['author']?.toString() ?? 'Unknown',
          })
          .where((b) => b['title']!.isNotEmpty && seen.add(b['title']!.toLowerCase()))
          .toList();
      
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
        source: BookSource.audible,
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
    // German Audible uses pagination, not infinite scroll
    // We'll extract current page, then navigate to next pages
    if (mounted) {
      setState(() => _statusMessage = 'Preparing to extract...');
    }
    
    // Just scroll to ensure current page is loaded
    await _controller.runJavaScript('window.scrollTo(0, document.body.scrollHeight);');
    await Future.delayed(const Duration(milliseconds: 500));
    await _controller.runJavaScript('window.scrollTo(0, 0);');
    await Future.delayed(const Duration(milliseconds: 300));
  }
  
  Future<int> _getTotalPages() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          // Look for "Seite X von Y" or "Page X of Y" pattern
          var pageText = document.body.innerText;
          var match = pageText.match(/(?:Seite|Page)\\s+(\\d+)\\s+(?:von|of)\\s+(\\d+)/i);
          return match ? parseInt(match[2]) : 1;
        })();
      ''');
      return int.tryParse(result.toString()) ?? 1;
    } catch (e) {
      return 1;
    }
  }
  
  Future<void> _goToPage(int pageNum) async {
    // Navigate via URL parameter instead of clicking
    // Audible uses ?page=X or adds to existing params
    final currentUrl = await _controller.currentUrl() ?? '';
    
    String newUrl;
    if (currentUrl.contains('page=')) {
      // Replace existing page param
      newUrl = currentUrl.replaceAll(RegExp(r'page=\d+'), 'page=$pageNum');
    } else if (currentUrl.contains('?')) {
      // Add page param to existing query
      newUrl = '$currentUrl&page=$pageNum';
    } else {
      // Add page param as first query
      newUrl = '$currentUrl?page=$pageNum';
    }
    
    debugPrint('Navigating to page $pageNum: $newUrl');
    await _controller.loadRequest(Uri.parse(newUrl));
    
    // Wait for page to fully load
    await Future.delayed(const Duration(seconds: 3));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Import from Audible', style: AppTypography.headlineMedium),
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
                : AppColors.burntOrange.withAlpha(30),
            child: Row(
              children: [
                if (_isLoading || _isExtracting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.burntOrange,
                    ),
                  )
                else
                  Icon(
                    _isOnLibraryPage ? Icons.check_circle : Icons.info_outline,
                    size: 18,
                    color: _isOnLibraryPage 
                        ? AppColors.forestGreen 
                        : AppColors.burntOrange,
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
          
          // Import button - always show, different styling based on detection
          if (!_isExtracting)
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
                    label: Text(_isOnLibraryPage 
                        ? 'Import Library' 
                        : 'Force Import (if you see books)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOnLibraryPage 
                          ? AppColors.burntOrange 
                          : AppColors.forestGreen,
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
                      color: AppColors.burntOrange,
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
