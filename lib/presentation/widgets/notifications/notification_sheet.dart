import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/notification_service.dart';
import '../../../domain/entities/app_notification.dart';
import '../app_bottom_sheet_frame.dart';
import '../empty_state.dart';

/// Modal bottom sheet displaying recent notifications and demo triggers (Rubric D2).
class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline = theme.colorScheme.outline;
    final notifService = Get.find<NotificationService>();

    return AppBottomSheetFrame(
      title: 'Notifications & Alerts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Rubric D2 Banner & Quick Demo Triggers
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2226) : const Color(0xFFFBF9F5),
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: hairline, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RUBRIC D2',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live Evaluation Demo Controls',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('demo_booking_notif_btn'),
                        onPressed: () => notifService.showDemoNotification(isBooking: true),
                        icon: const Icon(Icons.event_available_outlined, size: 16),
                        label: const Text(
                          'Test Booking',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: hairline),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('demo_reminder_notif_btn'),
                        onPressed: () => notifService.showDemoNotification(isBooking: false),
                        icon: const Icon(Icons.alarm_outlined, size: 16),
                        label: const Text(
                          'Test Reminder',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: hairline),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.mdPlus),

          // 2. Notification List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT ALERTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Obx(() {
                if (notifService.recentNotifications.isEmpty) {
                  return const SizedBox.shrink();
                }
                return TextButton(
                  onPressed: notifService.clearAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Text('Clear all', style: TextStyle(fontSize: 12)),
                );
              }),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // 3. Notification Items or Empty State
          Obx(() {
            final items = notifService.recentNotifications;
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  message:
                      'No notifications yet\nBooking confirmations and scheduled task reminders will appear here.',
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, index) => Divider(height: 1, color: hairline),
              itemBuilder: (context, index) {
                final item = items[index];
                final isBooking = item.type == NotificationType.bookingConfirmed ||
                    item.type == NotificationType.bookingReminder;
                final tagColor =
                    isBooking ? AppColors.primary : const Color(0xFF6FA3C7);
                final icon =
                    isBooking ? Icons.calendar_today_outlined : Icons.alarm_outlined;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: tagColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('HH:mm').format(item.timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.body,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
