// lib/pages/recordpage.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:google_speech/google_speech.dart';

import '../features/storage/store.dart';
import '../models/note.dart';
import '../models/category.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  // audio
  final _rec = RecorderStream();
  final _player = PlayerStream();
  late StreamSubscription _recStat, _playStat, _micSub;
  final List<Uint8List> _buffer = [];
  bool _recOn = false, _playOn = false;

  // stt
  SpeechToText? _stt;
  StreamController<List<int>>? _sttIn;
  bool _recognizing = false;

  // transcript model
  String _committed = ''; // finalized sentences
  String _interim = '';   // live, not-final yet
  final _textCtl = TextEditingController();

  static const _rate = 16000; // 16-kHz mono LINEAR16

  @override
  void initState() {
    super.initState();
    _initAudio();
    _initSTT();
  }

  @override
  void dispose() {
    _sttIn?.close();
    _micSub.cancel();
    _recStat.cancel();
    _playStat.cancel();
    _rec.stop();
    _player.stop();
    _textCtl.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    await Permission.microphone.request();
    _recStat = _rec.status.listen((s) {
      setState(() => _recOn = s == SoundStreamStatus.Playing);
    });
    _playStat = _player.status.listen((s) {
      setState(() => _playOn = s == SoundStreamStatus.Playing);
    });
    _micSub = _rec.audioStream.listen((bytes) {
      _buffer.add(bytes);
      _sttIn?.add(bytes);
      if (_playOn) _player.writeChunk(bytes);
    });

    // explicit params for LINEAR16
    await _rec.initialize(sampleRate: _rate);
    await _player.initialize(sampleRate: _rate);

  }

  Future<void> _initSTT() async {
    final json =
    await rootBundle.loadString('lib/assets/keys/stt_service_account.json');
    _stt = SpeechToText.viaServiceAccount(ServiceAccount.fromString(json));
  }

  Future<void> _start() async {
    if (!(await Permission.microphone.request()).isGranted) return;
    _buffer.clear();
    _committed = '';
    _interim = '';
    _updateTextField();
    setState(() => _recognizing = true);

    _sttIn = StreamController<List<int>>();

    final cfg = RecognitionConfig(
      encoding: AudioEncoding.LINEAR16,
      sampleRateHertz: _rate,
      languageCode: 'en-US',
      enableAutomaticPunctuation: true,
      model: RecognitionModel.basic,
    );

    final stream = _stt!.streamingRecognize(
      StreamingRecognitionConfig(config: cfg, interimResults: true),
      _sttIn!.stream,
    );

    stream.listen((resp) {
      // handle each result: finalize or interim
      for (final r in resp.results) {
        final t = r.alternatives.first.transcript;
        if (r.isFinal) {
          _committed += (t.endsWith(' ') ? t : '$t ') ;
          _interim = '';
        } else {
          _interim = t; // show latest interim
        }
      }
      _updateTextField();
      setState(() {}); // refresh status row
    }, onDone: () => setState(() => _recognizing = false), onError: (_) {
      setState(() => _recognizing = false);
    });

    await _rec.start();
  }

  Future<void> _pauseOrResumePlay() async {
    if (_playOn) {
      await _player.stop();
    } else {
      await _player.start();
      for (final c in _buffer) {
        await _player.writeChunk(c);
      }
    }
  }

  Future<void> _stop() async {
    await _rec.stop();
    await _sttIn?.close();
    _sttIn = null;

    final wav = await _saveWav(_buffer, _rate);
    final transcript = _textCtl.text;

    if (!mounted) return;
    await _saveDialog(audioPath: wav, transcript: transcript);

    setState(() {
      _buffer.clear();
      _recognizing = false;
    });
  }

  // keep text field in sync and scroll to end
  void _updateTextField() {
    final full = '$_committed$_interim';
    _textCtl.text = full;
    _textCtl.selection =
        TextSelection.fromPosition(TextPosition(offset: _textCtl.text.length));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Note')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // waveform placeholder
            const Icon(Icons.graphic_eq, size: 64),
            const SizedBox(height: 12),

            // scrollable, multiline text area that grows
            Expanded(
              child: TextField(
                controller: _textCtl,
                readOnly: true,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: 'text here',
                  filled: true,
                  fillColor: const Color(0xFFC6EFD4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // status + small VU meter
            Row(
              children: [
                if (_recognizing)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Text(_recognizing ? 'Listening…' : 'Idle'),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(value: _recOn ? null : 0),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _roundBtn(
                  icon: Icons.close,
                  color: Colors.black87,
                  onTap: _recOn ? null : () { _committed=''; _interim=''; _updateTextField(); },
                  label: 'Clear',
                ),
                _roundBtn(
                  icon: Icons.pause,
                  color: Colors.black87,
                  onTap: _playOn ? _player.stop : _pauseOrResumePlay,
                  label: _playOn ? 'Pause' : 'Play',
                ),
                _roundBtn(
                  icon: Icons.stop,
                  color: _recOn ? Colors.redAccent : Colors.grey,
                  onTap: _recOn ? _stop : null,
                  label: 'Stop',
                ),
                _roundBtn(
                  icon: Icons.mic,
                  color: _recOn ? Colors.grey : Colors.redAccent,
                  onTap: _recOn ? null : _start,
                  label: 'Record',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required String label,
  }) {
    return Column(
      children: [
        InkResponse(
          onTap: onTap,
          radius: 42,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: color.withValues(alpha: onTap == null ? 0.4 : 1.0),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }

  // ---- Save flow ----

  Future<void> _saveDialog({
    required String audioPath,
    required String transcript,
  }) async {
    final titleCtl = TextEditingController(text: 'Voice ${_stamp()}');
    String? selectedId;
    final cats = List<Category>.from(AppStore.categories);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Save recording'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  decoration: const InputDecoration(labelText: 'Title'),
                  controller: titleCtl),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                hint: const Text('Category'),
                items: [
                  ...cats.map(
                          (c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  const DropdownMenuItem(
                      value: '__add__', child: Text('+ Add category')),
                ],
                onChanged: (v) async {
                  if (v == '__add__') {
                    final name = await _promptCategory();
                    if (name != null && name.trim().isNotEmpty) {
                      AppStore.addCategory(name.trim());
                      cats
                        ..clear()
                        ..addAll(AppStore.categories);
                      setS(() {});
                    }
                  } else {
                    setS(() => selectedId = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final cat = cats.firstWhere(
                      (c) => c.id == selectedId,
                  orElse: () =>
                      Category(id: 'c0', name: 'No category', coverIndex: 0),
                );
                final note = Note(
                  id: 'n${DateTime.now().microsecondsSinceEpoch}',
                  title: titleCtl.text.trim().isEmpty
                      ? 'Untitled'
                      : titleCtl.text.trim(),
                  transcript: transcript,
                  category: cat.name,
                  audioPath: audioPath,
                );
                AppStore.addNote(note);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptCategory() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Category name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
  }

  // ---- WAV I/O ----

  Future<String> _saveWav(List<Uint8List> chunks, int sampleRate) async {
    final pcm = Uint8List.fromList(chunks.expand((e) => e).toList());
    final bytes = _wrapWav(pcm,
        sampleRate: sampleRate, channels: 1, bitsPerSample: 16);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/rec_${_stamp()}.wav');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Uint8List _wrapWav(Uint8List pcm,
      {required int sampleRate,
        required int channels,
        required int bitsPerSample}) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final chunkSize = 36 + pcm.length;
    final b = BytesBuilder()
      ..add('RIFF'.codeUnits)
      ..add(_le32(chunkSize))
      ..add('WAVE'.codeUnits)
      ..add('fmt '.codeUnits)
      ..add(_le32(16))
      ..add(_le16(1))
      ..add(_le16(channels))
      ..add(_le32(sampleRate))
      ..add(_le32(byteRate))
      ..add(_le16(blockAlign))
      ..add(_le16(bitsPerSample))
      ..add('data'.codeUnits)
      ..add(_le32(pcm.length))
      ..add(pcm);
    return Uint8List.fromList(b.toBytes());
  }

  List<int> _le16(int v) => [v & 0xff, (v >> 8) & 0xff];
  List<int> _le32(int v) =>
      [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff];

  String _stamp() {
    final n = DateTime.now();
    String t(int x) => x.toString().padLeft(2, '0');
    return '${n.year}${t(n.month)}${t(n.day)}_${t(n.hour)}${t(n.minute)}${t(n.second)}';
  }
}
