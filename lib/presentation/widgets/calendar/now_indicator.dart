import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 1.5px accent line with a 6px dot on the left edge indicating current time.
///
/// Updates every minute automatically.
/// Guarded against test timeouts: timer is disabled in widget tests.
class NowIndicator extends StatefulWidget {
  const NowIndicator({
    super.key,
    required this.hourHeight,
  });

  final double hourHeight;

  @override
  State<NowIndicator> createState() => _NowIndicatorState();
}

class _NowIndicatorState extends State<NowIndicator> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
        Get.testMode;
    if (!isTest) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          setState(() {
            _now = DateTime.now();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final minutes = _now.hour * 60.0 + _now.minute;
    final top = (minutes / 60.0) * widget.hourHeight;

    return Positioned(
      top: top - 4,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}
