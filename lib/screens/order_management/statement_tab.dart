import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/statement_models.dart';
import 'package:order_tracker/providers/statement_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:provider/provider.dart';

class StatementTab extends StatefulWidget {
  const StatementTab({super.key});

  @override
  State<StatementTab> createState() => _StatementTabState();
}

class _StatementTabState extends State<StatementTab> {
  DateTime? _issueDate;
  DateTime? _expiryDate;
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatementProvider>().fetchStatement();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _fmt(DateTime value) => DateFormat('yyyy/MM/dd').format(value);

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  DateTime _expiryDeadline(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59);
  }

  Duration _remainingDuration(DateTime expiryDate) {
    final remaining = _expiryDeadline(expiryDate).difference(_now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'اختر التاريخ',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
  }

  Future<void> _pickIssueDate() async {
    final now = DateTime.now();
    final picked = await _pickDate(
      initialDate: _issueDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() => _issueDate = picked);
  }

  Future<void> _pickExpiryDate({DateTime? initial}) async {
    final now = DateTime.now();
    final picked = await _pickDate(
      initialDate: initial ?? _expiryDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null || !mounted) return;
    setState(() => _expiryDate = picked);
  }

  Future<void> _submit(StatementProvider provider) async {
    final statement = provider.statement;

    if (statement == null) {
      final issueDate = _issueDate;
      final expiryDate = _expiryDate;
      if (issueDate == null || expiryDate == null) {
        _snack('يرجى تحديد تاريخ الإصدار والانتهاء', AppColors.errorRed);
        return;
      }

      final ok = await provider.createStatement(
        issueDate: issueDate,
        expiryDate: expiryDate,
      );
      if (!mounted) return;
      if (!ok) {
        _snack(provider.error ?? 'تعذر حفظ البيان', AppColors.errorRed);
        return;
      }
      setState(() {
        _issueDate = null;
        _expiryDate = null;
      });
      _snack('تم حفظ البيان', AppColors.successGreen);
      return;
    }

    final expiryDate = _expiryDate;
    if (expiryDate == null) {
      _snack('يرجى تحديد تاريخ الانتهاء', AppColors.errorRed);
      return;
    }

    final ok = await provider.renewStatement(expiryDate: expiryDate);
    if (!mounted) return;
    if (!ok) {
      _snack(provider.error ?? 'تعذر تجديد البيان', AppColors.errorRed);
      return;
    }

    setState(() => _expiryDate = null);
    _snack('تم تجديد البيان', AppColors.successGreen);
  }

  Future<void> _editRenewal(
    StatementProvider provider,
    StatementRenewalModel renewal,
  ) async {
    final now = DateTime.now();
    final picked = await _pickDate(
      initialDate: renewal.expiryDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null || !mounted) return;

    final ok = await provider.updateRenewal(
      renewalId: renewal.id,
      expiryDate: picked,
    );
    if (!mounted) return;
    if (!ok) {
      _snack(provider.error ?? 'تعذر تعديل البيان', AppColors.errorRed);
      return;
    }

    setState(() => _expiryDate = null);
    _snack('تم تعديل البيان', AppColors.successGreen);
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StatementProvider>(
      builder: (context, provider, _) {
        final statement = provider.statement;
        final renewals = (statement?.renewals ?? const <StatementRenewalModel>[])
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final isFirstTime = statement == null;
        final DateTime? countdownDate =
            _expiryDate ?? statement?.latestRenewal?.expiryDate;
        final bool countdownUsesDraftDate = _expiryDate != null;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
              children: [
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryBlue.withValues(alpha: 0.10),
                              border: Border.all(
                                color:
                                    AppColors.primaryBlue.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'البيان',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFirstTime
                                      ? 'أدخل تاريخ الإصدار والانتهاء لأول مرة'
                                      : 'جدد تاريخ الانتهاء فقط',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed:
                                provider.isSubmitting ? null : () => _submit(provider),
                            icon: provider.isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(isFirstTime
                                    ? Icons.save_rounded
                                    : Icons.autorenew_rounded),
                            label: Text(isFirstTime ? 'حفظ' : 'تجديد'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (provider.error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.errorRed.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.errorRed,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  provider.error!,
                                  style: const TextStyle(
                                    color: AppColors.errorRed,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'مسح',
                                onPressed: provider.clearError,
                                icon: const Icon(Icons.close_rounded),
                                color: AppColors.errorRed,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (isFirstTime)
                            _DateField(
                              label: 'تاريخ الإصدار',
                              value: _issueDate == null ? 'غير محدد' : _fmt(_issueDate!),
                              icon: Icons.event_available_outlined,
                              onTap: _pickIssueDate,
                            ),
                          _DateField(
                            label: isFirstTime ? 'تاريخ الانتهاء' : 'تاريخ الانتهاء الجديد',
                            value: _expiryDate == null
                                ? 'غير محدد'
                                : _fmt(_expiryDate!),
                            icon: Icons.event_busy_outlined,
                            onTap: _pickExpiryDate,
                          ),
                          if (!isFirstTime && statement.latestRenewal != null)
                            _InfoChip(
                              label: 'الانتهاء الحالي',
                              value: _fmt(statement.latestRenewal!.expiryDate),
                              icon: Icons.timelapse_rounded,
                              color: AppColors.secondaryTeal,
                            ),
                        ],
                      ),
                      if (countdownDate != null) ...[
                        const SizedBox(height: 14),
                        _CountdownCard(
                          title: countdownUsesDraftDate
                              ? 'العد التنازلي حتى التاريخ المحدد'
                              : 'العد التنازلي حتى الانتهاء الحالي',
                          targetDate: countdownDate,
                          remaining: _remainingDuration(countdownDate),
                          color: countdownUsesDraftDate
                              ? AppColors.infoBlue
                              : AppColors.secondaryTeal,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, color: AppColors.infoBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'سجل البيان',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            tooltip: 'تحديث',
                            onPressed:
                                provider.isFetching ? null : () => provider.fetchStatement(),
                            icon: provider.isFetching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (provider.isFetching && statement == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 22),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (renewals.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.appBarWaterBright.withValues(alpha: 0.10),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.inbox_outlined, color: Color(0xFF64748B)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'لا يوجد سجل للبيان حتى الآن.',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: renewals.map((renewal) {
                            final isLatest =
                                statement?.latestRenewal?.id == renewal.id;
                            return _RenewalRow(
                              renewal: renewal,
                              isLatest: isLatest,
                              onEdit: provider.isSubmitting
                                  ? null
                                  : () => _editRenewal(provider, renewal),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final String title;
  final DateTime targetDate;
  final Duration remaining;
  final Color color;

  const _CountdownCard({
    required this.title,
    required this.targetDate,
    required this.remaining,
    required this.color,
  });

  String _fmt(DateTime value) => DateFormat('yyyy/MM/dd').format(value);

  @override
  Widget build(BuildContext context) {
    final int days = remaining.inDays;
    final int hours = remaining.inHours.remainder(24);
    final int minutes = remaining.inMinutes.remainder(60);
    final int seconds = remaining.inSeconds.remainder(60);
    final bool expired = remaining == Duration.zero;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.10),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  expired ? Icons.timer_off_rounded : Icons.timer_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expired
                          ? 'انتهت مدة البيان في ${_fmt(targetDate)}'
                          : 'يستمر العد حتى نهاية يوم ${_fmt(targetDate)}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountdownUnit(
                label: 'يوم',
                value: days.toString(),
                color: color,
              ),
              _CountdownUnit(
                label: 'ساعة',
                value: hours.toString().padLeft(2, '0'),
                color: color,
              ),
              _CountdownUnit(
                label: 'دقيقة',
                value: minutes.toString().padLeft(2, '0'),
                color: color,
              ),
              _CountdownUnit(
                label: 'ثانية',
                value: seconds.toString().padLeft(2, '0'),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            expired
                ? 'إجمالي الثواني المتبقية: 0'
                : 'إجمالي الثواني المتبقية: ${remaining.inSeconds}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CountdownUnit({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.appBarWaterBright.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RenewalRow extends StatelessWidget {
  final StatementRenewalModel renewal;
  final bool isLatest;
  final VoidCallback? onEdit;

  const _RenewalRow({
    required this.renewal,
    required this.isLatest,
    this.onEdit,
  });

  String _fmt(DateTime value) => DateFormat('yyyy/MM/dd').format(value);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isLatest ? AppColors.successGreen : AppColors.appBarWaterBright)
              .withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isLatest ? AppColors.successGreen : AppColors.infoBlue)
                  .withValues(alpha: 0.12),
              border: Border.all(
                color: (isLatest ? AppColors.successGreen : AppColors.infoBlue)
                    .withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              isLatest ? Icons.check_circle_outline_rounded : Icons.event_note_rounded,
              color: isLatest ? AppColors.successGreen : AppColors.infoBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تاريخ الانتهاء: ${_fmt(renewal.expiryDate)}',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تم تسجيله: ${_fmt(renewal.createdAt)}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تعديل',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_calendar_outlined),
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}
