import 'package:equatable/equatable.dart';

/// Categories of notifications in OmniLife.
enum NotificationType {
  bookingConfirmed,
  bookingReminder,
  taskReminder,
  system,
}

/// Immutable domain entity representing a user notification (Rubric D2).
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.payload,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final String? payload;
  final bool isRead;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? timestamp,
    String? payload,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  List<Object?> get props => [id, title, body, type, timestamp, payload, isRead];
}
