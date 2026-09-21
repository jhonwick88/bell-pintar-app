import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'logs_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _licenseCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _schoolCtrl.text = state.settings['school_name'] ?? 'SMA Negeri 1 Pintar';
  }

  @override
  void dispose() {
    _licenseCtrl.dispose();
    _schoolCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSaveGeneral() async {
    setState(() => _isSaving = true);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final newSettings = Map<String, dynamic>.from(state.settings);
      newSettings['school_name'] = _schoolCtrl.text.trim();
      await state.api.saveSettings(newSettings.map((k, v) => MapEntry(k, v.toString())));
      await state.refreshAll();
      messenger.showSnackBar(const SnackBar(content: Text('Pengaturan berhasil disimpan!')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppTheme.errorRed));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleRenewLicense() async {
    final key = _licenseCtrl.text.trim();
    if (key.isEmpty) return;

    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await state.activateLicenseKey(key, schoolName: _schoolCtrl.text.trim());
    if (ok) {
      _licenseCtrl.clear();
      messenger.showSnackBar(const SnackBar(
        content: Text('Lisensi Berhasil Diperpanjang / Diperbarui!'),
        backgroundColor: Colors.teal,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(state.errorMessage ?? 'Gagal memperbarui lisensi. Periksa kembali kodenya.'),
        backgroundColor: AppTheme.errorRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lic = state.licenseInfo ?? {};
    final daysRemaining = lic['days_remaining'] ?? 0;
    final edition = lic['edition'] ?? state.edition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan & Suara Bel'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 1. KONTROL SUARA TTS (KECEPATAN PENGUCAPAN)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.record_voice_over_rounded, color: AppTheme.primaryCyan, size: 22),
                    SizedBox(width: 10),
                    Text('Pengaturan Suara Pengumuman (TTS)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Menggunakan suara resmi Microsoft Andika (Bahasa Indonesia). Atur tempo pengucapan agar terdengar jelas di speaker sekolah.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Kecepatan Suara: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        Text(
                          '${state.ttsSpeed.toStringAsFixed(1)}x ${state.ttsSpeed == 1.0 ? "(Normal)" : state.ttsSpeed < 1.0 ? "(Santai)" : "(Cepat)"}',
                          style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => state.broadcastTTS("Uji coba tempo suara Microsoft Andika Bahasa Indonesia."),
                      icon: const Icon(Icons.volume_up, size: 16),
                      label: const Text('Uji Suara'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryCyan,
                        side: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: state.ttsSpeed.clamp(0.6, 1.5),
                  min: 0.6,
                  max: 1.5,
                  divisions: 9,
                  activeColor: AppTheme.primaryCyan,
                  inactiveColor: Colors.white12,
                  onChanged: (val) => state.setTtsSpeed(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. IDENTITAS SEKOLAH & PENGATURAN UMUM
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_rounded, color: AppTheme.accentGold, size: 22),
                    SizedBox(width: 10),
                    Text('Identitas Sekolah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _schoolCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Sekolah / Instansi',
                    hintText: 'Contoh: SMA Negeri 1 Pintar',
                    prefixIcon: Icon(Icons.business_rounded, color: AppTheme.primaryCyan),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fungsi Identitas Sekolah: Digunakan sebagai identitas resmi kepemilikan lisensi aplikasi, nama server saat pairing HP Android guru piket via Wi-Fi/LAN, dan identitas instansi pada sistem.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.35),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSaveGeneral,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 18),
                    label: const Text('Simpan Perubahan'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. STATUS LISENSI & PERPANJANGAN (RENEWAL)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accentGold.withValues(alpha: 0.1), AppTheme.cardDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, color: AppTheme.accentGold, size: 22),
                        SizedBox(width: 10),
                        Text('Informasi & Perpanjangan Lisensi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentGold),
                      ),
                      child: Text(
                        '$edition Edition - Aktif',
                        style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Masa aktif tersisa: $daysRemaining hari. Form di bawah digunakan jika Anda ingin memperpanjang masa aktif 1 tahun berikutnya atau memperbarui edisi lisensi.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _licenseCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Kode Lisensi Baru',
                              hintText: 'Contoh: BELL-PRO-XXXX-XXXX-XXXX',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: state.isLoading ? null : _handleRenewLicense,
                            icon: const Icon(Icons.autorenew_rounded),
                            label: const Text('Perpanjang Masa Aktif'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _licenseCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Masukkan Kode Lisensi Baru (Untuk Perpanjangan)',
                              hintText: 'Contoh: BELL-PRO-XXXX-XXXX-XXXX',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: state.isLoading ? null : _handleRenewLicense,
                          icon: const Icon(Icons.autorenew_rounded),
                          label: const Text('Perpanjang'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. KONEKSI HP ANDROID GURU PIKET (feat_remote_mobile)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_android_rounded, color: AppTheme.primaryCyan, size: 22),
                        SizedBox(width: 10),
                        Text('Koneksi Remote HP Guru Piket', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: state.canRemoteMobile ? AppTheme.successGreen.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: state.canRemoteMobile ? AppTheme.successGreen : Colors.grey),
                      ),
                      child: Text(
                        state.canRemoteMobile ? 'Fitur Aktif' : 'Fitur Terkunci',
                        style: TextStyle(
                          color: state.canRemoteMobile ? AppTheme.successGreen : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hubungkan smartphone Android guru piket ke server bel via WiFi lokal (LAN) untuk memicu bel darurat atau mengirim pengumuman spontan dari mana saja di lingkungan sekolah.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showQRPairingDialog(context, state),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Tampilkan QR Code Pairing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await state.loadServerNetwork();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('IP Server: ${state.serverNetwork?['primary_ip'] ?? 'localhost'} (Port: ${state.serverNetwork?['port'] ?? '8088'})')),
                          );
                        }
                      },
                      icon: const Icon(Icons.wifi_rounded, size: 18),
                      label: const Text('Cek Jaringan LAN'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryCyan),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. MANAJEMEN PERANGKAT AKTIF (feat_max_devices)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.devices_rounded, color: AppTheme.primaryTeal, size: 22),
                        SizedBox(width: 10),
                        Text('Perangkat Terhubung & Batas Kuota', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryTeal),
                      ),
                      child: Text(
                        'Kuota: ${state.maxDevices} Perangkat',
                        style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Lisensi Anda membatasi maksimal ${state.maxDevices} perangkat yang dapat login bersamaan. Anda dapat melihat daftar perangkat aktif atau mencabut sesi perangkat yang tidak terpakai.',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showActiveDevicesDialog(context, state),
                  icon: const Icon(Icons.manage_accounts_rounded),
                  label: const Text('Kelola Perangkat Aktif'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceDark,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6. RIWAYAT & AUDIT LOG BEL (Terintegrasi di Pengaturan)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, color: AppTheme.primaryCyan, size: 22),
                        SizedBox(width: 10),
                        Text('Riwayat & Audit Log Bel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryCyan),
                      ),
                      child: Text(
                        '${state.logs.length} Log Tercatat',
                        style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pantau seluruh aktivitas pembunyian bel sekolah, baik yang terpicu otomatis sesuai jadwal maupun pemicuan manual dari HP guru piket dan komputer TU.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LogsScreen()));
                  },
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Buka Riwayat & Audit Log Bel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 8. TENTANG APLIKASI & PROMOSI DEVELOPER
          _buildAboutAndPromoCard(context),
        ],
      ),
    );
  }

  Widget _buildAboutAndPromoCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Logo & Brand
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryCyan.withValues(alpha: 0.18),
                  const Color(0xFF1E293B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryCyan, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Bell Pintar',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'v1.0 Pro',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Sistem Bel Sekolah Otomatis & Studio Pengumuman Suara Cerdas',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Title: Ringkasan Fitur
                const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: AppTheme.accentGold, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'FITUR UNGGULAN APLIKASI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fitur 1: Jadwal & Preset Bel
                _buildFeatureItem(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: AppTheme.primaryCyan,
                  title: 'Jadwal Bel Otomatis & Fleksibel',
                  desc: 'Mendukung pola 5 dan 6 hari sekolah, preset khusus Ujian & Ramadhan, otomatisasi relay amplifier audio, serta 138+ koleksi nada bel siap pakai.',
                ),
                const SizedBox(height: 12),

                // Fitur 2: Studio TTS AI & Suara
                _buildFeatureItem(
                  icon: Icons.record_voice_over_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Studio Pengumuman AI & Dikte Suara',
                  desc: 'Siaran langsung suara alami (TTS) bahasa Indonesia, fitur dikte suara otomatis tanpa perlu mengetik, serta manajemen template pengumuman instan.',
                ),
                const SizedBox(height: 12),

                // Fitur 3: Remote Mobile & Multi-Device
                _buildFeatureItem(
                  icon: Icons.phone_android_rounded,
                  iconColor: AppTheme.primaryTeal,
                  title: 'Remote HP Guru Piket & Multi-Device',
                  desc: 'Pengoperasian jarak jauh dari HP Android melalui jaringan Wi-Fi sekolah via Scan QR Pairing cepat tanpa instalasi ribet di server.',
                ),
                const SizedBox(height: 12),

                // Fitur 4: Keamanan & Audit Log
                _buildFeatureItem(
                  icon: Icons.shield_rounded,
                  iconColor: const Color(0xFFA78BFA),
                  title: 'Sistem Keamanan & Audit Log Real-time',
                  desc: 'Pencatatan riwayat setiap pembunyian bel sekolah, proteksi kuota perangkat aktif, dan sistem lisensi sekolah terintegrasi.',
                ),

                const SizedBox(height: 22),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 18),

                // KARTU PROMOSI & CUSTOM SOFTWARE DEV
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F2634),
                        Color(0xFF0B1E2B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.handshake_rounded, color: AppTheme.accentGold, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Ingin Custom Fitur atau Buat Aplikasi Lain?',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Aplikasi Bell Pintar dikembangkan oleh tim profesional Pintar Labs. Kami melayani permintaan custom fitur untuk sekolah Anda (integrasi IoT relay, RFID absensi, smart display TV, dsb) maupun rancang bangun aplikasi Web, Mobile Android/iOS, & Desktop untuk berbagai kebutuhan instansi atau bisnis.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tombol WhatsApp & Email
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          // Tombol WhatsApp
                          ElevatedButton.icon(
                            onPressed: () => _launchWhatsApp(context),
                            icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              'Hubungi Developer (0821-3293-5169)',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366), // Warna WhatsApp Resmi
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                          ),

                          // Tombol Email
                          OutlinedButton.icon(
                            onPressed: () => _launchEmail(context),
                            icon: const Icon(Icons.email_rounded, size: 16, color: AppTheme.primaryCyan),
                            label: const Text(
                              'Email: labspintar@gmail.com',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primaryCyan, width: 1.2),
                              foregroundColor: AppTheme.primaryCyan,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} Bell Pintar by Pintar Labs • Solusi Digital Sekolah Pintar',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const phone = '6282132935169';
    final message = Uri.encodeComponent(
      'Halo Developer Bell Pintar (Pintar Labs), saya tertarik untuk konsultasi custom fitur / pembuatan aplikasi.',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw 'Gagal membuka browser / aplikasi WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        Clipboard.setData(const ClipboardData(text: '082132935169'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nomor WhatsApp Developer (082132935169) telah disalin ke papan klip!'),
            backgroundColor: AppTheme.primaryCyan,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    final url = Uri.parse(
      'mailto:labspintar@gmail.com?subject=${Uri.encodeComponent("Konsultasi Custom Fitur / Pembuatan Aplikasi")}&body=${Uri.encodeComponent("Halo Tim Pintar Labs,\n\nSaya tertarik untuk konsultasi custom fitur / pembuatan aplikasi:\n\nNama / Instansi:\nKebutuhan:\n\nTerima kasih.")}',
    );
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw 'Gagal membuka aplikasi Email';
      }
    } catch (e) {
      if (context.mounted) {
        Clipboard.setData(const ClipboardData(text: 'labspintar@gmail.com'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alamat Email (labspintar@gmail.com) telah disalin ke papan klip!'),
            backgroundColor: AppTheme.primaryCyan,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showQRPairingDialog(BuildContext context, AppState state) async {
    await state.loadServerNetwork();
    if (!context.mounted) return;

    final network = state.serverNetwork ?? {};
    final serverUrl = network['server_url'] ?? ApiService.baseUrl;
    final primaryIp = network['primary_ip'] ?? 'localhost';
    final port = network['port'] ?? '8088';
    final deepLinkUrl = 'bellpintar://pair?url=${Uri.encodeComponent(serverUrl)}';

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
            Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 10),
            Text('Scan QR Pairing HP Guru Piket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: deepLinkUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: AppTheme.primaryCyan),
                      SizedBox(width: 4),
                      Text(
                        'Buka Langsung via Kamera HP',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      const Text('URL Server LAN:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      SelectableText(
                        serverUrl,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCyan, fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Arahkan kamera HP / Google Lens ke QR Code di atas. Android akan memunculkan opsi "Buka dengan Bell Pintar" dan otomatis menyambungkan ke $primaryIp:$port.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showActiveDevicesDialog(BuildContext context, AppState state) async {
    await state.loadActiveSessions();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final sessions = state.activeSessions;
          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: Row(
              children: [
                const Icon(Icons.devices_rounded, color: AppTheme.primaryTeal),
                const SizedBox(width: 10),
                Text('Daftar Perangkat Aktif (${sessions.length}/${state.maxDevices})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 320,
              child: sessions.isEmpty
                  ? const Center(
                      child: Text('Belum ada perangkat terdata', style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final s = sessions[index];
                        final id = s['id'] as int;
                        final name = s['device_name'] ?? 'Perangkat';
                        final plat = (s['platform'] ?? 'windows').toString().toLowerCase();
                        final ip = s['ip_address'] ?? '-';
                        final lastAct = s['last_active'] ?? '';

                        final isMobile = plat == 'android' || plat == 'ios';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isMobile ? Icons.phone_android_rounded : Icons.computer_rounded,
                                color: isMobile ? AppTheme.accentGold : AppTheme.primaryCyan,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text('IP: $ip • Platform: ${plat.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    Text('Terakhir Aktif: $lastAct', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.link_off_rounded, color: AppTheme.errorRed, size: 22),
                                tooltip: 'Putus / Cabut Sesi',
                                onPressed: () async {
                                  await state.revokeSession(id);
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Selesai', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}
