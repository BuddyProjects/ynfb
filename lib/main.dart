import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'services/supabase_service.dart';
import 'services/open_library_service.dart';
import 'services/ai_recommendation_service.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/library/domain/book.dart';
import 'features/library/presentation/library_provider.dart';
import 'features/library/presentation/library_screen.dart';
import 'features/library/presentation/import_screen.dart';
import 'features/recommendations/presentation/recommendations_provider.dart';
import 'features/recommendations/presentation/recommendations_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (fail gracefully if .env is missing or invalid)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Note: .env not loaded ($e) - running in demo mode');
  }
  
  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('onboarding_complete') ?? false;
  
  // Initialize Supabase if configured
  if (AppConfig.hasSupabase) {
    await SupabaseService.initialize(
      url: AppConfig.supabaseUrl!,
      anonKey: AppConfig.supabaseAnonKey!,
    );
  }

  runApp(YNFBApp(hasCompletedOnboarding: hasCompletedOnboarding));
}

class YNFBApp extends StatelessWidget {
  final bool hasCompletedOnboarding;
  
  const YNFBApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context) {
    // Create services
    final openLibraryService = OpenLibraryService();
    final aiService = AIRecommendationService();
    final supabaseService = SupabaseService();
    
    // Configure AI service if API key is available
    if (!AppConfig.isDemoMode) {
      aiService.configure(
        apiKey: AppConfig.aiApiKey!,
        baseUrl: AppConfig.aiBaseUrl,
        model: AppConfig.aiModel,
      );
    }

    return MultiProvider(
      providers: [
        // Services
        Provider<OpenLibraryService>.value(value: openLibraryService),
        Provider<AIRecommendationService>.value(value: aiService),
        Provider<SupabaseService>.value(value: supabaseService),
        
        // Auth Provider (for user context)
        ChangeNotifierProvider(
          create: (_) => AuthProvider(supabaseService),
        ),
        
        // Library Provider
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(supabaseService, openLibraryService),
        ),
        
        // Recommendations Provider
        ChangeNotifierProvider(
          create: (_) => RecommendationsProvider(supabaseService, aiService),
        ),
      ],
      child: MaterialApp(
        title: 'YNFB - Your Next Favourite Book',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: hasCompletedOnboarding 
            ? const MainShell() 
            : const OnboardingWrapper(),
      ),
    );
  }
}

/// Wrapper to handle onboarding completion
class OnboardingWrapper extends StatelessWidget {
  const OnboardingWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      onComplete: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete', true);
        
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        }
      },
    );
  }
}

/// Main app shell with bottom navigation
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Load demo data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final libraryProvider = context.read<LibraryProvider>();
      
      // Add demo books if library is empty
      if (libraryProvider.totalBooks == 0) {
        libraryProvider.addDemoBooks('demo-user');
      }
    });
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
  }

  void _openImportScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImportScreen(
          onSourceSelected: (source) {
            switch (source) {
              case BookSource.manual:
                Navigator.pop(context); // Close import screen
                _openManualAddScreen();
                break;
              case BookSource.audible:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AudibleImportGuide(),
                  ),
                );
                break;
              case BookSource.kindle:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const KindleImportGuide(),
                  ),
                );
                break;
              case BookSource.goodreads:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GoodreadsImportGuide(),
                  ),
                );
                break;
            }
          },
        ),
      ),
    );
  }
  
  void _openManualAddScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualAddScreen(
          onBookSelected: (book) {
            final libraryProvider = context.read<LibraryProvider>();
            libraryProvider.addBook(book, 'demo-user', BookSource.manual);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added "${book.title}" to your library!'),
                backgroundColor: AppColors.forestGreen,
              ),
            );
          },
        ),
      ),
    );
  }

  void _onBookTap(dynamic userBook) {
    // Show a simple bottom sheet with book details
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BookDetailSheet(userBook: userBook),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Library
          LibraryScreen(
            onImportTap: _openImportScreen,
            onBookTap: _onBookTap,
          ),
          // Recommendations
          const RecommendationsScreen(),
          // Settings
          const DemoSettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.library_books_rounded,
                  label: 'Library',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onNavTap(0),
                ),
                _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Discover',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onNavTap(1),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onNavTap(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Book detail bottom sheet
class _BookDetailSheet extends StatelessWidget {
  final dynamic userBook;

  const _BookDetailSheet({required this.userBook});

  @override
  Widget build(BuildContext context) {
    final book = userBook.book;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book.coverUrl != null
                    ? Image.network(
                        book.coverUrl,
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 120,
                        color: AppColors.beige,
                        child: const Icon(Icons.book, size: 40),
                      ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    if (userBook.rating != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.starFilled,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${userBook.rating}/10',
                            style: AppTypography.titleSmall,
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.beige,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'From: ${userBook.source.label}',
                        style: AppTypography.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (book.genres.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: book.genres.take(4).map<Widget>((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen.withAlpha(26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    genre,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.burntOrange.withAlpha(26) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.burntOrange : AppColors.textLight,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? AppColors.burntOrange : AppColors.textLight,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simplified settings screen for demo mode
class DemoSettingsScreen extends StatelessWidget {
  const DemoSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demo mode banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.forestGreen.withAlpha(51)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.science_rounded,
                    color: AppColors.forestGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo Mode',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.forestGreen,
                          ),
                        ),
                        Text(
                          'Running without Supabase. Data is local only.',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Account section
            Text('Account', style: AppTypography.headlineSmall),
            const SizedBox(height: 16),
            _buildAccountCard(),
            
            const SizedBox(height: 32),
            
            // Subscription section
            Text('Subscription', style: AppTypography.headlineSmall),
            const SizedBox(height: 16),
            _buildSubscriptionCard(context),
            
            const SizedBox(height: 32),
            
            // About section
            Text('About', style: AppTypography.headlineSmall),
            const SizedBox(height: 16),
            _buildAboutSection(),
            
            const SizedBox(height: 32),
            
            // Reset onboarding button (for testing)
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarding_complete', false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Onboarding reset! Restart app to see.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reset Onboarding'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.burntOrange.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'D',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.burntOrange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'demo@ynfb.app',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_border_rounded,
                      size: 16,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Free Plan',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                color: AppColors.burntOrange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Upgrade to Premium',
                  style: AppTypography.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPremiumFeature('Unlimited book recommendations'),
          _buildPremiumFeature('Ad-free experience'),
          _buildPremiumFeature('Priority support'),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '\$2.99',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.burntOrange,
                ),
              ),
              Text(
                '/month',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('In-app purchases coming soon!'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burntOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Upgrade Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.forestGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(text, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAboutRow(
            icon: Icons.info_outline_rounded,
            title: 'Version',
            trailing: Text('1.0.0 (Demo)', style: AppTypography.bodyMedium),
          ),
          const Divider(color: AppColors.divider),
          _buildAboutRow(
            icon: Icons.code_rounded,
            title: 'Built with Flutter',
          ),
          const Divider(color: AppColors.divider),
          _buildAboutRow(
            icon: Icons.favorite_rounded,
            title: 'Made for book lovers',
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textLight, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: AppTypography.bodyLarge),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
