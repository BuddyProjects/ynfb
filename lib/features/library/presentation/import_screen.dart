import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cozy_button.dart';
import '../../../services/open_library_service.dart';
import '../../../services/import_service.dart';
import '../domain/book.dart';
import 'library_provider.dart';

class ImportScreen extends StatelessWidget {
  final Function(BookSource) onSourceSelected;

  const ImportScreen({super.key, required this.onSourceSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Import Books', style: AppTypography.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a source',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import your existing library from one of these platforms.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            // Audible
            CozyOptionCard(
              title: 'Audible',
              subtitle: 'Import from audible.com',
              icon: Icons.headphones_rounded,
              iconColor: AppColors.burntOrange,
              onTap: () => onSourceSelected(BookSource.audible),
            ),
            const SizedBox(height: 16),
            // Kindle
            CozyOptionCard(
              title: 'Kindle',
              subtitle: 'Import from read.amazon.com',
              icon: Icons.tablet_android_rounded,
              iconColor: AppColors.forestGreen,
              onTap: () => onSourceSelected(BookSource.kindle),
            ),
            const SizedBox(height: 16),
            // Goodreads
            CozyOptionCard(
              title: 'Goodreads',
              subtitle: 'Export CSV from goodreads.com',
              icon: Icons.auto_stories_rounded,
              iconColor: AppColors.burntOrange,
              onTap: () => onSourceSelected(BookSource.goodreads),
            ),
            const SizedBox(height: 16),
            // Manual
            CozyOptionCard(
              title: 'Add Manually',
              subtitle: 'Search and add books one by one',
              icon: Icons.search_rounded,
              iconColor: AppColors.textMedium,
              onTap: () => onSourceSelected(BookSource.manual),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guide screen for importing from Audible
class AudibleImportGuide extends StatefulWidget {
  const AudibleImportGuide({super.key});

  @override
  State<AudibleImportGuide> createState() => _AudibleImportGuideState();
}

class _AudibleImportGuideState extends State<AudibleImportGuide> {
  bool _isImporting = false;
  final _importService = const ImportService();

  Future<void> _handleUploadCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showError('Could not read file');
        return;
      }

      setState(() => _isImporting = true);

      final csvContent = utf8.decode(file.bytes!);
      final bookData = _importService.parseAudibleCsv(csvContent);

      if (bookData.isEmpty) {
        _showError('No books found in the CSV file');
        setState(() => _isImporting = false);
        return;
      }

      if (!mounted) return;

      final libraryProvider = context.read<LibraryProvider>();
      final importedCount = await libraryProvider.importBooks(
        bookData: bookData,
        userId: 'demo-user',
        source: BookSource.audible,
      );

      setState(() => _isImporting = false);

      if (!mounted) return;

      _showSuccess(importedCount, bookData.length);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FormatException catch (e) {
      setState(() => _isImporting = false);
      _showError(e.message);
    } catch (e) {
      setState(() => _isImporting = false);
      _showError('Failed to import: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(int imported, int total) {
    final skipped = total - imported;
    final message = skipped > 0
        ? 'Imported $imported books! ($skipped already in library)'
        : 'Imported $imported books!';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.forestGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Import from Audible', style: AppTypography.headlineMedium),
      ),
      body: _isImporting
          ? const _ImportingIndicator(source: 'Audible')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep(
                    number: 1,
                    title: 'Go to your Audible library',
                    description: 'Visit audible.com and sign in to your account.',
                    link: 'audible.com/library',
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    number: 2,
                    title: 'Export your library',
                    description:
                        'Look for the "Export Library" or download option. Select CSV format if available.',
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    number: 3,
                    title: 'Upload your CSV file',
                    description:
                        'Tap the button below and select the CSV file you downloaded.',
                  ),
                  const SizedBox(height: 32),
                  CozyButton(
                    label: 'Upload CSV File',
                    icon: Icons.upload_file_rounded,
                    onPressed: _handleUploadCsv,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 16),
                  _buildHint(),
                ],
              ),
            ),
    );
  }

  Widget _buildStep({
    required int number,
    required String title,
    required String description,
    String? link,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.burntOrange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: AppTypography.titleSmall.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleMedium),
              const SizedBox(height: 4),
              Text(description, style: AppTypography.bodyMedium),
              if (link != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.beige,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    link,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.burntOrange,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.forestGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Can't find export? Try searching 'download library' in Audible's help section.",
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Guide screen for importing from Kindle
class KindleImportGuide extends StatefulWidget {
  const KindleImportGuide({super.key});

  @override
  State<KindleImportGuide> createState() => _KindleImportGuideState();
}

class _KindleImportGuideState extends State<KindleImportGuide> {
  bool _isImporting = false;
  final _importService = const ImportService();

  static const String _bookmarkletCode = '''
javascript:(function(){
  var books=[];
  document.querySelectorAll('[id^="title-"]').forEach(function(el){
    books.push({
      title:el.textContent.trim(),
      author:el.closest('.book-cell')?.querySelector('[id^="author-"]')?.textContent?.trim()||'Unknown'
    });
  });
  prompt('Copy this:',JSON.stringify(books));
})();
''';

  Future<void> _handlePasteJson() async {
    final controller = TextEditingController();
    
    final jsonData = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Paste Book Data', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste the JSON data from the bookmarklet popup:',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: '[{"title":"...","author":"..."},...]',
                filled: true,
                fillColor: AppColors.cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (jsonData == null || jsonData.trim().isEmpty) return;

    try {
      setState(() => _isImporting = true);

      final bookData = _importService.parseKindleJson(jsonData);

      if (bookData.isEmpty) {
        _showError('No books found in the pasted data');
        setState(() => _isImporting = false);
        return;
      }

      if (!mounted) return;

      final libraryProvider = context.read<LibraryProvider>();
      final importedCount = await libraryProvider.importBooks(
        bookData: bookData,
        userId: 'demo-user',
        source: BookSource.kindle,
      );

      setState(() => _isImporting = false);

      if (!mounted) return;

      _showSuccess(importedCount, bookData.length);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FormatException catch (e) {
      setState(() => _isImporting = false);
      _showError(e.message);
    } catch (e) {
      setState(() => _isImporting = false);
      _showError('Failed to import: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(int imported, int total) {
    final skipped = total - imported;
    final message = skipped > 0
        ? 'Imported $imported books! ($skipped already in library)'
        : 'Imported $imported books!';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.forestGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Import from Kindle', style: AppTypography.headlineMedium),
      ),
      body: _isImporting
          ? const _ImportingIndicator(source: 'Kindle')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep(
                    number: 1,
                    title: 'Go to Kindle Cloud Reader',
                    description: 'Visit read.amazon.com and sign in.',
                    link: 'read.amazon.com/kindle-library',
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    number: 2,
                    title: 'Copy the bookmarklet',
                    description:
                        'Tap the button below to copy a special link to your clipboard.',
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: CozyButton(
                        label: 'Copy Bookmarklet',
                        icon: Icons.copy_rounded,
                        style: CozyButtonStyle.outline,
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: _bookmarkletCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bookmarklet copied!')),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    number: 3,
                    title: 'Run it in your browser',
                    description:
                        'Paste the bookmarklet into your browser address bar while on the Kindle library page and press Enter.',
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    number: 4,
                    title: 'Paste the result here',
                    description:
                        'A popup will show your book data. Copy it and paste below.',
                  ),
                  const SizedBox(height: 32),
                  CozyButton(
                    label: 'Paste Book Data',
                    icon: Icons.paste_rounded,
                    onPressed: _handlePasteJson,
                    isFullWidth: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStep({
    required int number,
    required String title,
    required String description,
    String? link,
    Widget? child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.forestGreen,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: AppTypography.titleSmall.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleMedium),
              const SizedBox(height: 4),
              Text(description, style: AppTypography.bodyMedium),
              if (link != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.beige,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    link,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              ],
              if (child != null) child,
            ],
          ),
        ),
      ],
    );
  }
}

/// Guide screen for importing from Goodreads
class GoodreadsImportGuide extends StatefulWidget {
  const GoodreadsImportGuide({super.key});

  @override
  State<GoodreadsImportGuide> createState() => _GoodreadsImportGuideState();
}

class _GoodreadsImportGuideState extends State<GoodreadsImportGuide> {
  bool _isImporting = false;
  final _importService = const ImportService();

  Future<void> _handleUploadCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showError('Could not read file');
        return;
      }

      setState(() => _isImporting = true);

      final csvContent = utf8.decode(file.bytes!);
      final bookData = _importService.parseGoodreadsCsv(csvContent);

      if (bookData.isEmpty) {
        _showError('No books found in the CSV file');
        setState(() => _isImporting = false);
        return;
      }

      if (!mounted) return;

      final libraryProvider = context.read<LibraryProvider>();
      final importedCount = await libraryProvider.importBooks(
        bookData: bookData,
        userId: 'demo-user',
        source: BookSource.goodreads,
      );

      setState(() => _isImporting = false);

      if (!mounted) return;

      _showSuccess(importedCount, bookData.length);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FormatException catch (e) {
      setState(() => _isImporting = false);
      _showError(e.message);
    } catch (e) {
      setState(() => _isImporting = false);
      _showError('Failed to import: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(int imported, int total) {
    final skipped = total - imported;
    final message = skipped > 0
        ? 'Imported $imported books! ($skipped already in library)'
        : 'Imported $imported books!';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.forestGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title:
            Text('Import from Goodreads', style: AppTypography.headlineMedium),
      ),
      body: _isImporting
          ? const _ImportingIndicator(source: 'Goodreads')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep(
                    number: 1,
                    title: 'Go to Goodreads export',
                    description: 'Sign in to goodreads.com and go to "My Books".',
                    link: 'goodreads.com/review/import',
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    number: 2,
                    title: 'Export your library',
                    description:
                        'Click "Export Library" at the bottom of the page. Goodreads will email you a link to download your CSV.',
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    number: 3,
                    title: 'Upload your CSV file',
                    description:
                        'Once you receive the email, download the CSV and upload it here.',
                  ),
                  const SizedBox(height: 32),
                  CozyButton(
                    label: 'Upload CSV File',
                    icon: Icons.upload_file_rounded,
                    onPressed: _handleUploadCsv,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 16),
                  _buildBonusHint(),
                ],
              ),
            ),
    );
  }

  Widget _buildStep({
    required int number,
    required String title,
    required String description,
    String? link,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.burntOrange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: AppTypography.titleSmall.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleMedium),
              const SizedBox(height: 4),
              Text(description, style: AppTypography.bodyMedium),
              if (link != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.beige,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    link,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.burntOrange,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBonusHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppColors.forestGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bonus: Your Goodreads ratings will be imported too!',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Importing progress indicator
class _ImportingIndicator extends StatelessWidget {
  final String source;

  const _ImportingIndicator({required this.source});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.burntOrange,
            ),
            const SizedBox(height: 24),
            Text(
              'Importing from $source...',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Looking up book covers and metadata.\nThis may take a moment.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Manual book search and add screen
class ManualAddScreen extends StatefulWidget {
  final Function(Book) onBookSelected;

  const ManualAddScreen({super.key, required this.onBookSelected});

  @override
  State<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends State<ManualAddScreen> {
  final _searchController = TextEditingController();
  final _openLibrary = OpenLibraryService();
  List<Book> _searchResults = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _openLibrary.searchBooks(query, limit: 20);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Search failed. Check your connection.';
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Add Book', style: AppTypography.headlineMedium),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by title or author...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.burntOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.burntOrange,
                    ),
                  )
                : _searchResults.isEmpty
                    ? _buildEmptyState()
                    : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _error != null ? Icons.error_outline_rounded : Icons.search_rounded,
              size: 64,
              color: _error != null ? AppColors.error : AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Search for books',
              style: AppTypography.titleMedium.copyWith(
                color: _error != null ? AppColors.error : null,
              ),
              textAlign: TextAlign.center,
            ),
            if (_error == null) ...[
              const SizedBox(height: 8),
              Text(
                'Enter a title or author to find books to add to your library.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return ListTile(
          leading: book.coverUrl != null
              ? Image.network(book.coverUrl!, width: 40, fit: BoxFit.cover)
              : Container(
                  width: 40,
                  height: 60,
                  color: AppColors.beige,
                  child: const Icon(Icons.book),
                ),
          title: Text(book.title),
          subtitle: Text(book.author),
          onTap: () => widget.onBookSelected(book),
          tileColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}
