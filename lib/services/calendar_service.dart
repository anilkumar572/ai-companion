import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';

class CalendarService {
  CalendarService() : _plugin = DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  Future<bool> requestPermissions() async {
    final granted = await _plugin.requestPermissions();
    return granted.isSuccess && granted.data == true;
  }

  Future<String> summarizeToday() async {
    final granted = await requestPermissions();
    if (!granted) {
      return 'Calendar access has not been granted. Please enable calendar permissions in settings.';
    }

    final calendars = await _plugin.retrieveCalendars();
    if (!calendars.isSuccess || calendars.data == null || calendars.data!.isEmpty) {
      return 'No calendars were found on this device.';
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final formatter = DateFormat('h:mm a');

    final events = <Event>[];
    for (final calendar in calendars.data!) {
      final result = await _plugin.retrieveEvents(
        calendar.id,
        RetrieveEventsParams(startDate: start, endDate: end),
      );
      if (result.isSuccess && result.data != null) {
        events.addAll(result.data!);
      }
    }

    events.sort((a, b) => (a.start ?? start).compareTo(b.start ?? start));

    if (events.isEmpty) {
      return 'You have no calendar events scheduled for today.';
    }

    final lines = events.take(5).map((event) {
      final time = event.allDay == true
          ? 'All day'
          : formatter.format((event.start ?? start).toLocal());
      return '$time — ${event.title ?? 'Untitled event'}';
    });

    return 'Today\'s calendar summary:\n${lines.join('\n')}';
  }
}
