import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'services/prayer_times_service.dart';
import 'services/audio_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Athan Waterway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AthanHomePage(),
    );
  }
}

class AthanHomePage extends StatefulWidget {
  const AthanHomePage({super.key});

  @override
  State<AthanHomePage> createState() => _AthanHomePageState();
}

class _AthanHomePageState extends State<AthanHomePage> {
  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  final AudioService _audioService = AudioService();

  List<PrayerTime> _prayerTimes = [];
  String? _customAudioPath;
  String? _nextPrayerName;
  String? _timeUntilNext;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _loadSavedAudioPath();
    _startChecking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _updateTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadPrayerTimes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final times = await _prayerTimesService.getTodayPrayerTimes();
      setState(() {
        _prayerTimes = times;
        _isLoading = false;
        _updateNextPrayerInfo();
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to load prayer times. Please check your internet connection.';
        _isLoading = false;
      });
    }
  }

  void _updateNextPrayerInfo() {
    final nextPrayer = _prayerTimesService.getNextPrayer(_prayerTimes);
    if (nextPrayer != null) {
      final duration = _prayerTimesService.getTimeUntilNextPrayer(_prayerTimes);
      setState(() {
        _nextPrayerName = nextPrayer.name;
        if (duration != null) {
          final hours = duration.inHours;
          final minutes = duration.inMinutes.remainder(60);
          final seconds = duration.inSeconds.remainder(60);
          _timeUntilNext = '${hours}h ${minutes}m ${seconds}s';
        }
      });
    } else {
      setState(() {
        _nextPrayerName = 'All prayers completed';
        _timeUntilNext = null;
      });
    }
  }

  Future<void> _loadSavedAudioPath() async {
    final path = await _audioService.getSavedAudioPath();
    setState(() {
      _customAudioPath = path;
    });
  }

  void _startChecking() {
    // Check every 30 seconds if it's time for prayer
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndPlayAzan();
    });

    // Also check immediately when prayer times are loaded
    _checkAndPlayAzan();

    // Update UI every second
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prayerTimes.isNotEmpty) {
        _updateNextPrayerInfo();
      }
    });
  }

  void _checkAndPlayAzan() {
    final now = DateTime.now();
    print('Checking prayer times at: ${now.hour}:${now.minute}:${now.second}');

    for (var prayer in _prayerTimes) {
      // Check if current time matches prayer time (within same minute)
      if (prayer.time.year == now.year &&
          prayer.time.month == now.month &&
          prayer.time.day == now.day &&
          prayer.time.hour == now.hour &&
          prayer.time.minute == now.minute) {
        print(
          '🕌 وقت الأذان الآن! Playing ${prayer.name} at ${now.hour}:${now.minute}',
        );
        _audioService.playAzan();
        _showNotification(prayer.name);
        break;
      }
    }
  }

  void _showNotification(String prayerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🕌 حان الآن وقت صلاة $prayerName'),
        duration: const Duration(seconds: 10),
        backgroundColor: Colors.green.shade700,
        action: SnackBarAction(
          label: 'إيقاف',
          textColor: Colors.white,
          onPressed: () {
            _audioService.stopAzan();
          },
        ),
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _audioService.saveAudioPath(path);
        setState(() {
          _customAudioPath = path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio file saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testAudio() async {
    if (_customAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار ملف صوتي أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _audioService.testAudio();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🔊 تشغيل الصوت التجريبي...'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue.shade700,
        action: SnackBarAction(
          label: 'إيقاف',
          textColor: Colors.white,
          onPressed: () {
            _audioService.stopAzan();
          },
        ),
      ),
    );
  }

  Future<void> _stopAudio() async {
    await _audioService.stopAzan();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إيقاف الصوت'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Athan Waterway'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadPrayerTimes,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Next Prayer Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 48,
                            color: Color(0xFF1B5E20),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Next Prayer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _nextPrayerName ?? '',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          if (_timeUntilNext != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _timeUntilNext!,
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Prayer Times List
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Prayer Times',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          ..._prayerTimes.map(
                            (prayer) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.mosque,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        prayer.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormat('hh:mm a').format(prayer.time),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Audio Settings Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Custom Athan Sound',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_customAudioPath != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _customAudioPath!.split('/').last,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'لم يتم اختيار ملف صوتي',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _pickAudioFile,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('اختر ملف MP3'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _customAudioPath != null
                                      ? _testAudio
                                      : null,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('تجربة'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _stopAudio,
                              icon: const Icon(Icons.stop),
                              label: const Text('إيقاف الصوت'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                foregroundColor: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Refresh Button
                  OutlinedButton.icon(
                    onPressed: _loadPrayerTimes,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث مواقيت الصلاة'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'سيتم تشغيل الأذان تلقائياً عند حلول وقت الصلاة',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
