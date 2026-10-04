import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/entities/finance_transaction.dart';
import '../../controllers/finance_controller.dart';
import '../../../app/theme/app_spacing.dart';

class CreateTransactionSheet extends StatefulWidget {
  const CreateTransactionSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CreateTransactionSheet(),
    );
  }

  @override
  State<CreateTransactionSheet> createState() => _CreateTransactionSheetState();
}

class _CreateTransactionSheetState extends State<CreateTransactionSheet> {
  final _financeController = Get.find<FinanceController>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();

  TransactionCategory _selectedCategory = TransactionCategory.other;
  DateTime _selectedDate = DateTime.now();
  bool _isIncome = false;
  XFile? _receiptImage;

  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _receiptImage = picked);
    }
  }

  void _save() async {
    final amountText = _amountController.text.trim();
    final title = _titleController.text.trim();

    if (amountText.isEmpty || title.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);

    String? receiptUrl;
    if (_receiptImage != null) {
      receiptUrl = await _financeController.uploadReceipt(_receiptImage!);
    }

    final result = await _financeController.addTransaction(
      amount: amount,
      title: title,
      category: _isIncome ? TransactionCategory.income : _selectedCategory,
      date: _selectedDate,
      isIncome: _isIncome,
      receiptUrl: receiptUrl,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (result != null) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save transaction')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: bottomInset + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add Transaction', style: Theme.of(context).textTheme.titleLarge),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Expense')),
                  ButtonSegment(value: true, label: Text('Income')),
                ],
                selected: {_isIncome},
                onSelectionChanged: (val) {
                  setState(() {
                    _isIncome = val.first;
                    if (_isIncome) {
                      _selectedCategory = TransactionCategory.income;
                    } else if (_selectedCategory == TransactionCategory.income) {
                      _selectedCategory = TransactionCategory.other;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title / Description',
              border: OutlineInputBorder(),
            ),
          ),
          if (!_isIncome) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<TransactionCategory>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: TransactionCategory.values
                  .where((c) => c != TransactionCategory.income)
                  .map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat.name.capitalizeFirst!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ListTile(
            title: const Text('Date'),
            subtitle: Text('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, "0")}-${_selectedDate.day.toString().padLeft(2, "0")}'),
            trailing: const Icon(Icons.calendar_today),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            title: Text(_receiptImage == null ? 'Attach Receipt' : 'Receipt Attached'),
            subtitle: _receiptImage != null ? Text(_receiptImage!.name) : null,
            trailing: const Icon(Icons.camera_alt),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            onTap: _pickImage,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving ? const CircularProgressIndicator.adaptive() : const Text('Save Transaction'),
          ),
        ],
      ),
    );
  }
}
