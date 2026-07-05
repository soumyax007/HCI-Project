import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reminder screen — used in two ways:
///
///   embedded: true  → rendered as a tab inside MainShell's IndexedStack.
///                     No Scaffold/AppBar here; MainShell provides them.
///
///   embedded: false → pushed as a full Navigator route (e.g. from the
///                     "Add Reminder" button after translation).
///                     Renders its own Scaffold + AppBar; Flutter auto-adds
///                     the back arrow via automaticallyImplyLeading.
class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: Center(
        child: Text(
          'Reminder Screen',
          style: TextStyle(color: AppColors.textMuted, fontSize: 16),
        ),
      ),
    );

    if (embedded) {
      // No Scaffold — MainShell's Scaffold + AppBar wrap this.
      return body;
    }

    // Pushed as a route: provide our own Scaffold.
    // automaticallyImplyLeading: true (default) means Flutter adds the back
    // arrow automatically — no manual leading needed, no duplicate buttons.
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Add Reminder',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: body,
    );
  }
}
