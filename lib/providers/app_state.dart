import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:app_links/app_links.dart';
import '../core/api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isConnected = false;
  bool isLoading = false;
  String? errorMessage;

  // License State
  bool isCheckingLicense = true;
  bool isLicenseActive = false;
  bool isServerReachable = true;
  Map<String, dynamic>? licenseInfo;
  String hardwareId = '';
  double ttsSpeed = 1.0;

  // Auth
  String? token;
  Map<String, dynamic>? currentUser;
  bool get isAuthenticated => token != null && token!.isNotEmpty;
  bool get isAdmin => currentUser?['role'] == 'ADMIN';

  // Dashboard Data
  String currentTime = '--:--:--';
  String currentDate = '----/--/--';
  String activePresetName = 'Memuat...';
  String activePresetId = '1';
  bool isRelayOn = false;
  String masterVolume = '85';
  String edition = 'PRO';
  Map<String, dynamic>? nextSchedule;
  int countdownSeconds = 0;

  // Lists
  List<dynamic> presets = [];
  int? selectedPresetId;
  String get currentSelectedPresetName {
    final targetId = selectedPresetId ?? int.tryParse(activePresetId) ?? 1;
    final found = presets.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['id'] == targetId,
      orElse: () => null,
    );
    return found?['name'] ?? activePresetName;
  }
  List<dynamic> schedules = [];
  List<dynamic> audioList = [];
  List<dynamic> announcements = [];
  List<dynamic> logs = [];
  Map<String, dynamic> settings = {};

  int selectedDay = DateTime.now().weekday; // 1=Senin
  bool isLoadingSchedules = false;
  Timer? _timer;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    final savedUrl = prefs.getString('server_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      api.updateBaseUrl(savedUrl);
    }
    if (token != null) {
      api.setToken(token);
    }

    _initDeepLinks();
    await checkLicense();
    _startClockTimer();
    if (isLicenseActive && isAuthenticated) {
      await refreshAll();
    }
  }

  void _startClockTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      if (countdownSeconds > 0) {
        countdownSeconds--;
      }
      notifyListeners();
    });
  }

  Future<void> refreshAll() async {
    try {
      final ping = await api.ping();
      isConnected = ping['status'] == 'online';
      edition = ping['edition'] ?? 'PRO';

      final dash = await api.getDashboardStatus();
      activePresetId = dash['active_preset_id']?.toString() ?? '1';
      activePresetName = dash['active_preset_name'] ?? 'Reguler';
      selectedPresetId ??= int.tryParse(activePresetId) ?? 1;
      isRelayOn = dash['relay_status'] ?? false;
      masterVolume = dash['master_volume']?.toString() ?? '85';
      nextSchedule = dash['next_schedule'];
      countdownSeconds = (nextSchedule?['seconds_until'] as num?)?.toInt() ?? 0;

      if (isAuthenticated) {
        presets = await api.getPresets();
        await loadSchedules();
        audioList = await api.getAudioList();
        announcements = await api.getAnnouncements();
        logs = await api.getLogs();
        if (isAdmin) {
          settings = await api.getSettings();
      if (settings['tts_speed'] != null) {
        ttsSpeed = double.tryParse(settings['tts_speed'].toString()) ?? 1.0;
      }
        }
      }
      errorMessage = null;
    } catch (e) {
      isConnected = false;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<bool> login(String pin) async {
    try {
      isLoading = true;
      notifyListeners();
      final res = await api.loginPIN(pin);
      token = res['token'];
      currentUser = res['user'];
      api.setToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token!);

      await refreshAll();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      if (e is DioException && e.response?.data is Map && e.response?.data['error'] != null) {
        errorMessage = e.response!.data['error'].toString();
      } else {
        errorMessage = 'PIN Salah atau koneksi server gagal';
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> checkLicense() async {
    isCheckingLicense = true;
    notifyListeners();
    try {
      final res = await api.getLicenseStatus().timeout(const Duration(seconds: 4));
      licenseInfo = res;
      isServerReachable = true;
      isLicenseActive = res['is_valid'] == true;
      hardwareId = (res['hardware_id'] ?? '').toString();
    } catch (e) {
      isServerReachable = false;
      isLicenseActive = false;
      hardwareId = '';
    } finally {
      isCheckingLicense = false;
      notifyListeners();
    }
  }

  Future<bool> activateLicenseKey(String key, {String? schoolName, String? serverUrl}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await api.activateLicense(key, schoolName, serverUrl);
      await checkLicense();
      return isLicenseActive;
    } catch (e) {
      if (e is Exception) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      notifyListeners();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    token = null;
    currentUser = null;
    api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    api.updateBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
    await checkLicense();
    if (isLicenseActive && isAuthenticated) {
      await refreshAll();
    }
  }

  Future<void> loadSchedules({int? presetId, int? day}) async {
    try {
      isLoadingSchedules = true;
      notifyListeners();
      final targetPreset = presetId ?? selectedPresetId ?? int.tryParse(activePresetId) ?? 1;
      final targetDay = day ?? selectedDay;
      final res = await api.getSchedules(presetId: targetPreset, day: targetDay);
      schedules = res;
    } catch (_) {
      schedules = [];
    } finally {
      isLoadingSchedules = false;
      notifyListeners();
    }
  }

  Future<void> setSelectedPreset(int presetId, {int? day}) async {
    selectedPresetId = presetId;
    if (day != null) {
      selectedDay = day;
    }
    await loadSchedules(presetId: presetId, day: selectedDay);
  }

  Future<void> setSelectedDay(int day) async {
    selectedDay = day;
    await loadSchedules(day: day);
  }

  Future<int> copySchedules({
    required int presetId,
    required int sourceDay,
    required int targetDay,
  }) async {
    try {
      final source = await api.getSchedules(presetId: presetId, day: sourceDay);
      if (source.isEmpty) return 0;

      int count = 0;
      for (final item in source) {
        await api.createSchedule({
          'preset_id': presetId,
          'day_of_week': targetDay,
          'time_trigger': item['time_trigger'],
          'title': item['title'],
          'audio_file_id': item['audio_file_id'],
          'custom_tts_text': item['custom_tts_text'],
        });
        count++;
      }
      await loadSchedules(presetId: presetId, day: targetDay);
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearDaySchedules({
    required int presetId,
    required int day,
  }) async {
    try {
      isLoadingSchedules = true;
      schedules = []; // Segera kosongkan list di memory agar UI langsung berefek
      notifyListeners();

      try {
        await api.clearDaySchedules(presetId, day);
      } catch (_) {
        // Fallback jika memanggil server lama
        final list = await api.getSchedules(presetId: presetId, day: day);
        for (final item in list) {
          if (item['id'] != null) {
            await api.deleteSchedule(item['id']);
          }
        }
      }

      await loadSchedules(presetId: presetId, day: day);
    } catch (e) {
      schedules = [];
      rethrow;
    } finally {
      isLoadingSchedules = false;
      notifyListeners();
    }
  }

  Future<void> switchPreset(int presetId, {int? day}) async {
    try {
      isLoadingSchedules = true;
      selectedPresetId = presetId;
      activePresetId = presetId.toString();
      if (day != null) {
        selectedDay = day;
      }
      notifyListeners();

      await api.setActivePreset(presetId);
      final dash = await api.getDashboardStatus();
      activePresetId = dash['active_preset_id']?.toString() ?? presetId.toString();
      activePresetName = dash['active_preset_name'] ?? activePresetName;

      final res = await api.getSchedules(presetId: presetId, day: selectedDay);
      schedules = res;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoadingSchedules = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> createPreset({
    required String name,
    String? code,
    String? description,
    int? copyFromPresetId,
  }) async {
    try {
      isLoadingSchedules = true;
      notifyListeners();
      final res = await api.createPreset(
        name: name,
        code: code,
        description: description,
        copyFromPresetId: copyFromPresetId,
      );
      presets = await api.getPresets();
      final newPreset = res['preset'];
      final newId = newPreset?['id'] as int?;
      if (newId != null) {
        selectedPresetId = newId;
        selectedDay = 1;
        final schedRes = await api.getSchedules(presetId: newId, day: 1);
        schedules = schedRes;
      }
      return res;
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoadingSchedules = false;
      notifyListeners();
    }
  }

  Future<void> deletePreset(int presetId) async {
    try {
      isLoadingSchedules = true;
      notifyListeners();
      await api.deletePreset(presetId);
      presets = await api.getPresets();
      if (selectedPresetId == presetId) {
        final fallbackId = int.tryParse(activePresetId) ?? (presets.isNotEmpty ? presets.first['id'] as int : 1);
        selectedPresetId = fallbackId;
        selectedDay = 1;
        final schedRes = await api.getSchedules(presetId: fallbackId, day: 1);
        schedules = schedRes;
      }
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoadingSchedules = false;
      notifyListeners();
    }
  }

  Future<void> triggerManual(String title, {int? audioId}) async {
    await api.triggerManualBell(title: title, audioId: audioId);
    await refreshAll();
  }

  Future<void> testAudio(int audioId) async {
    try {
      await api.testAudio(audioId);
    } catch (_) {}
  }

  Future<void> broadcastTTS(String text, {double? speed}) async {
    await api.speakTTS(text, speed: speed ?? ttsSpeed);
    await refreshAll();
  }

  Future<void> loadAnnouncements() async {
    try {
      announcements = await api.getAnnouncements();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> triggerAnnouncement(int id) async {
    await api.triggerAnnouncement(id);
    await refreshAll();
  }

  Future<void> createAnnouncement({
    required String title,
    required String ttsText,
    String language = 'id-ID',
    int? chimeAudioId,
  }) async {
    await api.createAnnouncement(
      title: title,
      ttsText: ttsText,
      language: language,
      chimeAudioId: chimeAudioId,
    );
    await loadAnnouncements();
  }

  Future<void> updateAnnouncement({
    required int id,
    required String title,
    required String ttsText,
    String language = 'id-ID',
    int? chimeAudioId,
  }) async {
    await api.updateAnnouncement(
      id: id,
      title: title,
      ttsText: ttsText,
      language: language,
      chimeAudioId: chimeAudioId,
    );
    await loadAnnouncements();
  }

  Future<void> deleteAnnouncement(int id) async {
    await api.deleteAnnouncement(id);
    await loadAnnouncements();
  }

  Future<void> setTtsSpeed(double speed) async {
    ttsSpeed = speed;
    notifyListeners();
    try {
      final newSettings = Map<String, dynamic>.from(settings);
      newSettings['tts_speed'] = speed.toStringAsFixed(2);
      await api.saveSettings(newSettings.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {}
  }

  // Feature getters
  bool get canCustomAudio => licenseInfo?['feat_custom_audio'] == true;
  bool get canRemoteMobile => licenseInfo?['feat_remote_mobile'] == true;
  int get featMaxDevices => (licenseInfo?['feat_max_devices'] ?? licenseInfo?['max_devices'] as num?)?.toInt() ?? 1;
  int get maxDevices => featMaxDevices;

  // Network & Sessions
  Map<String, dynamic>? serverNetwork;
  List<dynamic> activeSessions = [];

  Future<void> loadAudioList() async {
    try {
      audioList = await api.getAudioList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> uploadAudioFile({
    required String filePath,
    required String title,
    required String category,
  }) async {
    await api.uploadAudio(filePath: filePath, title: title, category: category);
    await loadAudioList();
  }

  Future<void> updateAudioFile(int id, {required String title, required String category}) async {
    await api.updateAudio(id, title: title, category: category);
    await loadAudioList();
  }

  Future<void> deleteAudioFile(int id) async {
    await api.deleteAudio(id);
    await loadAudioList();
  }

  Future<void> loadServerNetwork() async {
    try {
      serverNetwork = await api.getServerNetwork();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadActiveSessions() async {
    try {
      final res = await api.getSessions();
      activeSessions = res['sessions'] ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> revokeSession(int id) async {
    await api.revokeSession(id);
    await loadActiveSessions();
  }

  StreamSubscription<Uri>? _subAppLinks;
  final AppLinks _appLinks = AppLinks();

  void _initDeepLinks() {
    try {
      // 1. Listen for background/runtime incoming deep links
      _subAppLinks = _appLinks.uriLinkStream.listen((uri) {
        _handleDeepLinkUri(uri);
      });

      // 2. Check if the app was cold-started from a deep link
      _appLinks.getInitialLink().then((uri) {
        if (uri != null) {
          _handleDeepLinkUri(uri);
        }
      });
    } catch (_) {}
  }

  void _handleDeepLinkUri(Uri uri) async {
    // Format: bellpintar://pair?url=http://172.16.0.137:8088/api/v1
    if (uri.scheme == 'bellpintar') {
      final serverUrl = uri.queryParameters['url'] ?? uri.queryParameters['server'];
      if (serverUrl != null && serverUrl.isNotEmpty) {
        final formattedUrl = serverUrl.startsWith('http') ? serverUrl : 'http://$serverUrl';
        await setServerUrl(formattedUrl);
      }
    }
  }

  @override
  void dispose() {
    _subAppLinks?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
