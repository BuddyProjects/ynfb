import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cozy_button.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.headlineMedium),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account section
                _buildSectionHeader('Account'),
                const SizedBox(height: 16),
                _buildAccountCard(user),
                
                const SizedBox(height: 32),
                
                // Preferences section
                _buildSectionHeader('Preferences'),
                const SizedBox(height: 16),
                _buildAffiliatePreference(context, authProvider),
                
                const SizedBox(height: 32),
                
                // Subscription section
                _buildSectionHeader('Subscription'),
                const SizedBox(height: 16),
                _buildSubscriptionCard(user),
                
                const SizedBox(height: 32),
                
                // About section
                _buildSectionHeader('About'),
                const SizedBox(height: 16),
                _buildAboutSection(),
                
                const SizedBox(height: 32),
                
                // Sign out button
                CozyButton(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  style: CozyButtonStyle.outline,
                  onPressed: () => _signOut(context, authProvider),
                  isFullWidth: true,
                ),
                
                const SizedBox(height: 16),
                
                // Delete account
                Center(
                  child: TextButton(
                    onPressed: () => _showDeleteAccountDialog(context),
                    child: Text(
                      'Delete Account',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.headlineSmall,
    );
  }

  Widget _buildAccountCard(AppUser? user) {
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
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.burntOrange.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user?.email.substring(0, 1).toUpperCase() ?? '?',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.burntOrange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.email ?? 'Not signed in',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      user?.isPremium == true
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 16,
                      color: user?.isPremium == true
                          ? AppColors.burntOrange
                          : AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user?.isPremium == true ? 'Premium' : 'Free Plan',
                      style: AppTypography.labelMedium.copyWith(
                        color: user?.isPremium == true
                            ? AppColors.burntOrange
                            : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            color: AppColors.textLight,
            onPressed: () {
              // TODO: Navigate to edit profile
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliatePreference(
      BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                color: AppColors.forestGreen,
              ),
              const SizedBox(width: 12),
              Text(
                'Where to buy books',
                style: AppTypography.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your preferred bookstore for purchase links.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          // Amazon option
          _buildRadioOption(
            value: AffiliatePreference.amazon,
            groupValue: user?.affiliatePreference ?? AffiliatePreference.amazon,
            title: 'Amazon',
            subtitle: 'Shop on amazon.com',
            icon: Icons.shopping_cart_rounded,
            onChanged: (value) {
              if (value != null) {
                authProvider.updateAffiliatePreference(value);
              }
            },
          ),
          const SizedBox(height: 8),
          // Bookshop option
          _buildRadioOption(
            value: AffiliatePreference.bookshop,
            groupValue: user?.affiliatePreference ?? AffiliatePreference.amazon,
            title: 'Bookshop.org',
            subtitle: 'Support independent bookstores',
            icon: Icons.local_library_rounded,
            onChanged: (value) {
              if (value != null) {
                authProvider.updateAffiliatePreference(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption<T>({
    required T value,
    required T groupValue,
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueChanged<T?> onChanged,
  }) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.beige : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.forestGreen : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMedium, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleSmall),
                  Text(subtitle, style: AppTypography.labelSmall),
                ],
              ),
            ),
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppColors.forestGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(AppUser? user) {
    final isPremium = user?.isPremium ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [AppColors.burntOrange, AppColors.burntOrangeLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPremium ? null : AppColors.cardBackground,
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
              Icon(
                isPremium ? Icons.workspace_premium : Icons.rocket_launch_rounded,
                color: isPremium ? Colors.white : AppColors.burntOrange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPremium ? 'Premium Member' : 'Upgrade to Premium',
                  style: AppTypography.titleLarge.copyWith(
                    color: isPremium ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isPremium) ...[
            Text(
              'Unlimited recommendations • No ads',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withAlpha(230),
              ),
            ),
          ] else ...[
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
            CozyButton(
              label: 'Upgrade Now',
              onPressed: () {
                // TODO: Implement in-app purchase
              },
              isFullWidth: true,
            ),
          ],
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
            trailing: Text('1.0.0', style: AppTypography.bodyMedium),
          ),
          const Divider(color: AppColors.divider),
          _buildAboutRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              // TODO: Open privacy policy
            },
          ),
          const Divider(color: AppColors.divider),
          _buildAboutRow(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {
              // TODO: Open terms
            },
          ),
          const Divider(color: AppColors.divider),
          _buildAboutRow(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () {
              // TODO: Open help
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textLight, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppTypography.bodyLarge),
            ),
            if (trailing != null) trailing,
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight,
              ),
          ],
        ),
      ),
    );
  }

  void _signOut(BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.signOut();
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement account deletion
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
