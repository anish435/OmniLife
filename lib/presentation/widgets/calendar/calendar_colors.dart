import 'package:flutter/material.dart';

class CalendarColorTag {
  const CalendarColorTag({
    required this.name,
    required this.color,
    required this.label,
  });

  final String name;
  final Color color;
  final String label;

  Color background(bool isDark) => color.withValues(alpha: isDark ? 0.16 : 0.12);
  Color border(bool isDark) => color.withValues(alpha: isDark ? 0.35 : 0.25);
}

abstract final class CalendarColors {
  static const tags = <String, CalendarColorTag>{
    'blue': CalendarColorTag(
      name: 'blue',
      color: Color(0xFF3B82F6),
      label: 'Focus & Work',
    ),
    'emerald': CalendarColorTag(
      name: 'emerald',
      color: Color(0xFF10B981),
      label: 'Personal & Health',
    ),
    'amber': CalendarColorTag(
      name: 'amber',
      color: Color(0xFFF59E0B),
      label: 'Meeting',
    ),
    'rose': CalendarColorTag(
      name: 'rose',
      color: Color(0xFFEF4444),
      label: 'Deadline',
    ),
    'purple': CalendarColorTag(
      name: 'purple',
      color: Color(0xFF8B5CF6),
      label: 'Creative',
    ),
    'slate': CalendarColorTag(
      name: 'slate',
      color: Color(0xFF64748B),
      label: 'General',
    ),
  };

  static CalendarColorTag getTag(String? name) =>
      tags[name] ?? tags['blue']!;
}
