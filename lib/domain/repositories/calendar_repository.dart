import '../entities/calendar_event.dart';

/// Domain contract for calendar event storage and queries.
abstract class CalendarRepository {
  /// Fetches all events falling within or overlapping [start] and [end] for [userId].
  Future<List<CalendarEvent>> getEventsForRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  /// Retrieves an event by its unique ID.
  Future<CalendarEvent?> getEvent(String id);

  /// Creates and persists a new calendar event.
  Future<CalendarEvent> createEvent(CalendarEvent event);

  /// Updates an existing calendar event.
  Future<CalendarEvent> updateEvent(CalendarEvent event);

  /// Deletes an event by its unique ID.
  Future<void> deleteEvent(String id);
}
