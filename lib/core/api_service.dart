import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String baseUrl = 'http://localhost:8088/api/v1';
  late Dio _dio;
  String? _token;
  String deviceId = 'unknown-device';
  String deviceName = 'Windows PC';
  String platform = 'windows';

  ApiService() {
    _initDevice();

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        options.headers['X-Device-Id'] = deviceId;
        options.headers['X-Device-Name'] = deviceName;
        options.headers['X-Device-Platform'] = platform;
        return handler.next(options);
      },
    ));
  }

  Future<void> _initDevice() async {
    try {
      if (Platform.isAndroid) {
        platform = 'android';
        deviceName = 'HP Android Guru Piket';
      } else if (Platform.isIOS) {
        platform = 'ios';
        deviceName = 'iPhone Guru';
      } else if (Platform.isWindows) {
        platform = 'windows';
        deviceName = Platform.localHostname.isNotEmpty ? 'PC ${Platform.localHostname}' : 'Server Bel Windows';
      } else {
        platform = 'linux';
        deviceName = 'Terminal Linux';
      }

      final prefs = await SharedPreferences.getInstance();
      var savedId = prefs.getString('device_unique_id');
      if (savedId == null || savedId.isEmpty) {
        savedId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${Platform.operatingSystem}';
        await prefs.setString('device_unique_id', savedId);
      }
      deviceId = savedId;
    } catch (_) {}
  }

  Future<void> ensureDeviceInitialized() async {
    if (deviceId == 'unknown-device') {
      await _initDevice();
    }
  }

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  void setToken(String? token) {
    _token = token;
  }

  Future<Map<String, dynamic>> ping() async {
    await ensureDeviceInitialized();
    final res = await _dio.get('/ping');
    return res.data;
  }

  Future<Map<String, dynamic>> loginPIN(String pin) async {
    await ensureDeviceInitialized();
    final res = await _dio.post('/auth/login-pin', data: {
      'pin': pin,
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
    });
    return res.data;
  }

  Future<void> logout() async {
    try {
      await ensureDeviceInitialized();
      await _dio.post('/auth/logout');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getDashboardStatus() async {
    final res = await _dio.get('/dashboard/status');
    return res.data;
  }

  Future<List<dynamic>> getPresets() async {
    final res = await _dio.get('/presets');
    return res.data;
  }

  Future<void> setActivePreset(int presetId) async {
    await _dio.post('/presets/active', data: {'preset_id': presetId});
  }

  Future<Map<String, dynamic>> createPreset({
    required String name,
    String? code,
    String? description,
    int? copyFromPresetId,
  }) async {
    final res = await _dio.post('/presets', data: {
      'name': name,
      if (code != null && code.isNotEmpty) 'code': code,
      if (description != null && description.isNotEmpty) 'description': description,
      if (copyFromPresetId != null && copyFromPresetId > 0) 'copy_from_preset_id': copyFromPresetId,
    });
    return res.data;
  }

  Future<void> deletePreset(int presetId) async {
    await _dio.delete('/presets/$presetId');
  }

  Future<List<dynamic>> getSchedules({int? presetId, int? day}) async {
    final query = <String, dynamic>{};
    if (presetId != null) query['preset_id'] = presetId;
    if (day != null) query['day'] = day;
    final res = await _dio.get('/schedules', queryParameters: query);
    if (res.data == null || res.data is! List) {
      return [];
    }
    return res.data as List<dynamic>;
  }

  Future<void> clearDaySchedules(int presetId, int day) async {
    await _dio.delete('/schedules/clear-day', queryParameters: {
      'preset_id': presetId,
      'day': day,
    });
  }

  Future<void> createSchedule(Map<String, dynamic> data) async {
    await _dio.post('/schedules', data: data);
  }

  Future<void> updateSchedule(int id, Map<String, dynamic> data) async {
    await _dio.put('/schedules/$id', data: data);
  }

  Future<void> deleteSchedule(int id) async {
    await _dio.delete('/schedules/$id');
  }

  Future<List<dynamic>> getAudioList() async {
    final res = await _dio.get('/audio');
    return res.data;
  }

  Future<void> testAudio(int audioId) async {
    await _dio.post('/audio/test', data: {'audio_id': audioId});
  }

  Future<void> triggerManualBell({int? audioId, required String title, String? filePath}) async {
    await _dio.post('/bell/trigger', data: {
      'audio_id': audioId,
      'title': title,
      'file_path': filePath ?? '',
    });
  }

  Future<void> speakTTS(String text, {String? chimePath, double? speed}) async {
    final body = <String, dynamic>{
      'text': text,
      'chime_audio_path': chimePath ?? '',
    };
    if (speed != null) {
      body['speed'] = speed;
    }
    await _dio.post('/tts/speak', data: body);
  }

  Future<List<dynamic>> getAnnouncements() async {
    final res = await _dio.get('/announcements');
    return res.data;
  }

  Future<void> createAnnouncement({
    required String title,
    required String ttsText,
    String language = 'id-ID',
    int? chimeAudioId,
  }) async {
    final body = {
      'title': title,
      'tts_text': ttsText,
      'language': language,
      'chime_audio_id': chimeAudioId,
    };
    await _dio.post('/announcements', data: body);
  }

  Future<void> updateAnnouncement({
    required int id,
    required String title,
    required String ttsText,
    String language = 'id-ID',
    int? chimeAudioId,
  }) async {
    final body = {
      'title': title,
      'tts_text': ttsText,
      'language': language,
      'chime_audio_id': chimeAudioId,
    };
    await _dio.put('/announcements/$id', data: body);
  }

  Future<void> deleteAnnouncement(int id) async {
    await _dio.delete('/announcements/$id');
  }

  Future<void> triggerAnnouncement(int id) async {
    await _dio.post('/announcements/trigger/$id');
  }

  Future<List<dynamic>> getLogs() async {
    final res = await _dio.get('/logs');
    return res.data;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final res = await _dio.get('/settings');
    return res.data;
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _dio.post('/settings', data: settings);
  }

  Future<void> testRelay(bool powerOn) async {
    await _dio.post('/relay/test', data: {'power_on': powerOn});
  }

  Future<Map<String, dynamic>> getLicenseStatus() async {
    final res = await _dio.get('/license/status');
    return res.data;
  }

  Future<Map<String, dynamic>> activateLicense(String licenseKey, [String? schoolName, String? serverUrl]) async {
    final res = await _dio.post('/license/activate', data: {
      'license_key': licenseKey,
      'school_name': schoolName ?? '',
      'server_url': serverUrl ?? '',
    });
    return res.data;
  }

  Future<Map<String, dynamic>> uploadAudio({
    required String filePath,
    required String title,
    required String category,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      'category': category,
      'audio_file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/audio/upload', data: formData);
    return res.data;
  }

  Future<void> updateAudio(int id, {required String title, required String category}) async {
    await _dio.put('/audio/$id', data: {
      'title': title,
      'category': category,
    });
  }

  Future<void> deleteAudio(int id) async {
    await _dio.delete('/audio/$id');
  }

  Future<Map<String, dynamic>> getServerNetwork() async {
    final res = await _dio.get('/server/network');
    return res.data;
  }

  Future<Map<String, dynamic>> getSessions() async {
    final res = await _dio.get('/sessions');
    return res.data;
  }

  Future<void> revokeSession(int id) async {
    await _dio.delete('/sessions/$id');
  }
}
