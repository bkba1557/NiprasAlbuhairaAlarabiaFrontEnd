import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:order_tracker/models/note_model.dart';
import 'package:order_tracker/providers/note_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/app_navigation.dart'; // the global navigatorKey
import 'package:provider/provider.dart';

class QuickNotesPanel extends StatefulWidget {
  final VoidCallback onClose;
  const QuickNotesPanel({super.key, required this.onClose});

  @override
  State<QuickNotesPanel> createState() => _QuickNotesPanelState();
}

class _QuickNotesPanelState extends State<QuickNotesPanel> {
  /* ---------- اللون ---------- */
  Future<Color?> _pickColor(BuildContext context, Color current) async {
    Color selected = current;
    return await showDialog<Color>(
      context: appNavigatorKey.currentContext!,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('اختر لون المذكرة'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: current,
            availableColors: const [
              Colors.red,
              Colors.pink,
              Colors.deepPurple,
              Colors.indigo,
              Colors.blue,
              Colors.cyan,
              Colors.teal,
              Colors.green,
              Colors.lime,
              Colors.yellow,
              Colors.amber,
              Colors.orange,
              Colors.deepOrange,
              Colors.brown,
              Colors.grey,
              Colors.black,
            ],
            onColorChanged: (c) => selected = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(selected),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  /* ---------- محرّر الملاحظة ---------- */
  Future<void> _openEditor(BuildContext ctx, [NoteModel? note]) async {
    final provider = ctx.read<NoteProvider>();
    final bool isEdit = note != null;

    final Color initColor = note?.color ?? const Color(0xFF2196F3);
    Color chosenColor = initColor;

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

    await showDialog<void>(
      context: appNavigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'تعديل المذكرة' : 'إضافة مذكرة جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // العنوان
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),

              // المحتوى
              TextField(
                controller: msgCtrl,
                decoration: const InputDecoration(
                  labelText: 'المحتوى',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // الفواصل الزمنية
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: daysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'أيام',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: hourCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ساعات',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: minuteCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'دقائق',
                        prefixIcon: Icon(Icons.timer),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // اختيار اللون
              Row(
                children: [
                  const Text('اللون:'),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final c = await _pickColor(context, chosenColor);
                      if (c != null) setState(() => chosenColor = c);
                    },
                    child: CircleAvatar(
                      backgroundColor: chosenColor,
                      radius: 14,
                      child: const Icon(
                        Icons.palette,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('حفظ'),
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final message = msgCtrl.text.trim();
              final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
              final hours = int.tryParse(hourCtrl.text.trim()) ?? 0;
              final minutes = int.tryParse(minuteCtrl.text.trim()) ?? 0;
              final interval = days * 24 * 60 + hours * 60 + minutes;

              if (title.isEmpty || interval <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('أدخل عنواناً وفترة تذكير صحيحة.'),
                  ),
                );
                return;
              }

              final noteData = NoteModel(
                id: note?.id ?? '',
                title: title,
                message: message,
                repeatDays: days,
                repeatHours: hours,
                repeatMinutes: minutes,
                intervalMinutes: interval,
                nextRunAt: DateTime.now().add(Duration(minutes: interval)),
                active: true,
                createdAt: note?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
                // اللون كـ HEX
                colorHex: chosenColor.value
                    .toRadixString(16)
                    .substring(2) // نحذف الـ alpha (FF)
                    .toUpperCase(),
              );

              final success = isEdit
                  ? await provider.updateNote(noteData)
                  : await provider.createNote(noteData);

              if (success) Navigator.of(dialogCtx).pop();
            },
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

        /* ---------------------------------------------------------
         *  لا خلفية أو ظل داخل هذه الـ Panel.
         *  كلّ ما يُظهر هو ما يقدِّمه الـ DraggableResizablePanel
         *  (الظل، اللون الخلفي، الزوايا المستديرة).
         * --------------------------------------------------------- */
        return Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // ---------- رأس الـ Panel ----------
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.appBarWaterMid.withOpacity(0.12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'الملاحظات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // ---------- محتوى القائمة ----------
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : notes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'لا توجد مذكرات بعد. اضغط إضافة لبدء التذكير.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: notes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return _NoteTile(
                            note: note,
                            onEdit: () => _openEditor(context, note),
                            onDelete: () async {
                              await provider.deleteNote(note.id);
                            },
                          );
                        },
                      ),
              ),

              // ---------- زر الإضافة ----------
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('إضافة مذكرة جديدة'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* -----------------------------------------------------------------
   Tile عرض كل مذكرة (يبقى كما هو)
   ----------------------------------------------------------------- */
class _NoteTile extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _NoteTile({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final soonText = note.nextRunAt.isAfter(DateTime.now())
        ? 'التذكير التالي: ${note.nextRunAt.toLocal().toString().split('.').first}'
        : 'التذكير مستحق الآن';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان + لون المذكرة
            Row(
              children: [
                CircleAvatar(backgroundColor: note.color, radius: 8),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (!note.active)
                  Chip(
                    label: const Text('متوقف'),
                    backgroundColor: AppColors.errorRed.withOpacity(0.16),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (note.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(note.message),
              ),
            // الفاصل الزمني
            Text(
              note.repeatLabel,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            // تاريخ التذكير
            Text(
              soonText,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_document, size: 18),
                  label: const Text('تعديل'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('حذف'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
