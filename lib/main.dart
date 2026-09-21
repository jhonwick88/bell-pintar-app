import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/activation_screen.dart';
import 'screens/main_layout.dart';
import 'screens/pin_login_screen.dart';
import 'screens/server_connection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const BellPintarApp(),
    ),
  );
}

class BellPintarApp extends StatelessWidget {
  const BellPintarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BellPintar - Sistem Bel Sekolah Otomatis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // ExcludeSemantics prevents the Windows Accessibility Bridge (AXTree) mismatch error
      builder: (context, child) => ExcludeSemantics(
        child: child ?? const SizedBox.shrink(),
      ),
      home: Consumer<AppState>(
        builder: (context, state, child) {
          // 1. Loading license/connection verification at startup
          if (state.isCheckingLicense) {
            return const Scaffold(
              backgroundColor: Color(0xFF0D1117),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF58A6FF)),
                    SizedBox(height: 16),
                    Text(
                      'Menghubungkan ke Server BellPintar...',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          // 2. Server unreachable (Offline / Beda Jaringan / Belum Set IP)
          // HP tidak akan pernah diminta aktivasi lisensi jika hanya karena offline/belum terhubung LAN!
          if (!state.isServerReachable) {
            return const ServerConnectionScreen();
          }

          // 3. Server terhubung, tapi Lisensi Server Bel PC Belum Aktif -> Tampilkan Layar Aktivasi
          if (!state.isLicenseActive) {
            return const ActivationScreen();
          }

          // 4. Server terhubung & Lisensi aktif -> Tampilkan Login PIN Guru Piket / Admin TU
          if (!state.isAuthenticated) {
            return const PinLoginScreen();
          }

          // 5. Sudah login PIN -> Tampilkan Dashboard Utama Aplikasi Bel
          return const MainLayout();
        },
      ),
    );
  }
}
