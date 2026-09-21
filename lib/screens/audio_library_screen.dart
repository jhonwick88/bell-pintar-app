import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../core/theme.dart';
import 'settings_screen.dart';

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  String _selectedFilter = 'Semua'; // 'Semua', 'Bawaan', 'Custom'
  String _searchQuery = '';
  int? _currentlyTestingId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canUpload = state.canCustomAudio;

    // Filter audio list
    final filteredAudios = state.audioList.where((item) {
      final isBuiltin = item['is_builtin'] == true;
      if (_selectedFilter == 'Bawaan' && !isBuiltin) return false;
      if (_selectedFilter == 'Custom' && isBuiltin) return false;

      final title = (item['title'] ?? '').toString().toLowerCase();
      final category = (item['category'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();
      if (q.isNotEmpty && !title.contains(q) && !category.contains(q)) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Suara & Bel'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () => state.loadAudioList(),
          ),
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

          return Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // License Alert if custom audio is disabled
                if (!canUpload)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.accentGold, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fitur Upload Nada Custom Terkunci',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGold, fontSize: 13),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Lisensi sekolah saat ini hanya mendukung nada bel bawaan sistem. Hubungi administrator/penyedia untuk mengaktifkan lisensi custom audio.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Upload Button Banner for quick access
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.audio_file_rounded, color: AppTheme.primaryCyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Koleksi Nada Bel',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            Text(
                              '${state.audioList.length} nada tersimpan di server',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showUploadDialog(context, state),
                        icon: Icon(canUpload ? Icons.upload_rounded : Icons.lock_outline_rounded, size: 18),
                        label: Text(isMobile ? 'Upload' : 'Upload Nada Baru'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canUpload ? AppTheme.primaryCyan : Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari nama bel atau kategori...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    fillColor: AppTheme.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),

                // Filter Chips (Horizontally scrollable to eliminate right-overflow)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua', 'Semua (${state.audioList.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Bawaan', 'Bawaan Sistem'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Custom', 'Koleksi Custom'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Audio Cards List (Spacious & Legible)
                Expanded(
                  child: filteredAudios.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.music_off_rounded, size: 54, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text('Tidak ada audio yang cocok', style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                              if (_selectedFilter == 'Custom' && canUpload) ...[
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: () => _showUploadDialog(context, state),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Upload Nada Pertama'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredAudios.length,
                          itemBuilder: (context, index) {
                            final item = filteredAudios[index];
                            final id = item['id'] as int;
                            final title = item['title'] ?? 'Tanpa Nama';
                            final category = item['category'] ?? 'Umum';
                            final isBuiltin = item['is_builtin'] == true;
                            final isPlaying = _currentlyTestingId == id;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDark,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPlaying ? AppTheme.primaryCyan : const Color(0xFF334155),
                                  width: isPlaying ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top: Avatar + Full width Title & Badges
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isPlaying
                                              ? AppTheme.primaryCyan.withValues(alpha: 0.25)
                                              : (isBuiltin
                                                  ? AppTheme.primaryTeal.withValues(alpha: 0.15)
                                                  : AppTheme.accentGold.withValues(alpha: 0.15)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                                          color: isPlaying
                                              ? AppTheme.primaryCyan
                                              : (isBuiltin ? AppTheme.primaryTeal : AppTheme.accentGold),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.white,
                                                height: 1.25,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: isBuiltin
                                                        ? Colors.blueGrey.withValues(alpha: 0.25)
                                                        : AppTheme.accentGold.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isBuiltin ? 'Bawaan Sistem' : 'Custom Guru',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isBuiltin ? Colors.white70 : AppTheme.accentGold,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF1E293B),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    category,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Color(0xFF1E293B)),
                                  const SizedBox(height: 10),

                                  // Bottom: Action Bar
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: isPlaying
                                            ? null
                                            : () async {
                                                setState(() => _currentlyTestingId = id);
                                                await state.testAudio(id);
                                                await Future.delayed(const Duration(seconds: 3));
                                                if (mounted) setState(() => _currentlyTestingId = null);
                                              },
                                        icon: Icon(
                                          isPlaying ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                                          size: 18,
                                        ),
                                        label: Text(isPlaying ? 'Memutar di Speaker...' : 'Coba Suara'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isPlaying ? AppTheme.primaryCyan : AppTheme.surfaceDark,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          side: const BorderSide(color: Color(0xFF334155)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (!isBuiltin) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryCyan, size: 20),
                                          tooltip: 'Ubah Judul / Kategori',
                                          onPressed: () => _showEditDialog(context, state, item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
                                          tooltip: 'Hapus Nada',
                                          onPressed: () => _confirmDelete(context, state, id, title),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      selectedColor: AppTheme.primaryCyan,
      backgroundColor: AppTheme.cardDark,
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: isSelected ? Colors.white : AppTheme.textMuted,
      ),
    );
  }

  void _showUploadDialog(BuildContext context, AppState state) {
    if (!state.canCustomAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitur upload audio custom terkunci oleh lisensi (feat_custom_audio).'),
          backgroundColor: AppTheme.accentGold,
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    String category = 'Custom Guru';
    String? selectedFilePath;
    String? selectedFileName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: const Row(
              children: [
                Icon(Icons.cloud_upload_rounded, color: AppTheme.primaryCyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload Nada Suara Baru',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File Picker Box
                    InkWell(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
                        );
                        if (result != null && result.files.single.path != null) {
                          setModalState(() {
                            selectedFilePath = result.files.single.path!;
                            selectedFileName = result.files.single.name;
                            if (titleCtrl.text.isEmpty) {
                              final nameWithoutExt = selectedFileName!.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                              titleCtrl.text = nameWithoutExt;
                            }
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedFilePath != null ? AppTheme.primaryCyan : const Color(0xFF334155),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              selectedFilePath != null ? Icons.check_circle_rounded : Icons.audio_file_rounded,
                              size: 40,
                              color: selectedFilePath != null ? AppTheme.successGreen : AppTheme.primaryCyan,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedFileName ?? 'Klik untuk memilih file audio',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selectedFileName != null ? Colors.white : AppTheme.primaryCyan,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Format yang didukung: MP3, WAV, OGG, M4A',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    const Text('Judul / Nama Nada', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(hintText: 'Contoh: Mars SMAN 1, Doa Pagi'),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    const Text('Kategori Nada', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor: AppTheme.surfaceDark,
                      items: const [
                        DropdownMenuItem(value: 'Custom Guru', child: Text('Custom Guru')),
                        DropdownMenuItem(value: 'Bel & Chime', child: Text('Bel & Chime')),
                        DropdownMenuItem(value: 'Lagu Nasional / Sekolah', child: Text('Lagu Nasional / Sekolah')),
                        DropdownMenuItem(value: 'Doa & Religi', child: Text('Doa & Religi')),
                        DropdownMenuItem(value: 'Pengumuman', child: Text('Pengumuman')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => category = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: (selectedFilePath == null || titleCtrl.text.trim().isEmpty || isUploading)
                    ? null
                    : () async {
                        setModalState(() => isUploading = true);
                        try {
                          await state.uploadAudioFile(
                            filePath: selectedFilePath!,
                            title: titleCtrl.text.trim(),
                            category: category,
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Audio custom berhasil diunggah!'), backgroundColor: AppTheme.successGreen),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isUploading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal upload: $e'), backgroundColor: AppTheme.errorRed),
                            );
                          }
                        }
                      },
                child: isUploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan & Upload'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, AppState state, Map<String, dynamic> item) {
    final titleCtrl = TextEditingController(text: item['title'] ?? '');
    String category = item['category'] ?? 'Custom Guru';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Ubah Info Nada Suara'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Nama Nada'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                dropdownColor: AppTheme.surfaceDark,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(value: 'Custom Guru', child: Text('Custom Guru')),
                  DropdownMenuItem(value: 'Bel & Chime', child: Text('Bel & Chime')),
                  DropdownMenuItem(value: 'Lagu Nasional / Sekolah', child: Text('Lagu Nasional / Sekolah')),
                  DropdownMenuItem(value: 'Doa & Religi', child: Text('Doa & Religi')),
                  DropdownMenuItem(value: 'Pengumuman', child: Text('Pengumuman')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final id = item['id'] as int;
                await state.updateAudioFile(id, title: titleCtrl.text.trim(), category: category);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, int id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
            SizedBox(width: 8),
            Expanded(child: Text('Hapus Nada Suara?')),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus nada "$title"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await state.deleteAudioFile(id);
                nav.pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Nada "$title" berhasil dihapus'), backgroundColor: AppTheme.successGreen),
                  );
                }
              } catch (e) {
                nav.pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed, duration: const Duration(seconds: 4)),
                  );
                }
              }
            },
            child: const Text('Hapus Sekarang'),
          ),
        ],
      ),
    );
  }
}
