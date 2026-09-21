import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({super.key});

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  bool _isReconnecting = false;

  Future<void> _handleRetry() async {
    setState(() => _isReconnecting = true);
    final state = context.read<AppState>();
    await state.checkLicense();
    if (mounted) {
      setState(() => _isReconnecting = false);
      if (!state.isServerReachable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Server di ${ApiService.baseUrl} belum dapat dihubungi. Periksa koneksi Wi-Fi Anda.',
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
            Text(
              'Sambungkan Server LAN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan IP Server Bell Pintar yang tertera di PC Server (komputer desktop sekolah):',
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
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  backgroundColor: const Color(0xFF21262D),
                  label: const Text('172.16.0.137:8088', style: TextStyle(fontSize: 11, color: Color(0xFF58A6FF))),
                  onPressed: () => controller.text = 'http://172.16.0.137:8088/api/v1',
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF21262D),
                  label: const Text('localhost:8088', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                  onPressed: () => controller.text = 'http://localhost:8088/api/v1',
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF21262D),
                  label: const Text('192.168.1.100:8088', style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                  onPressed: () => controller.text = 'http://192.168.1.100:8088/api/v1',
                ),
              ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: const Color(0xFF161B22),
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon Header
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 40),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Belum Terhubung ke Server',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Text(
                      'Aplikasi remote bel di HP ini tidak dapat menjangkau komputer server Bell Pintar di jaringan lokal sekolah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF8B949E), height: 1.4),
                    ),
                    const SizedBox(height: 24),

                    // Server Info Box
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
                                  Icon(Icons.dns_rounded, size: 16, color: Color(0xFF58A6FF)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Target Server Bel:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => _showServerConfigDialog(context),
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 14, color: Color(0xFF58A6FF)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ubah IP',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            ApiService.baseUrl,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 13,
                              color: Color(0xFFE6EDF3),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Checklist Panduan
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Langkah Pengecekan:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3)),
                          ),
                          SizedBox(height: 8),
                          _ChecklistRow(
                            icon: Icons.check_circle_outline_rounded,
                            text: 'Pastikan komputer PC Server di sekolah sudah menyala & bell_server.exe berjalan.',
                          ),
                          SizedBox(height: 6),
                          _ChecklistRow(
                            icon: Icons.check_circle_outline_rounded,
                            text: 'Pastikan HP terhubung ke Wi-Fi sekolah yang sama dengan PC (bukan kuota seluler).',
                          ),
                          SizedBox(height: 6),
                          _ChecklistRow(
                            icon: Icons.qr_code_scanner_rounded,
                            text: 'Bisa juga scan QR Pairing di menu Pengaturan PC via Kamera HP untuk menghubungkan otomatis.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action: Coba Hubungkan Kembali
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isReconnecting ? null : _handleRetry,
                        icon: _isReconnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20),
                        label: Text(
                          _isReconnecting ? 'Menghubungkan...' : 'Coba Hubungkan Kembali',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCyan,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action: Ubah IP Server
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => _showServerConfigDialog(context),
                        icon: const Icon(Icons.settings_ethernet_rounded, size: 18),
                        label: const Text(
                          'Atur Alamat IP Server LAN',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B949E),
                          side: const BorderSide(color: Color(0xFF30363D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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

class _ChecklistRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ChecklistRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF58A6FF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E), height: 1.3),
          ),
        ),
      ],
    );
  }
}
