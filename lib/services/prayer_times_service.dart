import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PrayerTime {
  final String name;
  final DateTime time;

  PrayerTime({required this.name, required this.time});
}

class Location {
  final String name;
  final double latitude;
  final double longitude;

  const Location({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class PrayerTimesService {
  // Using Aladhan API for Egypt prayer times
  static const String _baseUrl = 'http://api.aladhan.com/v1';

  // Available locations in Egypt
  static const List<Location> availableLocations = [
    Location(name: 'القاهرة (وسط)', latitude: 30.0444, longitude: 31.2357),
    Location(name: 'الرحاب', latitude: 30.0594, longitude: 31.4987),
    Location(name: 'الشيخ زايد', latitude: 30.0208, longitude: 30.9767),
    Location(name: 'مدينة نصر', latitude: 30.0594, longitude: 31.3553),
    Location(name: 'المعادي', latitude: 29.9602, longitude: 31.2628),
    Location(name: '6 أكتوبر', latitude: 29.9554, longitude: 30.9284),
    Location(name: 'التجمع الخامس', latitude: 30.0272, longitude: 31.4344),
    Location(name: 'مدينتي', latitude: 30.0910, longitude: 31.6543),
    Location(name: 'الإسكندرية', latitude: 31.2001, longitude: 29.9187),
    Location(name: 'الجيزة', latitude: 30.0131, longitude: 31.2089),
    Location(name: 'حلوان', latitude: 29.8420, longitude: 31.3339),
    Location(name: 'القاهرة الجديدة', latitude: 30.0293, longitude: 31.4759),
  ];

  Future<List<PrayerTime>> getTodayPrayerTimes({Location? location}) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(now);

      // Use provided location or default to Cairo
      final loc = location ?? availableLocations[0];

      final url = Uri.parse(
        '$_baseUrl/timings/$dateStr?latitude=${loc.latitude}&longitude=${loc.longitude}&method=5',
      );

      print(
        'Fetching prayer times for ${loc.name} (${loc.latitude}, ${loc.longitude})',
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
