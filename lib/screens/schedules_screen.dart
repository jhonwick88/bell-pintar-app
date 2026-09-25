import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../core/theme.dart';
import 'settings_screen.dart';

class SchedulesScreen extends StatelessWidget {
  const SchedulesScreen({super.key});

  final List<String> _days = const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  /// Helper untuk mendeteksi apakah hari tertentu adalah hari libur / akhir pekan
  /// berdasarkan preset yang sedang dipilih (misal: 5 hari sekolah = Sabtu & Minggu libur)
  bool _isOffDay(int dayNum, Map<String, dynamic>? preset) {
    if (preset == null) return dayNum >= 6; // Default: Sabtu & Minggu libur
    final code = (preset['code'] ?? '').toString().toUpperCase();
    final name = (preset['name'] ?? '').toString().toLowerCase();

    // Preset 5 Hari Sekolah (Senin s/d Jumat)
    if (code.contains('5D') || code == 'REGULAR_5D' || name.contains('5 hari') || name.contains('senin-jumat') || name.contains('senin - jumat')) {
      return dayNum == 6 || dayNum == 7; // Sabtu & Minggu libur
    }

    // Preset 6 Hari Sekolah (Senin s/d Sabtu)
    if (code.contains('6D') || code == 'REGULAR_6D' || name.contains('6 hari') || name.contains('senin-sabtu') || name.contains('senin - sabtu')) {
      return dayNum == 7; // Hanya Minggu libur
    }

    // Preset Khusus Hari Jumat
    if (code == 'FRIDAY' || name.contains('jumat')) {
      return dayNum != 5; // Hari selain Jumat tidak aktif
    }

    // Default umum sekolah: Sabtu (6) dan Minggu (7) adalah akhir pekan
    return dayNum >= 6;
  }

  String _getOffDayReason(int dayNum, Map<String, dynamic>? preset) {
    final presetName = preset?['name'] ?? 'Senin-Jumat';
    final dayName = _days[dayNum - 1];

    final code = (preset?['code'] ?? '').toString().toUpperCase();
    final name = (preset?['name'] ?? '').toString().toLowerCase();

    if (code.contains('5D') || code == 'REGULAR_5D' || name.contains('5 hari') || name.contains('senin-jumat')) {
      return 'Preset "$presetName" dikonfigurasi untuk 5 hari sekolah (Senin – Jumat).\nHari $dayName merupakan libur akhir pekan, sehingga daftar jadwal kosong dan tidak ada bel yang dibunyikan.';
    }
    if (code.contains('6D') || code == 'REGULAR_6D' || name.contains('6 hari') || name.contains('senin-sabtu')) {
      return 'Preset "$presetName" dikonfigurasi untuk 6 hari sekolah (Senin – Sabtu).\nHari Minggu merupakan libur akhir pekan, sehingga tidak ada jadwal bel aktif.';
    }
    if (code == 'FRIDAY' || name.contains('jumat')) {
      return 'Preset "$presetName" khusus untuk hari Jumat.\nHari $dayName tidak memiliki jadwal pada preset ini.';
    }
    return 'Hari $dayName adalah akhir pekan/libur pada preset "$presetName".';
  }

