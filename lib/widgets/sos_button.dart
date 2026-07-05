import 'package:flutter/material.dart';
import 'sos_countdown_dialog.dart';

/// Red SOS button for the app bar.
/// Tapping it shows the [SosCountdownDialog] full-screen overlay.
/// Matches Style 1 (filled circle) from the reference design.
class SosButton extends StatelessWidget {
  const SosButton({super.key});

  void _onTap(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // must use Cancel button
      builder: (_) => const SosCountdownDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFDC2626), // red-600
          shape: BoxShape.circle,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone, color: Colors.white, size: 16),
            Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}