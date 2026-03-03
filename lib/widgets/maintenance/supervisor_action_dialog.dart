import 'package:flutter/material.dart';

class SupervisorActionDialog extends StatelessWidget {
  final String maintenanceId;
  final VoidCallback onSendWarning;
  final VoidCallback onSendNote;

  const SupervisorActionDialog({
    super.key,
    required this.maintenanceId,
    required this.onSendWarning,
    required this.onSendNote,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إجراءات المشرف'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.orange),
            title: const Text('إرسال تحذير'),
            subtitle: const Text('إرسال تحذير للموظف'),
            onTap: () {
              Navigator.pop(context);
              onSendWarning();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.note, color: Colors.blue),
            title: const Text('إرسال ملاحظة'),
            subtitle: const Text('إرسال ملاحظة للموظف'),
            onTap: () {
              Navigator.pop(context);
              onSendNote();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.purple),
            title: const Text('جدولة صيانة'),
            subtitle: const Text('جدولة صيانة للمركبة'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement schedule maintenance
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
