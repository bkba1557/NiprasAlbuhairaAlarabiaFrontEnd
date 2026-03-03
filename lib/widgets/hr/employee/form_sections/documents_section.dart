import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class DocumentsSection extends StatelessWidget {
  final List<Map<String, dynamic>> documents;
  final ValueChanged<List<Map<String, dynamic>>> onDocumentsChanged;
  final Future<void> Function() onAddDocument;
  final bool isUploading;

  const DocumentsSection({
    super.key,
    required this.documents,
    required this.onDocumentsChanged,
    required this.onAddDocument,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'المستندات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...documents.asMap().entries.map((entry) {
            final index = entry.key;
            final doc = entry.value;
            return ListTile(
              key: ValueKey(index),
              leading: const Icon(Icons.insert_drive_file),
              title: Text(doc['name'] ?? 'وثيقة ${index + 1}'),
              subtitle: Text(doc['type'] ?? 'عام'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  final updated = List<Map<String, dynamic>>.from(documents)
                    ..removeAt(index);
                  onDocumentsChanged(updated);
                },
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add),
            label: Text(
              isUploading ? '???????? ??????????...' : '?????????? ??????????',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.hrPurple,
            ),
            onPressed: isUploading ? null : onAddDocument,
          ),
        ],
      ),
    );
  }
}
