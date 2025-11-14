// Enhanced Audio Note page with beautiful UI and AI features
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:google_speech/google_speech.dart';
import 'package:google_fonts/google_fonts.dart';

import '../languages/languages.dart';
import '../features/storage/store.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../my components/live_waveform.dart';
import '../themes/colors.dart';
import 'note_detail_page.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with TickerProviderStateMixin {
  // audio IO
  final _rec = RecorderStream();
  final _player = PlayerStream();
  late StreamSubscription _recStat, _playStat, _micSub;
  final List<Uint8List> _buffer = [];
  bool _recOn = false, _playOn = false;
  bool _isPaused = false;

  // live level for waveform
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  double _prevLevel = 0;
  late AnimationController _pulseController;

  // speech-to-text
  SpeechToText? _stt;
  StreamController<List<int>>? _sttIn;
  StreamSubscription? _sttSub;
  bool _recognizing = false;

  // transcript model
  String _committed = '';
  String _interim = '';
  String _lastFinal = '';
  final _textCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  final _titleCtl = TextEditingController();

  // language picker
  Lang _selectedLang = kSpeechLangs.firstWhere(
    (l) => l.code == 'en-US',
    orElse: () => kSpeechLangs.first,
  );

  // Recording duration
  Duration _duration = Duration.zero;
  Duration _pausedDuration = Duration.zero; // Track paused time
  Timer? _durationTimer;

  // AI features
  bool _showAIOptions = false;
  String? _aiSummary;
  String? _aiTranslation;
  List<String>? _importantPoints;

  static const _rate = 16000;
  static const _keyAssetPath = 'lib/assets/keys/stt_service_account.json';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _initAudio();
    _initSTT();
  }

  @override
  void dispose() {
    _sttSub?.cancel();
    _sttIn?.close();
    _micSub.cancel();
    _recStat.cancel();
    _playStat.cancel();
    _durationTimer?.cancel();
    _rec.stop();
    _player.stop();
    _textCtl.dispose();
    _scrollCtl.dispose();
    _titleCtl.dispose();
    _level.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    await Permission.microphone.request();

    _recStat = _rec.status.listen((s) {
      final on = s == SoundStreamStatus.Playing;
      setState(() => _recOn = on);
      if (!on) {
        _prevLevel = 0;
        _level.value = 0.0;
        _durationTimer?.cancel();
        _pulseController.stop();
      } else {
        _startDurationTimer();
        _pulseController.repeat(reverse: true);
      }
    });

    _playStat = _player.status.listen((s) {
      setState(() => _playOn = s == SoundStreamStatus.Playing);
    });

    // mic bytes -> buffer, STT stream, and waveform level
    _micSub = _rec.audioStream.listen((bytes) {
      _buffer.add(bytes);
      _sttIn?.add(bytes);
      if (_playOn) _player.writeChunk(bytes);

      // ---- mic level (dBFS -> 0..1) ----
      final n = bytes.length & ~1;
      if (n > 0) {
        double sum = 0;
        for (int i = 0; i < n; i += 2) {
          int s = (bytes[i] & 0xff) | ((bytes[i + 1] & 0xff) << 8);
          if (s >= 0x8000) s -= 0x10000;
          final v = s / 32768.0;
          sum += v * v;
        }
        final rms = math.sqrt(sum / (n ~/ 2));
        final db = 20 * math.log(rms + 1e-9) / math.ln10;
        final norm = ((db + 60) / 60).clamp(0.0, 1.0);
        final smoothed = 0.85 * _prevLevel + 0.15 * norm;
        _prevLevel = smoothed;
        _level.value = smoothed;
      }
    });

    await _rec.initialize(sampleRate: _rate);
    await _player.initialize(sampleRate: _rate);
  }

  Future<void> _initSTT() async {
    try {
      await rootBundle.load(_keyAssetPath);
      final json = await rootBundle.loadString(_keyAssetPath);
      _stt = SpeechToText.viaServiceAccount(ServiceAccount.fromString(json));
    } catch (_) {
      _stt = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech key not found'),
            backgroundColor: AppColors.error,
          ),
        );
      });
    }
  }

  void _startDurationTimer() {
    // Continue from paused duration if resuming
    final startSeconds = _pausedDuration.inSeconds;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = Duration(seconds: startSeconds + timer.tick);
        });
      }
    });
  }

  Future<void> _start() async {
    if (_recOn) return;
    if (!(await Permission.microphone.request()).isGranted) return;
    if (_stt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech key not loaded'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Only reset if starting fresh (not resuming)
    if (!_isPaused) {
      _interim = '';
      _lastFinal = '';
      _committed = '';
      _pausedDuration = Duration.zero;
      _duration = Duration.zero;
      _updateTextField();
    }
    
    setState(() {
      _recognizing = true;
      _showAIOptions = false;
      if (!_isPaused) {
        _aiSummary = null;
        _aiTranslation = null;
        _importantPoints = null;
      }
    });

    // Create new stream if not resuming (paused state means stream still exists)
    if (_sttIn == null || _sttIn!.isClosed) {
      _sttIn = StreamController<List<int>>();
      
      final cfg = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        sampleRateHertz: _rate,
        languageCode: _selectedLang.code,
        enableAutomaticPunctuation: true,
        maxAlternatives: 1,
        model: RecognitionModel.video,
        useEnhanced: true,
      );

      final responses = _stt!.streamingRecognize(
        StreamingRecognitionConfig(
          config: cfg,
          interimResults: true,
          singleUtterance: false,
        ),
        _sttIn!.stream,
      );

      // Set up listener
      _sttSub?.cancel();
      _sttSub = responses.listen((resp) {
        for (final r in resp.results) {
          final t = r.alternatives.first.transcript;
          if (r.isFinal) {
            String toAdd;
            if (_lastFinal.isNotEmpty && t.startsWith(_lastFinal)) {
              toAdd = t.substring(_lastFinal.length).trimLeft();
            } else {
              toAdd = t.trimLeft();
              if (_committed.isNotEmpty && !_committed.endsWith(' ')) {
                _committed += ' ';
              }
            }
            if (toAdd.isNotEmpty) {
              _committed += toAdd;
              if (!_committed.endsWith(' ')) _committed += ' ';
            }
            _lastFinal = t;
            _interim = '';
          } else {
            _interim = t;
          }
        }
        // Update immediately for real-time feel
        if (mounted) {
          _updateTextField();
        }
      }, onError: (_) {
        if (mounted) {
          setState(() => _recognizing = false);
        }
      }, onDone: () {
        if (mounted) {
          setState(() => _recognizing = false);
        }
      });
    }

    await _rec.start();
  }

  Future<void> _stop() async {
    if (_recOn) await _rec.stop();
    if (_isPaused) {
      // If paused, just stop and allow save
      setState(() {
        _isPaused = false;
        _recognizing = false;
        _recOn = false;
      });
    } else {
      // If recording, close STT stream
      await _sttIn?.close();
      _sttIn = null;
      await _sttSub?.cancel();
      _sttSub = null;
    }
    _lastFinal = '';
    _prevLevel = 0;
    _level.value = 0.0;
    _durationTimer?.cancel();
    _pulseController.stop();
    setState(() {
      _recognizing = false;
      _recOn = false;
    });
    
    // Auto-save and navigate if there's content
    if (_committed.trim().isNotEmpty) {
      await _saveNote();
    }
  }

  void _updateTextField() {
    if (!mounted) return;
    final full = '$_committed$_interim';
    // Always update for real-time streaming effect
    _textCtl.text = full;
    _textCtl.selection =
        TextSelection.fromPosition(TextPosition(offset: _textCtl.text.length));
    
    // Smooth auto-scroll to bottom for real-time note-taking feel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients && _scrollCtl.position.maxScrollExtent > 0) {
        _scrollCtl.animateTo(
          _scrollCtl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pause() async {
    if (!_recOn || _isPaused) return;
    await _rec.stop();
    // Save current duration
    _pausedDuration = _duration;
    setState(() {
      _isPaused = true;
      _recognizing = false;
      _durationTimer?.cancel();
      _pulseController.stop();
      _level.value = 0.0;
    });
  }

  Future<void> _resume() async {
    if (!_isPaused) return;
    // Don't reset STT stream - continue from where we left off
    await _rec.start();
    setState(() {
      _isPaused = false;
      _recognizing = true;
      _startDurationTimer(); // Continue from paused duration
      _pulseController.repeat(reverse: true);
    });
  }

  Future<void> _saveNote() async {
    if (_committed.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transcript to save'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show subject selection dialog with note name
    final result = await _showSubjectSelectionDialog();
    if (result == null) return; // User cancelled

    final noteName = result['noteName'] as String?;
    final selectedSubject = result['subjectId'] as String?;
    final comments = _titleCtl.text.trim(); // Comments from the text field

    final title = noteName?.isNotEmpty == true
        ? noteName!
        : 'Note ${DateTime.now().toString().substring(0, 16)}';

    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      transcript: _committed.trim(),
      subject: selectedSubject,
      comments: comments.isNotEmpty ? comments : null,
      aiSummary: _aiSummary,
      aiTranslation: _aiTranslation,
      importantPoints: _importantPoints,
    );

    AppStore.addNote(note);

    if (mounted) {
      // Navigate to home page to show the new note in recent notes
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    }
  }

  Future<Map<String, dynamic>?> _showSubjectSelectionDialog() async {
    final noteNameController = TextEditingController();
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Save Note',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note name field
                Text(
                  'Note Name',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter note name',
                    hintStyle: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.note, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Subject selection
                Text(
                  'Select Subject',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: AppStore.subjects.length,
                  itemBuilder: (context, index) {
                    final subject = AppStore.subjects[index];
                    return ListTile(
                      leading: Icon(
                        subject.icon ?? Icons.school,
                        color: AppColors.primary,
                      ),
                      title: Text(subject.name, style: GoogleFonts.poppins()),
                      onTap: () {
                        Navigator.pop(context, {
                          'subjectId': subject.id == 's0' ? null : subject.id,
                          'noteName': noteNameController.text.trim(),
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'subjectId': null,
              'noteName': noteNameController.text.trim(),
            }),
            child: Text('No Subject', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () async {
              // Show create subject dialog and wait for result
              final newSubjectId = await _showCreateSubjectDialog(context);
              if (newSubjectId != null && context.mounted) {
                Navigator.pop(context, {
                  'subjectId': newSubjectId,
                  'noteName': noteNameController.text.trim(),
                });
              }
            },
            child: Text('Create New', style: GoogleFonts.poppins(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCreateSubjectDialog(BuildContext dialogContext) async {
    final controller = TextEditingController();
    IconData? selectedIcon;
    
    // List of available icons
    final availableIcons = [
      Icons.school,
      Icons.calculate,
      Icons.science,
      Icons.language,
      Icons.history_edu,
    ];

    return showDialog<String>(
      context: dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Create Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Subject name',
                    prefixIcon: Icon(
                      selectedIcon ?? Icons.school,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Icon (Optional)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // No icon option
                    GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedIcon = null;
                        });
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selectedIcon == null
                              ? AppColors.primary.withOpacity(0.2)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedIcon == null
                                ? AppColors.primary
                                : AppColors.textLight,
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.block, size: 24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Icon options
                    ...availableIcons.map((icon) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: selectedIcon == icon
                                  ? AppColors.primary.withOpacity(0.2)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedIcon == icon
                                    ? AppColors.primary
                                    : AppColors.textLight,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  AppStore.addSubject(controller.text.trim(), icon: selectedIcon);
                  final newSubject = AppStore.subjects.last;
                  Navigator.pop(context, newSubject.id);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Create', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _generateSummary() {
    // Simulate AI summary
    setState(() {
      _aiSummary = 'Summary: ${_committed.substring(0, math.min(200, _committed.length))}...';
    });
  }

  void _translate() {
    // Simulate AI translation
    setState(() {
      _aiTranslation = 'Translation: $_committed';
    });
  }

  void _extractKeyPoints() {
    // Simulate AI key points
    setState(() {
      _importantPoints = [
        'Key point 1',
        'Key point 2',
        'Key point 3',
      ];
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Recording',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedLang.code,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: kSpeechLangs
                          .map((l) => DropdownMenuItem(
                                value: l.code,
                                child: Text(l.name),
                              ))
                          .toList(),
                      onChanged: (code) {
                        if (code == null) return;
                        setState(() {
                          _selectedLang =
                              kSpeechLangs.firstWhere((l) => l.code == code);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Enhanced waveform visualizer
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primaryLight.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ValueListenableBuilder<double>(
              valueListenable: _level,
              builder: (context, level, child) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Recording indicator
                          if (_recOn)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(_duration),
                                    style: GoogleFonts.poppins(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          // Enhanced waveform
                          LiveWaveform(
                            level: _level,
                            color: AppColors.primary,
                            barCount: 40,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _recognizing ? 'Listening...' : 'Ready to record',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Comments input - show always when recording or paused
          if (_recOn || _isPaused || _committed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _titleCtl,
                decoration: InputDecoration(
                  hintText: 'Comments (optional)',
                  hintStyle: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: const Icon(Icons.comment, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),

          if (_recOn || _isPaused || _committed.isNotEmpty) const SizedBox(height: 16),

          // Transcript
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _textCtl,
                readOnly: _recOn,
                maxLines: null,
                expands: true,
                scrollController: _scrollCtl,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: _recOn ? 'Start speaking...' : 'Transcript will appear here',
                  hintStyle: GoogleFonts.poppins(
                    color: AppColors.textLight,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // AI Options (after recording)
          if (_showAIOptions && !_recOn)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Actions',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AIActionButton(
                          icon: Icons.summarize,
                          label: 'Summarize',
                          onTap: _generateSummary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AIActionButton(
                          icon: Icons.translate,
                          label: 'Translate',
                          onTap: _translate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AIActionButton(
                          icon: Icons.lightbulb_outline,
                          label: 'Key Points',
                          onTap: _extractKeyPoints,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (_showAIOptions && !_recOn) const SizedBox(height: 16),

          // Control buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  icon: Icons.clear,
                  label: 'Clear',
                  color: AppColors.textSecondary,
                  onTap: _recOn || _isPaused
                      ? null
                      : () {
                          setState(() {
                            _committed = '';
                            _interim = '';
                            _lastFinal = '';
                            _showAIOptions = false;
                            _aiSummary = null;
                            _aiTranslation = null;
                            _importantPoints = null;
                          });
                          _updateTextField();
                        },
                ),
                if (_recOn && !_isPaused)
                  _ControlButton(
                    icon: Icons.pause,
                    label: 'Pause',
                    color: AppColors.warning,
                    onTap: _pause,
                  ),
                if (_isPaused) ...[
                  _ControlButton(
                    icon: Icons.play_arrow,
                    label: 'Resume',
                    color: AppColors.primary,
                    onTap: _resume,
                    isPrimary: true,
                  ),
                  _ControlButton(
                    icon: Icons.stop,
                    label: 'Stop',
                    color: AppColors.error,
                    onTap: _stop,
                  ),
                ],
                if (!_isPaused && !_recOn)
                  _ControlButton(
                    icon: Icons.mic,
                    label: 'Record',
                    color: AppColors.primary,
                    onTap: _start,
                    isPrimary: true,
                  ),
                if (_recOn && !_isPaused)
                  _ControlButton(
                    icon: Icons.stop,
                    label: 'Stop',
                    color: AppColors.error,
                    onTap: _stop,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: isPrimary ? 70 : 56,
          height: isPrimary ? 70 : 56,
          decoration: BoxDecoration(
            color: onTap == null
                ? color.withOpacity(0.3)
                : isPrimary
                    ? color
                    : color.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: onTap != null && isPrimary
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(100),
              child: Icon(
                icon,
                color: onTap == null
                    ? color.withOpacity(0.5)
                    : isPrimary
                        ? Colors.white
                        : color,
                size: isPrimary ? 32 : 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: onTap == null
                ? AppColors.textLight
                : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AIActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AIActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
