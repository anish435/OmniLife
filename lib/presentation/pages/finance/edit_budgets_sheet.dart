import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/finance_transaction.dart';
import '../../controllers/finance_controller.dart';
import '../../widgets/app_bottom_sheet_frame.dart';

/// Lets the person set a monthly limit for each spending category.
/// Saved limits are kept on the device and in their account.
class EditBudgetsSheet extends StatefulWidget {
  const EditBudgetsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditBudgetsSheet(),
    );
  }

  @override
  State<EditBudgetsSheet> createState() => _EditBudgetsSheetState();
}

class _EditBudgetsSheetState extends State<EditBudgetsSheet> {
  final _controller = Get.find<FinanceController>();
  final _fields = <TransactionCategory, TextEditingController>{};
  final _errors = <TransactionCategory, String?>{};
  bool _saving = false;

  static final _categories = [
    for (final c in TransactionCategory.values)
      if (c != TransactionCategory.income) c,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _categories) {
      final limit = _controller.budgets[c];
      _fields[c] = TextEditingController(
        text: limit == null || limit <= 0 ? '' : _plain(limit),
      );
    }
  }

  @override
  void dispose() {
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _save() async {
    final next = <TransactionCategory, double>{};
    var ok = true;
    setState(() {
      for (final c in _categories) {
        final text = _fields[c]!.text.trim();
        if (text.isEmpty) {
          _errors[c] = null;
          continue;
        }
        final value = double.tryParse(text);
        if (value == null || value < 0) {
          _errors[c] = 'Enter an amount like 150';
          ok = false;
        } else {
          _errors[c] = null;
          next[c] = value;
        }
      }
    });
    if (!ok) return;

    setState(() => _saving = true);
    final saved = await _controller.saveBudgets(next);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage.value ??
                'Could not save your budgets. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBottomSheetFrame(
      title: 'Monthly budgets',
      action: FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save budgets'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set how much you want to spend on each thing in a month. '
            'Leave a box empty if you do not want a limit.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final c in _categories) ...[
            TextField(
              controller: _fields[c],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: c.name[0].toUpperCase() + c.name.substring(1),
                prefixText: '\$ ',
                errorText: _errors[c],
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
