import 'package:flutter/material.dart';

/// MedHelp design tokens — sage green + warm cream palette.
class AppColors {
  // Soft Peach / Warm White / Rose / Brown Accent palette
  static const cream = Color(0xFFFDFBF7); // Warm White
  static const cardCream = Color(0xFFFDEAE2); // Soft Peach
  static const sage = Color(0xFFE59A9A); // Rose
  static const sageDark = Color(0xFF8B5A4B); // Brown Accent
  static const sageMuted = Color(0xFFF2CDCD); // Muted Rose
  static const textDark = Color(0xFF3E2723); // Dark Brown
  static const textMuted = Color(0xFF8D6E63); // Muted Brown
  static const border = Color(0xFFE0D4D0);
  static const danger = Color(0xFFB5564B);
  static const dangerBg = Color(0xFFF3E2DE);
  static const warning = Color(0xFFD9A357);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sage,
        surface: AppColors.cream,
      ),
      textTheme: const TextTheme(
        // Serif headings, matching the "MedHelp" / "Add Prescription" titles
        headlineMedium: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        titleLarge: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: AppColors.textDark,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sageDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardCream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}

/// Shared bottom nav bar used by Home / Scan / Translate / Profile screens.
/// Lives in [MainShell] so the four tabs share one persistent nav bar.
class MedHelpBottomNav extends StatelessWidget {
  const MedHelpBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.crop_free, 'Scan'),
      (Icons.translate, 'Translate'),
      (Icons.person_outline, 'Profile'),
    ];

    return BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: AppColors.cream,
      selectedItemColor: AppColors.sageDark,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      onTap: onTap,
      items: items
          .map((e) => BottomNavigationBarItem(icon: Icon(e.$1), label: e.$2))
          .toList(),
    );
  }
}

/// Small reusable section label used across forms (e.g. "Full Name", "Age").
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

/// Reusable rounded "selection row" used by language list & add-prescription
/// method list (Scan Prescription / Upload Photo / Type Manually).
class SelectableRow extends StatelessWidget {
  const SelectableRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leadingIcon,
    this.selected = false,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? leadingIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.sageDark : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(leadingIcon, color: AppColors.textDark, size: 20),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            if (leadingIcon != null)
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}