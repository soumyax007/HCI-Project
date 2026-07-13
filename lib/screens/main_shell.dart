import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../widgets/sos_button.dart';
import '../services/app_settings.dart';
import 'home_screen.dart';
import 'add_prescription_screen.dart';
import 'reminder_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  final _scanKey = GlobalKey<AddPrescriptionScreenState>();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _tabs = [
      const HomeScreen(),
      AddPrescriptionScreen(embedded: true, key: _scanKey),
      const ReminderScreen(embedded: true),
      const ProfileScreen(),
    ];
  }

  void _onBackPressed() {
    if (_index == 1) {
      final handled = _scanKey.currentState?.handleBack() ?? false;
      if (!handled) setState(() => _index = 0);
    } else {
      setState(() => _index = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHome   = _index == 0;
    final userName = AppSettings.instance.name;
    final greeting = _greeting();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isHome) _onBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: isHome
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  onPressed: _onBackPressed,
                ),
          backgroundColor: AppColors.cream,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              if (isHome) ...[
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/SVG/newcapsule.svg',
                      width: 15,
                      height: 15,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(greeting,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w400)),
                    Text(
                      userName.isNotEmpty ? userName : 'MedHelp',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  _tabTitle(_index),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
              ],
            ],
          ),
          actions: const [SosButton()],
        ),
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          backgroundColor: AppColors.cream,
          selectedItemColor: AppColors.sageDark,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined),       label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.crop_free),           label: 'Scan'),
            BottomNavigationBarItem(icon: Icon(Icons.alarm_outlined),      label: 'Reminders'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline),      label: 'Profile'),
          ],
        ),
      ),
    );
  }

  String _tabTitle(int index) {
    switch (index) {
      case 1: return 'Scan Prescription';
      case 2: return 'Reminders';
      case 3: return 'Profile';
      default: return 'MedHelp';
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }
}