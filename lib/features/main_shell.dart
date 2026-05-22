import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import 'home/presentation/screens/home_screen.dart';
import 'occurrence/presentation/screens/occurrence_radar_screen.dart';
import 'occurrence/presentation/screens/occurrence_screen.dart';
import 'history/presentation/screens/history_screen.dart';
import 'profile/presentation/screens/profile_screen.dart';

/// Shell principal do app com bottom navigation + FAB de câmera central.
/// Segue o layout do protótipo: Início | Radar | [Camera] | Histórico | Perfil.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<Widget> get _pages => const [
    HomeScreen(),
    OccurrenceRadarScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  void _openCapture() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OccurrenceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: _CameraFab(onTap: _openCapture),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── FAB câmera ────────────────────────────────────────────────────────────────

class _CameraFab extends StatelessWidget {
  final VoidCallback onTap;
  const _CameraFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: AppColors.primary,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt_rounded, size: 30, color: AppColors.onPrimary),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 64,
      child: Row(
        children: [
          _NavItem(icon: Icons.home_rounded,    label: 'Início',    index: 0, current: currentIndex, onTap: onTap),
          _NavItem(icon: Icons.radar_rounded,   label: 'Radar',     index: 1, current: currentIndex, onTap: onTap),
          const Expanded(child: SizedBox()),   // espaço do FAB
          _NavItem(icon: Icons.history_rounded, label: 'Histórico', index: 2, current: currentIndex, onTap: onTap),
          _NavItem(icon: Icons.person_rounded,  label: 'Perfil',    index: 3, current: currentIndex, onTap: onTap),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == index;
    final color = active ? AppColors.primary : AppColors.textHint;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
