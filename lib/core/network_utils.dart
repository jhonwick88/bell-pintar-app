import 'dart:io';

class NetworkUtils {
  /// Mendeteksi daftar IP address (IPv4 LAN/Wi-Fi) aktif pada komputer/perangkat ini
  static Future<List<String>> getLocalIPv4Addresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          // Abaikan loopback dan link-local autoconfiguration (169.254.x.x)
          if (!addr.isLoopback &&
              !addr.address.startsWith('169.254.') &&
              addr.type == InternetAddressType.IPv4) {
            if (!ips.contains(addr.address)) {
              ips.add(addr.address);
            }
          }
        }
      }
    } catch (_) {}
    return ips;
  }
}
