import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:order_tracker/widgets/maps/advanced_web_map.dart';

import 'package:order_tracker/providers/marketing_station_provider.dart';
import 'package:order_tracker/utils/constants.dart';

import 'marketing_models.dart';

class MarketingStationFormScreen extends StatefulWidget {
  final MarketingStation? stationToEdit;

  const MarketingStationFormScreen({super.key, this.stationToEdit});

  @override
  State<MarketingStationFormScreen> createState() =>
      _MarketingStationFormScreenState();
}

class _MarketingStationFormScreenState
    extends State<MarketingStationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerIdController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _ownerAddressController = TextEditingController();
  final _ownerEjarController = TextEditingController();
  final _stationCostController = TextEditingController();
  final _leaseAmountController = TextEditingController();
  final List<MarketingPump> _pumps = [];
  final List<XFile> _attachments = [];
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  bool _locating = false;

  StationMarketingStatus _status = StationMarketingStatus.pendingReview;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final station = widget.stationToEdit;
    if (station != null) {
      _nameController.text = station.name;
      _cityController.text = station.city;
      _addressController.text = station.address;
      _notesController.text = station.notes ?? '';
      _status = station.status;
      final owner = station.owner;
      if (owner != null) {
        _ownerNameController.text = owner.name;
        _ownerIdController.text = owner.idNumber;
        _ownerPhoneController.text = owner.phone;
        _ownerAddressController.text = owner.address;
        _ownerEjarController.text = owner.ejarContractNumber;
      }
      _stationCostController.text =
          station.accounting.stationCost == 0
              ? ''
              : station.accounting.stationCost.toStringAsFixed(2);
      _leaseAmountController.text =
          station.accounting.leaseAmount == 0
              ? ''
              : station.accounting.leaseAmount.toStringAsFixed(2);
      if (station.location != null) {
        _latController.text = station.location!.lat.toString();
        _lngController.text = station.location!.lng.toString();
        _selectedLatLng = LatLng(
          station.location!.lat,
          station.location!.lng,
        );
      }
      _pumps.addAll(station.pumps);
      // محضر الاستلام يتم التعامل معه في صفحة منفصلة.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _ownerNameController.dispose();
    _ownerIdController.dispose();
    _ownerPhoneController.dispose();
    _ownerAddressController.dispose();
    _ownerEjarController.dispose();
    _stationCostController.dispose();
    _leaseAmountController.dispose();
    super.dispose();
  }

  void _addPump() {
    showDialog<void>(
      context: context,
      builder: (_) => _PumpDialog(
        onSave: (pump) => setState(() => _pumps.add(pump)),
      ),
    );
  }

  void _removePump(int index) {
    setState(() => _pumps.removeAt(index));
  }

  Future<void> _pickImages(ImageSource source) async {
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file != null) {
        setState(() => _attachments.add(file));
      }
      return;
    }

    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() => _attachments.addAll(files));
    }
  }

  Future<void> _setCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await _determinePosition();
      if (position == null) return;
      _updateLocation(
        LatLng(position.latitude, position.longitude),
      );
      if (!kIsWeb) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<Position?> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('يرجى تفعيل خدمات الموقع أولاً');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      _showSnackBar('تم رفض صلاحية الموقع');
      return null;
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('تم رفض صلاحية الموقع نهائياً من الإعدادات');
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _updateLocation(LatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
      _latController.text = latLng.latitude.toStringAsFixed(6);
      _lngController.text = latLng.longitude.toStringAsFixed(6);
    });
  }

  void _syncMapFromFields() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return;
    _updateLocation(LatLng(lat, lng));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _mapLink() {
    if (_selectedLatLng == null) return null;
    final lat = _selectedLatLng!.latitude;
    final lng = _selectedLatLng!.longitude;
    return 'https://www.google.com/maps?q=$lat,$lng';
  }

  bool get _supportsGoogleMaps {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _openExternalMap({bool directions = false}) async {
    final latLng = _selectedLatLng;
    final url = latLng == null
        ? 'https://www.google.com/maps'
        : directions
            ? 'https://www.google.com/maps/dir/?api=1&destination=${latLng.latitude},${latLng.longitude}'
            : 'https://www.google.com/maps?q=${latLng.latitude},${latLng.longitude}';
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('تعذر فتح الخرائط');
    }
  }

  Widget _buildMapArea() {
    if (_supportsGoogleMaps) {
      if (kIsWeb) {
        final center = _selectedLatLng ?? const LatLng(24.7136, 46.6753);
        return AdvancedWebMap(
          center: center,
          zoom: _selectedLatLng == null ? 6 : 14,
          primaryMarker: _selectedLatLng,
          onTap: _updateLocation,
        );
      }

      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _selectedLatLng ?? const LatLng(24.7136, 46.6753),
          zoom: _selectedLatLng == null ? 6 : 14,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: _selectedLatLng == null
            ? {}
            : {
                Marker(
                  markerId: const MarkerId('station-location'),
                  position: _selectedLatLng!,
                ),
              },
        onTap: _updateLocation,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      );
    }

    return Container(
      color: AppColors.backgroundGray,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 42, color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            'خرائط Google غير مدعومة على Windows داخل التطبيق.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك تحديد موقعك بزر "تحديد موقعي الآن" أو فتح الخرائط في المتصفح.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mediumGray),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openExternalMap(directions: false),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('فتح الخرائط'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openExternalMap(directions: true),
                icon: const Icon(Icons.directions),
                label: const Text('فتح المسار'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  MarketingStation _buildStation() {
    StationLocation? location;
    if (_latController.text.isNotEmpty && _lngController.text.isNotEmpty) {
      location = StationLocation(
        lat: double.tryParse(_latController.text.trim()) ?? 0,
        lng: double.tryParse(_lngController.text.trim()) ?? 0,
      );
    }
    StationOwner? owner;
    if (_ownerNameController.text.trim().isNotEmpty ||
        _ownerPhoneController.text.trim().isNotEmpty ||
        _ownerIdController.text.trim().isNotEmpty ||
        _ownerAddressController.text.trim().isNotEmpty ||
        _ownerEjarController.text.trim().isNotEmpty) {
      owner = StationOwner(
        name: _ownerNameController.text.trim(),
        phone: _ownerPhoneController.text.trim(),
        idNumber: _ownerIdController.text.trim(),
        address: _ownerAddressController.text.trim(),
        ejarContractNumber: _ownerEjarController.text.trim(),
      );
    }

    final existingAccounting =
        widget.stationToEdit?.accounting ?? const MarketingAccounting();
    final stationCost =
        double.tryParse(_stationCostController.text.trim()) ?? 0;
    final leaseAmount =
        double.tryParse(_leaseAmountController.text.trim()) ?? 0;

    return MarketingStation(
      id: widget.stationToEdit?.id ?? '',
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      status: _status,
      createdAt: widget.stationToEdit?.createdAt ?? DateTime.now(),
      createdByName: widget.stationToEdit?.createdByName,
      pumps: _pumps,
      location: location,
      owner: owner,
      notes: _notesController.text.trim(),
      attachments: widget.stationToEdit?.attachments ?? const [],
      tenantName: widget.stationToEdit?.tenantName,
      lease: widget.stationToEdit?.lease,
      accounting: MarketingAccounting(
        stationCost: stationCost,
        leaseAmount: leaseAmount,
        expenses: existingAccounting.expenses,
        revenue: existingAccounting.revenue,
      ),
      handoverReport: widget.stationToEdit?.handoverReport,
      expenseVouchers: widget.stationToEdit?.expenseVouchers ?? const [],
      receiptVouchers: widget.stationToEdit?.receiptVouchers ?? const [],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pumps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إضافة مضخة واحدة على الأقل'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final provider = context.read<MarketingStationProvider>();
    final station = _buildStation();
    MarketingStation? result;

    if (widget.stationToEdit == null) {
      result = await provider.createStation(station);
    } else {
      result = await provider.updateStation(station);
    }

    if (result == null) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'فشل حفظ المحطة')),
        );
      }
      return;
    }

    if (_attachments.isNotEmpty) {
      final urls =
          await provider.uploadAttachments(result.id, _attachments);
      await provider.addAttachments(result.id, urls);
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.stationToEdit == null ? 'إضافة محطة' : 'تعديل محطة',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionTitle('بيانات المحطة الأساسية'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'اسم المحطة',
              icon: Icons.local_gas_station,
            ),
            const SizedBox(height: 12),
            isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _cityController,
                          label: 'المدينة',
                          icon: Icons.location_city,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _addressController,
                          label: 'العنوان',
                          icon: Icons.place,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(
                        controller: _cityController,
                        label: 'المدينة',
                        icon: Icons.location_city,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _addressController,
                        label: 'العنوان',
                        icon: Icons.place,
                      ),
                    ],
                  ),
            const SizedBox(height: 12),
            _sectionTitle('حالة المحطة'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StationMarketingStatus.values.map((status) {
                final isSelected = _status == status;
                return ChoiceChip(
                  label: Text(_statusLabel(status)),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                  onSelected: (_) => setState(() => _status = status),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _sectionTitle('بيانات مالك المحطة'),
            const SizedBox(height: 12),
            isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _ownerNameController,
                          label: 'اسم المالك',
                          icon: Icons.person,
                          requiredField: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _ownerIdController,
                          label: 'رقم الهوية',
                          icon: Icons.badge,
                          requiredField: false,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(
                        controller: _ownerNameController,
                        label: 'اسم المالك',
                        icon: Icons.person,
                        requiredField: false,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _ownerIdController,
                        label: 'رقم الهوية',
                        icon: Icons.badge,
                        requiredField: false,
                      ),
                    ],
                  ),
            const SizedBox(height: 12),
            isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _ownerPhoneController,
                          label: 'رقم الجوال',
                          icon: Icons.phone,
                          requiredField: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _ownerEjarController,
                          label: 'رقم عقد منصة إيجار',
                          icon: Icons.assignment,
                          requiredField: false,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(
                        controller: _ownerPhoneController,
                        label: 'رقم الجوال',
                        icon: Icons.phone,
                        requiredField: false,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _ownerEjarController,
                        label: 'رقم عقد منصة إيجار',
                        icon: Icons.assignment,
                        requiredField: false,
                      ),
                    ],
                  ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _ownerAddressController,
              label: 'عنوان المالك',
              icon: Icons.home_work,
              requiredField: false,
            ),
            const SizedBox(height: 20),
            _sectionTitle('بيانات التأجير'),
            const SizedBox(height: 12),
            isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _stationCostController,
                          label: 'تكلفة استئجار المحطة (ر.س)',
                          icon: Icons.money_off,
                          keyboardType: TextInputType.number,
                          requiredField: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _leaseAmountController,
                          label: 'سعر تأجيرها للمستأجر (ر.س)',
                          icon: Icons.payments,
                          keyboardType: TextInputType.number,
                          requiredField: false,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(
                        controller: _stationCostController,
                        label: 'تكلفة استئجار المحطة (ر.س)',
                        icon: Icons.money_off,
                        keyboardType: TextInputType.number,
                        requiredField: false,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _leaseAmountController,
                        label: 'سعر تأجيرها للمستأجر (ر.س)',
                        icon: Icons.payments,
                        keyboardType: TextInputType.number,
                        requiredField: false,
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            _sectionTitle('تحديد الموقع'),
            const SizedBox(height: 12),
            isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _latController,
                          label: 'خط العرض',
                          icon: Icons.my_location,
                          keyboardType: TextInputType.number,
                          requiredField: false,
                          onChanged: (_) => _syncMapFromFields(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _lngController,
                          label: 'خط الطول',
                          icon: Icons.my_location,
                          keyboardType: TextInputType.number,
                          requiredField: false,
                          onChanged: (_) => _syncMapFromFields(),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(
                        controller: _latController,
                        label: 'خط العرض',
                        icon: Icons.my_location,
                        keyboardType: TextInputType.number,
                        requiredField: false,
                        onChanged: (_) => _syncMapFromFields(),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _lngController,
                        label: 'خط الطول',
                        icon: Icons.my_location,
                        keyboardType: TextInputType.number,
                        requiredField: false,
                        onChanged: (_) => _syncMapFromFields(),
                      ),
                    ],
                  ),
            const SizedBox(height: 8),
            Text(
              'يمكنك إدخال الإحداثيات مباشرة أو اختيارها من الخريطة.',
              style: TextStyle(color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _locating ? null : _setCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(_locating ? 'جاري التحديد...' : 'تحديد موقعي الآن'),
                ),
                OutlinedButton.icon(
                  onPressed: _syncMapFromFields,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث الخريطة'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMapArea(),
              ),
            ),
            if (_mapLink() != null) ...[
              const SizedBox(height: 8),
              Text(
                'رابط الموقع: ${_mapLink()}',
                style: TextStyle(color: AppColors.mediumGray),
              ),
            ],
            const SizedBox(height: 20),
            _sectionTitle('صور المحطة'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickImages(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('تصوير'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImages(ImageSource.gallery),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('رفع صور'),
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'تم اختيار ${_attachments.length} صورة',
                style: TextStyle(color: AppColors.mediumGray),
              ),
            ],
            const SizedBox(height: 20),
            _sectionTitle('المضخات وقراءات الفتح'),
            const SizedBox(height: 12),
            if (_pumps.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: const Text('لم يتم إضافة مضخات بعد'),
              ),
            if (_pumps.isNotEmpty)
              ..._pumps.asMap().entries.map((entry) {
                final index = entry.key;
                final pump = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(pump.type),
                    subtitle: Text(
                      'عدد الليّات: ${pump.nozzleCount} • قراءة الفتح: ${pump.totalOpeningReading.toStringAsFixed(2)} • الأنواع: ${_pumpFuelTypes(pump)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _removePump(index),
                    ),
                  ),
                );
              }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addPump,
                icon: const Icon(Icons.add),
                label: const Text('إضافة مضخة'),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('ملاحظات'),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب تفاصيل إضافية عن المحطة...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.save),
              label: Text(
                _saving
                    ? 'جارٍ الحفظ...'
                    : (widget.stationToEdit == null
                        ? 'حفظ المحطة'
                        : 'تحديث المحطة'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }


  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = true,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (requiredField && (value == null || value.trim().isEmpty)) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }

  String _statusLabel(StationMarketingStatus status) {
    switch (status) {
      case StationMarketingStatus.pendingReview:
        return 'تحت المراجعة';
      case StationMarketingStatus.readyForLease:
        return 'جاهزة للتأجير';
      case StationMarketingStatus.rented:
        return 'مؤجرة';
      case StationMarketingStatus.rentedToNasserMotairi:
        return 'مستأجرة لشركة ناصر المطيري';
      case StationMarketingStatus.cancelled:
        return 'ملغية';
      case StationMarketingStatus.maintenance:
        return 'تحت الصيانة';
      case StationMarketingStatus.study:
        return 'تحت الدراسة';
    }
  }

  String _pumpFuelTypes(MarketingPump pump) {
    final types = pump.nozzles
        .map((nozzle) => _fuelTypeLabel(nozzle.fuelType))
        .toSet()
        .toList();
    if (types.isEmpty) return '-';
    return types.join('، ');
  }

  String _fuelTypeLabel(FuelType type) {
    switch (type) {
      case FuelType.gas91:
        return 'بنزين 91';
      case FuelType.gas95:
        return 'بنزين 95';
      case FuelType.diesel:
        return 'ديزل';
      case FuelType.kerosene:
        return 'كيروسين';
    }
  }
}

