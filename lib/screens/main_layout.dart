import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'dashboard_screen.dart';
import 'schedules_screen.dart';
import 'audio_library_screen.dart';
import 'announcements_screen.dart';
import 'settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SchedulesScreen(),
    AudioLibraryScreen(),
    AnnouncementsScreen(),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    // Auto-refresh data dari server setiap kali menu diklik
    context.read<AppState>().refreshMenuData(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar Navigation for Desktop / Web
            NavigationRail(
              backgroundColor: AppTheme.surfaceDark,
              selectedIndex: _currentIndex,
              onDestinationSelected: _onDestinationSelected,
              extended: MediaQuery.of(context).size.width > 1024,
              minExtendedWidth: 200,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => CircleAvatar(
                          backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.2),
                          child: const Icon(Icons.notifications_active, color: AppTheme.primaryCyan),
                        ),
                      ),
                    ),
                    if (MediaQuery.of(context).size.width > 1024) ...[
                      const SizedBox(width: 12),
                      const Text('BELL PINTAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                    ],
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryCyan), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule, color: AppTheme.primaryCyan), label: Text('Jadwal Bel')),
                NavigationRailDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music, color: AppTheme.primaryCyan), label: Text('Bank Suara')),
                NavigationRailDestination(icon: Icon(Icons.record_voice_over_outlined), selectedIcon: Icon(Icons.record_voice_over, color: AppTheme.primaryCyan), label: Text('Pengumuman TTS')),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryCyan),
                          tooltip: 'Pengaturan Sistem',
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          },
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: const Icon(Icons.logout, color: AppTheme.errorRed),
                          tooltip: 'Logout / Kunci Layar',
                          onPressed: () => _showLogoutConfirmDialog(context, context.read<AppState>()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF334155)),
            // Main View Area
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    }

    // Mobile Android Layout with Bottom Navigation (4 spacious tabs)
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surfaceDark,
        indicatorColor: AppTheme.primaryCyan.withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryCyan), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule, color: AppTheme.primaryCyan), label: 'Jadwal Bel'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music, color: AppTheme.primaryCyan), label: 'Bank Suara'),
          NavigationDestination(icon: Icon(Icons.record_voice_over_outlined), selectedIcon: Icon(Icons.record_voice_over, color: AppTheme.primaryCyan), label: 'Pengumuman'),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmDialog(BuildContext context, AppState state) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.errorRed, size: 22),
            SizedBox(width: 10),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi aplikasi Bell Pintar?',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Keluar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await state.logout();
    }
  }
}
