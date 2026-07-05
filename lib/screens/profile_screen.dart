import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import 'language_selection_screen.dart';
import 'prescription_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;

    String _languageLabel(String code) {
      final match = kLanguages.firstWhere(
        (l) => l.code == code, orElse: () => kLanguages.first);
      return match.englishLabel.isEmpty ? match.nativeLabel : match.englishLabel;
    }

    void _logOut() async {
      await AuthService.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
        (_) => false,
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          // ── profile card ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const CircleAvatar(
                radius: 26, backgroundColor: Colors.white24,
                child: Text('👤', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name.isNotEmpty ? s.name : 'Patient',
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay', color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (s.age.isNotEmpty)
                    Text('Age ${s.age} · ${s.mobile}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Reads in: ${_languageLabel(s.languageCode)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),
          // ── caregiver card ────────────────────────────────────────────
          if (s.caregiverName.isNotEmpty || s.caregiverMobile.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardCream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Linked Family Member',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 12),
                Row(children: [
                  Container(width: 3, height: 32,
                    margin: const EdgeInsets.only(right: 10), color: AppColors.sage),
                  const Text('👧', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.caregiverName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(s.caregiverMobile,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ]),
              ]),
            ),
          // ── prescription history ──────────────────────────────────────
          SelectableRow(
            leadingIcon: Icons.description_outlined,
            title: 'Prescription History',
            subtitle: 'View all your saved prescriptions',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrescriptionHistoryScreen()),
            ),
          ),
          const SizedBox(height: 8),
          // ── log out ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _logOut(),
              icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
              label: const Text('Log Out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}