class _PumpDialog extends StatefulWidget {
  final void Function(MarketingPump pump) onSave;

  const _PumpDialog({required this.onSave});

  @override
  State<_PumpDialog> createState() => _PumpDialogState();
}

class _NozzleDraft {
  FuelType fuelType;
  NozzleStatus status;
  final TextEditingController readingController;

  _NozzleDraft({
    required this.fuelType,
    required this.status,
    required this.readingController,
  });
}

class _PumpDialogState extends State<_PumpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _nozzleCountController = TextEditingController(text: '2');
  PumpCondition _status = PumpCondition.good;
  final List<_NozzleDraft> _nozzles = [];

  @override
  void initState() {
    super.initState();
    _applyNozzleCount();
  }

  @override
  void dispose() {
    _typeController.dispose();
    _nozzleCountController.dispose();
    for (final nozzle in _nozzles) {
      nozzle.readingController.dispose();
    }
    super.dispose();
  }

  void _applyNozzleCount() {
    final count = int.tryParse(_nozzleCountController.text.trim()) ?? 0;
    if (count <= 0) return;
    setState(() {
      for (final nozzle in _nozzles) {
        nozzle.readingController.dispose();
      }
      _nozzles
        ..clear()
        ..addAll(
          List.generate(
            count,
            (_) => _NozzleDraft(
              fuelType: FuelType.gas91,
              status: NozzleStatus.good,
              readingController: TextEditingController(),
            ),
          ),
        );
    });
  }

  double _totalOpeningReading() {
    return _nozzles.fold<double>(
      0,
      (total, nozzle) =>
          total + (double.tryParse(nozzle.readingController.text.trim()) ?? 0),
    );
  }

  Map<FuelType, double> _fuelTotals() {
    final totals = <FuelType, double>{};
    for (final nozzle in _nozzles) {
      final reading =
          double.tryParse(nozzle.readingController.text.trim()) ?? 0;
      totals[nozzle.fuelType] = (totals[nozzle.fuelType] ?? 0) + reading;
    }
    return totals;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_nozzles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد عدد الليّات أولاً')),
      );
      return;
    }

    final nozzleCount = _nozzles.length;
    final totalOpening = _totalOpeningReading();
    for (final nozzle in _nozzles) {
      final reading = double.tryParse(nozzle.readingController.text.trim());
      if (reading == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال قراءة لكل لي')),
        );
        return;
      }
    }

    widget.onSave(
      MarketingPump(
        id: '',
        type: _typeController.text.trim(),
        nozzleCount: nozzleCount,
        status: _status,
        nozzles: _nozzles.asMap().entries.map((entry) {
          final index = entry.key;
          final nozzle = entry.value;
          return MarketingNozzle(
            nozzleNumber: index + 1,
            status: nozzle.status,
            fuelType: nozzle.fuelType,
            openingReading:
                double.tryParse(nozzle.readingController.text.trim()) ?? 0,
          );
        }).toList(),
        openingReading: totalOpening,
        openingReadingDate: DateTime.now(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مضخة'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: 'نوع المضخة',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nozzleCountController,
                decoration: const InputDecoration(
                  labelText: 'عدد الليّات',
                ),
                keyboardType: TextInputType.number,
                validator: _required,
                onChanged: (_) => _applyNozzleCount(),
              ),
              const SizedBox(height: 12),
              const Text('حالة المضخة'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: PumpCondition.values.map((status) {
                  return ChoiceChip(
                    label: Text(_pumpStatusLabel(status)),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('تفاصيل كل لي'),
              const SizedBox(height: 6),
              Column(
                children: _nozzles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final nozzle = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لي رقم ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<FuelType>(
                                value: nozzle.fuelType,
                                items: FuelType.values.map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(_fuelTypeLabel(value)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => nozzle.fuelType = value);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'نوع الوقود',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<NozzleStatus>(
                                value: nozzle.status,
                                items: NozzleStatus.values.map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(_nozzleLabel(value)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => nozzle.status = value);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'حالة اللي',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: nozzle.readingController,
                          keyboardType: TextInputType.number,
                          validator: _required,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'قراءة اللي',
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (_nozzles.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text(
                  'إجمالي القراءة حسب نوع الوقود',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...FuelType.values.map((type) {
                  final total = _fuelTotals()[type] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(_fuelTypeLabel(type))),
                        Text('${total.toStringAsFixed(2)} قراءة'),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'إجمالي قراءة الفتح للمضخة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text('${_totalOpeningReading().toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('حفظ المضخة'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'مطلوب';
    }
    return null;
  }

  String _pumpStatusLabel(PumpCondition status) {
    switch (status) {
      case PumpCondition.good:
        return 'سليمة';
      case PumpCondition.damaged:
        return 'تالفة';
      case PumpCondition.needsMaintenance:
        return 'تحتاج صيانة';
    }
  }

  String _nozzleLabel(NozzleStatus status) {
    switch (status) {
      case NozzleStatus.good:
        return 'سليمة';
      case NozzleStatus.damaged:
        return 'تالفة';
      case NozzleStatus.needsMaintenance:
        return 'تحتاج صيانة';
    }
  }

  String _fuelTypeLabel(FuelType type) {
    switch (type) {
      case FuelType.gas91:
        return 'بنزين 91';
      case FuelType.gas95:
        return 'بنزين 95';
      case FuelType.diesel:
        return 'ديزل';
      case FuelType.kerosene:
        return 'كيروسين';
    }
  }
}
