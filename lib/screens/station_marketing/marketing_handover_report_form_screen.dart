import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:order_tracker/providers/marketing_station_provider.dart';
import 'package:order_tracker/utils/constants.dart';

import 'marketing_models.dart';

class MarketingHandoverReportFormScreen extends StatefulWidget {
  final MarketingStation station;

  const MarketingHandoverReportFormScreen({super.key, required this.station});

  @override
  State<MarketingHandoverReportFormScreen> createState() =>
      _MarketingHandoverReportFormScreenState();
}

class _MarketingHandoverReportFormScreenState
    extends State<MarketingHandoverReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late MarketingStation _station;

  final _reportNumberController = TextEditingController();
  final _reportDayController = TextEditingController();
  final _reportHijriDateController = TextEditingController();
  final _reportGregorianDateController = TextEditingController();
  final _stationNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _streetController = TextEditingController();
  final _civilLicenseNumberController = TextEditingController();
  final _civilLicenseDateController = TextEditingController();
  final _municipalityLicenseNumberController = TextEditingController();
  final _municipalityLicenseDateController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _representativeNameController = TextEditingController();
  final _authorizationNumberController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyRepresentativeController = TextEditingController();
  final _contractReferenceController = TextEditingController();
  final _dispensersCountController = TextEditingController();
  final _doubleDispensersCountController = TextEditingController();

  final List<FuelDispenserRow> _fuelDispensers = [];
  final List<FuelTankRow> _fuelTanks = [];
  final List<SubmersiblePumpRow> _submersiblePumps = [];
  final List<StationEquipmentRow> _equipment = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _station = widget.station;
    final report = _station.handoverReport;

    _reportNumberController.text =
        report?.reportNumber ?? _generateReportNumber();
    _contractReferenceController.text =
        report?.contractReference ?? _generateContractReference();

    _reportDayController.text = report?.dayName ?? '';
    _reportHijriDateController.text = report?.hijriDate ?? '';
    _reportGregorianDateController.text = report?.gregorianDate ?? '';
    _stationNameController.text =
        report?.stationName.isNotEmpty == true ? report!.stationName : _station.name;
    _cityController.text =
        report?.city.isNotEmpty == true ? report!.city : _station.city;
    _districtController.text = report?.district ?? '';
    _streetController.text =
        report?.street.isNotEmpty == true ? report!.street : _station.address;
    _civilLicenseNumberController.text = report?.civilLicenseNumber ?? '';
    _civilLicenseDateController.text = report?.civilLicenseDate ?? '';
    _municipalityLicenseNumberController.text =
        report?.municipalityLicenseNumber ?? '';
    _municipalityLicenseDateController.text =
        report?.municipalityLicenseDate ?? '';
    _ownerNameController.text = report?.ownerName ?? '';
    _representativeNameController.text = report?.representativeName ?? '';
    _authorizationNumberController.text = report?.authorizationNumber ?? '';
    _companyNameController.text =
        report?.companyName.isNotEmpty == true
            ? report!.companyName
            : (_station.tenantName ?? '');
    _companyRepresentativeController.text =
        report?.companyRepresentativeName ?? '';
    _dispensersCountController.text = report?.dispensersCount ?? '';
    _doubleDispensersCountController.text =
        report?.doubleDispensersCount ?? '';

    if (report != null) {
      _fuelDispensers.addAll(report.fuelDispensers);
      _fuelTanks.addAll(report.fuelTanks);
      _submersiblePumps.addAll(report.submersiblePumps);
      _equipment.addAll(report.equipment);
    }
    _ensureDefaultReportRows();
  }

  @override
  void dispose() {
    _reportNumberController.dispose();
    _reportDayController.dispose();
    _reportHijriDateController.dispose();
    _reportGregorianDateController.dispose();
    _stationNameController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _streetController.dispose();
    _civilLicenseNumberController.dispose();
    _civilLicenseDateController.dispose();
    _municipalityLicenseNumberController.dispose();
    _municipalityLicenseDateController.dispose();
    _ownerNameController.dispose();
    _representativeNameController.dispose();
    _authorizationNumberController.dispose();
    _companyNameController.dispose();
    _companyRepresentativeController.dispose();
    _contractReferenceController.dispose();
    _dispensersCountController.dispose();
    _doubleDispensersCountController.dispose();
    super.dispose();
  }

  String _generateReportNumber() {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final suffix = _station.id.length >= 4
        ? _station.id.substring(_station.id.length - 4).toUpperCase()
        : _station.id.toUpperCase();
    return 'MR-$date-$suffix';
  }

  String _generateContractReference() {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final suffix = _station.id.length >= 6
        ? _station.id.substring(_station.id.length - 6).toUpperCase()
        : _station.id.toUpperCase();
    return 'REF-$date-$suffix';
  }

  void _ensureDefaultReportRows() {
    if (_fuelDispensers.isEmpty) {
      _fuelDispensers.addAll(
        List.generate(4, (_) => FuelDispenserRow.empty()),
      );
    }
    if (_fuelTanks.isEmpty) {
      _fuelTanks.addAll(
        List.generate(4, (index) {
          return FuelTankRow.empty(tankNumber: '${index + 1}');
        }),
      );
    }
    if (_submersiblePumps.isEmpty) {
      _submersiblePumps.add(SubmersiblePumpRow.empty());
    }
    if (_equipment.isEmpty) {
      const defaultEquipment = [
        'الروافع',
        'ضواغط الهواء',
        'بكرات التزييت والتشحيم',
        'مضخات المياه',
        'معدات الأمن والسلامة',
      ];
      _equipment.addAll(
        defaultEquipment
            .map((type) => StationEquipmentRow.empty(equipmentType: type))
            .toList(),
      );
    }
  }

  HandoverReport _buildReport() {
    return HandoverReport(
      reportNumber: _reportNumberController.text.trim(),
      dayName: _reportDayController.text.trim(),
      hijriDate: _reportHijriDateController.text.trim(),
      gregorianDate: _reportGregorianDateController.text.trim(),
      stationName: _stationNameController.text.trim(),
      city: _cityController.text.trim(),
      district: _districtController.text.trim(),
      street: _streetController.text.trim(),
      civilLicenseNumber: _civilLicenseNumberController.text.trim(),
      civilLicenseDate: _civilLicenseDateController.text.trim(),
      municipalityLicenseNumber: _municipalityLicenseNumberController.text.trim(),
      municipalityLicenseDate: _municipalityLicenseDateController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      representativeName: _representativeNameController.text.trim(),
      authorizationNumber: _authorizationNumberController.text.trim(),
      companyName: _companyNameController.text.trim(),
      companyRepresentativeName: _companyRepresentativeController.text.trim(),
      contractReference: _contractReferenceController.text.trim(),
      dispensersCount: _dispensersCountController.text.trim(),
      doubleDispensersCount: _doubleDispensersCountController.text.trim(),
      fuelDispensers: _fuelDispensers,
      fuelTanks: _fuelTanks,
      submersiblePumps: _submersiblePumps,
      equipment: _equipment,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final report = _buildReport();
    final updated = _station.copyWith(handoverReport: report);
    final result =
        await context.read<MarketingStationProvider>().updateStation(updated);
    if (mounted) {
      setState(() => _saving = false);
      if (result != null) {
        Navigator.pop(context, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حفظ المحضر')),
        );
      }
    }
  }

  void _addFuelDispenserRow() {
    setState(() => _fuelDispensers.add(FuelDispenserRow.empty()));
  }

  void _removeFuelDispenserRow() {
    if (_fuelDispensers.isEmpty) return;
    setState(() => _fuelDispensers.removeLast());
  }

  void _addFuelTankRow() {
    setState(() => _fuelTanks.add(FuelTankRow.empty()));
  }

  void _removeFuelTankRow() {
    if (_fuelTanks.isEmpty) return;
    setState(() => _fuelTanks.removeLast());
  }

  void _addSubmersiblePumpRow() {
    setState(() => _submersiblePumps.add(SubmersiblePumpRow.empty()));
  }

  void _removeSubmersiblePumpRow() {
    if (_submersiblePumps.isEmpty) return;
    setState(() => _submersiblePumps.removeLast());
  }

  void _addEquipmentRow() {
    setState(() => _equipment.add(StationEquipmentRow.empty()));
  }

  void _removeEquipmentRow() {
    if (_equipment.isEmpty) return;
    setState(() => _equipment.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('محضر استلام محطة محروقات'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionTitle('بيانات المحضر'),
                const SizedBox(height: 12),
                isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _reportNumberController,
                              label: 'رقم المحضر',
                              icon: Icons.article_outlined,
                              requiredField: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _contractReferenceController,
                              label: 'مرجع العقد',
                              icon: Icons.description_outlined,
                              requiredField: false,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildTextField(
                            controller: _reportNumberController,
                            label: 'رقم المحضر',
                            icon: Icons.article_outlined,
                            requiredField: false,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _contractReferenceController,
                            label: 'مرجع العقد',
                            icon: Icons.description_outlined,
                            requiredField: false,
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
                _buildRow(isWide, [
                  _buildTextField(
                    controller: _reportDayController,
                    label: 'اليوم',
                    icon: Icons.today,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _reportHijriDateController,
                    label: 'التاريخ الهجري',
                    icon: Icons.date_range,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _reportGregorianDateController,
                    label: 'التاريخ الميلادي',
                    icon: Icons.event,
                    requiredField: false,
                  ),
                ]),
                const SizedBox(height: 12),
                _buildRow(isWide, [
                  _buildTextField(
                    controller: _stationNameController,
                    label: 'اسم المحطة',
                    icon: Icons.local_gas_station,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _cityController,
                    label: 'المدينة',
                    icon: Icons.location_city,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _districtController,
                    label: 'الحي',
                    icon: Icons.location_on_outlined,
                    requiredField: false,
                  ),
                ]),
                const SizedBox(height: 12),
                _buildRow(isWide, [
                  _buildTextField(
                    controller: _streetController,
                    label: 'الشارع',
                    icon: Icons.route,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _civilLicenseNumberController,
                    label: 'رقم الترخيص المدني',
                    icon: Icons.confirmation_number_outlined,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _civilLicenseDateController,
                    label: 'تاريخ الترخيص المدني',
                    icon: Icons.calendar_today,
                    requiredField: false,
                  ),
                ]),
                const SizedBox(height: 12),
                _buildRow(isWide, [
                  _buildTextField(
                    controller: _municipalityLicenseNumberController,
                    label: 'رقم ترخيص البلدية',
                    icon: Icons.apartment,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _municipalityLicenseDateController,
                    label: 'تاريخ ترخيص البلدية',
                    icon: Icons.calendar_today,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _ownerNameController,
                    label: 'اسم صاحب المحطة',
                    icon: Icons.person,
                    requiredField: false,
                  ),
                ]),
                const SizedBox(height: 12),
                _buildRow(isWide, [
                  _buildTextField(
                    controller: _representativeNameController,
                    label: 'اسم الممثل/الوكيل',
                    icon: Icons.person_outline,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _authorizationNumberController,
                    label: 'رقم الوكالة الشرعية',
                    icon: Icons.verified_user,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _companyNameController,
                    label: 'اسم المستأجر',
                    icon: Icons.business,
                    requiredField: false,
                  ),
                ]),
                const SizedBox(height: 12),
                _buildRow(isWide, [
                  _buildTextField(
                    controller: _companyRepresentativeController,
                    label: 'مندوب المستأجر',
                    icon: Icons.badge,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _dispensersCountController,
                    label: 'عدد الطرمبات',
                    icon: Icons.local_gas_station,
                    keyboardType: TextInputType.number,
                    requiredField: false,
                  ),
                  _buildTextField(
                    controller: _doubleDispensersCountController,
                    label: 'عدد الطرمبات المزدوجة',
                    icon: Icons.local_gas_station_outlined,
                    keyboardType: TextInputType.number,
                    requiredField: false,
                  ),
                ]),
                const SizedBox(height: 20),
                _sectionTitle('1) طرمبات الوقود'),
                const SizedBox(height: 8),
                _buildEditableTable(
                  headers: const [
                    'نوع الطرمبة',
                    'العدد',
                    'قراءة العداد السري',
                    'الحالة الفنية',
                  ],
                  rows: _fuelDispensers
                      .map(
                        (row) => TableRow(
                          key: ValueKey(row),
                          children: [
                            _tableTextFieldCell(
                              initialValue: row.pumpType,
                              onChanged: (value) => row.pumpType = value,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.count,
                              onChanged: (value) => row.count = value,
                              keyboardType: TextInputType.number,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.meterReading,
                              onChanged: (value) => row.meterReading = value,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.technicalStatus,
                              onChanged: (value) => row.technicalStatus = value,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _tableActions(
                  onAdd: _addFuelDispenserRow,
                  onRemove: _removeFuelDispenserRow,
                ),
                const SizedBox(height: 20),
                _sectionTitle('2) الخزانات'),
                const SizedBox(height: 8),
                _buildEditableTable(
                  headers: const [
                    'رقم الخزان',
                    'نوع الوقود',
                    'السعة التشغيلية',
                    'الحالة الفنية',
                  ],
                  rows: _fuelTanks
                      .map(
                        (row) => TableRow(
                          key: ValueKey(row),
                          children: [
                            _tableTextFieldCell(
                              initialValue: row.tankNumber,
                              onChanged: (value) => row.tankNumber = value,
                              keyboardType: TextInputType.number,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.fuelType,
                              onChanged: (value) => row.fuelType = value,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.operatingCapacity,
                              onChanged: (value) => row.operatingCapacity = value,
                              keyboardType: TextInputType.number,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.technicalStatus,
                              onChanged: (value) => row.technicalStatus = value,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _tableActions(
                  onAdd: _addFuelTankRow,
                  onRemove: _removeFuelTankRow,
                ),
                const SizedBox(height: 20),
                _sectionTitle('3) الطرمبات الغاطسة'),
                const SizedBox(height: 8),
                _buildEditableTable(
                  headers: const [
                    'ماركة الغاطس',
                    'عددها',
                    'قوة الغاطس',
                    'الحالة الفنية',
                  ],
                  rows: _submersiblePumps
                      .map(
                        (row) => TableRow(
                          key: ValueKey(row),
                          children: [
                            _tableTextFieldCell(
                              initialValue: row.brand,
                              onChanged: (value) => row.brand = value,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.count,
                              onChanged: (value) => row.count = value,
                              keyboardType: TextInputType.number,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.power,
                              onChanged: (value) => row.power = value,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.technicalStatus,
                              onChanged: (value) => row.technicalStatus = value,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _tableActions(
                  onAdd: _addSubmersiblePumpRow,
                  onRemove: _removeSubmersiblePumpRow,
                ),
                const SizedBox(height: 20),
                _sectionTitle('4) المعدات'),
                const SizedBox(height: 8),
                _buildEditableTable(
                  headers: const [
                    'نوع الجهاز',
                    'العدد',
                    'المواصفات',
                    'الحالة الفنية',
                    'الملاحظات',
                  ],
                  rows: _equipment
                      .map(
                        (row) => TableRow(
                          key: ValueKey(row),
                          children: [
                            _tableTextFieldCell(
                              initialValue: row.equipmentType,
                              onChanged: (value) => row.equipmentType = value,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.count,
                              onChanged: (value) => row.count = value,
                              keyboardType: TextInputType.number,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.specifications,
                              onChanged: (value) => row.specifications = value,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.technicalStatus,
                              onChanged: (value) => row.technicalStatus = value,
                            ),
                            _tableTextFieldCell(
                              initialValue: row.notes,
                              onChanged: (value) => row.notes = value,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _tableActions(
                  onAdd: _addEquipmentRow,
                  onRemove: _removeEquipmentRow,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ المحضر'),
                ),
              ],
            ),
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.white70,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(bool isWide, List<Widget> children) {
    if (isWide) {
      return Row(
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 12),
          Expanded(child: children[1]),
          const SizedBox(width: 12),
          Expanded(child: children[2]),
        ],
      );
    }
    return Column(
      children: [
        children[0],
        const SizedBox(height: 12),
        children[1],
        const SizedBox(height: 12),
        children[2],
      ],
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
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildEditableTable({
    required List<String> headers,
    required List<TableRow> rows,
  }) {
    return Table(
      border: TableBorder.all(color: AppColors.lightGray),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppColors.backgroundGray),
          children: headers
              .map(
                (header) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    header,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows,
      ],
    );
  }

  Widget _tableTextFieldCell({
    required String initialValue,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _tableActions({
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    return Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('إضافة صف'),
        ),
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('حذف آخر صف'),
        ),
      ],
    );
  }
}
