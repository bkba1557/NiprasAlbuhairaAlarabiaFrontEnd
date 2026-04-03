import 'package:flutter/material.dart';
import 'package:order_tracker/providers/tax_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:provider/provider.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vatPercentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vatRate = context.read<TaxProvider>().vatRate;
      _vatPercentController.text = (vatRate * 100).toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _vatPercentController.dispose();
    super.dispose();
  }

  double? _parsePercentToRate(String raw) {
    final text = raw.trim().replaceAll('%', '').replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return null;
    return value / 100.0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final parsed = _parsePercentToRate(_vatPercentController.text);
    if (parsed == null) return;

    final ok = await context.read<TaxProvider>().setVatRate(parsed);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم حفظ الضريبة' : 'تعذر حفظ الضريبة'),
        backgroundColor: ok ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  Future<void> _reset() async {
    final ok = await context.read<TaxProvider>().resetVatRate();
    if (!mounted) return;
    final rate = context.read<TaxProvider>().vatRate;
    _vatPercentController.text = (rate * 100).toStringAsFixed(2);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تمت إعادة الضريبة إلى 15%' : 'تعذر إعادة الضريبة'),
        backgroundColor: ok ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  void _applyQuickPercent(double percent) {
    _vatPercentController.text = percent.toStringAsFixed(2);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaxProvider>();
    final currentPercent = (provider.vatRate * 100);

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الضريبة')),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppSurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.percent,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ضريبة القيمة المضافة (VAT)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'القيمة الحالية: ${currentPercent.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: Colors.black87.withValues(
                                        alpha: 0.66,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _vatPercentController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'نسبة الضريبة (%)',
                            prefixIcon: const Icon(Icons.percent_outlined),
                            helperText:
                                'يتم تطبيقها على إجمالي الطلب (قبل الضريبة) لإظهار المبلغ شامل الضريبة.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) {
                            final parsed = _parsePercentToRate(value ?? '');
                            if (parsed == null) return 'أدخل نسبة صحيحة';
                            if (parsed < 0 || parsed > 1) {
                              return 'النسبة يجب أن تكون بين 0% و 100%';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _quickChip(
                              label: '0%',
                              selected: currentPercent.toStringAsFixed(0) == '0',
                              onTap: () => _applyQuickPercent(0),
                            ),
                            _quickChip(
                              label: '5%',
                              selected:
                                  currentPercent.toStringAsFixed(0) == '5',
                              onTap: () => _applyQuickPercent(5),
                            ),
                            _quickChip(
                              label: '15%',
                              selected:
                                  currentPercent.toStringAsFixed(0) == '15',
                              onTap: () => _applyQuickPercent(15),
                            ),
                            _quickChip(
                              label: '20%',
                              selected:
                                  currentPercent.toStringAsFixed(0) == '20',
                              onTap: () => _applyQuickPercent(20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    provider.isSaving ? null : _reset,
                                icon: const Icon(Icons.restart_alt_outlined),
                                label: const Text('إرجاع 15%'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    provider.isSaving ? null : _save,
                                icon: provider.isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('حفظ'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((provider.error ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            provider.error!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.errorRed,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.primaryBlue.withValues(alpha: 0.24)
                : Colors.transparent,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? AppColors.primaryBlue : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

