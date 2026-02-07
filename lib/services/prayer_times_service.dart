import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PrayerTime {
  final String name;
  final DateTime time;

  PrayerTime({required this.name, required this.time});
}

class PrayerTimesService {
  // Using Aladhan API for Egypt prayer times
  static const String _baseUrl = 'http://api.aladhan.com/v1';

  // Cairo, Egypt coordinates
  static const double _latitude = 30.0444;
  static const double _longitude = 31.2357;

  Future<List<PrayerTime>> getTodayPrayerTimes() async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(now);

      final url = Uri.parse(
        '$_baseUrl/timings/$dateStr?latitude=$_latitude&longitude=$_longitude&method=5',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timings = data['data']['timings'];

        return _parsePrayerTimes(timings, now);
      } else {
        throw Exception('Failed to load prayer times');
      }
    } catch (e) {
      print('Error fetching prayer times: $e');
      rethrow;
    }
  }

  List<PrayerTime> _parsePrayerTimes(
    Map<String, dynamic> timings,
    DateTime date,
  ) {
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayerTimes = <PrayerTime>[];

    for (var prayer in prayers) {
      final timeStr = timings[prayer] as String;
      final time = _parseTimeString(timeStr, date);
      prayerTimes.add(PrayerTime(name: prayer, time: time));
    }

    return prayerTimes;
  }

  DateTime _parseTimeString(String timeStr, DateTime date) {
    // Time format is "HH:mm"
    final parts = timeStr.split(' ')[0].split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  PrayerTime? getNextPrayer(List<PrayerTime> prayerTimes) {
    final now = DateTime.now();

    for (var prayer in prayerTimes) {
      if (prayer.time.isAfter(now)) {
        return prayer;
      }
    }

    return null; // All prayers have passed for today
  }

  Duration? getTimeUntilNextPrayer(List<PrayerTime> prayerTimes) {
    final nextPrayer = getNextPrayer(prayerTimes);
    if (nextPrayer == null) return null;

    return nextPrayer.time.difference(DateTime.now());
  }
}
