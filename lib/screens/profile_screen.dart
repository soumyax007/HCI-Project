import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/reminder_store.dart';
import 'language_selection_screen.dart';
import 'prescription_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;

    String languageLabel(String code) {
      try {
        final match = kLanguages.firstWhere((l) => l.code == code);
        return match.englishLabel.isEmpty ? match.nativeLabel : match.englishLabel;
      } catch (_) {
        return code.toUpperCase();
      }
    }

    Future<void> logOut() async {
      // Clear reminders from memory so next login starts fresh
      await ReminderStore.instance.deleteAll();
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
          // ── profile card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Text('👤', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name.isNotEmpty ? s.name : 'Patient',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  if (s.age.isNotEmpty || s.mobile.isNotEmpty)
                    Text(
                      [if (s.age.isNotEmpty) 'Age ${s.age}', if (s.mobile.isNotEmpty) s.mobile]
                          .join(' · '),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  Text(
                    'Reads in: ${languageLabel(s.languageCode)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),
          // ── caregiver card ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardCream,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Family / Caregiver',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  InkWell(
                    onTap: _showEditProfileDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          (s.caregiverName.isEmpty && s.caregiverMobile.isEmpty)
                              ? Icons.add_circle_outline
                              : Icons.edit_outlined,
                          size: 16,
                          color: AppColors.sageDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (s.caregiverName.isEmpty && s.caregiverMobile.isEmpty) ? 'Add' : 'Edit',
                          style: const TextStyle(color: AppColors.sageDark, fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (s.caregiverName.isEmpty && s.caregiverMobile.isEmpty)
                const Text('No caregiver added yet. Tap Add to set up.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted))
              else
                Row(children: [
                  Container(width: 3, height: 32,
                      margin: const EdgeInsets.only(right: 10), color: AppColors.sage),
                  const Text('👧', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (s.caregiverName.isNotEmpty)
                      Text(s.caregiverName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (s.caregiverMobile.isNotEmpty)
                      Text(s.caregiverMobile,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ]),
            ]),
          ),
          // ── edit profile ───────────────────────────────────────────────
          SelectableRow(
            leadingIcon: Icons.edit_outlined,
            title: 'Edit Profile Details',
            subtitle: 'Update your mobile and caregiver info',
            onTap: _showEditProfileDialog,
          ),
          // ── prescription history ───────────────────────────────────────
          SelectableRow(
            leadingIcon: Icons.description_outlined,
            title: 'Prescription History',
            subtitle: 'View all your saved prescriptions',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrescriptionHistoryScreen()),
            ),
          ),
          SelectableRow(
            leadingIcon: Icons.language,
            title: 'Change Language',
            subtitle: 'Update your preferred language',
            onTap: _showLanguageDialog,
          ),
          SelectableRow(
            leadingIcon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 24),
          // ── log out ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: logOut,
              icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
              label: const Text('Log Out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    String selected = AppSettings.instance.languageCode;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Change Language', style: TextStyle(color: AppColors.textDark)),
          content: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: kLanguages.map((l) => DropdownMenuItem(
              value: l.code,
              child: Text(l.englishLabel.isEmpty ? l.nativeLabel : l.englishLabel),
            )).toList(),
            onChanged: (v) {
              if (v != null) {
                setDialogState(() => selected = v);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(80, 40),
              ),
              onPressed: () {
                AppSettings.instance.languageCode = selected;
                AppSettings.instance.save();
                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    String newPass = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Change Password', style: TextStyle(color: AppColors.textDark)),
        content: TextField(
          obscureText: true,
          onChanged: (v) => newPass = v,
          decoration: InputDecoration(
            hintText: 'New password (min 6 chars)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(80, 40),
            ),
            onPressed: () async {
              if (newPass.length < 6) return;
              Navigator.pop(ctx);
              try {
                await AuthService.instance.updatePassword(newPass);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update password.')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  // ── edit profile dialog ──────────────────────────────────────────────────
  Future<void> _showEditProfileDialog() async {
    final s = AppSettings.instance;
    final mobileCtrl = TextEditingController(text: s.mobile);
    final cgNameCtrl = TextEditingController(text: s.caregiverName);
    final cgMobileCtrl = TextEditingController(text: s.caregiverMobile);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Your Mobile Number', counterText: ''),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (v.length != 10) return 'Enter exactly 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cgNameCtrl,
                  decoration: const InputDecoration(labelText: 'Caregiver Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cgMobileCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Caregiver Mobile Number', counterText: ''),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (v.length != 10) return 'Enter exactly 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setStateSB(() => saving = true);
                            try {
                              await AuthService.instance.updateProfile(
                                mobile: mobileCtrl.text.trim(),
                                caregiverName: cgNameCtrl.text.trim(),
                                caregiverMobile: cgMobileCtrl.text.trim(),
                              );
                              if (context.mounted) Navigator.pop(ctx);
                              setState(() {}); // refresh profile screen
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')));
                              }
                            } finally {
                              if (context.mounted) setStateSB(() => saving = false);
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }),
    );
  }
}