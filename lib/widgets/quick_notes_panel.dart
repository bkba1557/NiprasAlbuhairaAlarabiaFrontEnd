import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/note_model.dart';
import 'package:order_tracker/providers/note_provider.dart';
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class QuickNotesPanel extends StatefulWidget {
  const QuickNotesPanel({super.key});

  @override
  State<QuickNotesPanel> createState() => _QuickNotesPanelState();
}

class _QuickNotesPanelState extends State<QuickNotesPanel> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();
  final TextEditingController _daysCtrl = TextEditingController(text: '0');
  final TextEditingController _hourCtrl = TextEditingController(text: '0');
  final TextEditingController _minuteCtrl = TextEditingController(text: '0');

  NoteModel? _editingNote;
  Color _selectedColor = const Color(0xFF1A73E8);
  bool _showInlineEditor = false;
  bool _isSavingEditor = false;

  static const List<Color> _palette = [
    Color(0xFF1A73E8),
    Color(0xFF26A69A),
    Color(0xFF7E57C2),
    Color(0xFFEF6C00),
    Color(0xFFE53935),
    Color(0xFF3949AB),
    Color(0xFF00897B),
    Color(0xFF8E24AA),
  ];

  static const List<_PresetReminder> _presets = [
    _PresetReminder(label: '15 دقيقة', minutes: 15),
    _PresetReminder(label: '30 دقيقة', minutes: 30),
    _PresetReminder(label: 'ساعة', minutes: 60),
    _PresetReminder(label: '4 ساعات', minutes: 240),
    _PresetReminder(label: 'يوم', minutes: 1440),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _daysCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(value.toLocal());
  }

  int _totalIntervalMinutes({
    required TextEditingController daysCtrl,
    required TextEditingController hourCtrl,
    required TextEditingController minuteCtrl,
  }) {
    final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
    final hours = int.tryParse(hourCtrl.text.trim()) ?? 0;
    final minutes = int.tryParse(minuteCtrl.text.trim()) ?? 0;
    return (days * 24 * 60) + (hours * 60) + minutes;
  }

  void _applyPreset(
    _PresetReminder preset,
    TextEditingController daysCtrl,
    TextEditingController hourCtrl,
    TextEditingController minuteCtrl,
  ) {
    final days = preset.minutes ~/ (24 * 60);
    final remainingAfterDays = preset.minutes % (24 * 60);
    final hours = remainingAfterDays ~/ 60;
    final minutes = remainingAfterDays % 60;

    daysCtrl.text = days.toString();
    hourCtrl.text = hours.toString();
    minuteCtrl.text = minutes.toString();
  }

  String _buildRepeatLabelFromMinutes(int totalMinutes) {
    final days = totalMinutes ~/ (24 * 60);
    final remainingAfterDays = totalMinutes % (24 * 60);
    final hours = remainingAfterDays ~/ 60;
    final minutes = remainingAfterDays % 60;
    final parts = <String>[];

    if (days > 0) parts.add('$days يوم');
    if (hours > 0) parts.add('$hours ساعة');
    if (minutes > 0) parts.add('$minutes دقيقة');

    return parts.isEmpty ? 'مرة واحدة' : parts.join(' • ');
  }

  void _populateEditor([NoteModel? note]) {
    _editingNote = note;
    _titleCtrl.text = note?.title ?? '';
    _msgCtrl.text = note?.message ?? '';
    _daysCtrl.text = note?.repeatDays.toString() ?? '0';
    _hourCtrl.text = note?.repeatHours.toString() ?? '0';
    _minuteCtrl.text = note?.repeatMinutes.toString() ?? '0';
    _selectedColor = note?.color ?? _palette.first;
  }

  void _openInlineEditor([NoteModel? note]) {
    FocusScope.of(context).unfocus();
    setState(() {
      _populateEditor(note);
      _showInlineEditor = true;
    });
  }

  void _closeInlineEditor() {
    FocusScope.of(context).unfocus();
    if (!_showInlineEditor) return;
    setState(() {
      _showInlineEditor = false;
      _isSavingEditor = false;
    });
  }

  Future<void> _submitInlineEditor(NoteProvider provider) async {
    final title = _titleCtrl.text.trim();
    final message = _msgCtrl.text.trim();
    final interval = _totalIntervalMinutes(
      daysCtrl: _daysCtrl,
      hourCtrl: _hourCtrl,
      minuteCtrl: _minuteCtrl,
    );

    if (title.isEmpty || interval <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل عنوانًا وحدد مدة تذكير صحيحة.'),
        ),
      );
      return;
    }

    setState(() => _isSavingEditor = true);

    final editingNote = _editingNote;
    final noteData = NoteModel(
      id: editingNote?.id ?? '',
      title: title,
      message: message,
      repeatDays: int.tryParse(_daysCtrl.text.trim()) ?? 0,
      repeatHours: int.tryParse(_hourCtrl.text.trim()) ?? 0,
      repeatMinutes: int.tryParse(_minuteCtrl.text.trim()) ?? 0,
      intervalMinutes: interval,
      nextRunAt: DateTime.now().add(Duration(minutes: interval)),
      active: true,
      createdAt: editingNote?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      colorHex: _selectedColor.value.toRadixString(16).substring(2).toUpperCase(),
    );

    final success = editingNote != null
        ? await provider.updateNote(noteData)
        : await provider.createNote(noteData);

    if (!mounted) return;

    if (success) {
      _closeInlineEditor();
      return;
    }

    setState(() => _isSavingEditor = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.error ?? 'تعذر حفظ المذكرة'),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, [NoteModel? note]) async {
    final provider = context.read<NoteProvider>();
    final isEdit = note != null;

    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final msgCtrl = TextEditingController(text: note?.message ?? '');
    final daysCtrl = TextEditingController(
      text: note?.repeatDays.toString() ?? '0',
    );
    final hourCtrl = TextEditingController(
      text: note?.repeatHours.toString() ?? '0',
    );
    final minuteCtrl = TextEditingController(
      text: note?.repeatMinutes.toString() ?? '0',
    );

    Color selectedColor = note?.color ?? _palette.first;

    await showGeneralDialog<void>(
      context: appNavigatorKey.currentContext!,
      barrierDismissible: true,
      barrierLabel: 'editor',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final intervalMinutes = _totalIntervalMinutes(
              daysCtrl: daysCtrl,
              hourCtrl: hourCtrl,
              minuteCtrl: minuteCtrl,
            );
            final nextRun = intervalMinutes > 0
                ? DateTime.now().add(Duration(minutes: intervalMinutes))
                : null;

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              const Color(0xFFF7FAFF),
                              const Color(0xFFEEF5FF),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDarkBlue.withValues(
                                alpha: 0.16,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 18),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.primaryBlue.withValues(alpha: 0.10),
                          ),
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.edit_note_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEdit
                                            ? 'تحديث المذكرة'
                                            : 'إضافة مذكرة جديدة',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryDarkBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'صمّم تذكيرك بشكل أوضح وسيصل تنبيه Push وإيميل عند انتهاء الوقت.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mediumGray,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'إغلاق',
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _EditorField(
                              controller: titleCtrl,
                              label: 'عنوان المذكرة',
                              hint: 'مثال: متابعة عرض السعر',
                              icon: Icons.title_rounded,
                            ),
                            const SizedBox(height: 14),
                            _EditorField(
                              controller: msgCtrl,
                              label: 'التفاصيل',
                              hint: 'اكتب تفاصيل التذكير أو ما يجب عمله عند انتهاء الوقت.',
                              icon: Icons.notes_rounded,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'اختصارات سريعة',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDarkBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _presets.map((preset) {
                                return ActionChip(
                                  label: Text(preset.label),
                                  avatar: const Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      _applyPreset(
                                        preset,
                                        daysCtrl,
                                        hourCtrl,
                                        minuteCtrl,
                                      );
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                    controller: daysCtrl,
                                    label: 'أيام',
                                    icon: Icons.calendar_today_outlined,
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _NumberField(
                                    controller: hourCtrl,
                                    label: 'ساعات',
                                    icon: Icons.schedule_outlined,
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _NumberField(
                                    controller: minuteCtrl,
                                    label: 'دقائق',
                                    icon: Icons.av_timer_outlined,
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لون المذكرة',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDarkBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _palette.map((color) {
                                final selected =
                                    color.value == selectedColor.value;
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() => selectedColor = color);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: selected ? 38 : 34,
                                    height: selected ? 38 : 34,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.42),
                                          blurRadius: selected ? 16 : 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: selected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.06,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    intervalMinutes > 0
                                        ? 'سيتم التذكير بعد ${_buildRepeatLabelFromMinutes(intervalMinutes)}'
                                        : 'حدد مدة صحيحة لبدء التذكير',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDarkBlue,
                                    ),
                                  ),
                                  if (nextRun != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'التنبيه القادم: ${_formatDateTime(nextRun)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mediumGray,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('إلغاء'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      final title = titleCtrl.text.trim();
                                      final message = msgCtrl.text.trim();
                                      final interval = _totalIntervalMinutes(
                                        daysCtrl: daysCtrl,
                                        hourCtrl: hourCtrl,
                                        minuteCtrl: minuteCtrl,
                                      );

                                      if (title.isEmpty || interval <= 0) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'أدخل عنوانًا وحدد مدة تذكير صحيحة.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final noteData = NoteModel(
                                        id: note?.id ?? '',
                                        title: title,
                                        message: message,
                                        repeatDays:
                                            int.tryParse(daysCtrl.text.trim()) ??
                                            0,
                                        repeatHours:
                                            int.tryParse(hourCtrl.text.trim()) ??
                                            0,
                                        repeatMinutes: int.tryParse(
                                              minuteCtrl.text.trim(),
                                            ) ??
                                            0,
                                        intervalMinutes: interval,
                                        nextRunAt: DateTime.now().add(
                                          Duration(minutes: interval),
                                        ),
                                        active: true,
                                        createdAt:
                                            note?.createdAt ?? DateTime.now(),
                                        updatedAt: DateTime.now(),
                                        colorHex: selectedColor.value
                                            .toRadixString(16)
                                            .substring(2)
                                            .toUpperCase(),
                                      );

                                      final success = isEdit
                                          ? await provider.updateNote(noteData)
                                          : await provider.createNote(noteData);

                                      if (!context.mounted) return;
                                      if (success) {
                                        Navigator.of(dialogContext).pop();
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              provider.error ?? 'تعذر حفظ المذكرة',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: const Icon(Icons.save_outlined),
                                    label: Text(isEdit ? 'حفظ التعديل' : 'إنشاء'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildInlineEditor(NoteProvider provider) {
    final isEdit = _editingNote != null;
    final intervalMinutes = _totalIntervalMinutes(
      daysCtrl: _daysCtrl,
      hourCtrl: _hourCtrl,
      minuteCtrl: _minuteCtrl,
    );
    final nextRun = intervalMinutes > 0
        ? DateTime.now().add(Duration(minutes: intervalMinutes))
        : null;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isSavingEditor ? null : _closeInlineEditor,
              child: Container(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          const Color(0xFFF7FAFF),
                          const Color(0xFFEEF5FF),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDarkBlue.withValues(alpha: 0.16),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: 0.10),
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: AppColors.accentGradient,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.edit_note_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEdit ? 'تحديث المذكرة' : 'إضافة مذكرة جديدة',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryDarkBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'تظهر نافذة الإضافة الآن داخل لوحة الملاحظات نفسها، وليس خلفها.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.mediumGray,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'إغلاق',
                                onPressed: _isSavingEditor ? null : _closeInlineEditor,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _EditorField(
                            controller: _titleCtrl,
                            label: 'عنوان المذكرة',
                            hint: 'مثال: متابعة عرض السعر',
                            icon: Icons.title_rounded,
                          ),
                          const SizedBox(height: 12),
                          _EditorField(
                            controller: _msgCtrl,
                            label: 'التفاصيل',
                            hint: 'اكتب تفاصيل التذكير أو ما يجب عمله عند انتهاء الوقت.',
                            icon: Icons.notes_rounded,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'اختصارات سريعة',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDarkBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _presets.map((preset) {
                              return ActionChip(
                                label: Text(preset.label),
                                avatar: const Icon(Icons.timer_outlined, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _applyPreset(
                                      preset,
                                      _daysCtrl,
                                      _hourCtrl,
                                      _minuteCtrl,
                                    );
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _NumberField(
                                  controller: _daysCtrl,
                                  label: 'أيام',
                                  icon: Icons.calendar_today_outlined,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _NumberField(
                                  controller: _hourCtrl,
                                  label: 'ساعات',
                                  icon: Icons.schedule_outlined,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _NumberField(
                                  controller: _minuteCtrl,
                                  label: 'دقائق',
                                  icon: Icons.av_timer_outlined,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'لون المذكرة',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDarkBlue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _palette.map((color) {
                              final selected = color.value == _selectedColor.value;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedColor = color);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: selected ? 38 : 34,
                                  height: selected ? 38 : 34,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.42),
                                        blurRadius: selected ? 16 : 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: selected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  intervalMinutes > 0
                                      ? 'سيتم التذكير بعد ${_buildRepeatLabelFromMinutes(intervalMinutes)}'
                                      : 'حدد مدة صحيحة لبدء التذكير',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDarkBlue,
                                  ),
                                ),
                                if (nextRun != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'التنبيه القادم: ${_formatDateTime(nextRun)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSavingEditor ? null : _closeInlineEditor,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('إلغاء'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isSavingEditor
                                      ? null
                                      : () => _submitInlineEditor(provider),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: _isSavingEditor
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(isEdit ? 'حفظ التعديل' : 'إنشاء'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, provider, _) {
        final notes = provider.notes;
        final now = DateTime.now();
        final activeCount = notes.where((note) => note.active).length;
        final dueCount = notes.where((note) => !note.nextRunAt.isAfter(now)).length;

        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SummaryChip(
                          icon: Icons.notifications_active_outlined,
                          label: '$activeCount تذكير نشط',
                          color: AppColors.primaryBlue,
                        ),
                        _SummaryChip(
                          icon: Icons.alarm_on_outlined,
                          label: '$dueCount مستحق الآن',
                          color: AppColors.warningOrange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _openInlineEditor(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('إضافة'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'يمكنك سحب النافذة من الشريط العلوي، تكبيرها أو تصغيرها، وسيصل عند انتهاء الوقت تنبيه داخل التطبيق وعلى الجوال والبريد.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : notes.isEmpty
                    ? _EmptyNotesState(
                        onCreate: () => _openInlineEditor(),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: notes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return _NoteCard(
                              note: note,
                              onEdit: () => _openInlineEditor(note),
                              onDelete: () async {
                                await provider.deleteNote(note.id);
                              },
                              formattedDate: _formatDateTime(note.nextRunAt),
                            );
                          },
                        ),
                      ),
              ),
                ],
              ),
            ),
            if (_showInlineEditor) _buildInlineEditor(provider),
          ],
        );
      },
    );
  }
}

class _EditorField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _EditorField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotesState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyNotesState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.sticky_note_2_outlined,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد مذكرات بعد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ابدأ أول تذكير لك، وسيتم إرسال تنبيه وقت الاستحقاق داخل التطبيق وعلى البريد والجوال.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.mediumGray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مذكرة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String formattedDate;

  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDue = !note.nextRunAt.isAfter(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: note.color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: note.color.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: note.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isDue ? AppColors.warningOrange : AppColors.successGreen)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isDue ? 'مستحق الآن' : 'نشط',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDue
                        ? AppColors.warningOrange
                        : AppColors.successGreen,
                  ),
                ),
              ),
            ],
          ),
          if (note.message.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              note.message.trim(),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: AppColors.mediumGray,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                icon: Icons.refresh_rounded,
                label: note.repeatLabel,
                color: AppColors.primaryBlue,
              ),
              _MetaPill(
                icon: Icons.alarm_rounded,
                label: formattedDate,
                color: AppColors.secondaryTeal,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('حذف'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.errorRed.withValues(alpha: 0.10),
                    foregroundColor: AppColors.errorRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetReminder {
  final String label;
  final int minutes;

  const _PresetReminder({required this.label, required this.minutes});
}
