import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../core/network_utils.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _enteredPin = '';
  bool _isLoading = false;
  String? _errorMessage;

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 8) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClear() {
    setState(() {
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _submitPin() async {
    if (_enteredPin.isEmpty) return;

    setState(() => _isLoading = true);
    final state = context.read<AppState>();
    final success = await state.login(_enteredPin);

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        setState(() {
          _errorMessage = state.errorMessage ?? 'PIN Salah! Silakan coba lagi.';
          _enteredPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ActionChip(
              avatar: const Icon(Icons.wifi_tethering_rounded, size: 16, color: AppTheme.primaryCyan),
              label: Text(
                'Server: ${_cleanUrl(ApiService.baseUrl)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.surfaceDark,
              side: const BorderSide(color: Color(0xFF334155)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onPressed: () => _showServerConfigDialog(context),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.15),
                      child: const Icon(Icons.notifications_active, size: 36, color: AppTheme.primaryCyan),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'BELL PINTAR',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masukkan PIN Petugas untuk Membuka Akses',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // PIN Dots Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_enteredPin.length > 6 ? 8 : 6, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      key: ValueKey('pin_dot_$index'),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? AppTheme.primaryCyan : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? AppTheme.primaryCyan : const Color(0xFF475569),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],

                const SizedBox(height: 28),

                // Numeric Keypad
                Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 12),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 12),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.clear,
                          label: 'C',
                          color: AppTheme.textMuted,
                          onTap: _onClear,
                        ),
                        _buildDigitButton('0'),
                        _buildActionButton(
                          icon: Icons.backspace_outlined,
                          label: '',
                          color: AppTheme.textMuted,
                          onTap: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading || _enteredPin.isEmpty ? null : _submitPin,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Masuk Aplikasi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 20),

                // Quick preset helper for demo / testing
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('PIN Uji Coba Bawaan:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickPinChip('Guru Piket (432234)', '432234'),
                          _buildQuickPinChip('Admin (741147)', '741147'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return _BouncingKeypadButton(
      onTap: () => _onDigitPress(digit),
      builder: (context, isPressed) {
        return Container(
          width: 72,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPressed ? AppTheme.primaryCyan.withValues(alpha: 0.2) : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPressed ? AppTheme.primaryCyan : const Color(0xFF334155),
              width: isPressed ? 2 : 1,
            ),
            boxShadow: isPressed
                ? [
                    BoxShadow(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isPressed ? AppTheme.primaryCyan : Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return _BouncingKeypadButton(
      onTap: onTap,
      builder: (context, isPressed) {
        return Container(
          width: 72,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPressed ? color.withValues(alpha: 0.2) : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPressed ? color : const Color(0xFF334155),
              width: isPressed ? 2 : 1,
            ),
            boxShadow: isPressed
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                    )
                  ]
                : [],
          ),
          child: label.isNotEmpty
              ? Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
              : Icon(icon, color: color, size: 22),
        );
      },
    );
  }

  Widget _buildQuickPinChip(String label, String pin) {
    return _BouncingKeypadButton(
      maxScale: 1.08,
      onTap: () {
        setState(() {
          _enteredPin = pin;
          _errorMessage = null;
        });
        _submitPin();
      },
      builder: (context, isPressed) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPressed ? AppTheme.primaryCyan.withValues(alpha: 0.3) : AppTheme.primaryCyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPressed ? Colors.white : AppTheme.primaryCyan.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.primaryCyan, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  String _cleanUrl(String url) {
    return url.replaceAll('http://', '').replaceAll('https://', '').replaceAll('/api/v1', '');
  }

  void _showServerConfigDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiService.baseUrl);
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
            Icon(Icons.settings_ethernet_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 10),
            Text('Sambungkan Server LAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan IP Server Bell Pintar yang tertera di komputer desktop (atau dari hasil scan barcode QR):',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'URL Server API',
                hintText: 'http://192.168.1.100:8088/api/v1',
                prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.primaryCyan),
                filled: true,
                fillColor: AppTheme.cardDark,
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
                        avatar: const Icon(Icons.computer, size: 14, color: AppTheme.primaryCyan),
                        label: Text('$ip:8088 (PC Ini)', style: const TextStyle(fontSize: 11, color: AppTheme.primaryCyan, fontWeight: FontWeight.bold)),
                        onPressed: () => controller.text = 'http://$ip:8088/api/v1',
                      ),
                    ActionChip(
                      label: const Text('localhost:8088', style: TextStyle(fontSize: 11)),
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
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Simpan & Hubungkan'),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                final formattedUrl = newUrl.startsWith('http') ? newUrl : 'http://$newUrl/api/v1';
                await context.read<AppState>().setServerUrl(formattedUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {
                  _errorMessage = null;
                });
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
}

/// A smooth interactive bouncing button that scales up on press and smoothly springs back.
class _BouncingKeypadButton extends StatefulWidget {
  final Widget Function(BuildContext context, bool isPressed) builder;
  final VoidCallback onTap;
  final double maxScale;

  const _BouncingKeypadButton({
    required this.builder,
    required this.onTap,
    this.maxScale = 1.12,
  });

  @override
  State<_BouncingKeypadButton> createState() => _BouncingKeypadButtonState();
}

class _BouncingKeypadButtonState extends State<_BouncingKeypadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.maxScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) async {
    // Keep the scale-up pulse clearly visible before returning
    await Future.delayed(const Duration(milliseconds: 70));
    if (mounted) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
    widget.onTap();
  }

  void _onTapCancel() {
    if (mounted) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.builder(context, _isPressed),
          );
        },
      ),
    );
  }
}

