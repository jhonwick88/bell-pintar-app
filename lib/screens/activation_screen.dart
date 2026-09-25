import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/network_utils.dart';
import '../providers/app_state.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController = TextEditingController();
  final _schoolController = TextEditingController();
  bool _isCopied = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    if (state.schoolName.isNotEmpty && state.schoolName != 'Bell Pintar Sekolah') {
      _schoolController.text = state.schoolName;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  String _cleanUrl(String url) {
    return url.replaceAll('http://', '').replaceAll('https://', '').replaceAll('/api/v1', '');
  }

  void _showServerConfigDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.settings_ethernet_rounded, color: Color(0xFF58A6FF)),
            SizedBox(width: 10),
            Text('Sambungkan Server LAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan IP Server Bell Pintar yang tertera di PC Server (komputer desktop):',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'URL Server API',
                labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                hintText: 'http://172.16.0.137:8088/api/v1',
                hintStyle: const TextStyle(color: Color(0xFF484F58)),
                prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF58A6FF)),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<String>>(
              future: NetworkUtils.getLocalIPv4Addresses(),
              builder: (context, snapshot) {
                final localIps = snapshot.data ?? [];
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final ip in localIps)
                      ActionChip(
                        backgroundColor: const Color(0xFF21262D),
                        avatar: const Icon(Icons.computer, size: 14, color: Color(0xFF58A6FF)),
                        label: Text('$ip:8088 (PC Ini)', style: const TextStyle(fontSize: 11, color: Color(0xFF58A6FF), fontWeight: FontWeight.bold)),
                        onPressed: () => controller.text = 'http://$ip:8088/api/v1',
                      ),
                    ActionChip(
                      backgroundColor: const Color(0xFF21262D),
                      label: const Text('localhost:8088', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                      onPressed: () => controller.text = 'http://localhost:8088/api/v1',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Simpan & Hubungkan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                final formattedUrl = newUrl.startsWith('http') ? newUrl : 'http://$newUrl/api/v1';
                await context.read<AppState>().setServerUrl(formattedUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Server dialihkan ke: $formattedUrl')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _copyHWID(String hwid) {
    Clipboard.setData(ClipboardData(text: hwid));
    setState(() => _isCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hardware ID (HWID) berhasil disalin ke clipboard!'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _handleActivation() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _localError = 'Silakan masukkan License Key dari admin PintarLabs');
      return;
    }

    setState(() => _localError = null);
    final state = Provider.of<AppState>(context, listen: false);

    final success = await state.activateLicenseKey(
      key,
      schoolName: _schoolController.text.trim(),
    );

    if (!success && mounted) {
      setState(() {
        _localError = state.errorMessage ?? 'Gagal aktivasi lisensi. Pastikan key valid dan server lisensi terjangkau.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hwid = state.hardwareId.isNotEmpty ? state.hardwareId : 'Memuat Hardware ID...';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Card(
              color: const Color(0xFF161B22),
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Server Connection Status Chip
                    Align(
                      alignment: Alignment.topRight,
                      child: ActionChip(
                        avatar: Icon(
                          state.isServerReachable ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
                          size: 14,
                          color: state.isServerReachable ? const Color(0xFF58A6FF) : const Color(0xFFF0883E),
                        ),
                        label: Text(
                          'Server: ${_cleanUrl(ApiService.baseUrl)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: state.isServerReachable ? const Color(0xFF8B949E) : const Color(0xFFF0883E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: const Color(0xFF0F141C),
                        side: BorderSide(
                          color: state.isServerReachable ? const Color(0xFF30363D) : const Color(0xFFD29922),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onPressed: () => _showServerConfigDialog(context),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header Logo & Icon
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 38),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Aktivasi Bell Pintar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aplikasi belum teraktivasi. Daftarkan lisensi resmi PintarLabs untuk mulai menggunakan bel otomatis sekolah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF8B949E), height: 1.4),
                    ),
                    const SizedBox(height: 24),

                    // Server Unreachable Warning Box
                    if (!state.isServerReachable) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D1D09),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD29922), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.wifi_off_rounded, color: Color(0xFFF0883E), size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Server Bel di PC Belum Terhubung',
                                    style: TextStyle(color: Color(0xFFF0883E), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Aplikasi di HP belum terhubung ke Server BellPintar di PC desktop (${ApiService.baseUrl}).\n'
                              'Jika Anda menggunakan HP dalam 1 jaringan Wi-Fi sekolah, silakan atur IP Server PC agar HP langsung tersambung dan membaca lisensi aktif dari PC.',
                              style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                                label: const Text('Sambungkan Server LAN (Atur IP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F6FEB),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showServerConfigDialog(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Machine Fingerprint / HWID Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.fingerprint_rounded, size: 16, color: Color(0xFF58A6FF)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Hardware ID (HWID Mesin Ini):',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => _copyHWID(hwid),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_isCopied ? Icons.check : Icons.copy_rounded, size: 14, color: _isCopied ? Colors.greenAccent : const Color(0xFF58A6FF)),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isCopied ? 'Tersalin' : 'Salin HWID',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _isCopied ? Colors.greenAccent : const Color(0xFF58A6FF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            hwid,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 12,
                              color: Color(0xFFE6EDF3),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Input License Key
                    const Text(
                      'Kode Lisensi (License Key)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC9D1D9)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _keyController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Consolas', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Contoh: BELL-PRO-XXXX-XXXX-XXXX',
                        hintStyle: const TextStyle(color: Color(0xFF484F58)),
                        prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF58A6FF), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF30363D)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF58A6FF), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Optional School Name
                    const Text(
                      'Nama Sekolah / Instansi (Opsional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC9D1D9)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _schoolController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Contoh: SMA Negeri 1 Pintar',
                        hintStyle: const TextStyle(color: Color(0xFF484F58)),
                        prefixIcon: const Icon(Icons.school_rounded, color: Color(0xFF8B949E), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF30363D)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF58A6FF), width: 1.5),
                        ),
                      ),
                    ),

                    // Error Message
                    if (_localError != null || state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _localError ?? state.errorMessage ?? '',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: state.isLoading ? null : _handleActivation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF238636),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Aktivasi Lisensi Sekarang',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => state.checkLicense(),
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF58A6FF)),
                          label: const Text(
                            'Segarkan Status Lisensi',
                            style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12),
                          ),
                        ),
                        const Text('•', style: TextStyle(color: Color(0xFF484F58))),
                        TextButton.icon(
                          onPressed: () => _showServerConfigDialog(context),
                          icon: const Icon(Icons.settings_ethernet_rounded, size: 16, color: Color(0xFF8B949E)),
                          label: const Text(
                            'Atur IP Server LAN',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
