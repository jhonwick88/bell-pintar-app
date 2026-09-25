import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../core/theme.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.notifications_active, color: AppTheme.primaryCyan, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'BELL PINTAR',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: state.edition == 'PRO' ? AppTheme.accentGold.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: state.edition == 'PRO' ? AppTheme.accentGold : Colors.blue),
              ),
              child: Text(
                state.edition == 'PRO' ? 'PRO' : 'BASIC',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: state.edition == 'PRO' ? AppTheme.accentGold : Colors.blue),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryCyan),
            tooltip: 'Segarkan Dashboard',
            onPressed: () => state.refreshAll(),
          ),
          _StatusPill(
            icon: Icons.wifi,
            label: state.isConnected ? 'Online' : 'Offline',
            color: state.isConnected ? AppTheme.successGreen : AppTheme.errorRed,
          ),
          if (MediaQuery.of(context).size.width < 600) ...[
            // Dotted Menu for Mobile (HP)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              tooltip: 'Menu Opsi',
              color: AppTheme.surfaceDark,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              onSelected: (value) {
                if (value == 'settings') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                } else if (value == 'logout') {
                  _showLogoutConfirmDialog(context, state);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, color: AppTheme.primaryCyan, size: 18),
                      SizedBox(width: 12),
                      Text('Pengaturan', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: AppTheme.errorRed, size: 18),
                      SizedBox(width: 12),
                      Text('Keluar Aplikasi', style: TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryCyan),
              tooltip: 'Pengaturan Sistem',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppTheme.errorRed, size: 20),
              tooltip: 'Kunci / Logout',
              onPressed: () => _showLogoutConfirmDialog(context, state),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: SingleViewDashboard(state: state, formatCountdown: _formatCountdown),
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

class SingleViewDashboard extends StatelessWidget {
  final AppState state;
  final String Function(int) formatCountdown;

  const SingleViewDashboard({super.key, required this.state, required this.formatCountdown});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final displaySchool = (state.schoolName.isNotEmpty && state.schoolName != 'Bell Pintar Sekolah')
        ? state.schoolName
        : (state.settings['school_name']?.toString() ?? '');

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      children: [
        if (displaySchool.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: AppTheme.accentGold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displaySchool,
                    style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Hero Card: Countdown & Next Schedule
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppTheme.primaryCyan.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, color: AppTheme.primaryCyan, size: 20),
                          const SizedBox(width: 8),
                          Text('HITUNG MUNDUR BEL BERIKUTNYA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.primaryCyan)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        formatCountdown(state.countdownSeconds),
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.nextSchedule?['title'] ?? 'Tidak ada jadwal berikutnya hari ini',
                        textAlign: isWide ? TextAlign.start : TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Pukul: ${state.nextSchedule?['time_trigger'] ?? '--:--'} • Nada: ${state.nextSchedule?['audio_title'] ?? '-'}",
                        textAlign: isWide ? TextAlign.start : TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  if (!isWide) const SizedBox(height: 20),
                  // Current Live Clock Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: isWide ? CrossAxisAlignment.end : CrossAxisAlignment.center,
                      children: [
                        Text('JAM SISTEM SEKARANG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppTheme.textMuted)),
                        const SizedBox(height: 4),
                        Text(state.currentTime, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(state.currentDate, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        const SizedBox(height: 8),
                        // Active Preset Dropdown
                        PopupMenuButton<int>(
                          initialValue: int.tryParse(state.activePresetId),
                          onSelected: (id) => state.switchPreset(id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primaryTeal),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune, size: 14, color: AppTheme.primaryTeal),
                                const SizedBox(width: 6),
                                Text(state.activePresetName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal)),
                                const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primaryTeal),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => state.presets.map((p) {
                            return PopupMenuItem<int>(
                              value: p['id'],
                              child: Text(p['name'] ?? ''),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Quick Soundboard Trigger Pad (Responsive 2-column Grid on Mobile)
        const Text('KONTROL BEL CEPAT (INSTANT TRIGGER)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppTheme.textMuted)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final columns = isMobile ? 2 : (constraints.maxWidth < 900 ? 3 : 4);
            final itemWidth = (constraints.maxWidth - ((columns - 1) * 12)) / columns;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickBellButton(
                  width: itemWidth,
                  title: 'Bel Masuk Kelas',
                  subtitle: 'Jam Pelajaran Ke-1',
                  icon: Icons.school,
                  color: AppTheme.primaryCyan,
                  onTap: () => state.triggerManual('Bel Masuk Jam Ke-1', audioId: 2),
                ),
                _QuickBellButton(
                  width: itemWidth,
                  title: 'Pergantian Jam',
                  subtitle: 'Ganti Pelajaran',
                  icon: Icons.swap_horiz,
                  color: AppTheme.primaryTeal,
                  onTap: () => state.triggerManual('Pergantian Jam Pelajaran', audioId: 4),
                ),
                _QuickBellButton(
                  width: itemWidth,
                  title: 'Waktu Istirahat',
                  subtitle: 'Istirahat Pertama',
                  icon: Icons.free_breakfast,
                  color: AppTheme.accentGold,
                  onTap: () => state.triggerManual('Waktu Istirahat', audioId: 5),
                ),
                _QuickBellButton(
                  width: itemWidth,
                  title: 'Waktu Pulang',
                  subtitle: 'Selesai KBM',
                  icon: Icons.home,
                  color: AppTheme.successGreen,
                  onTap: () => state.triggerManual('Bel Pulang Sekolah', audioId: 8),
                ),
                _QuickBellButton(
                  width: itemWidth,
                  title: 'Indonesia Raya',
                  subtitle: '3 Stanza Lagu Nasional',
                  icon: Icons.flag,
                  color: Colors.redAccent,
                  onTap: () => state.triggerManual('Lagu Kebangsaan Indonesia Raya', audioId: 9),
                ),
                _QuickBellButton(
                  width: itemWidth,
                  title: 'Panggilan Sholat',
                  subtitle: 'Dzuhur Berjamaah',
                  icon: Icons.mosque,
                  color: Colors.purpleAccent,
                  onTap: () => state.triggerManual('Panggilan Sholat Dzuhur', audioId: 7),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Today's Timetable Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TIMELINE JADWAL HARI INI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppTheme.textMuted)),
            TextButton.icon(
              onPressed: () => state.loadSchedules(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.schedules.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16)),
            child: Text('Tidak ada jadwal terdaftar untuk hari ini', style: TextStyle(color: AppTheme.textMuted)),
          )
        else
          ...state.schedules.map((s) => _ScheduleItemCard(item: s)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _QuickBellButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double? width;

  const _QuickBellButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Bunyikan $title?'),
            content: Text('Apakah Anda yakin ingin membunyikan "$title" ke seluruh pengeras suara sekolah sekarang?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: color),
                onPressed: () {
                  Navigator.pop(ctx);
                  onTap();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Memutar $title...')));
                },
                child: const Text('Ya, Bunyikan!'),
              ),
            ],
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width ?? 175,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              radius: 18,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleItemCard extends StatelessWidget {
  final dynamic item;

  const _ScheduleItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final time = item['time_trigger'] ?? '--:--';
    final title = item['title'] ?? '';
    final audio = item['audio_title'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryCyan, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                Text("Nada: $audio", style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Icon(Icons.check_circle_outline, size: 18, color: AppTheme.successGreen),
        ],
      ),
    );
  }
}
