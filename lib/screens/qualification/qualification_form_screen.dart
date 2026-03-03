import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:order_tracker/providers/qualification_provider.dart';
import 'package:order_tracker/models/qualification_models.dart';
import 'package:order_tracker/screens/tasks/task_location_picker_screen.dart';
import 'package:order_tracker/utils/constants.dart';

class QualificationStationFormScreen extends StatefulWidget {
  final QualificationStation? inspectionToEdit;

  const QualificationStationFormScreen({super.key, this.inspectionToEdit});

  @override
  State<QualificationStationFormScreen> createState() =>
      _QualificationStationFormScreenState();
}

class _QualificationStationFormScreenState
    extends State<QualificationStationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  QualificationStatus _status = QualificationStatus.underReview;
  LatLng? _selectedLatLng;
  final List<PlatformFile> _newAttachments = [];
  final List<QualificationAttachment> _existingAttachments = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final inspection = widget.inspectionToEdit;
    if (inspection != null) {
      _nameController.text = inspection.name;
      _ownerNameController.text = inspection.ownerName ?? '';
      _ownerPhoneController.text = inspection.ownerPhone ?? '';
      _cityController.text = inspection.city;
      _regionController.text = inspection.region;
      _addressController.text = inspection.address;
      _notesController.text = inspection.notes ?? '';
      _status = inspection.status;
      _existingAttachments
        ..clear()
        ..addAll(inspection.attachments);
      if (inspection.location != null) {
        _selectedLatLng = LatLng(
          inspection.location.lat,
          inspection.location.lng,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _statusLabel(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return 'تحت الدراسة';
      case QualificationStatus.negotiating:
        return 'جاري التفاوض';
      case QualificationStatus.agreed:
        return 'تم الاتفاق';
      case QualificationStatus.notAgreed:
        return 'لم يتم الاتفاق';
    }
  }

  Color _statusColor(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return Colors.amber.shade700;
      case QualificationStatus.negotiating:
        return Colors.blue.shade700;
      case QualificationStatus.agreed:
        return Colors.green;
      case QualificationStatus.notAgreed:
        return Colors.red;
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<TaskLocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskLocationPickerScreen(
          initialLat: _selectedLatLng?.latitude,
          initialLng: _selectedLatLng?.longitude,
          initialAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      _selectedLatLng = LatLng(result.latitude, result.longitude);
      if (_addressController.text.trim().isEmpty &&
          (result.address ?? '').trim().isNotEmpty) {
        _addressController.text = result.address!.trim();
      }
      if (_cityController.text.trim().isEmpty &&
          (result.city ?? '').trim().isNotEmpty) {
        _cityController.text = result.city!.trim();
      }
      if (_regionController.text.trim().isEmpty) {
        final region = result.district?.trim().isNotEmpty == true
            ? result.district!.trim()
            : result.city?.trim() ?? '';
        if (region.isNotEmpty) {
          _regionController.text = region;
        }
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLatLng == null) {
      _showSnackBar('يرجى تحديد موقع المحطة من الخريطة');
      return;
    }

    setState(() => _saving = true);
    try {
      final provider = context.read<QualificationProvider>();
      final uploaded = await provider.uploadAttachments(_newAttachments);
      final attachments = [
        ..._existingAttachments,
        ...uploaded,
      ];
      final location = QualificationLocation(
        lat: _selectedLatLng!.latitude,
        lng: _selectedLatLng!.longitude,
      );
      final payload = QualificationStation(
        id: widget.inspectionToEdit?.id ?? '',
        name: _nameController.text.trim(),
        ownerName: _ownerNameController.text.trim().isEmpty
            ? null
            : _ownerNameController.text.trim(),
        ownerPhone: _ownerPhoneController.text.trim().isEmpty
            ? null
            : _ownerPhoneController.text.trim(),
        city: _cityController.text.trim(),
        region: _regionController.text.trim(),
        address: _addressController.text.trim(),
        status: _status,
        createdAt: widget.inspectionToEdit?.createdAt ?? DateTime.now(),
        createdByName: widget.inspectionToEdit?.createdByName,
        location: location,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        attachments: attachments,
      );

      if (widget.inspectionToEdit == null) {
        await provider.createStation(payload);
      } else {
        await provider.updateStation(payload);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('تعذر حفظ المحطة');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
      ],
    );
    if (result == null) return;
    setState(() {
      _newAttachments.addAll(result.files);
    });
  }

  void _removeNewAttachment(PlatformFile file) {
    setState(() {
      _newAttachments.remove(file);
    });
  }

  void _removeExistingAttachment(QualificationAttachment attachment) {
    setState(() {
      _existingAttachments.remove(attachment);
    });
  }

  String _attachmentLabel(String name) {
    if (name.length <= 24) return name;
    return '${name.substring(0, 21)}...';
  }

  Widget _buildStationFieldsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 1;
        if (width >= 1200) {
          columns = 3;
        } else if (width >= 800) {
          columns = 2;
        }

        final fields = <Widget>[
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'اسم المحطة',
              prefixIcon: Icon(Icons.local_gas_station),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال اسم المحطة';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _ownerNameController,
            decoration: const InputDecoration(
              labelText: 'اسم المالك',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          TextFormField(
            controller: _ownerPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[0-9+ ]'),
              ),
            ],
            decoration: const InputDecoration(
              labelText: 'رقم الجوال',
              prefixIcon: Icon(Icons.phone_android),
            ),
          ),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'المدينة',
              prefixIcon: Icon(Icons.location_city),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال المدينة';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _regionController,
            decoration: const InputDecoration(
              labelText: 'المنطقة',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال المنطقة';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال العنوان';
              }
              return null;
            },
          ),
        ];

        final rows = <Widget>[];
        for (var i = 0; i < fields.length; i += columns) {
          final rowChildren = <Widget>[];
          for (var j = 0; j < columns; j++) {
            if (i + j < fields.length) {
              rowChildren.add(Expanded(child: fields[i + j]));
            } else {
              rowChildren.add(const Expanded(child: SizedBox()));
            }
            if (j < columns - 1) {
              rowChildren.add(const SizedBox(width: 12));
            }
          }
          rows.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowChildren,
          ));
          rows.add(const SizedBox(height: 12));
        }
        if (rows.isNotEmpty) {
          rows.removeLast();
        }

        return Column(children: rows);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inspectionToEdit == null
            ? 'إضافة محطة تأهيل'
            : 'تعديل محطة التأهيل'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'بيانات المحطة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
            ),
            const SizedBox(height: 12),
            _buildStationFieldsGrid(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'حالة التأهيل',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor(_status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor(_status)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: _statusColor(_status)),
                  const SizedBox(width: 8),
                  Text(_statusLabel(_status)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'تحديد الموقع',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _selectedLatLng == null
                    ? 'تحديد الموقع من الخريطة'
                    : 'تعديل موقع المحطة',
              ),
            ),
            if (_selectedLatLng != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإحداثيات',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_selectedLatLng!.latitude.toStringAsFixed(6)}, '
                      '${_selectedLatLng!.longitude.toStringAsFixed(6)}',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'المرفقات (اختياري)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickAttachments,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _newAttachments.isEmpty
                    ? 'إرفاق صور أو فيديو'
                    : 'تم إضافة ${_newAttachments.length} ملف',
              ),
            ),
            if (_existingAttachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _existingAttachments.map((attachment) {
                  return InputChip(
                    label: Text(_attachmentLabel(attachment.name)),
                    onDeleted: () => _removeExistingAttachment(attachment),
                  );
                }).toList(),
              ),
            ],
            if (_newAttachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _newAttachments.map((file) {
                  return InputChip(
                    label: Text(_attachmentLabel(file.name)),
                    onDeleted: () => _removeNewAttachment(file),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label:
                    Text(_saving ? 'جاري الحفظ...' : 'حفظ بيانات المحطة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
