import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../core/theme.dart';
import 'settings_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  bool _isBroadcasting = false;

  // Speech-to-Text
  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _baseTextBeforeVoice = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
            }
          }
        },
      );
      if (mounted) {
        setState(() => _speechEnabled = available);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _speechEnabled = false);
      }
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    // Cek apakah pengguna sudah pernah melihat notice penjelasan izin mikrofon & Bluetooth
    final prefs = await SharedPreferences.getInstance();
    final hasAgreed = prefs.getBool('mic_permission_notice_agreed') ?? false;

    if (!hasAgreed) {
      if (!mounted) return;
      final bool? proceed = await _showPermissionNoticeDialog(context);
      if (proceed != true) {
        return; // Pengguna membatalkan
      }
      await prefs.setBool('mic_permission_notice_agreed', true);
    }

    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (!_speechEnabled) {
      if (mounted) {
        _showPermissionDeniedDialog(context);
      }
      return;
    }

    _baseTextBeforeVoice = _textCtrl.text.trim();
    setState(() => _isListening = true);

    try {
      // Cari locale Bahasa Indonesia jika tersedia di perangkat
      final locales = await _speech.locales();
      String localeId = 'id_ID';
      final hasIndonesian = locales.any((l) => l.localeId.toLowerCase().startsWith('id'));
      if (!hasIndonesian && locales.isNotEmpty) {
        final sys = await _speech.systemLocale();
        localeId = sys?.localeId ?? locales.first.localeId;
      }

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              final recognized = result.recognizedWords;
              if (_baseTextBeforeVoice.isEmpty) {
                _textCtrl.text = recognized;
              } else {
                _textCtrl.text = '$_baseTextBeforeVoice $recognized';
              }
              // Posisikan kursor di akhir teks yang baru diketik otomatis
              _textCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _textCtrl.text.length),
              );
            });
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 4),
          localeId: localeId,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulai input suara: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  /// Dialog edukasi/notice izin mikrofon & bluetooth sebelum rekaman pertama kali
  Future<bool?> _showPermissionNoticeDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
              child: Icon(Icons.mic_rounded, color: AppTheme.primaryCyan, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Izin Mikrofon & Audio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fitur Dikte Suara (Speech-to-Text) memerlukan izin akses Mikrofon & Bluetooth agar ucapan Anda dapat diubah langsung menjadi teks pengumuman secara otomatis.',
                style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.25)),
                ),
                child: const Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security_rounded, color: AppTheme.primaryCyan, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Privasi Anda Terjaga: Suara hanya direkam saat tombol dikte ditekan, langsung diproses di perangkat, dan tidak pernah disimpan atau dibagikan.',
                            style: TextStyle(fontSize: 11.5, color: Colors.white, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.bluetooth_audio_rounded, color: AppTheme.primaryCyan, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dukungan Bluetooth: Digunakan untuk mendeteksi headset nirkabel atau mikrofon Bluetooth jika Anda menggunakannya.',
                            style: TextStyle(fontSize: 11.5, color: Colors.white, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Lanjutkan & Berikan Izin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog peringatan jika izin mikrofon ditolak oleh sistem Android
  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.mic_off_rounded, color: AppTheme.errorRed),
            SizedBox(width: 10),
            Text('Izin Mikrofon Diperlukan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Aplikasi belum dapat mendengarkan suara Anda karena izin akses mikrofon belum diizinkan pada perangkat ini.\n\nSilakan izinkan akses mikrofon untuk Bell Pintar melalui menu Pengaturan Aplikasi (Settings) di HP Anda.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti', style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _sendBroadcast(String text) async {
    if (text.trim().isEmpty) return;
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }

    setState(() => _isBroadcasting = true);
    try {
      await appState.broadcastTTS(text);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Pengumuman suara AI berhasil disiarkan ke speaker sekolah!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _textCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  Future<void> _triggerQuickAnnouncement(int id, String title) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.triggerAnnouncement(id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Pengumuman "$title" berhasil disiarkan!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal menyiarkan: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _showAnnouncementDialog({Map<String, dynamic>? item}) async {
    final messenger = ScaffoldMessenger.of(context);
    final isEdit = item != null;
    final titleCtrl = TextEditingController(text: item?['title'] ?? '');
    final ttsCtrl = TextEditingController(text: item?['tts_text'] ?? '');
    String selectedLang = item?['language'] ?? 'id-ID';

    int? selectedChimeId;
    if (item?['chime_audio_id'] != null) {
      selectedChimeId = (item!['chime_audio_id'] as num).toInt();
    }

    bool isSubmitting = false;
    String errorMessage = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final state = context.watch<AppState>();

          final hasChimeMatch = selectedChimeId == null ||
              state.audioList.any((a) => a['id'] == selectedChimeId);
          if (!hasChimeMatch) {
            selectedChimeId = null;
          }

          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.15),
                  radius: 18,
                  child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                    color: AppTheme.primaryCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Template Pengumuman' : 'Tambah Template Pengumuman',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Judul Template
                    const Text(
                      'Judul Template',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Pemanggilan Siswa Piket',
                        prefixIcon: Icon(Icons.title_rounded, color: AppTheme.primaryCyan, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Naskah Pengumuman TTS
                    const Text(
                      'Naskah Teks Pengumuman (TTS)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ttsCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tuliskan teks yang akan diucapkan oleh suara AI secara jelas...',
                        suffixIcon: ttsCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                                onPressed: () {
                                  setModalState(() {
                                    ttsCtrl.clear();
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nada Chime Pembuka
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nada Pembuka / Chime Bel',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        if (selectedChimeId != null)
                          OutlinedButton.icon(
                            onPressed: () => state.testAudio(selectedChimeId!),
                            icon: const Icon(Icons.volume_up, size: 13),
                            label: const Text('Tes Nada', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryCyan,
                              side: const BorderSide(color: AppTheme.primaryCyan),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedChimeId,
                      dropdownColor: AppTheme.surfaceDark,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.music_note_rounded, color: AppTheme.primaryCyan, size: 18),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            '(Tanpa Chime / Langsung Suara AI)',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        ...state.audioList.map<DropdownMenuItem<int?>>((a) {
                          return DropdownMenuItem<int?>(
                            value: a['id'],
                            child: Text(
                              a['title'] ?? 'Audio #${a['id']}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          selectedChimeId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bahasa
                    const Text(
                      'Bahasa Pelafalan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedLang,
                      dropdownColor: AppTheme.surfaceDark,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.language_rounded, color: AppTheme.primaryCyan, size: 18),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'id-ID',
                          child: Text('Bahasa Indonesia (id-ID)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'en-US',
                          child: Text('Bahasa Inggris (en-US)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedLang = val;
                          });
                        }
                      },
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
                        final title = titleCtrl.text.trim();
                        final text = ttsCtrl.text.trim();

                        if (title.isEmpty) {
                          setModalState(() => errorMessage = 'Judul template harus diisi.');
                          return;
                        }
                        if (text.isEmpty) {
                          setModalState(() => errorMessage = 'Naskah teks pengumuman harus diisi.');
                          return;
                        }

                        setModalState(() {
                          isSubmitting = true;
                          errorMessage = '';
                        });

                        try {
                          if (isEdit) {
                            await state.updateAnnouncement(
                              id: item['id'],
                              title: title,
                              ttsText: text,
                              language: selectedLang,
                              chimeAudioId: selectedChimeId,
                            );
                          } else {
                            await state.createAnnouncement(
                              title: title,
                              ttsText: text,
                              language: selectedLang,
                              chimeAudioId: selectedChimeId,
                            );
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }

                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Template "$title" berhasil diperbarui.'
                                      : 'Template "$title" berhasil ditambahkan.',
                                ),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isSubmitting = false;
                            errorMessage = 'Gagal menyimpan: $e';
                          });
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(isSubmitting ? 'Menyimpan...' : (isEdit ? 'Simpan Perubahan' : 'Tambah Template')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteAnnouncementDialog(Map<String, dynamic> item) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final title = item['title'] ?? 'Template';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed, size: 22),
            SizedBox(width: 10),
            Text('Hapus Template?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus template pengumuman "$title"? Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Hapus'),
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

    if (confirmed == true) {
      try {
        await state.deleteAnnouncement(item['id']);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Template "$title" berhasil dihapus.'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio Pengumuman (TTS)'),
        backgroundColor: Colors.transparent,
        actions: [
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final padding = isMobile ? 16.0 : 24.0;

          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              // Live TTS Input Card
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isListening ? AppTheme.primaryCyan : const Color(0xFF334155),
                    width: _isListening ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _isListening
                              ? AppTheme.errorRed.withValues(alpha: 0.2)
                              : AppTheme.primaryCyan.withValues(alpha: 0.2),
                          radius: 18,
                          child: Icon(
                            _isListening ? Icons.mic : Icons.record_voice_over,
                            color: _isListening ? AppTheme.errorRed : AppTheme.primaryCyan,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Siaran Langsung Text-to-Speech',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Ketik pesan atau tekan tombol mikrofon untuk mendiktekan suara otomatis',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Text Field Form Input
                    TextField(
                      controller: _textCtrl,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Perhatian kepada seluruh ketua kelas untuk segera menuju ruang piket...',
                        suffixIcon: _textCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                                tooltip: 'Hapus Teks',
                                onPressed: () {
                                  _textCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Voice Input Toolbar (Fitur Dikte Suara ke Teks)
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Tombol Rekam Suara (Speech to Text)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return ElevatedButton.icon(
                              onPressed: _toggleListening,
                              icon: Icon(
                                _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                                size: 18,
                                color: _isListening ? Colors.white : AppTheme.primaryCyan,
                              ),
                              label: Text(
                                _isListening ? 'Selesai Bicara' : 'Dikte Lewat Suara',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isListening ? Colors.white : AppTheme.primaryCyan,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isListening
                                    ? AppTheme.errorRed.withValues(alpha: 0.85 + 0.15 * _pulseController.value)
                                    : AppTheme.primaryCyan.withValues(alpha: 0.15),
                                foregroundColor: _isListening ? Colors.white : AppTheme.primaryCyan,
                                side: BorderSide(
                                  color: _isListening ? AppTheme.errorRed : AppTheme.primaryCyan,
                                  width: _isListening ? 1.5 : 1.0,
                                ),
                                elevation: _isListening ? 4 : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            );
                          },
                        ),

                        // Indikator Status Suara
                        if (_isListening)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.graphic_eq_rounded, color: AppTheme.errorRed, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Silakan bicara, teks otomatis terketik...',
                                  style: TextStyle(color: AppTheme.errorRed, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        else
                          const Text(
                            'Ketuk tombol di atas lalu ucapkan pengumuman',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Speed Control Slider Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.speed_rounded, color: AppTheme.primaryCyan, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Tempo Suara (Microsoft Andika)',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${state.ttsSpeed.toStringAsFixed(1)}x ${state.ttsSpeed == 1.0 ? "(Normal)" : state.ttsSpeed < 1.0 ? "(Santai)" : "(Cepat)"}',
                                  style: const TextStyle(color: AppTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  ),
                                  child: Slider(
                                    value: state.ttsSpeed.clamp(0.6, 1.5),
                                    min: 0.6,
                                    max: 1.5,
                                    divisions: 9,
                                    activeColor: AppTheme.primaryCyan,
                                    inactiveColor: Colors.white12,
                                    onChanged: (val) => state.setTtsSpeed(val),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _isBroadcasting ? null : () => state.broadcastTTS("Uji tempo suara pengumuman."),
                                icon: const Icon(Icons.volume_up, size: 14),
                                label: const Text('Tes', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryCyan,
                                  side: const BorderSide(color: AppTheme.primaryCyan),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol Siarkan Sekarang
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBroadcasting || _textCtrl.text.trim().isEmpty
                            ? null
                            : () => _sendBroadcast(_textCtrl.text),
                        icon: _isBroadcasting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.volume_up_rounded),
                        label: Text(_isBroadcasting ? 'Menyiarkan Suara...' : 'Siarkan Pengumuman Sekarang'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.primaryCyan,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Quick Announcement Templates Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TEMPLATE PENGUMUMAN CEPAT',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppTheme.textMuted),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAnnouncementDialog(),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(isMobile ? 'Tambah' : 'Tambah Template', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.announcements.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.campaign_outlined, size: 40, color: AppTheme.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'Belum ada template pengumuman',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Buat template pengumuman agar dapat disiarkan sewaktu-waktu dengan 1 klik.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _showAnnouncementDialog(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Buat Template Pertama'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...state.announcements.map((a) {
                  final text = a['tts_text'] ?? '';
                  final chimeId = a['chime_audio_id'];
                  Map<String, dynamic>? chimeAudio;
                  if (chimeId != null) {
                    for (final item in state.audioList) {
                      if (item is Map<String, dynamic> && item['id'] == chimeId) {
                        chimeAudio = item;
                        break;
                      }
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.accentGold.withValues(alpha: 0.15),
                          child: const Icon(Icons.campaign, color: AppTheme.accentGold, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _textCtrl.text = text;
                                _textCtrl.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _textCtrl.text.length),
                                );
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  text,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (chimeAudio != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.music_note_rounded, size: 12, color: AppTheme.primaryCyan),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Chime: ${chimeAudio['title']}',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.primaryCyan),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cardDarkElevated,
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 8),
                          ),
                          onPressed: () => _triggerQuickAnnouncement(a['id'], a['title'] ?? ''),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: Text(isMobile ? 'Siarkan' : 'Siarkan Sekarang', style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                          tooltip: 'Edit Template',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          onPressed: () => _showAnnouncementDialog(item: a),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorRed.withValues(alpha: 0.85)),
                          tooltip: 'Hapus Template',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          onPressed: () => _showDeleteAnnouncementDialog(a),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
