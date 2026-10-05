import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:app_links/app_links.dart';
import '../core/api_service.dart';
import '../core/sound_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isConnected = false;
  bool isLoading = false;
  String? errorMessage;

  // Demo Mode State
  bool isDemoMode = false;
  Map<int, Map<int, List<Map<String, dynamic>>>> _demoSchedules = {};
  int _demoNextScheduleId = 100;
  int _demoNextPresetId = 10;
  int _demoNextAudioId = 50;
  int _demoNextAnnouncementId = 10;
  int? _lastTriggeredScheduleId;

  // License State
  bool isCheckingLicense = true;
  bool isLicenseActive = false;
  bool isServerReachable = true;
  Map<String, dynamic>? licenseInfo;
  String schoolName = 'Bell Pintar Sekolah';
  String hardwareId = '';
  double ttsSpeed = 1.0;

  // Auth
  String? token;
  Map<String, dynamic>? currentUser;
  bool get isAuthenticated => (token != null && token!.isNotEmpty) || isDemoMode;
  bool get isAdmin => isDemoMode || (currentUser?['role'] == 'ADMIN');

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

    final cachedSchool = prefs.getString('cached_school_name');
    if (cachedSchool != null && cachedSchool.isNotEmpty) {
      schoolName = cachedSchool;
      settings['school_name'] = cachedSchool;
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

      if (isDemoMode) {
        _updateDemoCountdown();
      } else {
        if (countdownSeconds > 0) {
          countdownSeconds--;
        }
      }
      notifyListeners();
    });
  }

  // ==========================================
  // DEMO MODE IMPLEMENTATION (OFFLINE / PREVIEW)
  // ==========================================
  void enterDemoMode() {
    isDemoMode = true;
    isCheckingLicense = false;
    isServerReachable = true;
    isLicenseActive = true;
    isConnected = true;
    token = 'demo_token';
    currentUser = {
      'id': 1,
      'name': 'Admin TU (Demo Mode)',
      'role': 'ADMIN',
      'pin': '741147',
    };
    schoolName = 'SMA Negeri 1 Pintar (Mode Demo)';
    edition = 'DEMO PRO';
    activePresetId = '1';
    activePresetName = 'Jadwal Reguler (5 Hari)';
    selectedPresetId = 1;
    selectedDay = (DateTime.now().weekday >= 1 && DateTime.now().weekday <= 5) ? DateTime.now().weekday : 1;
    masterVolume = '90';
    ttsSpeed = 1.0;

    licenseInfo = {
      'is_valid': true,
      'plan_id': 'DEMO_EDITION',
      'customer_id': 'Pintar Labs Demo Showcase',
      'product_id': 'BELLPINTAR-DEMO',
      'feat_custom_audio': true,
      'feat_remote_mobile': true,
      'feat_max_devices': 5,
    };

    settings = {
      'school_name': 'SMA Negeri 1 Pintar (Mode Demo)',
      'relay_delay_before': '2',
      'relay_delay_after': '3',
      'master_volume': '90',
      'tts_speed': '1.0',
      'relay_enabled': '1',
    };

    _seedDemoData();
    _updateDemoCountdown();
    notifyListeners();

    // Bunyikan chime pembuka saat masuk mode demo sebagai tanda audio aktif
    SoundService().playDemoBell(audioId: 11);
  }

  void exitDemoMode() {
    SoundService().stop();
    isDemoMode = false;
    token = null;
    currentUser = null;
    api.setToken(null);
    _demoSchedules.clear();
    checkLicense();
  }

  void _seedDemoData() {
    presets = [
      {
        'id': 1,
        'name': 'Jadwal Reguler (5 Hari)',
        'code': 'REGULER',
        'is_active': 1,
        'description': 'Jadwal standar kegiatan belajar mengajar (Senin - Jumat)',
      },
      {
        'id': 2,
        'name': 'Jadwal Khusus Hari Jumat',
        'code': 'JUMAT',
        'is_active': 0,
        'description': 'Jadwal kepulangan lebih awal hari Jumat untuk persiapan ibadah',
      },
      {
        'id': 3,
        'name': 'Pekan Penilaian Akhir (Ujian)',
        'code': 'UJIAN',
        'is_active': 0,
        'description': 'Jadwal bel pelaksanaan evaluasi dan ujian semester',
      },
    ];

    audioList = [
      {'id': 1, 'title': 'Bel Masuk Jam Ke-1 (Bahasa Indonesia & English)', 'category': 'Jam Pelajaran', 'duration': 18, 'is_builtin': 1},
      {'id': 2, 'title': 'Bel Pergantian Jam Pelajaran Ke-2', 'category': 'Jam Pelajaran', 'duration': 12, 'is_builtin': 1},
      {'id': 3, 'title': 'Bel Pergantian Jam Pelajaran Ke-3', 'category': 'Jam Pelajaran', 'duration': 12, 'is_builtin': 1},
      {'id': 4, 'title': 'Bel Pergantian Jam Pelajaran Ke-4', 'category': 'Jam Pelajaran', 'duration': 12, 'is_builtin': 1},
      {'id': 5, 'title': 'Bel Istirahat Pertama (Snack & Refresh)', 'category': 'Istirahat', 'duration': 16, 'is_builtin': 1},
      {'id': 6, 'title': 'Bel Selesai Istirahat - Masuk Kelas', 'category': 'Istirahat', 'duration': 15, 'is_builtin': 1},
      {'id': 7, 'title': 'Bel Sholat Dzuhur Berjamaah', 'category': 'Ibadah', 'duration': 22, 'is_builtin': 1},
      {'id': 8, 'title': 'Bel Kepulangan Siswa & Doa Penutup', 'category': 'Kepulangan', 'duration': 25, 'is_builtin': 1},
      {'id': 9, 'title': 'Lagu Kebangsaan Indonesia Raya (3 Stanza)', 'category': 'Lagu Nasional', 'duration': 195, 'is_builtin': 1},
      {'id': 10, 'title': 'Mars Pendidikan Nasional / Hening Cipta', 'category': 'Lagu Nasional', 'duration': 160, 'is_builtin': 1},
      {'id': 11, 'title': 'Panggilan Siswa/Guru ke Ruang Piket (Chime)', 'category': 'Panggilan', 'duration': 14, 'is_builtin': 1},
      {'id': 12, 'title': 'Sirine Peringatan / Simulasi Tanggap Darurat', 'category': 'Peringatan', 'duration': 30, 'is_builtin': 1},
    ];

    announcements = [
      {
        'id': 1,
        'title': 'Panggilan Guru Piket Hari Ini',
        'tts_text': 'Diberitahukan kepada seluruh bapak ibu guru piket untuk berkumpul di ruang piket sekarang. Terima kasih.',
        'language': 'id-ID',
        'chime_audio_id': 11,
      },
      {
        'id': 2,
        'title': 'Himbauan Ketertiban & Kebersihan',
        'tts_text': 'Perhatian kepada seluruh siswa siswi agar tetap menjaga kebersihan kelas dan membuang sampah pada tempatnya.',
        'language': 'id-ID',
        'chime_audio_id': 5,
      },
      {
        'id': 3,
        'title': 'Pengumuman Rapat Dinas Dewan Guru',
        'tts_text': 'Diberitahukan kepada seluruh dewan guru bahwa rapat dinas bulanan akan dimulai pukul 13:00 WIB di aula sekolah.',
        'language': 'id-ID',
        'chime_audio_id': 11,
      },
    ];

    logs = [
      {
        'id': 1,
        'triggered_at': '$currentDate 07:00:00',
        'trigger_type': 'SCHEDULED',
        'audio_title': 'Masuk Kelas Jam Ke-1 & Doa Pagi',
        'triggered_by_user': 'SYSTEM',
        'status': 'SUCCESS',
      },
      {
        'id': 2,
        'triggered_at': '$currentDate 07:45:00',
        'trigger_type': 'SCHEDULED',
        'audio_title': 'Pergantian Jam Pelajaran Ke-2',
        'triggered_by_user': 'SYSTEM',
        'status': 'SUCCESS',
      },
      {
        'id': 3,
        'triggered_at': '$currentDate 08:30:00',
        'trigger_type': 'SCHEDULED',
        'audio_title': 'Pergantian Jam Pelajaran Ke-3',
        'triggered_by_user': 'SYSTEM',
        'status': 'SUCCESS',
      },
    ];

    // Seed preset 1 (Reguler 5 Hari)
    _demoSchedules[1] = {};
    for (int day = 1; day <= 4; day++) {
      _demoSchedules[1]![day] = [
        {'id': day * 100 + 1, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '06:45', 'title': 'Lagu Kebangsaan Indonesia Raya', 'audio_file_id': 9, 'audio_title': 'Lagu Kebangsaan Indonesia Raya (3 Stanza)'},
        {'id': day * 100 + 2, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '07:00', 'title': 'Masuk Kelas Jam Ke-1 & Doa Pagi', 'audio_file_id': 1, 'audio_title': 'Bel Masuk Jam Ke-1 (Bahasa Indonesia & English)'},
        {'id': day * 100 + 3, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '07:45', 'title': 'Pergantian Jam Pelajaran Ke-2', 'audio_file_id': 2, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-2'},
        {'id': day * 100 + 4, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '08:30', 'title': 'Pergantian Jam Pelajaran Ke-3', 'audio_file_id': 3, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-3'},
        {'id': day * 100 + 5, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '09:15', 'title': 'Pergantian Jam Pelajaran Ke-4', 'audio_file_id': 4, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-4'},
        {'id': day * 100 + 6, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '10:00', 'title': 'Istirahat Pertama (Snack & Refresh)', 'audio_file_id': 5, 'audio_title': 'Bel Istirahat Pertama (Snack & Refresh)'},
        {'id': day * 100 + 7, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '10:30', 'title': 'Selesai Istirahat - Masuk Jam Ke-5', 'audio_file_id': 6, 'audio_title': 'Bel Selesai Istirahat - Masuk Kelas'},
        {'id': day * 100 + 8, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '11:15', 'title': 'Pergantian Jam Pelajaran Ke-6', 'audio_file_id': 2, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-2'},
        {'id': day * 100 + 9, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '12:00', 'title': 'Istirahat Siang & Sholat Dzuhur', 'audio_file_id': 7, 'audio_title': 'Bel Sholat Dzuhur Berjamaah'},
        {'id': day * 100 + 10, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '13:00', 'title': 'Masuk Kelas Siang Jam Ke-7', 'audio_file_id': 1, 'audio_title': 'Bel Masuk Jam Ke-1 (Bahasa Indonesia & English)'},
        {'id': day * 100 + 11, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '13:45', 'title': 'Pergantian Jam Pelajaran Ke-8', 'audio_file_id': 2, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-2'},
        {'id': day * 100 + 12, 'preset_id': 1, 'day_of_week': day, 'time_trigger': '14:30', 'title': 'Jam Kepulangan Siswa & Doa Penutup', 'audio_file_id': 8, 'audio_title': 'Bel Kepulangan Siswa & Doa Penutup'},
      ];
    }
    // Hari Jumat (Day 5)
    _demoSchedules[1]![5] = [
      {'id': 501, 'preset_id': 1, 'day_of_week': 5, 'time_trigger': '06:30', 'title': 'Senam Pagi & Literasi', 'audio_file_id': 9, 'audio_title': 'Lagu Kebangsaan Indonesia Raya (3 Stanza)'},
      {'id': 502, 'preset_id': 1, 'day_of_week': 5, 'time_trigger': '07:00', 'title': 'Masuk Jam Pelajaran Ke-1', 'audio_file_id': 1, 'audio_title': 'Bel Masuk Jam Ke-1 (Bahasa Indonesia & English)'},
      {'id': 503, 'preset_id': 1, 'day_of_week': 5, 'time_trigger': '07:40', 'title': 'Masuk Jam Pelajaran Ke-2', 'audio_file_id': 2, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-2'},
      {'id': 504, 'preset_id': 1, 'day_of_week': 5, 'time_trigger': '08:20', 'title': 'Masuk Jam Pelajaran Ke-3', 'audio_file_id': 3, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-3'},
      {'id': 505, 'preset_id': 1, 'day_of_week': 5, 'time_trigger': '09:00', 'title': 'Istirahat & Sholat Dhuha', 'audio_file_id': 5, 'audio_title': 'Bel Istirahat Pertama (Snack & Refresh)'},
      {'id': 506, 'preset_id': 1, 'day_of_week': 5, 'time_trigger': '09:30', 'title': 'Masuk Jam Pelajaran Ke-4', 'audio_file_id': 4, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-4'},
      {'id': 507, 'preset_id': 1, 'day_of_week': 5, 'time_trigger': '10:10', 'title': 'Masuk Jam Pelajaran Ke-5', 'audio_file_id': 2, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-2'},
      {'id': 508, 'preset_id': 1, 'day_of_week': 5, 'time_trigger': '11:00', 'title': 'Kepulangan & Persiapan Sholat Jumat', 'audio_file_id': 8, 'audio_title': 'Bel Kepulangan Siswa & Doa Penutup'},
    ];
    _demoSchedules[1]![6] = [];
    _demoSchedules[1]![7] = [];

    // Seed preset 2 & 3
    _demoSchedules[2] = {5: List.from(_demoSchedules[1]![5] ?? [])};
    _demoSchedules[3] = {};
    for (int day = 1; day <= 5; day++) {
      _demoSchedules[3]![day] = [
        {'id': 3000 + day * 10 + 1, 'preset_id': 3, 'day_of_week': day, 'time_trigger': '07:15', 'title': 'Pemeriksaan & Masuk Ruang Ujian', 'audio_file_id': 1, 'audio_title': 'Bel Masuk Jam Ke-1 (Bahasa Indonesia & English)'},
        {'id': 3000 + day * 10 + 2, 'preset_id': 3, 'day_of_week': day, 'time_trigger': '07:30', 'title': 'Pengerjaan Sesi Ujian Ke-1 Dimulai', 'audio_file_id': 2, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-2'},
        {'id': 3000 + day * 10 + 3, 'preset_id': 3, 'day_of_week': day, 'time_trigger': '09:30', 'title': 'Sesi Ujian Ke-1 Selesai & Istirahat', 'audio_file_id': 5, 'audio_title': 'Bel Istirahat Pertama (Snack & Refresh)'},
        {'id': 3000 + day * 10 + 4, 'preset_id': 3, 'day_of_week': day, 'time_trigger': '10:00', 'title': 'Masuk Ruang Sesi Ujian Ke-2', 'audio_file_id': 1, 'audio_title': 'Bel Masuk Jam Ke-1 (Bahasa Indonesia & English)'},
        {'id': 3000 + day * 10 + 5, 'preset_id': 3, 'day_of_week': day, 'time_trigger': '10:15', 'title': 'Pengerjaan Sesi Ujian Ke-2 Dimulai', 'audio_file_id': 2, 'audio_title': 'Bel Pergantian Jam Pelajaran Ke-2'},
        {'id': 3000 + day * 10 + 6, 'preset_id': 3, 'day_of_week': day, 'time_trigger': '12:00', 'title': 'Ujian Hari Ini Selesai & Kepulangan', 'audio_file_id': 8, 'audio_title': 'Bel Kepulangan Siswa & Doa Penutup'},
      ];
    }

    schedules = _demoSchedules[selectedPresetId]?[selectedDay] ?? [];
  }

  void _updateDemoCountdown() {
    if (!isDemoMode) return;
    final now = DateTime.now();
    final currentMinSec = now.hour * 3600 + now.minute * 60 + now.second;

    final activeId = int.tryParse(activePresetId) ?? 1;
    final dayList = _demoSchedules[activeId]?[now.weekday] ?? _demoSchedules[activeId]?[1] ?? [];

    Map<String, dynamic>? upcoming;
    int minDiff = 999999;

    for (final item in dayList) {
      final timeStr = item['time_trigger']?.toString() ?? '';
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final targetSec = h * 3600 + m * 60;
        final diff = targetSec - currentMinSec;
        if (diff > 0 && diff < minDiff) {
          minDiff = diff;
          upcoming = item;
        }
      }
    }

    if (upcoming != null) {
      nextSchedule = {
        'id': upcoming['id'],
        'time_trigger': upcoming['time_trigger'],
        'title': upcoming['title'],
        'audio_title': upcoming['audio_title'] ?? 'Bel Sekolah',
        'seconds_until': minDiff,
      };
      countdownSeconds = minDiff;
    } else if (dayList.isNotEmpty) {
      final first = dayList.first;
      nextSchedule = {
        'id': first['id'],
        'time_trigger': first['time_trigger'],
        'title': first['title'],
        'audio_title': first['audio_title'] ?? 'Bel Sekolah',
        'seconds_until': 0,
      };
      countdownSeconds = 0;
    }
  }

  // ==========================================
  // GENERAL DATA & REFRESH
  // ==========================================
  Future<void> refreshAll() async {
    if (isDemoMode) {
      _updateDemoCountdown();
      notifyListeners();
      return;
    }

    try {
      final ping = await api.ping();
      isConnected = ping['status'] == 'online';
      edition = ping['edition'] ?? 'PRO';
      if (ping['school_name'] != null && ping['school_name'].toString().isNotEmpty) {
        schoolName = ping['school_name'].toString();
        settings['school_name'] = schoolName;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_school_name', schoolName);
      }

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
          if (settings['school_name'] != null && settings['school_name'].toString().isNotEmpty) {
            schoolName = settings['school_name'].toString();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cached_school_name', schoolName);
          }
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
    if (isDemoMode) {
      token = 'demo_token';
      currentUser = {'id': 1, 'name': 'Admin TU (Demo)', 'role': 'ADMIN'};
      notifyListeners();
      return true;
    }

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
    if (isDemoMode) {
      isCheckingLicense = false;
      isServerReachable = true;
      isLicenseActive = true;
      notifyListeners();
      return;
    }

    isCheckingLicense = true;
    notifyListeners();
    try {
      final res = await api.getLicenseStatus().timeout(const Duration(seconds: 4));
      licenseInfo = res;
      isServerReachable = true;
      isLicenseActive = res['is_valid'] == true;
      hardwareId = (res['hardware_id'] ?? '').toString();
      if (res['school_name'] != null && res['school_name'].toString().isNotEmpty) {
        schoolName = res['school_name'].toString();
        settings['school_name'] = schoolName;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_school_name', schoolName);
      }
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
      if (schoolName != null && schoolName.isNotEmpty) {
        this.schoolName = schoolName;
        settings['school_name'] = schoolName;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_school_name', schoolName);
      }
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
    if (isDemoMode) {
      exitDemoMode();
      return;
    }

    try {
      await api.logout();
    } catch (_) {}
    token = null;
    currentUser = null;
    api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    settings['school_name'] = schoolName;
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

  // ==========================================
  // SCHEDULES & PRESETS
  // ==========================================
  Future<void> loadSchedules({int? presetId, int? day}) async {
    final targetPreset = presetId ?? selectedPresetId ?? int.tryParse(activePresetId) ?? 1;
    final targetDay = day ?? selectedDay;

    if (isDemoMode) {
      isLoadingSchedules = true;
      notifyListeners();
      schedules = List.from(_demoSchedules[targetPreset]?[targetDay] ?? []);
      isLoadingSchedules = false;
      notifyListeners();
      return;
    }

    try {
      isLoadingSchedules = true;
      notifyListeners();
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

  Future<void> createSchedule(Map<String, dynamic> data) async {
    if (isDemoMode) {
      final targetPreset = data['preset_id'] as int? ?? selectedPresetId ?? 1;
      final targetDay = data['day_of_week'] as int? ?? selectedDay;
      final newId = ++_demoNextScheduleId;
      final audioId = data['audio_file_id'];
      String audioTitle = 'Bel Sekolah';
      for (final a in audioList) {
        if (a['id'] == audioId) {
          audioTitle = a['title'] ?? 'Bel Sekolah';
          break;
        }
      }

      final item = {
        'id': newId,
        'preset_id': targetPreset,
        'day_of_week': targetDay,
        'time_trigger': data['time_trigger'],
        'title': data['title'],
        'audio_file_id': audioId,
        'audio_title': audioTitle,
        'custom_tts_text': data['custom_tts_text'],
      };

      _demoSchedules.putIfAbsent(targetPreset, () => {});
      _demoSchedules[targetPreset]!.putIfAbsent(targetDay, () => []);
      _demoSchedules[targetPreset]![targetDay]!.add(item);
      _demoSchedules[targetPreset]![targetDay]!.sort((a, b) => (a['time_trigger'] ?? '').compareTo(b['time_trigger'] ?? ''));

      await loadSchedules(presetId: targetPreset, day: targetDay);
      return;
    }

    await api.createSchedule(data);
    await loadSchedules();
  }

  Future<void> updateSchedule(int id, Map<String, dynamic> data) async {
    if (isDemoMode) {
      final targetPreset = selectedPresetId ?? 1;
      final targetDay = data['day_of_week'] as int? ?? selectedDay;
      final audioId = data['audio_file_id'];
      String audioTitle = 'Bel Sekolah';
      for (final a in audioList) {
        if (a['id'] == audioId) {
          audioTitle = a['title'] ?? 'Bel Sekolah';
          break;
        }
      }

      if (_demoSchedules[targetPreset]?[targetDay] != null) {
        final list = _demoSchedules[targetPreset]![targetDay]!;
        for (int i = 0; i < list.length; i++) {
          if (list[i]['id'] == id) {
            list[i] = {
              ...list[i],
              ...data,
              'audio_title': audioTitle,
            };
            break;
          }
        }
        list.sort((a, b) => (a['time_trigger'] ?? '').compareTo(b['time_trigger'] ?? ''));
      }
      await loadSchedules(presetId: targetPreset, day: targetDay);
      return;
    }

    await api.updateSchedule(id, data);
    await loadSchedules();
  }

  Future<void> deleteSchedule(int id) async {
    if (isDemoMode) {
      final targetPreset = selectedPresetId ?? 1;
      final targetDay = selectedDay;
      if (_demoSchedules[targetPreset]?[targetDay] != null) {
        _demoSchedules[targetPreset]![targetDay]!.removeWhere((item) => item['id'] == id);
      }
      await loadSchedules(presetId: targetPreset, day: targetDay);
      return;
    }

    await api.deleteSchedule(id);
    await loadSchedules();
  }

  Future<int> copySchedules({
    required int presetId,
    required int sourceDay,
    required int targetDay,
  }) async {
    if (isDemoMode) {
      final sourceList = _demoSchedules[presetId]?[sourceDay] ?? [];
      if (sourceList.isEmpty) return 0;
      _demoSchedules[presetId] ??= {};
      _demoSchedules[presetId]![targetDay] = sourceList.map((item) {
        return {
          ...item,
          'id': ++_demoNextScheduleId,
          'day_of_week': targetDay,
        };
      }).toList();
      await loadSchedules(presetId: presetId, day: targetDay);
      return sourceList.length;
    }

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
    if (isDemoMode) {
      isLoadingSchedules = true;
      schedules = [];
      notifyListeners();
      _demoSchedules[presetId]?[day] = [];
      await loadSchedules(presetId: presetId, day: day);
      return;
    }

    try {
      isLoadingSchedules = true;
      schedules = [];
      notifyListeners();

      try {
        await api.clearDaySchedules(presetId, day);
      } catch (_) {
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
    if (isDemoMode) {
      isLoadingSchedules = true;
      selectedPresetId = presetId;
      activePresetId = presetId.toString();
      final found = presets.firstWhere((p) => p['id'] == presetId, orElse: () => null);
      if (found != null) {
        activePresetName = found['name'] ?? 'Preset Demo';
      }
      if (day != null) {
        selectedDay = day;
      }
      schedules = _demoSchedules[presetId]?[selectedDay] ?? [];
      isLoadingSchedules = false;
      _updateDemoCountdown();
      notifyListeners();
      return;
    }

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
    if (isDemoMode) {
      isLoadingSchedules = true;
      notifyListeners();
      final newId = ++_demoNextPresetId;
      final newPreset = {
        'id': newId,
        'name': name,
        'code': code ?? 'CUSTOM_$newId',
        'description': description ?? '',
        'is_active': 0,
      };
      presets.add(newPreset);
      _demoSchedules[newId] = {};

      if (copyFromPresetId != null && _demoSchedules[copyFromPresetId] != null) {
        for (final dayEntry in _demoSchedules[copyFromPresetId]!.entries) {
          _demoSchedules[newId]![dayEntry.key] = dayEntry.value.map((item) {
            return {
              ...item,
              'id': ++_demoNextScheduleId,
              'preset_id': newId,
            };
          }).toList();
        }
      }

      selectedPresetId = newId;
      selectedDay = 1;
      schedules = _demoSchedules[newId]?[1] ?? [];
      isLoadingSchedules = false;
      notifyListeners();
      return {'preset': newPreset};
    }

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
        try {
          await api.setActivePreset(newId);
          activePresetId = newId.toString();
          activePresetName = name;
        } catch (_) {}
        final schedRes = await api.getSchedules(presetId: newId, day: 1);
        schedules = schedRes;
        await refreshAll();
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
    if (isDemoMode) {
      isLoadingSchedules = true;
      notifyListeners();
      presets.removeWhere((p) => p['id'] == presetId);
      _demoSchedules.remove(presetId);
      if (selectedPresetId == presetId) {
        final fallbackId = presets.isNotEmpty ? (presets.first['id'] as int) : 1;
        selectedPresetId = fallbackId;
        selectedDay = 1;
        schedules = _demoSchedules[fallbackId]?[1] ?? [];
      }
      isLoadingSchedules = false;
      notifyListeners();
      return;
    }

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

  // ==========================================
  // AUDIO, TTS & MANUAL TRIGGERS
  // ==========================================
  Future<void> triggerManual(String title, {int? audioId}) async {
    if (isDemoMode) {
      isRelayOn = true;
      logs.insert(0, {
        'id': logs.length + 1,
        'triggered_at': '$currentDate $currentTime',
        'trigger_type': 'MANUAL_DEMO',
        'audio_title': title,
        'triggered_by_user': 'Admin TU (Demo)',
        'status': 'SUCCESS',
      });
      notifyListeners();

      // Putar suara bel lokal di perangkat saat demo
      SoundService().playDemoBell(audioId: audioId, title: title);

      Future.delayed(const Duration(seconds: 3), () {
        isRelayOn = false;
        notifyListeners();
      });
      return;
    }

    await api.triggerManualBell(title: title, audioId: audioId);
    await refreshAll();
  }

  Future<void> testAudio(int audioId) async {
    if (isDemoMode) {
      // Putar suara bel lokal di perangkat saat tes suara di Bank Suara
      SoundService().playDemoBell(audioId: audioId);
      return;
    }
    try {
      await api.testAudio(audioId);
    } catch (_) {}
  }

  Future<void> broadcastTTS(String text, {double? speed}) async {
    if (isDemoMode) {
      logs.insert(0, {
        'id': logs.length + 1,
        'triggered_at': '$currentDate $currentTime',
        'trigger_type': 'TTS_DEMO',
        'audio_title': 'Siaran Suara TTS: "$text"',
        'triggered_by_user': 'Admin TU (Demo)',
        'status': 'SUCCESS',
      });
      notifyListeners();

      // Langsung berbicara melalui Text-to-Speech lokal perangkat
      SoundService().speakDemoTTS(text, speed: speed ?? ttsSpeed);
      return;
    }

    await api.speakTTS(text, speed: speed ?? ttsSpeed);
    await refreshAll();
  }

  Future<void> loadAnnouncements() async {
    if (isDemoMode) return;
    try {
      announcements = await api.getAnnouncements();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> triggerAnnouncement(int id) async {
    if (isDemoMode) {
      final found = announcements.firstWhere((a) => a['id'] == id, orElse: () => null);
      if (found != null) {
        logs.insert(0, {
          'id': logs.length + 1,
          'triggered_at': '$currentDate $currentTime',
          'trigger_type': 'ANNOUNCEMENT_DEMO',
          'audio_title': found['title'] ?? 'Pengumuman TTS',
          'triggered_by_user': 'Admin TU (Demo)',
          'status': 'SUCCESS',
        });
        notifyListeners();

        // Putar chime + teks pengumuman bersuara
        SoundService().speakDemoTTS(found['tts_text'] ?? found['title'] ?? '', speed: ttsSpeed);
      }
      return;
    }

    await api.triggerAnnouncement(id);
    await refreshAll();
  }

  Future<void> createAnnouncement({
    required String title,
    required String ttsText,
    String language = 'id-ID',
    int? chimeAudioId,
  }) async {
    if (isDemoMode) {
      announcements.add({
        'id': ++_demoNextAnnouncementId,
        'title': title,
        'tts_text': ttsText,
        'language': language,
        'chime_audio_id': chimeAudioId,
      });
      notifyListeners();
      return;
    }

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
    if (isDemoMode) {
      for (int i = 0; i < announcements.length; i++) {
        if (announcements[i]['id'] == id) {
          announcements[i] = {
            'id': id,
            'title': title,
            'tts_text': ttsText,
            'language': language,
            'chime_audio_id': chimeAudioId,
          };
          break;
        }
      }
      notifyListeners();
      return;
    }

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
    if (isDemoMode) {
      announcements.removeWhere((a) => a['id'] == id);
      notifyListeners();
      return;
    }

    await api.deleteAnnouncement(id);
    await loadAnnouncements();
  }

  Future<void> setTtsSpeed(double speed) async {
    ttsSpeed = speed;
    notifyListeners();
    if (isDemoMode) return;
    try {
      final newSettings = Map<String, dynamic>.from(settings);
      newSettings['tts_speed'] = speed.toStringAsFixed(2);
      await api.saveSettings(newSettings.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {}
  }

  Future<void> saveSettings(Map<String, String> newSettings) async {
    settings = Map<String, dynamic>.from(newSettings);
    if (newSettings['school_name'] != null && newSettings['school_name']!.isNotEmpty) {
      schoolName = newSettings['school_name']!;
    }
    notifyListeners();
    if (isDemoMode) return;
    await api.saveSettings(newSettings);
  }

  // Feature getters
  bool get canCustomAudio => isDemoMode || (licenseInfo?['feat_custom_audio'] == true);
  bool get canRemoteMobile => isDemoMode || (licenseInfo?['feat_remote_mobile'] == true);
  int get featMaxDevices => isDemoMode ? 5 : ((licenseInfo?['feat_max_devices'] ?? licenseInfo?['max_devices'] as num?)?.toInt() ?? 1);
  int get maxDevices => featMaxDevices;

  // Network & Sessions
  Map<String, dynamic>? serverNetwork;
  List<dynamic> activeSessions = [];

  Future<void> loadAudioList() async {
    if (isDemoMode) return;
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
    if (isDemoMode) {
      audioList.add({
        'id': ++_demoNextAudioId,
        'title': title,
        'category': category,
        'duration': 15,
        'is_builtin': 0,
      });
      notifyListeners();
      return;
    }

    await api.uploadAudio(filePath: filePath, title: title, category: category);
    await loadAudioList();
  }

  Future<void> updateAudioFile(int id, {required String title, required String category}) async {
    if (isDemoMode) {
      for (int i = 0; i < audioList.length; i++) {
        if (audioList[i]['id'] == id) {
          audioList[i] = {
            ...audioList[i],
            'title': title,
            'category': category,
          };
          break;
        }
      }
      notifyListeners();
      return;
    }

    await api.updateAudio(id, title: title, category: category);
    await loadAudioList();
  }

  Future<void> deleteAudioFile(int id) async {
    if (isDemoMode) {
      audioList.removeWhere((a) => a['id'] == id);
      notifyListeners();
      return;
    }

    await api.deleteAudio(id);
    await loadAudioList();
  }

  Future<void> loadServerNetwork() async {
    if (isDemoMode) {
      serverNetwork = {
        'ips': ['192.168.1.100 (Demo Mode)'],
        'port': '8088',
        'pairing_url': 'bellpintar://pair?server=demo',
      };
      notifyListeners();
      return;
    }
    try {
      serverNetwork = await api.getServerNetwork();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadActiveSessions() async {
    if (isDemoMode) {
      activeSessions = [
        {
          'id': 1,
          'device_name': 'Android Tablet Demo Showcase',
          'ip_address': '127.0.0.1',
          'connected_at': '$currentDate 07:00:00',
          'is_current': true,
        },
      ];
      notifyListeners();
      return;
    }
    try {
      final res = await api.getSessions();
      activeSessions = res['sessions'] ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> revokeSession(int id) async {
    if (isDemoMode) {
      activeSessions.removeWhere((s) => s['id'] == id);
      notifyListeners();
      return;
    }
    await api.revokeSession(id);
    await loadActiveSessions();
  }

  Future<void> refreshMenuData(int index) async {
    if (isDemoMode) {
      _updateDemoCountdown();
      notifyListeners();
      return;
    }

    try {
      switch (index) {
        case 0:
          await refreshAll();
          break;
        case 1:
          presets = await api.getPresets();
          await loadSchedules();
          break;
        case 2:
          await loadAudioList();
          break;
        case 3:
          await loadAnnouncements();
          await loadAudioList();
          break;
        default:
          await refreshAll();
          break;
      }
    } catch (_) {}
  }

  StreamSubscription<Uri>? _subAppLinks;
  final AppLinks _appLinks = AppLinks();

  void _initDeepLinks() {
    try {
      _subAppLinks = _appLinks.uriLinkStream.listen((uri) {
        _handleDeepLinkUri(uri);
      });
      _appLinks.getInitialLink().then((uri) {
        if (uri != null) {
          _handleDeepLinkUri(uri);
        }
      });
    } catch (_) {}
  }

  void _handleDeepLinkUri(Uri uri) async {
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
    SoundService().stop();
    super.dispose();
  }
}