  Map<String, dynamic>? _getCurrentPreset(AppState state) {
    final curId = state.selectedPresetId ?? int.tryParse(state.activePresetId) ?? 1;
    return state.presets.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['id'] == curId,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentPreset = _getCurrentPreset(state);
    final isCurrentDayOff = _isOffDay(state.selectedDay, currentPreset);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Jadwal Bel'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Jadwal',
            onPressed: () => state.refreshMenuData(1),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Salin Jadwal dari Hari Lain',
            onPressed: () => _showCopyScheduleDialog(context, state),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Jadwal Jam',
            onPressed: () => _showAddScheduleDialog(context, state),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Preset Selector Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 500;
                final currentPresetId = state.selectedPresetId ?? int.tryParse(state.activePresetId) ?? 1;
                final isPresetActive = currentPresetId.toString() == state.activePresetId;
                final currentPreset = _getCurrentPreset(state);
                final isCustomPreset = currentPreset?['is_default'] == false;

                return Flex(
                  direction: isNarrow ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tune_rounded, color: AppTheme.primaryCyan, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Preset:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMuted),
                        ),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: currentPresetId,
                            dropdownColor: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryCyan),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            onChanged: (newId) async {
                              if (newId != null) {
                                final newPreset = state.presets.cast<Map<String, dynamic>?>().firstWhere(
                                  (p) => p?['id'] == newId,
                                  orElse: () => null,
                                );
                                int targetDay = state.selectedDay;
                                if (_isOffDay(state.selectedDay, newPreset)) {
                                  targetDay = 1;
                                }
                                await state.setSelectedPreset(newId, day: targetDay);
                              }
                            },
                            items: state.presets.map<DropdownMenuItem<int>>((p) {
                              final id = p['id'] as int;
                              final name = p['name'] as String;
                              final isLive = id.toString() == state.activePresetId;
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(name),
                                    if (isLive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successGreen.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.successGreen, width: 0.8),
                                        ),
                                        child: const Text('AKTIF', style: TextStyle(fontSize: 10, color: AppTheme.successGreen, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Tombol Buat Preset Baru
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryCyan, size: 20),
                          tooltip: 'Buat Preset Jadwal Baru',
                          visualDensity: VisualDensity.compact,
                          splashRadius: 18,
                          onPressed: () => _showCreatePresetDialog(context, state),
                        ),
                        // Tombol Hapus Preset (Hanya untuk preset kustom & sedang tidak aktif di speaker)
                        if (isCustomPreset && !isPresetActive && currentPreset != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                            tooltip: 'Hapus Preset Kustom Ini',
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                            onPressed: () => _showDeletePresetDialog(context, state, currentPreset),
                          ),
                      ],
                    ),
                    if (isNarrow) const SizedBox(height: 8),
                    if (isPresetActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.successGreen),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volume_up_rounded, color: AppTheme.successGreen, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Sedang Berjalan di Speaker',
                              style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () async {
                          await state.switchPreset(currentPresetId, day: state.selectedDay);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Preset "${state.currentSelectedPresetName}" sekarang aktif di speaker dan jadwal telah diperbarui.'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.volume_up_rounded, size: 16),
                        label: const Text('Aktifkan Preset Ini ke Speaker', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Day Selector Tabs dengan indikator Hari Aktif & Libur
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _days.length,
              itemBuilder: (context, index) {
                final dayNum = index + 1;
                final isSelected = state.selectedDay == dayNum;
                final isOff = _isOffDay(dayNum, currentPreset);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_days[index]),
                        if (isOff) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Libur',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) => state.setSelectedDay(dayNum),
                    selectedColor: isOff ? const Color(0xFF475569) : AppTheme.primaryCyan,
                    backgroundColor: AppTheme.cardDark,
                    side: BorderSide(
                      color: isSelected
                          ? (isOff ? const Color(0xFF64748B) : AppTheme.primaryCyan)
                          : (isOff ? const Color(0xFF334155) : const Color(0xFF475569)),
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isOff ? AppTheme.textMuted.withValues(alpha: 0.7) : Colors.white70),
                    ),
                  ),
                );
              },
            ),
          ),

          // Schedule List & Status
          Expanded(
            child: state.isLoadingSchedules
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryCyan),
                        SizedBox(height: 16),
                        Text(
                          'Memuat daftar jadwal bel...',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : state.schedules.isEmpty
                    ? (isCurrentDayOff
                    // TAMPILAN RESMI JIKA HARI LIBUR & LIST JADWAL KOSONG
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 520),
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryCyan.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.weekend_rounded,
                                    size: 48,
                                    color: AppTheme.primaryCyan,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Hari Libur Akhir Pekan (${_days[state.selectedDay - 1]})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _getOffDayReason(state.selectedDay, currentPreset),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                                ),
                                const SizedBox(height: 24),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => state.setSelectedDay(1),
                                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                      label: const Text('Beralih ke Jadwal Senin'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryCyan,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _showAddScheduleDialog(context, state),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Tambah Jadwal Khusus'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.textMuted,
                                        side: const BorderSide(color: Color(0xFF475569)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    // TAMPILAN JIKA HARI AKTIF TETAPI BELUM ADA JADWAL
                    : Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 480),
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 14),
                                Text(
                                  'Belum Ada Jadwal untuk ${_days[state.selectedDay - 1]}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Preset: ${state.currentSelectedPresetName}',
                                  style: const TextStyle(color: AppTheme.primaryCyan, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddScheduleDialog(context, state),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Tambah Jadwal Sekarang'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryCyan,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _showCopyScheduleDialog(context, state),
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      label: const Text('Salin dari Hari Lain'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryCyan,
                                        side: const BorderSide(color: AppTheme.primaryCyan),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ))
                : Column(
                    children: [
                      // Banner Peringatan jika terdapat jadwal di hari libur preset
                      if (isCurrentDayOff)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Catatan: ${_days[state.selectedDay - 1]} adalah hari libur pada preset "${state.currentSelectedPresetName}". Jadwal di bawah ini hanya berbunyi bila bel akhir pekan diizinkan.',
                                  style: const TextStyle(color: Colors.amber, fontSize: 12),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _confirmClearDaySchedules(context, state),
                                icon: const Icon(Icons.cleaning_services_rounded, size: 15, color: AppTheme.errorRed),
                                label: const Text('Kosongkan', style: TextStyle(color: AppTheme.errorRed, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),

                      // Daftar Jadwal
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isMobile)
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                                    child: Row(
                                      children: [
                                        Icon(Icons.swipe_right_rounded, size: 14, color: AppTheme.textMuted),
                                        SizedBox(width: 6),
                                        Text(
                                          'Geser jadwal ke kanan untuk opsi Edit atau Hapus',
                                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    itemCount: state.schedules.length,
                                    itemBuilder: (context, index) {
                                      final item = state.schedules[index];
                                      return _SwipeableScheduleItem(
                                        key: ValueKey(item['id'] ?? index),
                                        item: item,
                                        isMobile: isMobile,
                                        onEdit: () => _showScheduleDialog(context, state, item),
                                        onDelete: () => _confirmDeleteSchedule(context, state, item),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showCreatePresetDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int selectedSchoolDays = 5; // 5 = Senin-Jumat, 6 = Senin-Sabtu
    final currentPresetId = state.selectedPresetId ?? int.tryParse(state.activePresetId) ?? (state.presets.isNotEmpty ? state.presets.first['id'] as int : 1);
    int? selectedTemplatePresetId = state.presets.any((p) => p['id'] == currentPresetId) ? currentPresetId : (state.presets.isNotEmpty ? state.presets.first['id'] as int : null);
    bool copySchedules = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0x2600E5FF),
                radius: 18,
                child: Icon(Icons.playlist_add_rounded, color: AppTheme.primaryCyan, size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Buat Preset Jadwal Baru',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nama Preset Jadwal *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Jadwal Pekan Ujian PTS',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.cardDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pola Hari Sekolah',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedSchoolDays = 5),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: selectedSchoolDays == 5 ? AppTheme.primaryCyan.withValues(alpha: 0.15) : AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedSchoolDays == 5 ? AppTheme.primaryCyan : const Color(0xFF334155),
                                width: selectedSchoolDays == 5 ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: selectedSchoolDays == 5 ? AppTheme.primaryCyan : AppTheme.textMuted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '5 Hari Sekolah',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedSchoolDays == 5 ? Colors.white : AppTheme.textMuted,
                                  ),
                                ),
                                const Text(
                                  'Senin – Jumat',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedSchoolDays = 6),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: selectedSchoolDays == 6 ? AppTheme.primaryCyan.withValues(alpha: 0.15) : AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedSchoolDays == 6 ? AppTheme.primaryCyan : const Color(0xFF334155),
                                width: selectedSchoolDays == 6 ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.date_range_rounded,
                                  size: 18,
                                  color: selectedSchoolDays == 6 ? AppTheme.primaryCyan : AppTheme.textMuted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '6 Hari Sekolah',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedSchoolDays == 6 ? Colors.white : AppTheme.textMuted,
                                  ),
                                ),
                                const Text(
                                  'Senin – Sabtu',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.copy_rounded, color: AppTheme.primaryCyan, size: 16),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Salin Jadwal dari Template',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                            ),
                            Switch(
                              value: copySchedules,
                              activeThumbColor: AppTheme.primaryCyan,
                              onChanged: (val) => setModalState(() => copySchedules = val),
                            ),
                          ],
                        ),
                        if (copySchedules && state.presets.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Pilih preset sumber untuk menyalin jam bel:',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: selectedTemplatePresetId,
                                isExpanded: true,
                                dropdownColor: AppTheme.surfaceDark,
                                style: const TextStyle(fontSize: 13, color: Colors.white),
                                items: state.presets.map<DropdownMenuItem<int>>((p) {
                                  return DropdownMenuItem<int>(
                                    value: p['id'] as int,
                                    child: Text(p['name'] ?? 'Preset ${p['id']}'),
                                  );
                                }).toList(),
                                onChanged: (val) => setModalState(() => selectedTemplatePresetId = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '💡 Jam bel dari preset sumber akan otomatis disalin ke preset baru agar Anda tidak perlu mengetik dari awal.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Preset baru akan dimulai dengan daftar jadwal kosong (0 bel).',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Keterangan / Catatan (Opsional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Masa ujian semester ganjil 2026',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.cardDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nama preset tidak boleh kosong!'),
                            backgroundColor: AppTheme.errorRed,
                          ),
                        );
                        return;
                      }

                      setModalState(() => isSubmitting = true);
                      try {
                        final codePrefix = selectedSchoolDays == 5 ? 'CUSTOM_5D' : 'CUSTOM_6D';
                        final code = '${codePrefix}_${DateTime.now().millisecondsSinceEpoch}';

                        await state.createPreset(
                          name: name,
                          code: code,
                          description: descCtrl.text.trim().isEmpty
                              ? (selectedSchoolDays == 5 ? '5 Hari Sekolah (Senin-Jumat)' : '6 Hari Sekolah (Senin-Sabtu)')
                              : descCtrl.text.trim(),
                          copyFromPresetId: copySchedules ? selectedTemplatePresetId : null,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Preset "$name" berhasil dibuat dan dipilih.'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        }
                      } catch (err) {
                        setModalState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal membuat preset: $err'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(isSubmitting ? 'Menyimpan...' : 'Simpan & Buat Preset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletePresetDialog(BuildContext context, AppState state, Map<String, dynamic> preset) {
    final presetName = preset['name'] ?? 'Preset';
    final presetId = preset['id'] as int;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0x26EF4444),
              radius: 18,
              child: Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hapus Preset Jadwal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus preset "$presetName"?\n\nSeluruh jadwal bel yang ada di dalam preset ini akan dihapus permanen dari sistem.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await state.deletePreset(presetId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Preset "$presetName" berhasil dihapus.'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus preset: $e'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Ya, Hapus'),
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
  }

  void _showAddScheduleDialog(BuildContext context, AppState state) {
    _showScheduleDialog(context, state, null);
  }

  void _showScheduleDialog(BuildContext context, AppState state, [Map<String, dynamic>? item]) {
    final isEdit = item != null;
    final titleCtrl = TextEditingController(text: item?['title'] ?? '');
    final timeCtrl = TextEditingController(text: item?['time_trigger'] ?? '07:00:00');
    int targetDay = item?['day_of_week'] is int ? item!['day_of_week'] as int : state.selectedDay;
    
    int? selectedAudioId;
    if (item != null && item['audio_file_id'] != null) {
      selectedAudioId = (item['audio_file_id'] as num).toInt();
    }
    final hasAudioMatch = state.audioList.any((a) => a['id'] == selectedAudioId);
    if (!hasAudioMatch && state.audioList.isNotEmpty) {
      selectedAudioId = state.audioList.first['id'];
    }

    bool isTestingAudio = false;
    String testStatusMessage = '';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentPreset = _getCurrentPreset(state);
          final isTargetDayOff = _isOffDay(targetDay, currentPreset);

          // Find current selected audio title
          String currentAudioTitle = 'Bel Standar';
          final foundAudio = state.audioList.cast<Map<String, dynamic>?>().firstWhere(
            (a) => a?['id'] == selectedAudioId,
            orElse: () => null,
          );
          if (foundAudio != null) {
            currentAudioTitle = foundAudio['title'] ?? 'Bel';
          }

          Future<void> pickTime() async {
            final parts = timeCtrl.text.split(':');
            int initialHour = 7;
            int initialMinute = 0;
            if (parts.length >= 2) {
              initialHour = int.tryParse(parts[0]) ?? 7;
              initialMinute = int.tryParse(parts[1]) ?? 0;
            }

            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppTheme.primaryCyan,
                      surface: AppTheme.cardDark,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setModalState(() {
                final h = picked.hour.toString().padLeft(2, '0');
                final m = picked.minute.toString().padLeft(2, '0');
                timeCtrl.text = '$h:$m:00';
              });
            }
          }

          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_calendar_rounded : Icons.alarm_add_rounded,
                  color: AppTheme.primaryCyan,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Jadwal Jam Bel' : 'Tambah Jadwal Jam Baru',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Preset Terpilih
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: AppTheme.primaryCyan, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Preset: ${state.currentSelectedPresetName}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pilihan Hari
                    const Text('Hari Bel Berbunyi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: targetDay,
                      dropdownColor: AppTheme.surfaceDark,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_month_rounded, color: AppTheme.primaryCyan),
                      ),
                      items: List.generate(7, (idx) {
                        final d = idx + 1;
                        final off = _isOffDay(d, currentPreset);
                        return DropdownMenuItem<int>(
                          value: d,
                          child: Text(
                            off ? '${_days[idx]} (Libur Akhir Pekan)' : _days[idx],
                            style: TextStyle(
                              color: off ? Colors.amber : Colors.white,
                              fontWeight: off ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }),
                      onChanged: isSubmitting
                          ? null
                          : (v) {
                              if (v != null) {
                                setModalState(() {
                                  targetDay = v;
                                });
                              }
                            },
                    ),
                    if (isTargetDayOff) ...[
                      const SizedBox(height: 6),
                      Text(
                        '⚠️ Catatan: ${_days[targetDay - 1]} adalah hari libur akhir pekan pada preset ${state.currentSelectedPresetName}.',
                        style: const TextStyle(fontSize: 11, color: Colors.amber, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Nama Bel
                    const Text('Nama Bel / Keterangan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Masuk Jam Ke-1, Istirahat, Pulang',
                        prefixIcon: Icon(Icons.label_outline_rounded, color: AppTheme.primaryCyan),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Waktu Trigger dengan Time Picker
                    const Text('Waktu Trigger (Jam Berbunyi)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: isSubmitting ? null : pickTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, color: AppTheme.primaryCyan, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    timeCtrl.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const Text('Klik untuk ubah jam dan menit', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: isSubmitting ? null : pickTime,
                              icon: const Icon(Icons.touch_app_rounded, size: 16),
                              label: const Text('Pilih Jam'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryCyan,
                                side: const BorderSide(color: AppTheme.primaryCyan),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Pilihan Nada Suara
                    const Text('Pilihan Nada Suara', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAudioId,
                      dropdownColor: AppTheme.surfaceDark,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.music_note_rounded, color: AppTheme.primaryCyan),
                      ),
                      items: state.audioList.map<DropdownMenuItem<int>>((a) {
                        return DropdownMenuItem<int>(
                          value: a['id'],
                          child: Text(
                            a['title'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (val) {
                              setModalState(() {
                                selectedAudioId = val;
                                testStatusMessage = '';
                              });
                            },
                    ),
                    const SizedBox(height: 12),

                    // Coba / Preview Audio Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.volume_up_rounded, color: AppTheme.primaryCyan, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nada terpilih: $currentAudioTitle',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: (selectedAudioId == null || isTestingAudio || isSubmitting)
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isTestingAudio = true;
                                          testStatusMessage = 'Memutar di speaker bel: "$currentAudioTitle"...';
                                        });
                                        await state.testAudio(selectedAudioId!);
                                        await Future.delayed(const Duration(seconds: 2));
                                        if (context.mounted) {
                                          setModalState(() {
                                            isTestingAudio = false;
                                          });
                                        }
                                      },
                                label: Text(isTestingAudio ? 'Memutar...' : 'Coba Suara'),
                                icon: Icon(
                                  isTestingAudio ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryCyan,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (testStatusMessage.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              testStatusMessage,
                              style: const TextStyle(fontSize: 11, color: AppTheme.primaryCyan, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty || timeCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Harap isi nama bel dan waktu trigger'),
                              backgroundColor: AppTheme.accentGold,
                            ),
                          );
                          return;
                        }

                        setModalState(() => isSubmitting = true);

                        try {
                          if (isEdit) {
                            await state.api.updateSchedule(item['id'], {
                              'day_of_week': targetDay,
                              'time_trigger': timeCtrl.text.trim(),
                              'title': titleCtrl.text.trim(),
                              'audio_file_id': selectedAudioId,
                            });
                          } else {
                            await state.api.createSchedule({
                              'preset_id': state.selectedPresetId ?? int.tryParse(state.activePresetId) ?? 1,
                              'day_of_week': targetDay,
                              'time_trigger': timeCtrl.text.trim(),
                              'title': titleCtrl.text.trim(),
                              'audio_file_id': selectedAudioId,
                            });
                          }

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }

                          // Reload & arahkan tampilan hari ke targetDay
                          await state.setSelectedDay(targetDay);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEdit ? 'Jadwal bel berhasil diperbarui!' : 'Jadwal bel berhasil ditambahkan!'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        } catch (err) {
                          setModalState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menyimpan jadwal: $err'),
                                backgroundColor: AppTheme.errorRed,
                              ),
                            );
                          }
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  isSubmitting
                      ? 'Menyimpan...'
                      : (isEdit ? 'Simpan Perubahan' : 'Simpan Jadwal'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog untuk menyalin seluruh jadwal dari hari asal ke hari target
  void _showCopyScheduleDialog(BuildContext context, AppState state) {
    int sourceDay = state.selectedDay == 1 ? 2 : 1; // Default hari sumber
    int targetDay = state.selectedDay;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentPreset = _getCurrentPreset(state);
          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: const Row(
              children: [
                Icon(Icons.copy_rounded, color: AppTheme.primaryCyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Salin Jadwal Antar Hari',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fitur ini menduplikasi seluruh jadwal jam bel dari hari sumber ke hari tujuan pada preset "${state.currentSelectedPresetName}".',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 18),

                  const Text('Salin Dari Hari:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: sourceDay,
                    dropdownColor: AppTheme.surfaceDark,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.outbox_rounded, color: AppTheme.primaryCyan),
                    ),
                    items: List.generate(7, (idx) {
                      final d = idx + 1;
                      return DropdownMenuItem<int>(
                        value: d,
                        child: Text(_days[idx]),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() => sourceDay = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Ke Hari Tujuan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: targetDay,
                    dropdownColor: AppTheme.surfaceDark,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.move_to_inbox_rounded, color: AppTheme.primaryCyan),
                    ),
                    items: List.generate(7, (idx) {
                      final d = idx + 1;
                      final off = _isOffDay(d, currentPreset);
                      return DropdownMenuItem<int>(
                        value: d,
                        child: Text(off ? '${_days[idx]} (Libur)' : _days[idx]),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() => targetDay = v);
                      }
                    },
                  ),
                  if (_isOffDay(targetDay, currentPreset)) ...[
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Perhatian: Hari ${_days[targetDay - 1]} adalah hari libur akhir pekan pada preset ${state.currentSelectedPresetName}.',
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton.icon(
                onPressed: isSubmitting || sourceDay == targetDay
                    ? null
                    : () async {
                        setModalState(() => isSubmitting = true);
                        final presetId = state.selectedPresetId ?? int.tryParse(state.activePresetId) ?? 1;
                        final count = await state.copySchedules(
                          presetId: presetId,
                          sourceDay: sourceDay,
                          targetDay: targetDay,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          state.setSelectedDay(targetDay);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(count > 0
                                  ? '$count jadwal dari ${_days[sourceDay - 1]} berhasil disalin ke ${_days[targetDay - 1]}!'
                                  : 'Tidak ada jadwal pada ${_days[sourceDay - 1]} untuk disalin.'),
                              backgroundColor: count > 0 ? AppTheme.successGreen : AppTheme.errorRed,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(isSubmitting ? 'Menyalin...' : 'Salin Jadwal'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Konfirmasi mengosongkan jadwal pada hari libur
  void _confirmClearDaySchedules(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
            const SizedBox(width: 8),
            Text('Kosongkan Jadwal ${_days[state.selectedDay - 1]}?'),
          ],
        ),
        content: Text(
          'Seluruh jadwal di hari ${_days[state.selectedDay - 1]} pada preset "${state.currentSelectedPresetName}" akan dihapus sehingga menjadi kosong (libur).\n\nApakah Anda yakin?',
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final presetId = state.selectedPresetId ?? int.tryParse(state.activePresetId) ?? 1;
              try {
                await state.clearDaySchedules(presetId: presetId, day: state.selectedDay);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Jadwal hari ${_days[state.selectedDay - 1]} telah dikosongkan.'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal mengosongkan jadwal: $e'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Ya, Kosongkan'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
          ),
        ],
      ),
    );
  }

  /// Konfirmasi hapus satu jadwal bel
  void _confirmDeleteSchedule(BuildContext context, AppState state, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
            SizedBox(width: 8),
            Text('Hapus Jadwal Bel?'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus jadwal "${item['title'] ?? 'Bel'}" pada jam ${item['time_trigger'] ?? ''}?\n\nJadwal yang telah dihapus tidak dapat dikembalikan.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final id = item['id'];
              if (id != null) {
                await state.api.deleteSchedule(id);
                final presetId = state.selectedPresetId ?? int.tryParse(state.activePresetId) ?? 1;
                await state.loadSchedules(presetId: presetId, day: state.selectedDay);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Jadwal "${item['title']}" berhasil dihapus.'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Ya, Hapus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget item jadwal bel dengan dukungan gestur geser ke kanan (swipe-to-reveal) pada perangkat mobile/HP
class _SwipeableScheduleItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isMobile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SwipeableScheduleItem({
    super.key,
    required this.item,
    required this.isMobile,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SwipeableScheduleItem> createState() => _SwipeableScheduleItemState();
}

class _SwipeableScheduleItemState extends State<_SwipeableScheduleItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0.0;
  static const double _maxReveal = 144.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragExtent = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _dragExtent, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.reset();
    _controller.forward();
  }

  void _close() {
    if (_dragExtent > 0) {
      _animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    // Di Layar Desktop/Tablet (lebar >= 600), tampilkan tombol Edit & Hapus langsung di kanan
    if (!widget.isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item['time_trigger'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primaryCyan,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Nada: ${item['audio_title'] ?? 'Default'}",
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryCyan, size: 20),
              tooltip: 'Edit Jadwal',
              onPressed: widget.onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
              tooltip: 'Hapus Jadwal',
              onPressed: widget.onDelete,
            ),
          ],
        ),
      );
    }

    // Di Layar Mobile / HP: Sembunyikan tombol default, geser ke kanan untuk menampilkan menu Edit & Hapus
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          // Background Action Tray (terbuka di sebelah kiri saat item digeser ke kanan)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tombol Edit
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _close();
                        widget.onEdit();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 62,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_rounded, color: AppTheme.primaryCyan, size: 20),
                            SizedBox(height: 3),
                            Text('Edit', style: TextStyle(color: AppTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Hapus
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _close();
                        widget.onDelete();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 62,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed, size: 20),
                            SizedBox(height: 3),
                            Text('Hapus', style: TextStyle(color: AppTheme.errorRed, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Foreground Card yang dapat digeser ke kanan secara halus
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragExtent = (_dragExtent + details.primaryDelta!).clamp(0.0, _maxReveal + 20.0);
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragExtent > _maxReveal / 2 || details.primaryVelocity! > 200) {
                _animateTo(_maxReveal);
              } else {
                _animateTo(0.0);
              }
            },
            onTap: () {
              if (_dragExtent > 0) {
                _close();
              }
            },
            child: Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _dragExtent > 0
                        ? AppTheme.primaryCyan.withValues(alpha: 0.5)
                        : const Color(0xFF334155),
                  ),
                  boxShadow: _dragExtent > 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(-2, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item['time_trigger'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryCyan,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Nada: ${item['audio_title'] ?? 'Default'}",
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    // Indikator panah geser di HP jika belum digeser
                    if (_dragExtent == 0)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 20),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
