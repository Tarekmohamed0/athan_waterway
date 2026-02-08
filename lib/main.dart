import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          seedColor: Colors.black,
          brightness: Brightness.light,
          primary: Colors.black,
          secondary: Colors.grey.shade800,
        ),
        scaffoldBackgroundColor: Colors.white,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          color: Colors.white,
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
  Timer? _retryTimer;
  Location _selectedLocation = PrayerTimesService.availableLocations[0];
  bool _isUsingCachedData = false;

  // Track which prayers have been played today
  final Set<String> _playedPrayers = {};
  DateTime? _lastCheckDate;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();

    // Load cached data first (synchronously with UI)
    _loadCachedPrayerTimes().then((_) {
      // Only try to fetch fresh data if we have internet
      // Don't show error if it fails - we already have cached data
      _loadPrayerTimes();
    });

    _loadSavedAudioPath();
    _startChecking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _updateTimer?.cancel();
    _retryTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadPrayerTimes() async {
    try {
      setState(() {
        _isLoading =
            _prayerTimes.isEmpty; // Only show loading if no cached data
        _errorMessage = null;
      });

      final times = await _prayerTimesService.getTodayPrayerTimes(
        location: _selectedLocation,
      );

      // Save prayer times to cache
      await _savePrayerTimesToCache(times);

      // Reset played prayers when loading new prayer times
      _playedPrayers.clear();
      _lastCheckDate = DateTime.now();

      setState(() {
        _prayerTimes = times;
        _isLoading = false;
        _isUsingCachedData = false;
        _updateNextPrayerInfo();
      });

      // Cancel retry timer if we successfully loaded data
      _retryTimer?.cancel();
    } catch (e) {
      print('❌ خطأ في تحميل المواقيت: $e');

      // Don't show error message if we already have cached data
      if (_prayerTimes.isEmpty) {
        // No cached data available at all - this is the only time we show error
        setState(() {
          _errorMessage = 'فشل تحميل مواقيت الصلاة. تحقق من اتصال الإنترنت.';
          _isLoading = false;
        });
      } else {
        // We have cached data, just mark it as such and continue silently
        print('💡 استمرار العمل بالمواقيت المحفوظة');
        setState(() {
          _isLoading = false;
          if (!_isUsingCachedData) {
            _isUsingCachedData = true;
          }
        });

        // Start retry timer to try fetching fresh data every 5 minutes
        _startRetryTimer();
      }
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isUsingCachedData) {
        print('🔄 محاولة إعادة الاتصال بالإنترنت...');
        _loadPrayerTimes();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _savePrayerTimesToCache(List<PrayerTime> times) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> prayerTimesJson = times.map((prayer) {
        return '${prayer.name}|${prayer.time.millisecondsSinceEpoch}';
      }).toList();

      await prefs.setStringList('cached_prayer_times', prayerTimesJson);
      await prefs.setString(
        'cached_prayer_date',
        DateTime.now().toIso8601String(),
      );
      await prefs.setString('cached_location', _selectedLocation.name);

      print('✅ تم حفظ مواقيت الصلاة في الكاش');
    } catch (e) {
      print('Error saving prayer times to cache: $e');
    }
  }

  Future<List<PrayerTime>> _loadCachedPrayerTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? cachedData = prefs.getStringList(
        'cached_prayer_times',
      );
      final String? cachedDate = prefs.getString('cached_prayer_date');
      final String? cachedLocation = prefs.getString('cached_location');

      if (cachedData == null || cachedDate == null) {
        print('⚠️ لا توجد بيانات محفوظة');
        return [];
      }

      // Check if cached data is for today and same location
      final savedDate = DateTime.parse(cachedDate);
      final now = DateTime.now();
      final isSameDay =
          savedDate.year == now.year &&
          savedDate.month == now.month &&
          savedDate.day == now.day;
      final isSameLocation = cachedLocation == _selectedLocation.name;

      // Parse cached prayer times
      final List<PrayerTime> times = cachedData.map((item) {
        final parts = item.split('|');
        final name = parts[0];
        final timestamp = int.parse(parts[1]);
        final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return PrayerTime(name: name, time: time);
      }).toList();

      if (times.isEmpty) {
        return [];
      }

      // Always load cached data to avoid blank screen
      setState(() {
        _prayerTimes = times;
        _isLoading = false;
        _updateNextPrayerInfo();
      });

      // Mark as using cached data if not same day/location
      if (!isSameDay || !isSameLocation) {
        print(
          '⚠️ استخدام مواقيت محفوظة (${isSameDay ? "نفس اليوم" : "يوم سابق"}, ${isSameLocation ? "نفس الموقع" : "موقع مختلف"})',
        );
        setState(() {
          _isUsingCachedData = true;
        });
      } else {
        print('📦 تم تحميل مواقيت الصلاة من الكاش');
      }

      return times;
    } catch (e) {
      print('Error loading cached prayer times: $e');
      return [];
    }
  }

  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocationName = prefs.getString('selected_location');

      if (savedLocationName != null) {
        final location = PrayerTimesService.availableLocations.firstWhere(
          (loc) => loc.name == savedLocationName,
          orElse: () => PrayerTimesService.availableLocations[0],
        );
        setState(() {
          _selectedLocation = location;
        });
      }
    } catch (e) {
      print('Error loading saved location: $e');
    }
  }

  Future<void> _saveLocation(Location location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_location', location.name);
    } catch (e) {
      print('Error saving location: $e');
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

    // Reset played prayers if it's a new day
    if (_lastCheckDate == null ||
        _lastCheckDate!.day != now.day ||
        _lastCheckDate!.month != now.month ||
        _lastCheckDate!.year != now.year) {
      _playedPrayers.clear();
      _lastCheckDate = now;
      print('🔄 تم إعادة تعيين قائمة الصلوات ليوم جديد');
    }

    print('Checking prayer times at: ${now.hour}:${now.minute}:${now.second}');

    for (var prayer in _prayerTimes) {
      // Create unique key for this prayer time
      final prayerKey =
          '${prayer.name}_${prayer.time.day}_${prayer.time.hour}_${prayer.time.minute}';

      // Check if current time matches prayer time (within same minute)
      if (prayer.time.year == now.year &&
          prayer.time.month == now.month &&
          prayer.time.day == now.day &&
          prayer.time.hour == now.hour &&
          prayer.time.minute == now.minute) {
        // Only play if not already played
        if (!_playedPrayers.contains(prayerKey)) {
          print(
            '🕌 وقت الأذان الآن! Playing ${prayer.name} at ${now.hour}:${now.minute}',
          );
          _playedPrayers.add(prayerKey);
          _audioService.playAzan();
          _showNotification(prayer.name);
          break;
        } else {
          print('⏭️ تم تشغيل أذان ${prayer.name} بالفعل، تخطي...');
        }
      }
    }
  }

  void _showNotification(String prayerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🕌 حان الآن وقت صلاة $prayerName'),
        duration: const Duration(seconds: 10),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      SnackBar(
        content: const Text('تم إيقاف الصوت'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 2,
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadPrayerTimes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.black,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: const Text(
                      'Athan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                        fontSize: 24,
                        letterSpacing: 4,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.grey.shade900, Colors.black],
                        ),
                      ),
                      child: Image.asset(
                        width: MediaQuery.sizeOf(context).width,
                        'assets/The_Waterway_Developments.jpg',
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(20.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Location Selector
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'الموقع',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isUsingCachedData)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.cloud_off,
                                          size: 14,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'وضع عدم الاتصال',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Location>(
                                  isExpanded: true,
                                  value: _selectedLocation,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.black,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  items: PrayerTimesService.availableLocations
                                      .map(
                                        (location) => DropdownMenuItem(
                                          value: location,
                                          child: Text(location.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (Location? newLocation) {
                                    if (newLocation != null) {
                                      setState(() {
                                        _selectedLocation = newLocation;
                                      });
                                      _saveLocation(newLocation);
                                      _loadPrayerTimes();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'تم تغيير الموقع إلى ${newLocation.name}',
                                          ),
                                          duration: const Duration(seconds: 2),
                                          backgroundColor: Colors.black,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Next Prayer Card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.schedule,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'الصلاة القادمة',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _nextPrayerName ?? '---',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                            if (_timeUntilNext != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _timeUntilNext!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Prayer Times List
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مواقيت اليوم',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ..._prayerTimes.asMap().entries.map((entry) {
                              final prayer = entry.value;
                              final isLast =
                                  entry.key == _prayerTimes.length - 1;
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: const BoxDecoration(
                                                color: Colors.black,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              prayer.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          DateFormat(
                                            'hh:mm a',
                                          ).format(prayer.time),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isLast)
                                    Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Audio Settings
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.audiotrack,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'ملف الأذان',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_customAudioPath != null)
                              Container(
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _customAudioPath!.split('/').last,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ElevatedButton(
                              onPressed: _pickAudioFile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload_file, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'اختيار ملف MP3',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _customAudioPath != null
                                        ? _testAudio
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      side: const BorderSide(
                                        color: Colors.black,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_arrow, size: 20),
                                        SizedBox(width: 6),
                                        Text('تجربة'),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _stopAudio,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      side: const BorderSide(
                                        color: Colors.black,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.stop, size: 20),
                                        SizedBox(width: 6),
                                        Text('إيقاف'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Refresh Button
                      OutlinedButton(
                        onPressed: _loadPrayerTimes,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'تحديث المواقيت',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isUsingCachedData
                              ? Colors.orange.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: _isUsingCachedData
                              ? Border.all(color: Colors.orange.shade200)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isUsingCachedData
                                  ? Icons.cloud_off
                                  : Icons.info_outline,
                              color: _isUsingCachedData
                                  ? Colors.orange.shade700
                                  : Colors.grey.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isUsingCachedData
                                    ? 'يتم استخدام مواقيت محفوظة. سيتم التحديث عند الاتصال بالإنترنت.'
                                    : 'سيتم تشغيل الأذان تلقائياً عند حلول وقت الصلاة',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isUsingCachedData
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}
