import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../themes/colors.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final languageService = Provider.of<LanguageService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor =
    isDark ? const Color(0xFF1E1E1E) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondaryColor =
    isDark ? Colors.white70 : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)?.settings ?? 'Settings',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Appearance + Language Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.appearance ?? 'Appearance',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                // Dark mode toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)?.darkMode ?? 'Dark Mode',
                              style: GoogleFonts.poppins(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              isDark
                                  ? (AppLocalizations.of(context)?.darkThemeEnabled ?? 'Dark theme enabled')
                                  : (AppLocalizations.of(context)?.lightThemeEnabled ?? 'Light theme enabled'),
                              style: GoogleFonts.poppins(
                                color: textSecondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: themeService.isDarkMode,
                      onChanged: (value) {
                        themeService.setDarkMode(value);
                      },
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Language row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.language,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)?.language ?? 'Language',
                              style: GoogleFonts.poppins(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              languageService.getLanguageName(
                                  languageService.locale),
                              style: GoogleFonts.poppins(
                                color: textSecondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: textColor,
                        size: 18,
                      ),
                      onPressed: () =>
                          _showLanguageDialog(context, languageService),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // About Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.about ?? 'About',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsItem(
                  icon: Icons.info_outline,
                  title: AppLocalizations.of(context)?.appVersion ?? 'App Version',
                  subtitle: '1.0.0',
                  onTap: () {},
                  isDark: isDark,
                ),
                const Divider(height: 32),
                _SettingsItem(
                  icon: Icons.description_outlined,
                  title: AppLocalizations.of(context)?.termsOfService ?? 'Terms of Service',
                  onTap: () {
                    // Navigate to terms page
                  },
                  isDark: isDark,
                ),
                const Divider(height: 32),
                _SettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: AppLocalizations.of(context)?.privacyPolicy ?? 'Privacy Policy',
                  onTap: () {
                    // Navigate to privacy policy page
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(
      BuildContext context, LanguageService languageService) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context)?.selectLanguage ?? 'Select Language',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: LanguageService.supportedLocales.map((locale) {
              final isSelected = languageService.locale == locale;
              return ListTile(
                title: Text(
                  languageService.getLanguageName(locale),
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  languageService.setLanguage(locale);
                  Navigator.pop(context);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondaryColor =
    isDark ? Colors.white70 : AppColors.textSecondary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle!,
        style: GoogleFonts.poppins(
          color: textSecondaryColor,
          fontSize: 12,
        ),
      )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
