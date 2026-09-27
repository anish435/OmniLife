import 'package:flutter/material.dart';

/// Standard "nothing here yet" placeholder for empty lists/collections.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
