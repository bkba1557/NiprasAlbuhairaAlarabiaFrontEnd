// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:order_tracker/models/station_models.dart';
// import 'package:order_tracker/providers/auth_provider.dart';
// import 'package:order_tracker/providers/station_provider.dart';
// import 'package:order_tracker/localization/app_localizations.dart' as loc;
// import 'package:order_tracker/utils/constants.dart' show AppColors;
// import 'package:order_tracker/widgets/custom_text_field.dart';
// import 'package:order_tracker/widgets/gradient_button.dart';
// import 'package:provider/provider.dart';
// import 'dart:io';
// import 'package:order_tracker/services/firebase_storage_service.dart';
// import 'package:intl/intl.dart';

// class OpenSessionScreen extends StatefulWidget {
//   const OpenSessionScreen({super.key});

//   @override
//   State<OpenSessionScreen> createState() => _OpenSessionScreenState();
// }

// class _OpenSessionScreenState extends State<OpenSessionScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final Map<String, TextEditingController> _nozzleControllers = {};
//   final Map<String, XFile?> _nozzleImages = {};
//   final ImagePicker _imagePicker = ImagePicker();

//   String? _selectedStationId;
//   final List<Pump> _selectedPumps = [];
//   String? _currentPumpId;

//   String? _selectedShiftType = 'صباحية';
//   Station? _selectedStation;
//   bool _isSubmitting = false;
//   DateTime _selectedSessionDateTime = DateTime.now();
//   final DateFormat _sessionDateFormat = DateFormat('yyyy/MM/dd HH:mm');
//   final TextEditingController _sessionDateController = TextEditingController();

//   final List<String> _shiftTypes = ['صباحية', 'مسائية'];

//   String _nozzleKey(Pump pump, Nozzle nozzle) {
//     final nozzleId = nozzle.id.isNotEmpty ? nozzle.id : nozzle.nozzleNumber;
//     return '${pump.id}_$nozzleId';
//   }

//   @override
//   void initState() {
//     super.initState();
//     _sessionDateController.text = _sessionDateFormat.format(_selectedSessionDateTime);

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       final auth = context.read<AuthProvider>();
//         final stationProvider = context.read<StationProvider>();

//       // 🧑‍🔧 station_boy → محطة واحدة فقط
//       if (auth.isStationBoy && auth.stationId != null) {
//         await stationProvider.fetchStationById(auth.stationId!);

//         if (!mounted) return;

//         setState(() {
//           _selectedStation = stationProvider.selectedStation;
//           _selectedStationId = _selectedStation?.id;
//           _selectedSessionDateTime = DateTime.now();
//           _sessionDateController.text = _sessionDateFormat.format(_selectedSessionDateTime);
//         });
//       }
//       // 🧑‍💼 admin / owner / sales_manager_station → كل المحطات
//       else {
//         await stationProvider.fetchStations();

//         if (!mounted) return;

//         // تأكيد تصفير أي اختيار قديم
//         setState(() {
//           _selectedStation = null;
//           _selectedStationId = null;
//           _selectedPumps.clear();
//           _resetNozzleControllers();
//         });
//       }
//     });
//   }

//   void _prepareNozzlesForAllPumps(List<Pump> pumps) {
//     _resetNozzleControllers();

//     for (final pump in pumps) {
//       for (final nozzle in pump.nozzles) {
//         final key = _nozzleKey(pump, nozzle);
//         _nozzleControllers[key] = TextEditingController();
//         _nozzleImages[key] = null;
//       }
//     }
//   }

//   void _resetNozzleControllers() {
//     for (final controller in _nozzleControllers.values) {
//       controller.dispose();
//     }
//     _nozzleControllers.clear();
//     _nozzleImages.clear();
//   }

//   void _prepareNozzles(Pump pump) {
//     for (final nozzle in pump.nozzles) {
//       final key = '${pump.id}_${_nozzleKey(pump, nozzle)}';

//       if (!_nozzleControllers.containsKey(key)) {
//         _nozzleControllers[key] = TextEditingController();
//         _nozzleImages[key] = null;
//       }
//     }
//   }

//   Future<void> _pickNozzleImage(String key) async {
//     final picked = await _imagePicker.pickImage(
//       source: ImageSource.camera,
//       maxWidth: 1200,
//       imageQuality: 70,
//     );
//     if (picked == null || !mounted) return;
//     setState(() {
//       _nozzleImages[key] = picked;
//     });
//   }

//   Widget _buildSalesManagerStockTable(Station station, bool isLargeScreen) {
//     final pumps = station.pumps;

//     if (pumps.isEmpty) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         child: Text(
//           context.tr(loc.AppStrings.stationStockNoData),
//           style: TextStyle(color: AppColors.mediumGray),
//         ),
//       );
//     }

//     return Card(
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.stationStockTitle),
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: isLargeScreen ? 16 : 15,
//               ),
//             ),
//             const SizedBox(height: 14),
//             Wrap(
//               spacing: 12,
//               runSpacing: 12,
//               children: pumps
//                   .map((pump) => _buildStockColumn(pump, isLargeScreen))
//                   .toList(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStockColumn(Pump pump, bool isLargeScreen) {
//     final pumpLabel = pump.fuelType.isNotEmpty
//         ? '${pump.pumpNumber} - ${pump.fuelType}'
//         : pump.pumpNumber;
//     final available = pump.availableStock.toStringAsFixed(1);
//     final yesterday = pump.yesterdaySalesLiters.toStringAsFixed(1);

//     return Container(
//       width: isLargeScreen ? 200 : 165,
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.lightGray),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.03),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             pumpLabel,
//             style: TextStyle(
//               fontWeight: FontWeight.w600,
//               fontSize: isLargeScreen ? 15 : 13,
//             ),
//           ),
//           const SizedBox(height: 10),
//           Table(
//             columnWidths: const {
//               0: FlexColumnWidth(),
//               1: FlexColumnWidth(),
//             },
//             children: [
//               TableRow(
//                 children: [
//                   Text(
//                     context.tr(loc.AppStrings.stockAvailableLabel),
//                     style: TextStyle(
//                       fontSize: isLargeScreen ? 12 : 11,
//                       color: AppColors.mediumGray,
//                     ),
//                   ),
//                   Text(
//                     context.tr(loc.AppStrings.stockYesterdayLabel),
//                     style: TextStyle(
//                       fontSize: isLargeScreen ? 12 : 11,
//                       color: AppColors.mediumGray,
//                     ),
//                   ),
//                 ],
//               ),
//               TableRow(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.only(top: 6),
//                     child: Text(
//                       '$available لتر',
//                       style: TextStyle(
//                         fontWeight: FontWeight.w600,
//                         fontSize: isLargeScreen ? 14 : 13,
//                       ),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.only(top: 6),
//                     child: Text(
//                       '$yesterday لتر',
//                       style: TextStyle(
//                         fontWeight: FontWeight.w600,
//                         fontSize: isLargeScreen ? 14 : 13,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _pickSessionDateTime() async {
//     final DateTime initialDate = _selectedSessionDateTime;
//     final DateTime now = DateTime.now();
//     final DateTime? pickedDate = await showDatePicker(
//       context: context,
//       initialDate: initialDate,
//       firstDate: now.subtract(const Duration(days: 365)),
//       lastDate: now.add(const Duration(days: 365)),
//     );
//     if (pickedDate == null) return;

//     final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
//     final TimeOfDay? pickedTime = await showTimePicker(
//       context: context,
//       initialTime: initialTime,
//     );

//     if (!mounted) return;

//     final TimeOfDay selectedTime = pickedTime ?? initialTime;
//     final newDateTime = DateTime(
//       pickedDate.year,
//       pickedDate.month,
//       pickedDate.day,
//       selectedTime.hour,
//       selectedTime.minute,
//     );

//     setState(() {
//       _selectedSessionDateTime = newDateTime;
//       _sessionDateController.text = _sessionDateFormat.format(newDateTime);
//     });
//   }

//   Future<void> _submitForm() async {
//     if (_isSubmitting) return;
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isSubmitting = true);

//     try {
//       final stationProvider = Provider.of<StationProvider>(
//         context,
//         listen: false,
//       );
//       final authProvider = Provider.of<AuthProvider>(context, listen: false);

//       final String? finalStationId = authProvider.isStationBoy
//           ? authProvider.stationId
//           : _selectedStationId;

//       if (finalStationId == null || _selectedPumps.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(context.tr(loc.AppStrings.selectStationAndPump)),
//             backgroundColor: AppColors.errorRed,
//           ),
//         );
//         return;
//       }

//       final List<NozzleReading> allReadings = [];

//       for (final pump in _selectedPumps) {
//         final activeNozzles = pump.nozzles.where((n) => n.isActive).toList();

//         if (activeNozzles.isEmpty) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 context.tr(loc.AppStrings.activatePumpSlots, {
//                   'pumpNumber': pump.pumpNumber,
//                 }),
//               ),
//               backgroundColor: AppColors.errorRed,
//             ),
//           );
//           return;
//         }

//         for (final nozzle in activeNozzles) {
//           final key = _nozzleKey(pump, nozzle);

//           final text = _nozzleControllers[key]?.text.trim();
//           final value = double.tryParse(text ?? '');

//           if (value == null) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                   context.tr(loc.AppStrings.invalidNozzleReading, {
//                     'nozzleNumber': nozzle.nozzleNumber,
//                     'pumpNumber': pump.pumpNumber,
//                   }),
//                 ),
//                 backgroundColor: AppColors.errorRed,
//               ),
//             );
//             return;
//           }

//           final image = _nozzleImages[key];
//           if (image == null) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                   context.tr(loc.AppStrings.attachNozzleImage, {
//                     'nozzleNumber': nozzle.nozzleNumber,
//                     'pumpNumber': pump.pumpNumber,
//                   }),
//                 ),
//                 backgroundColor: AppColors.errorRed,
//               ),
//             );
//             return;
//           }

//           String imageUrl;

//           if (kIsWeb) {
//             final bytes = await image.readAsBytes();
//             imageUrl = await FirebaseStorageService.uploadSessionImage(
//               sessionId: 'TEMP',
//               type: 'opening',
//               nozzleId: nozzle.id,
//               webBytes: bytes,
//             );
//           } else {
//             imageUrl = await FirebaseStorageService.uploadSessionImage(
//               sessionId: 'TEMP',
//               type: 'opening',
//               nozzleId: nozzle.id,
//               filePath: image.path,
//             );
//           }

//           allReadings.add(
//             NozzleReading(
//               nozzleId: nozzle.id,
//               nozzleNumber: nozzle.nozzleNumber,
//               position: nozzle.position,
//               fuelType: nozzle.fuelType,
//               openingReading: value,
//               openingImageUrl: imageUrl,
//               pumpId: pump.id,
//               pumpNumber: pump.pumpNumber,
//             ),
//           );
//         }
//       }

//       final DateTime sessionDateTime = authProvider.isStationBoy
//           ? DateTime.now()
//           : _selectedSessionDateTime;

//       final session = PumpSession(
//         id: '',
//         sessionNumber: '',
//         stationId: finalStationId,
//         stationName: _selectedStation?.stationName ?? '',
//         pumpId: _selectedPumps.first.id,
//         pumpNumber: _selectedPumps.first.pumpNumber,
//         fuelType: _selectedPumps.first.fuelType,
//         pumpsCount: _selectedPumps.length,
//         shiftType: _selectedShiftType ?? _shiftTypes.first,
//         sessionDate: sessionDateTime,
//         openingEmployeeId: authProvider.user?.id,
//         openingEmployeeName: authProvider.user?.name,
//         openingReading: allReadings.first.openingReading,
//         openingTime: sessionDateTime,
//         openingApproved: false,
//         closingApproved: false,
//         paymentTypes: PaymentTypes(cash: 0, card: 0, mada: 0, other: 0),
//         nozzleReadings: allReadings,
//         carriedForwardBalance: 0,
//         status: 'مفتوحة',
//         createdAt: DateTime.now(),
//         updatedAt: DateTime.now(),
//       );

//       final success = await stationProvider.openSession(session);

//       if (!mounted) return;

//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(context.tr(loc.AppStrings.openSessionSuccess)),
//             backgroundColor: AppColors.successGreen,
//           ),
//         );
//         Navigator.of(context).pop();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               stationProvider.error ??
//                   context.tr(loc.AppStrings.unexpectedError),
//             ),
//             backgroundColor: AppColors.errorRed,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isSubmitting = false);
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _sessionDateController.dispose();
//     super.dispose();
//   }

//   Widget _buildPumpsSelectors(Station station, bool isLargeScreen) {
//     final pumps = station.pumps;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: List.generate(_selectedPumps.length + 1, (index) {
//         if (index >= pumps.length) return const SizedBox.shrink();

//         return Padding(
//           padding: const EdgeInsets.only(bottom: 16),
//           child: DropdownButtonFormField<String>(
//             value: index < _selectedPumps.length
//                 ? _selectedPumps[index].id
//                 : null,
//             decoration: InputDecoration(
//               labelText: index == 0
//                   ? context.tr(loc.AppStrings.selectPump)
//                   : context.tr(loc.AppStrings.selectNextPump),
//             ),
//             items: pumps
//                 .where(
//                   (p) =>
//                       !_selectedPumps.any((selected) => selected.id == p.id) ||
//                       (index < _selectedPumps.length &&
//                           p.id == _selectedPumps[index].id),
//                 )
//                 .map((pump) {
//                   return DropdownMenuItem<String>(
//                     value: pump.id,
//                     child: Text('${pump.pumpNumber} - ${pump.fuelType}'),
//                   );
//                 })
//                 .toList(),
//             onChanged: (value) {
//               if (value == null) return;

//               final pump = pumps.firstWhere((p) => p.id == value);

//               setState(() {
//                 if (index < _selectedPumps.length) {
//                   _selectedPumps[index] = pump;
//                 } else {
//                   _selectedPumps.add(pump);
//                 }

//                 _prepareNozzlesForAllPumps(_selectedPumps);
//               });
//             },
//           ),
//         );
//       }),
//     );
//   }

//   Widget _buildNozzleReadingsSection() {
//     if (_selectedPumps.isEmpty) return const SizedBox.shrink();

//     final isLargeScreen = MediaQuery.of(context).size.width > 768;

//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.openingReadingsTitle),
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             for (final pump in _selectedPumps) ...[
//               Text(
//                 context.tr(loc.AppStrings.pumpFuelLabel, {
//                   'pumpNumber': pump.pumpNumber,
//                   'fuelType': pump.fuelType,
//                 }),
//                 style: const TextStyle(fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 8),
//               for (final nozzle in pump.nozzles)
//                 _buildNozzleItem(pump, nozzle, isLargeScreen),

//               const SizedBox(height: 24),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNozzleGrid(
//     Pump pump,
//     List<Nozzle> activeNozzles,
//     bool isMediumScreen,
//   ) {
//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: isMediumScreen ? 2 : 1,
//         crossAxisSpacing: 16,
//         mainAxisSpacing: 16,
//         childAspectRatio: 2.5,
//       ),
//       itemCount: activeNozzles.length,
//       itemBuilder: (context, index) {
//         return _buildNozzleItem(pump, activeNozzles[index], true);
//       },
//     );
//   }

//   Widget _buildNozzleItem(Pump pump, Nozzle nozzle, bool isLargeScreen) {
//     final key = _nozzleKey(pump, nozzle);
//     final controller = _nozzleControllers[key];
//     final image = _nozzleImages[key];

//     final bool isLeft = nozzle.position.toLowerCase() == 'left';
//     final directionText = isLeft
//         ? context.tr(loc.AppStrings.sideLeft)
//         : context.tr(loc.AppStrings.sideRight);

//     return Container(
//       decoration: BoxDecoration(
//         border: Border.all(color: AppColors.lightGray),
//         borderRadius: BorderRadius.circular(12),
//         color: Colors.white,
//       ),
//       padding: EdgeInsets.all(isLargeScreen ? 16 : 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 context.tr(loc.AppStrings.fuelTypeLabel, {
//                   'fuelType': nozzle.fuelType,
//                 }),
//                 style: const TextStyle(fontWeight: FontWeight.bold),
//               ),

//               Chip(
//                 label: Text(
//                   directionText,
//                   style: TextStyle(fontSize: isLargeScreen ? 13 : 12),
//                 ),
//                 backgroundColor: isLeft
//                     ? Colors.blue.withOpacity(0.1)
//                     : Colors.orange.withOpacity(0.1),
//                 side: BorderSide.none,
//               ),
//             ],
//           ),

//           const SizedBox(height: 12),

//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Expanded(
//                 flex: 3,
//                 child: CustomTextField(
//                   controller: controller,
//                   labelText: context.tr(loc.AppStrings.meterReadingLabel),
//                   prefixIcon: Icons.speed,
//                   keyboardType: const TextInputType.numberWithOptions(
//                     decimal: true,
//                   ),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return context.tr(loc.AppStrings.enterReading);
//                     }
//                     if (double.tryParse(value) == null) {
//                       return context.tr(loc.AppStrings.readingMustBeNumber);
//                     }
//                     return null;
//                   },
//                   contentPadding: EdgeInsets.symmetric(
//                     horizontal: isLargeScreen ? 16 : 12,
//                     vertical: isLargeScreen ? 14 : 12,
//                   ),
//                 ),
//               ),

//               SizedBox(width: isLargeScreen ? 16 : 12),

//               Expanded(
//                 flex: 4,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     OutlinedButton.icon(
//                       onPressed: () => _pickNozzleImage(key),
//                       icon: Icon(
//                         Icons.camera_alt,
//                         size: isLargeScreen ? 20 : 18,
//                       ),
//                       label: Text(
//                         image == null
//                             ? context.tr(loc.AppStrings.attachMeterImage)
//                             : context.tr(loc.AppStrings.changeImage),
//                         style: TextStyle(fontSize: isLargeScreen ? 14 : 13),
//                       ),
//                       style: OutlinedButton.styleFrom(
//                         minimumSize: Size.fromHeight(isLargeScreen ? 50 : 46),
//                         padding: EdgeInsets.symmetric(
//                           horizontal: isLargeScreen ? 16 : 12,
//                         ),
//                       ),
//                     ),

//                     if (image != null) ...[
//                       const SizedBox(height: 8),
//                       Container(
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: AppColors.successGreen.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(
//                             color: AppColors.successGreen.withOpacity(0.3),
//                           ),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(
//                               Icons.check_circle,
//                               color: AppColors.successGreen,
//                               size: isLargeScreen ? 18 : 16,
//                             ),
//                             const SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 image.name,
//                                 style: TextStyle(
//                                   color: AppColors.darkGray,
//                                   fontSize: isLargeScreen ? 13 : 12,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final stationProvider = Provider.of<StationProvider>(context);
//     final authProvider = Provider.of<AuthProvider>(context);
//     final bool isSalesManager = authProvider.role == 'sales_manager_statiun';

//     final stations = stationProvider.stations;

//     final Station? station = authProvider.isStationBoy
//         ? _selectedStation
//         : (_selectedStation ?? stationProvider.selectedStation);

//     final isLargeScreen = MediaQuery.of(context).size.width > 768;
//     final screenWidth = MediaQuery.of(context).size.width;

//     if (stationProvider.isStationsLoading) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           context.tr(loc.AppStrings.openSessionTitle),
//           style: const TextStyle(color: Colors.white),
//         ),
//         centerTitle: isLargeScreen,
//       ),
//       body: Center(
//         child: Form(
//           key: _formKey,
//           child: SingleChildScrollView(
//             padding: EdgeInsets.symmetric(
//               horizontal: isLargeScreen ? screenWidth * 0.1 : 16,
//               vertical: 16,
//             ),
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 maxWidth: isLargeScreen ? 900 : double.infinity,
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Card(
//                     elevation: isLargeScreen ? 4 : 2,
//                     child: Padding(
//                       padding: EdgeInsets.all(isLargeScreen ? 32 : 20),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             context.tr(loc.AppStrings.sessionInfoTitle),
//                             style: Theme.of(context).textTheme.titleLarge
//                                 ?.copyWith(fontWeight: FontWeight.bold),
//                           ),
//                           const SizedBox(height: 24),

//                           if (authProvider.isStationBoy) ...[
//                             if (station != null)
//                               _buildStationInfoCard(station, isLargeScreen)
//                             else
//                               const Center(
//                                 child: Padding(
//                                   padding: EdgeInsets.all(16),
//                                   child: CircularProgressIndicator(),
//                                 ),
//                               ),
//                           ] else ...[
//                             _buildStationDropdown(stations, isLargeScreen),
//                           ],

//                           const SizedBox(height: 20),

//                           if (!authProvider.isStationBoy &&
//                               isSalesManager &&
//                               station != null) ...[
//                             _buildSalesManagerStockTable(station, isLargeScreen),
//                             const SizedBox(height: 20),
//                           ],

//                           if (station != null)
//                             _buildPumpsSelectors(station, isLargeScreen),

//                           const SizedBox(height: 20),

//                           _buildShiftDropdown(isLargeScreen),

//                           if (isSalesManager) ...[
//                             const SizedBox(height: 16),
//                             Text(
//                               context.tr(loc.AppStrings.sessionDateTimeLabel),
//                               style: TextStyle(
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: isLargeScreen ? 15 : 14,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             TextFormField(
//                               controller: _sessionDateController,
//                               readOnly: true,
//                               onTap: _pickSessionDateTime,
//                               decoration: InputDecoration(
//                                 labelText:
//                                     context.tr(loc.AppStrings.sessionDateTimeLabel),
//                                 prefixIcon: const Icon(Icons.calendar_today),
//                                 border: const OutlineInputBorder(),
//                               ),
//                             ),
//                           ],

//                           if (_selectedPumps.isNotEmpty) ...[
//                             const SizedBox(height: 32),
//                             _buildNozzleReadingsSection(),
//                           ],

//                           const SizedBox(height: 40),

//                           GradientButton(
//                             onPressed:
//                                 (_isSubmitting || stationProvider.isLoading)
//                                 ? null
//                                 : _submitForm,
//                             text: (_isSubmitting || stationProvider.isLoading)
//                                 ? context.tr(
//                                     loc.AppStrings.loadingOpeningSession,
//                                   )
//                                 : context.tr(loc.AppStrings.openSessionButton),
//                             gradient: AppColors.accentGradient,
//                             isLoading:
//                                 _isSubmitting || stationProvider.isLoading,
//                             height: isLargeScreen ? 56 : 50,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStationInfoCard(Station station, bool isLargeScreen) {
//     return Container(
//       padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
//       decoration: BoxDecoration(
//         color: AppColors.primaryBlue.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.local_gas_station,
//             color: AppColors.primaryBlue,
//             size: isLargeScreen ? 28 : 24,
//           ),
//           SizedBox(width: isLargeScreen ? 16 : 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   context.tr(loc.AppStrings.assignedStationLabel),
//                   style: TextStyle(
//                     color: AppColors.mediumGray,
//                     fontSize: isLargeScreen ? 14 : 13,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   '${station.stationCode ?? ''} - ${station.stationName ?? ''}',
//                   style: TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: isLargeScreen ? 16 : 15,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

// Widget _buildStationDropdown(List<Station> stations, bool isLargeScreen) {
//     final auth = context.read<AuthProvider>();

//     // ❌ رسالة فقط لو station_boy فعلًا ومفيش محطة
//     if (stations.isEmpty && auth.isStationBoy) {
//       return Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.orange.withOpacity(0.08),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.orange.withOpacity(0.4)),
//         ),
//         child: Row(
//           children: [
//             const Icon(Icons.info_outline, color: Colors.orange),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 'لا توجد محطة مخصصة لهذا المستخدم',
//                 style: TextStyle(
//                   color: Colors.orange.shade800,
//                   fontWeight: FontWeight.w500,
//                   fontSize: isLargeScreen ? 14 : 13,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(bottom: 6),
//           child: Text(
//             context.tr(loc.AppStrings.selectStation),
//             style: TextStyle(
//               fontWeight: FontWeight.w500,
//               fontSize: isLargeScreen ? 15 : 14,
//             ),
//           ),
//         ),
//         Container(
//           padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 16 : 12),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.lightGray),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: DropdownButton<String>(
//             value: _selectedStationId,
//             isExpanded: true,
//             underline: const SizedBox(),
//             hint: Padding(
//               padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 13 : 14),
//               child: Text(
//                 context.tr(loc.AppStrings.selectStationHint),
//                 style: TextStyle(
//                   color: AppColors.mediumGray,
//                   fontSize: isLargeScreen ? 15 : 14,
//                 ),
//               ),
//             ),
//             icon: Icon(
//               Icons.arrow_drop_down,
//               size: isLargeScreen ? 28 : 24,
//               color: AppColors.primaryBlue,
//             ),
//             items: stations.map((station) {
//               return DropdownMenuItem<String>(
//                 value: station.id,
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(
//                     vertical: isLargeScreen ? 8 : 6,
//                   ),
//                   child: Text(
//                     '${station.stationCode} - ${station.stationName}',
//                     style: TextStyle(fontSize: isLargeScreen ? 15 : 14),
//                   ),
//                 ),
//               );
//             }).toList(),
//             onChanged: (value) async {
//               if (value == null) return;

//               final stationProvider = Provider.of<StationProvider>(
//                 context,
//                 listen: false,
//               );

//               // 🧹 تصفير الحالة قبل جلب المحطة
//               setState(() {
//                 _selectedStationId = value;
//                 _selectedStation = null;
//                 _selectedPumps.clear();
//                 _resetNozzleControllers();
//               });

//               // 📡 جلب بيانات المحطة كاملة
//               await stationProvider.fetchStationById(value);

//               if (!mounted) return;

//               setState(() {
//                 _selectedStation = stationProvider.selectedStation;
//               });
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildPumpDropdown(Station station, bool isLargeScreen) {
//     final pumps = station.pumps;

//     if (pumps.isEmpty) {
//       return Text(
//         context.tr(loc.AppStrings.noPumpsForStation),
//         style: const TextStyle(color: Colors.red),
//       );
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(bottom: 8),
//           child: Text(
//             context.tr(loc.AppStrings.selectPump),
//             style: TextStyle(
//               fontWeight: FontWeight.w500,
//               fontSize: isLargeScreen ? 15 : 14,
//             ),
//           ),
//         ),
//         Container(
//           padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 16 : 12),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.lightGray),
//           ),
//           child: DropdownButton<String>(
//             value: _currentPumpId,
//             isExpanded: true,
//             underline: const SizedBox(),
//             hint: Text(
//               _selectedPumps.isEmpty
//                   ? context.tr(loc.AppStrings.selectPump)
//                   : context.tr(loc.AppStrings.selectNextPump),
//               style: TextStyle(color: AppColors.mediumGray),
//             ),
//             icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),

//             items: pumps
//                 .where(
//                   (pump) =>
//                       !_selectedPumps.any((selected) => selected.id == pump.id),
//                 )
//                 .map(
//                   (pump) => DropdownMenuItem<String>(
//                     value: pump.id,
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 8),
//                       child: Text('${pump.pumpNumber} - ${pump.fuelType}'),
//                     ),
//                   ),
//                 )
//                 .toList(),

//             onChanged: (value) {
//               if (value == null) return;

//               final pump = pumps.firstWhere((p) => p.id == value);

//               setState(() {
//                 _selectedPumps.add(pump);
//                 _prepareNozzles(pump);
//                 _currentPumpId = null;
//               });
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildShiftDropdown(bool isLargeScreen) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(bottom: 8),
//           child: Text(
//             context.tr(loc.AppStrings.shiftLabel),
//             style: TextStyle(
//               fontWeight: FontWeight.w500,
//               fontSize: isLargeScreen ? 15 : 14,
//             ),
//           ),
//         ),
//         Container(
//           padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 16 : 12),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.lightGray),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: DropdownButton<String>(
//             value: _selectedShiftType ?? _shiftTypes.first,
//             isExpanded: true,
//             underline: const SizedBox(),
//             icon: Icon(
//               Icons.arrow_drop_down,
//               size: isLargeScreen ? 28 : 24,
//               color: AppColors.primaryBlue,
//             ),
//             items: _shiftTypes.map((shift) {
//               final translatedShift = shift == 'صباحية'
//                   ? context.tr(loc.AppStrings.shiftTypeMorning)
//                   : context.tr(loc.AppStrings.shiftTypeEvening);

//               return DropdownMenuItem<String>(
//                 value: shift,
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(
//                     vertical: isLargeScreen ? 8 : 6,
//                   ),
//                   child: Text(
//                     translatedShift,
//                     style: TextStyle(fontSize: isLargeScreen ? 15 : 14),
//                   ),
//                 ),
//               );
//             }).toList(),
//             onChanged: (value) {
//               setState(() {
//                 _selectedShiftType = value;
//               });
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/localization/app_localizations.dart' as loc;
import 'package:order_tracker/utils/constants.dart' show AppColors;
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:order_tracker/services/firebase_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpenSessionScreen extends StatefulWidget {
  const OpenSessionScreen({super.key});

  @override
  State<OpenSessionScreen> createState() => _OpenSessionScreenState();
}

class FuelStockSummary {
  FuelStockSummary({
    required this.fuelType,
    required this.baseStock,
    this.initialSales = 0,
    this.salesAlreadyAppliedInBase = false,
  });

  final String fuelType;

  /// الرصيد الأصلي قبل فتح الجلسة (من التوريد / التقرير)
  final double baseStock;

  /// المبيعات التي حصلت بالفعل (من الجلسات اليومية)
  double initialSales;

  final bool salesAlreadyAppliedInBase;

  /// المبيعات اللحظية أثناء فتح الجلسة
  double liveSales = 0;

  /// ✅ الرصيد بعد خصم المبيعات (اللي انت محتاجه)
  double get postSalesBalance =>
      (baseStock -
              (salesAlreadyAppliedInBase ? 0 : initialSales) -
              liveSales)
          .clamp(0, double.infinity);

  /// للاستخدامات القديمة إن لزم
  double get availableStock => postSalesBalance;
}

class _OpenSessionScreenState extends State<OpenSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _nozzleControllers = {};
  final Map<String, XFile?> _nozzleImages = {};
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedStationId;
  final List<Pump> _selectedPumps = [];

  String? _selectedShiftType = 'صباحية';
  Station? _selectedStation;
  bool _isSubmitting = false;
  DateTime _selectedSessionDateTime = DateTime.now();
  final DateFormat _sessionDateFormat = DateFormat('yyyy/MM/dd HH:mm');
  final TextEditingController _sessionDateController = TextEditingController();

  final List<String> _shiftTypes = ['صباحية', 'مسائية'];

  // Web table state
  final ScrollController _tableScrollController = ScrollController();
  bool _showValidationErrors = false;
  List<FuelStockSummary> _fuelStockSummaries = [];
  bool _isFuelBalanceReportLoading = false;
  String? _fuelBalanceReportError;
  String? _fuelBalanceStationId;
  String? _loadingFuelBalanceStationId;
  final Map<String, double> _fuelPriceLookup = {};
  final Map<String, double> _cachedClosingBalances = {};
  DateTime? _lastInventorySyncAt;

  // State for showing nozzle dialog
  Pump? _selectedPumpForNozzles;
  bool _showNozzleDialog = false;

  String _nozzleKey(Pump pump, Nozzle nozzle) {
    final nozzleId = nozzle.id.isNotEmpty ? nozzle.id : nozzle.nozzleNumber;
    return '${pump.id}_$nozzleId';
  }

  double _getAvailableStockFromPump(Pump pump) {
    return pump.availableStock;
  }

  // double _getAvailableStockForFuel(String fuelType) {
  //   final target = _normalizeFuelType(fuelType);
  //   final match = _fuelStockSummaries.firstWhere(
  //     (e) => _normalizeFuelType(e.fuelType) == target,
  //     orElse: () => FuelStockSummary(fuelType: fuelType),
  //   );

  //   return match.availableStock;
  // }

  String _normalizeFuelType(String value) {
    var normalized = value;
    normalized = normalized.replaceAll(RegExp(r'[\u200E\u200F]'), '');
    normalized = _arabicDigitsToWestern(normalized);
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  String _arabicDigitsToWestern(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const eastern = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();

    for (final ch in input.runes) {
      final char = String.fromCharCode(ch);
      final indexArabic = arabic.indexOf(char);
      if (indexArabic != -1) {
        buffer.write(indexArabic);
        continue;
      }
      final indexEastern = eastern.indexOf(char);
      if (indexEastern != -1) {
        buffer.write(indexEastern);
        continue;
      }
      buffer.write(char);
    }

    return buffer.toString();
  }

  double _parseStockNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    var text = value.toString();
    text = text.replaceAll(RegExp(r'[\u200E\u200F]'), '');
    text = _arabicDigitsToWestern(text);
    text = text.replaceAll(',', '');
    text = text.replaceAll(RegExp(r'\s+'), '');
    return double.tryParse(text) ?? 0;
  }

  String _fuelTypeFromPump(String pumpId) {
    final pumps = _selectedStation?.pumps ?? const <Pump>[];
    for (final pump in pumps) {
      if (pump.id == pumpId && pump.fuelType.isNotEmpty) {
        return _normalizeFuelType(pump.fuelType);
      }
    }
    return '';
  }

  double _sessionReadingLiters(NozzleReading reading) {
    // ✅ لو في closingReading هي الأساس
    if (reading.closingReading != null) {
      final diff = reading.closingReading! - reading.openingReading;
      return diff > 0 ? diff : 0;
    }

    // ✅ استخدم totalLiters فقط لو مفيش closingReading
    if (reading.totalLiters != null && reading.totalLiters! > 0) {
      return reading.totalLiters!;
    }

    return 0;
  }

  Map<String, double> _lastActualBalanceByFuel(
    List<FuelBalanceReportRow> rows,
  ) {
    final map = <String, FuelBalanceReportRow>{};

    for (final row in rows) {
      final key = row.fuelType.trim();

      if (!map.containsKey(key)) {
        map[key] = row;
        continue;
      }

      final existing = map[key]!;
      if (row.date.isAfter(existing.date)) {
        map[key] = row;
      }
    }

    return map.map((k, v) {
      final balance =
          v.actualBalance ?? v.calculatedBalance ?? v.openingBalance;
      return MapEntry(k, balance);
    });
  }

  Map<String, double> _salesByFuelForDate(
    List<PumpSession> sessions,
    DateTime targetDate,
  ) {
    final totals = <String, double>{};

    for (final session in sessions) {
      if (session.stationId != _selectedStationId) continue;
      if (!_isSameDay(session.sessionDate, targetDate)) continue;

      final readings = session.nozzleReadings ?? [];
      final sessionFuelTypeKey = _normalizeFuelType(session.fuelType);

      if (readings.isNotEmpty) {
        final seenNozzles = <String>{};
        for (final reading in readings) {
          final nozzleKey =
              '${reading.nozzleId}|${reading.pumpId}|${reading.position}';
          if (nozzleKey.isNotEmpty && !seenNozzles.add(nozzleKey)) continue;
          final liters = _sessionReadingLiters(reading);
          if (liters <= 0) continue;
          var key = _normalizeFuelType(
            reading.fuelType.isNotEmpty ? reading.fuelType : session.fuelType,
          );
          if (key.isEmpty && reading.pumpId.isNotEmpty) {
            key = _fuelTypeFromPump(reading.pumpId);
          }
          if (key.isEmpty && session.pumpId.isNotEmpty) {
            key = _fuelTypeFromPump(session.pumpId);
          }
          if (key.isEmpty) continue;
          totals[key] = (totals[key] ?? 0) + liters;
        }
        continue;
      }

      final pumps = session.pumps ?? [];
      if (pumps.isNotEmpty) {
        for (final pump in pumps) {
          if (pump.closingReading == null) continue;
          final liters = pump.closingReading! - pump.openingReading;
          if (liters <= 0) continue;
          var key = _normalizeFuelType(pump.fuelType);
          if (key.isEmpty && pump.pumpId.isNotEmpty) {
            key = _fuelTypeFromPump(pump.pumpId);
          }
          if (key.isEmpty) continue;
          totals[key] = (totals[key] ?? 0) + liters;
        }
        continue;
      } else if (session.totalLiters != null && session.totalLiters! > 0) {
        var key = sessionFuelTypeKey;
        if (key.isEmpty && session.pumpId.isNotEmpty) {
          key = _fuelTypeFromPump(session.pumpId);
        }
        if (key.isEmpty) continue;
        totals[key] = (totals[key] ?? 0) + session.totalLiters!;
      }
    }

    return totals;
  }

  void _applySalesDeductionsToSummaries(
    List<FuelStockSummary> summaries,
    DateTime targetDate,
  ) {
    final stationProvider = context.read<StationProvider>();
    Map<String, double> salesTotals;
    if (stationProvider.sessionTotalsByFuel.isNotEmpty) {
      salesTotals = <String, double>{};
      stationProvider.sessionTotalsByFuel.forEach((key, value) {
        final normalized = _normalizeFuelType(key);
        if (normalized.isEmpty) return;
        salesTotals[normalized] = (salesTotals[normalized] ?? 0) + value;
      });
    } else {
      salesTotals = _salesByFuelForDate(stationProvider.sessions, targetDate);
    }

    for (final summary in summaries) {
      final key = _normalizeFuelType(summary.fuelType);
      summary.initialSales = salesTotals[key] ?? 0;
    }
  }

  List<FuelStockSummary> _summariesFromInventories(
    List<DailyInventory> inventories,
  ) {
    final Map<String, DailyInventory> latestByFuel = {};

    for (final inv in inventories) {
      final key = _normalizeFuelType(inv.fuelType);
      if (key.isEmpty) continue;
      final existing = latestByFuel[key];

      if (existing == null) {
        latestByFuel[key] = inv;
        continue;
      }

      final sameDay = _isSameDay(inv.inventoryDate, existing.inventoryDate);
      if (inv.inventoryDate.isAfter(existing.inventoryDate) ||
          (sameDay && inv.updatedAt.isAfter(existing.updatedAt))) {
        latestByFuel[key] = inv;
      }
    }

    final result = latestByFuel.values.map(_inventoryToSummary).toList();
    result.sort((a, b) => a.fuelType.compareTo(b.fuelType));
    return result;
  }

  void _maybeRefreshStockFromProvider(StationProvider stationProvider) {
    if (_selectedStationId == null) return;

    final inventories = stationProvider.inventories
        .where((inv) => inv.stationId == _selectedStationId)
        .toList();
    if (inventories.isEmpty) return;

    final latestUpdate = inventories
        .map((inv) => inv.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    if (_lastInventorySyncAt != null &&
        !latestUpdate.isAfter(_lastInventorySyncAt!)) {
      return;
    }

    _lastInventorySyncAt = latestUpdate;
    _loadFuelBalanceReportForStation(_selectedStationId!);
  }

  Future<void> _loadLiveFuelStockFromInventory(String stationId) async {
    await _loadFuelBalanceReportForStation(stationId);
    return;

    final stationProvider = context.read<StationProvider>();

    await stationProvider.fetchInventories(filters: {'stationId': stationId});
    if (!mounted) return;

    final Map<String, DailyInventory> latestByFuel = {};

    for (final inv in stationProvider.inventories) {
      final key = _normalizeFuelType(inv.fuelType);
      if (key.isEmpty) continue;

      final existing = latestByFuel[key];

      if (existing == null) {
        latestByFuel[key] = inv;
        continue;
      }

      final sameDay = _isSameDay(inv.inventoryDate, existing.inventoryDate);

      // ✅ نفس اليوم → خُد الأحدث بالتحديث
      if (sameDay && inv.updatedAt.isAfter(existing.updatedAt)) {
        latestByFuel[key] = inv;
        continue;
      }

      // ✅ يوم أحدث
      if (inv.inventoryDate.isAfter(existing.inventoryDate)) {
        latestByFuel[key] = inv;
      }
    }

    final summaries = latestByFuel.values.map((inv) {
      // ✅ نفس منطق صفحة التوريد
      final double baseStock =
          inv.previousBalance + inv.receivedQuantity - inv.totalSales;

      return FuelStockSummary(fuelType: inv.fuelType, baseStock: baseStock);
    }).toList();

    _applySalesDeductionsToSummaries(summaries, _selectedSessionDateTime);

    setState(() {
      _fuelStockSummaries = summaries;

      if (stationProvider.inventories.isNotEmpty) {
        _lastInventorySyncAt = stationProvider.inventories
            .map((inv) => inv.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
    });
  }

  Future<void> _persistClosingBalances() async {
    if (_selectedStationId == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _fuelStockSummaries) {
      final key = _closingBalanceCacheKey(entry.fuelType);
      await prefs.setDouble(key, entry.availableStock);
      _cachedClosingBalances[entry.fuelType] = entry.availableStock;
    }
  }

  String _closingBalanceCacheKey(String fuelType) {
    final stationPart = _selectedStationId ?? 'unknown';
    return 'closing_balance_${stationPart}_$fuelType';
  }

  FuelStockSummary? _findFuelStockSummary(String fuelType) {
    if (fuelType.trim().isEmpty) return null;
    final target = _normalizeFuelType(fuelType);
    try {
      return _fuelStockSummaries.firstWhere(
        (summary) => _normalizeFuelType(summary.fuelType) == target,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();

    _sessionDateController.text = _sessionDateFormat.format(
      _selectedSessionDateTime,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final stationProvider = context.read<StationProvider>();

      if (auth.isStationBoy && auth.stationId != null) {
        await stationProvider.fetchStationById(auth.stationId!);
        if (!mounted) return;

        setState(() {
          _selectedStation = stationProvider.selectedStation;
          _selectedStationId = _selectedStation?.id;

          _selectedSessionDateTime = DateTime.now();
          _sessionDateController.text = _sessionDateFormat.format(
            _selectedSessionDateTime,
          );

          _selectedPumps.clear();
          _resetNozzleControllers();
          _fuelStockSummaries.clear();
          _lastInventorySyncAt = null;
          _refreshFuelPrices();
        });

        if (_selectedStation != null && _selectedStation!.pumps.isNotEmpty) {
          _selectedPumps.addAll(_selectedStation!.pumps);
          _prepareNozzlesForAllPumps(_selectedPumps);
        }

        // ✅ المصدر الصح
        await _loadLiveFuelStockFromInventory(_selectedStationId!);
      } else {
        await stationProvider.fetchStations();
        if (!mounted) return;

        setState(() {
          _selectedStation = null;
          _selectedStationId = null;
          _selectedPumps.clear();
          _resetNozzleControllers();
          _fuelStockSummaries.clear();
          _lastInventorySyncAt = null;
        });
      }
    });
  }

  void _prepareNozzlesForAllPumps(List<Pump> pumps) {
    _resetNozzleControllers();

    for (final pump in pumps) {
      for (final nozzle in pump.nozzles) {
        final key = _nozzleKey(pump, nozzle);
        _nozzleControllers[key] = TextEditingController();
        _nozzleImages[key] = null;
      }
    }
  }

  void _resetNozzleControllers() {
    for (final controller in _nozzleControllers.values) {
      controller.dispose();
    }
    _nozzleControllers.clear();
    _nozzleImages.clear();
  }

  void _refreshFuelPrices() {
    _fuelPriceLookup.clear();
    if (_selectedStation == null) return;
    for (final price in _selectedStation!.fuelPrices) {
      final fuelType = price.fuelType.trim();
      if (fuelType.isEmpty) continue;
      _fuelPriceLookup[fuelType] = price.price;
    }
  }

  List<FuelStockSummary> _buildFuelStockSummariesFromCurrentStock(
    List<Map<String, dynamic>> currentStock,
  ) {
    final latestByFuel = <String, FuelStockSummary>{};

    double readValue(Map<String, dynamic> item, List<String> keys) {
      bool sawAnyValue = false;
      for (final key in keys) {
        if (!item.containsKey(key)) continue;
        final value = item[key];
        if (value == null) continue;

        sawAnyValue = true;
        final parsed = _parseStockNumber(value);
        if (parsed.abs() > 0.0001) return parsed;
      }
      return sawAnyValue ? 0 : 0;
    }

    for (final item in currentStock) {
      final fuelType = item['fuelType']?.toString().trim() ?? '';
      final key = _normalizeFuelType(fuelType);
      if (key.isEmpty) continue;

      latestByFuel[key] = FuelStockSummary(
        fuelType: fuelType,
        baseStock: readValue(item, const [
          'currentBalance',
          'quantity',
          'remaining',
          'inventoryReferenceBalance',
          'balance',
          'availableStock',
          'actualBalance',
          'calculatedBalance',
        ]),
        salesAlreadyAppliedInBase: true,
      );
    }

    final summaries = latestByFuel.values.toList();
    summaries.sort((a, b) => a.fuelType.compareTo(b.fuelType));
    return summaries;
  }

  Future<void> _loadFuelBalanceReportForStation(String stationId) async {
    if (!mounted) return;

    setState(() {
      _isFuelBalanceReportLoading = true;
      _fuelBalanceReportError = null;
      _loadingFuelBalanceStationId = stationId;
    });

    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    // ✅ مهم: استخدم تاريخ الجلسة المختار (مش DateTime.now)
    final targetDate = DateTime(
      _selectedSessionDateTime.year,
      _selectedSessionDateTime.month,
      _selectedSessionDateTime.day,
    );

    List<FuelStockSummary> summaries = [];
    String? error;

    try {
      await stationProvider.fetchCurrentStock(
        stationId,
        asOfDate: _selectedSessionDateTime,
      );
      summaries = _buildFuelStockSummariesFromCurrentStock(
        stationProvider.currentStock,
      );
      if (summaries.isNotEmpty &&
          !summaries.any((s) => s.baseStock.abs() > 0.0001)) {
        summaries = [];
      }
    } catch (e) {
      error = e.toString();
    }

    // ✅ بدل التجميع السنوي: خُد آخر رصيد لكل نوع وقود حتى targetDate
    var finalSummaries = summaries;

    // ✅ fallback: لو التقرير رجّع فاضي
    if (finalSummaries.isEmpty) {
      final startOfYear = DateTime(targetDate.year, 1, 1);
      final endOfRange = targetDate;
      List<FuelBalanceReportRow> rows = [];

      try {
        await stationProvider.fetchFuelBalanceReport(
          stationId: stationId,
          startDate: startOfYear,
          endDate: endOfRange,
        );
        rows = stationProvider.fuelBalanceReport;
      } catch (e) {
        error ??= e.toString();
      }

      finalSummaries = _buildFuelStockSummariesFromReport(rows, targetDate);
      if (finalSummaries.isEmpty) {
        finalSummaries = await _loadInventorySummariesFallback(
          stationId,
          targetDate,
        );
      }
      _applySalesDeductionsToSummaries(finalSummaries, targetDate);
    }

    if (!mounted) return;

    setState(() {
      _fuelStockSummaries = finalSummaries;
      _fuelBalanceReportError = error;
      _fuelBalanceStationId = stationId;
      _loadingFuelBalanceStationId = null;
      _isFuelBalanceReportLoading = false;
    });
  }

  List<FuelStockSummary> _buildFuelStockSummariesFromReport(
    List<FuelBalanceReportRow> rows,
    DateTime targetDate,
  ) {
    final Map<String, FuelBalanceReportRow> latestByFuel = {};

    bool isSameOrBeforeDay(DateTime d) {
      final dd = DateTime(d.year, d.month, d.day);
      return !dd.isAfter(targetDate);
    }

    for (final row in rows) {
      final fuelKey = _normalizeFuelType(row.fuelType);
      if (fuelKey.isEmpty) continue;

      // تجاهل أي صف بعد تاريخ الجلسة
      if (!isSameOrBeforeDay(row.date)) continue;

      final existing = latestByFuel[fuelKey];
      if (existing == null || row.date.isAfter(existing.date)) {
        latestByFuel[fuelKey] = row;
      }
    }

    final result = <FuelStockSummary>[];

    for (final entry in latestByFuel.entries) {
      final row = entry.value;

      // ✅ الرصيد الأساسي الصحيح من التقرير
      final double baseStock =
          row.actualBalance ??
          row.calculatedBalance ??
          (row.openingBalance + row.received - row.sales);

      result.add(
        FuelStockSummary(fuelType: row.fuelType.trim(), baseStock: baseStock),
      );
    }

    // ترتيب ثابت (اختياري)
    result.sort((a, b) => a.fuelType.compareTo(b.fuelType));
    return result;
  }

  // List<FuelStockSummary> _aggregateFuelStockSummaries(
  //   List<FuelBalanceReportRow> rows,
  // ) {
  //   final map = <String, FuelStockSummary>{};

  //   for (final row in rows) {
  //     final key = _normalizeFuelType(row.fuelType);

  //     final entry = map.putIfAbsent(key, () => FuelStockSummary(fuelType: key));

  //     entry.openingBalance += row.openingBalance;
  //     entry.received += row.received;
  //     entry.sales += row.sales;

  //     final computedAvailable =
  //         (row.actualBalance != null && row.actualBalance! > 0)
  //         ? row.actualBalance!
  //         : row.calculatedBalance ??
  //               (row.openingBalance + row.received - row.sales);
  //     entry.availableStock = computedAvailable;
  //     entry.baseStock = computedAvailable;

  //     if (row.calculatedBalance != null) {
  //       entry.calculatedBalance = row.calculatedBalance;
  //     }
  //     if (row.actualBalance != null) {
  //       entry.actualBalance = row.actualBalance;
  //     }
  //     entry.status = row.status;
  //   }

  //   return map.values.toList();
  // }

  // Future<void> _refreshCurrentFuelStock() async {
  //   if (_selectedStationId == null) return;

  //   final stationProvider = context.read<StationProvider>();

  //   await stationProvider.fetchCurrentStock(_selectedStationId!);

  //   if (!mounted) return;

  //   final targetDate = DateTime(
  //     _selectedSessionDateTime.year,
  //     _selectedSessionDateTime.month,
  //     _selectedSessionDateTime.day,
  //   );
  //   final salesTotals = _salesByFuelForDate(
  //     stationProvider.sessions,
  //     targetDate,
  //   );

  //   setState(() {
  //     _fuelStockSummaries = stationProvider.currentStock.map((item) {
  //       final balance = (item['balance'] as num?)?.toDouble() ?? 0;
  //       final fuelType = item['fuelType']?.trim() ?? '';
  //       final key = _normalizeFuelType(fuelType);
  //       final sold = salesTotals[key] ?? 0;
  //       final available = balance - sold;

  //       return FuelStockSummary(
  //         fuelType: fuelType,
  //         openingBalance: balance,
  //         received: 0,
  //         sales: sold,
  //         availableStock: available,
  //         calculatedBalance: balance,
  //         actualBalance: balance,
  //         baseStock: balance,
  //         status: balance > 0 ? 'معتمد' : 'بدون مخزون',
  //       );
  //     }).toList();
  //   });
  // }

  Future<List<FuelStockSummary>> _loadInventorySummariesFallback(
    String stationId,
    DateTime date,
  ) async {
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    try {
      await stationProvider.fetchInventories(
        filters: {
          'stationId': stationId,
          'startDate': _formatDate(date),
          'endDate': _formatDate(date),
        },
      );
    } catch (_) {
      return [];
    }

    final targetDate = DateTime(date.year, date.month, date.day);
    final inventories = stationProvider.inventories.where(
      (inventory) => _isSameDay(inventory.inventoryDate, targetDate),
    );

    return inventories.map(_inventoryToSummary).toList();
  }

  String _formatDate(DateTime date) => date.toIso8601String().split('T').first;

  bool _isSameDay(DateTime date, DateTime target) {
    return date.year == target.year &&
        date.month == target.month &&
        date.day == target.day;
  }

  FuelStockSummary _inventoryToSummary(DailyInventory inventory) {
    // ✅ الرصيد الأساسي = نفس منطق صفحة التوريد
    final double baseStock =
        inventory.previousBalance +
        inventory.receivedQuantity -
        inventory.totalSales;

    return FuelStockSummary(
      fuelType: inventory.fuelType,
      baseStock: baseStock,
      salesAlreadyAppliedInBase: true,
    );
  }

  Future<void> _pickNozzleImage(String key) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 70,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _nozzleImages[key] = picked;
    });
  }

  Future<void> _pickSessionDateTime() async {
    final DateTime initialDate = _selectedSessionDateTime;
    final DateTime firstAllowedDate = DateTime(2000);
    final DateTime lastAllowedDate = DateTime.now().add(
      const Duration(days: 3650),
    );
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstAllowedDate,
      lastDate: lastAllowedDate,
    );
    if (pickedDate == null) return;

    final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (!mounted) return;

    final TimeOfDay selectedTime = pickedTime ?? initialTime;
    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    setState(() {
      _selectedSessionDateTime = newDateTime;
      _sessionDateController.text = _sessionDateFormat.format(newDateTime);
    });

    if (_selectedStationId != null) {
      await _loadFuelBalanceReportForStation(_selectedStationId!);
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    setState(() => _showValidationErrors = true);

    if (!_formKey.currentState!.validate()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstError();
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final stationProvider = Provider.of<StationProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final String? finalStationId = authProvider.isStationBoy
          ? authProvider.stationId
          : _selectedStationId;

      if (finalStationId == null || _selectedPumps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(loc.AppStrings.selectStationAndPump)),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      // =========================
      // 🔹 تجهيز قراءات الخراطيم
      // =========================
      final List<NozzleReading> allReadings = [];
      final Set<String> fuelTypesInSession = {};

      for (final pump in _selectedPumps) {
        final activeNozzles = pump.nozzles.where((n) => n.isActive).toList();

        if (activeNozzles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(loc.AppStrings.activatePumpSlots, {
                  'pumpNumber': pump.pumpNumber,
                }),
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return;
        }

        for (final nozzle in activeNozzles) {
          final key = _nozzleKey(pump, nozzle);

          final text = _nozzleControllers[key]?.text.trim();
          final value = double.tryParse(text ?? '');

          if (value == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr(loc.AppStrings.invalidNozzleReading, {
                    'nozzleNumber': nozzle.nozzleNumber,
                    'pumpNumber': pump.pumpNumber,
                  }),
                ),
                backgroundColor: AppColors.errorRed,
              ),
            );
            return;
          }

          final image = _nozzleImages[key];
          if (image == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr(loc.AppStrings.attachNozzleImage, {
                    'nozzleNumber': nozzle.nozzleNumber,
                    'pumpNumber': pump.pumpNumber,
                  }),
                ),
                backgroundColor: AppColors.errorRed,
              ),
            );
            return;
          }

          String imageUrl;

          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            imageUrl = await FirebaseStorageService.uploadSessionImage(
              sessionId: 'TEMP',
              type: 'opening',
              nozzleId: nozzle.id,
              webBytes: bytes,
            );
          } else {
            imageUrl = await FirebaseStorageService.uploadSessionImage(
              sessionId: 'TEMP',
              type: 'opening',
              nozzleId: nozzle.id,
              filePath: image.path,
            );
          }

          final fuelType = nozzle.fuelType.trim();
          fuelTypesInSession.add(fuelType);

          allReadings.add(
            NozzleReading(
              nozzleId: nozzle.id,
              nozzleNumber: nozzle.nozzleNumber,
              position: nozzle.position,
              fuelType: fuelType,
              openingReading: value,
              openingImageUrl: imageUrl,
              pumpId: pump.id,
              pumpNumber: pump.pumpNumber,
            ),
          );
        }
      }

      // ملاحظة: لا نمنع فتح الجلسة في حالة عدم وجود مخزون.

      // =========================
      // 🔹 إنشاء الجلسة
      // =========================
      final DateTime sessionDateTime = authProvider.isStationBoy
          ? DateTime.now()
          : _selectedSessionDateTime;

      final session = PumpSession(
        id: '',
        sessionNumber: '',
        stationId: finalStationId,
        stationName: _selectedStation?.stationName ?? '',

        pumpId: _selectedPumps.first.id,
        pumpNumber: _selectedPumps.first.pumpNumber,

        // مهم: مطلوب في الموديل
        fuelType: fuelTypesInSession.length == 1
            ? fuelTypesInSession.first
            : 'متعدد',

        pumpsCount: _selectedPumps.length,
        shiftType: _selectedShiftType ?? _shiftTypes.first,
        sessionDate: sessionDateTime,
        openingEmployeeId: authProvider.user?.id,
        openingEmployeeName: authProvider.user?.name,
        openingReading: allReadings.first.openingReading,
        openingTime: sessionDateTime,
        openingApproved: false,
        closingApproved: false,
        paymentTypes: PaymentTypes(cash: 0, card: 0, mada: 0, other: 0),
        nozzleReadings: allReadings,
        carriedForwardBalance: 0,
        status: 'مفتوحة',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await stationProvider.openSession(session);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(loc.AppStrings.openSessionSuccess)),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              stationProvider.error ??
                  context.tr(loc.AppStrings.unexpectedError),
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showValidationErrors = false;
        });
      }
    }
  }

  void _scrollToFirstError() {
    final RenderObject? renderObject = _formKey.currentContext
        ?.findRenderObject();
    if (renderObject != null) {
      _tableScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showNozzlesDialog(Pump pump) {
    setState(() {
      _selectedPumpForNozzles = pump;
      _showNozzleDialog = true;
    });
  }

  void _closeNozzlesDialog() {
    setState(() {
      _selectedPumpForNozzles = null;
      _showNozzleDialog = false;
    });
  }

  @override
  void dispose() {
    _sessionDateController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildWebLayout();
    }
  }

  Widget _buildMobileLayout() {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final stations = stationProvider.stations;
    final Station? station = authProvider.isStationBoy
        ? _selectedStation
        : (_selectedStation ?? stationProvider.selectedStation);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRefreshStockFromProvider(stationProvider);
    });

    if (stationProvider.isStationsLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              context.tr(loc.AppStrings.openSessionTitle),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFf8f9fa), Color(0xFFe9ecef)],
              ),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Station Selection
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(loc.AppStrings.sessionInfoTitle),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (authProvider.isStationBoy) ...[
                              if (station != null)
                                _buildMobileStationInfo(station)
                              else
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ] else ...[
                              _buildStationDropdown(stations, false),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Session Details
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تفاصيل قرائات',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildShiftDropdown(false),
                            const SizedBox(height: 12),
                            if (authProvider.role ==
                                'sales_manager_statiun') ...[
                              Text(
                                context.tr(loc.AppStrings.sessionDateTimeLabel),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _sessionDateController,
                                readOnly: true,
                                onTap: _pickSessionDateTime,
                                decoration: InputDecoration(
                                  labelText: context.tr(
                                    loc.AppStrings.sessionDateTimeLabel,
                                  ),
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Display ALL Pumps Automatically
                    if (_selectedStation != null &&
                        _selectedStation!.pumps.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildAllPumpsDisplay(isWeb: false),
                    ],

                    const SizedBox(height: 16),

                    // Fuel Stock Summary - المخزون الإجمالي
                    if (_selectedStation != null) ...[
                      _buildTotalFuelStockSummary(),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),

                    // Submit Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GradientButton(
                        onPressed: (_isSubmitting || stationProvider.isLoading)
                            ? null
                            : _submitForm,
                        text: (_isSubmitting || stationProvider.isLoading)
                            ? context.tr(loc.AppStrings.loadingOpeningSession)
                            : context.tr(loc.AppStrings.openSessionButton),
                        gradient: AppColors.accentGradient,
                        isLoading: _isSubmitting || stationProvider.isLoading,
                        height: 50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_showNozzleDialog && _selectedPumpForNozzles != null)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(child: _buildNozzlesDialog()),
            ),
          ),
      ],
    );
  }

  Widget _buildAllPumpsDisplay({required bool isWeb}) {
    if (_selectedStation == null || _selectedStation!.pumps.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.local_gas_station,
                size: 60,
                color: AppColors.lightGray,
              ),
              const SizedBox(height: 16),
              const Text(
                'لا توجد مضخات في هذه المحطة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مضخات المحطة',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedStation!.pumps.length} مضخة',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // عرض جميع المضخات في شبكة متجاوبة
            _buildPumpsGrid(isWeb: isWeb),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpsGrid({required bool isWeb}) {
    final pumps = _selectedStation!.pumps;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = isWeb
        ? (screenWidth >= 1500
              ? 5
              : screenWidth >= 1300
              ? 4
              : screenWidth >= 1024
              ? 3
              : 2)
        : 2;
    final childAspectRatio = isWeb ? 1.0 : 0.85;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: pumps.length,
      itemBuilder: (context, index) {
        final pump = pumps[index];
        return _buildModernPumpCard(pump);
      },
    );
  }

  bool _isPumpReadingsComplete(Pump pump) {
    final activeNozzles = pump.nozzles
        .where((nozzle) => nozzle.isActive)
        .toList();

    if (activeNozzles.isEmpty) return false;

    for (final nozzle in activeNozzles) {
      final key = _nozzleKey(pump, nozzle);
      final text = _nozzleControllers[key]?.text.trim();
      final image = _nozzleImages[key];

      if (text == null || text.isEmpty || image == null) {
        return false;
      }
    }

    return true;
  }

  Widget _buildModernPumpCard(Pump pump) {
    final activeNozzles = pump.nozzles.where((n) => n.isActive).toList();
    final leftNozzles = activeNozzles
        .where((n) => n.position.toLowerCase() == 'left')
        .toList();
    final rightNozzles = activeNozzles
        .where((n) => n.position.toLowerCase() == 'right')
        .toList();
    final bool readingsComplete = _isPumpReadingsComplete(pump);

    return InkWell(
      onTap: () => _showNozzlesDialog(pump),
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pump Header - الجزء العلوي للمضخة
                Container(
                  height: 64,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getFuelTypeColor(pump.fuelType).withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getFuelTypeColor(pump.fuelType),
                        boxShadow: [
                          BoxShadow(
                            color: _getFuelTypeColor(
                              pump.fuelType,
                            ).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          pump.pumpNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Pump Body - جسم المضخة
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // نوع الوقود
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getFuelTypeColor(
                              pump.fuelType,
                            ).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getFuelTypeColor(
                                pump.fuelType,
                              ).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            pump.fuelType,
                            style: TextStyle(
                              color: _getFuelTypeColor(pump.fuelType),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // عرض الليات المصغرة
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // الليات اليسرى
                            _buildNozzleMiniColumn(
                              nozzles: leftNozzles,
                              side: 'left',
                              fallbackFuelType: pump.fuelType,
                            ),

                            // فاصل
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),

                            // الليات اليمنى
                            _buildNozzleMiniColumn(
                              nozzles: rightNozzles,
                              side: 'right',
                              fallbackFuelType: pump.fuelType,
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // عدد الليات ومؤشر النقر
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 14,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${activeNozzles.length} لي  - انقر للإدخال',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (readingsComplete)
            Positioned(
              top: -10,
              right: -10,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNozzleMiniColumn({
    required List<Nozzle> nozzles,
    required String side,
    required String fallbackFuelType,
  }) {
    final uniqueFuelTypes = nozzles
        .map((nozzle) => nozzle.fuelType.trim())
        .where((type) => type.isNotEmpty)
        .toSet();
    final displayFuelType = uniqueFuelTypes.isNotEmpty
        ? uniqueFuelTypes.join(' • ')
        : fallbackFuelType;
    final labelColor = uniqueFuelTypes.isNotEmpty
        ? _getNozzleColor(uniqueFuelTypes.first)
        : _getNozzleColor(fallbackFuelType);

    return Column(
      children: [
        Text(
          displayFuelType,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          side == 'left' ? 'يسار' : 'يمين',
          style: TextStyle(
            color: side == 'left' ? Colors.blue : Colors.orange,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ...nozzles.take(2).map((nozzle) {
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getNozzleColor(nozzle.fuelType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _getNozzleColor(nozzle.fuelType).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Text(
              nozzle.nozzleNumber,
              style: TextStyle(
                color: _getNozzleColor(nozzle.fuelType),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }),
        if (nozzles.length > 2)
          Text(
            '+${nozzles.length - 2}',
            style: TextStyle(color: Colors.grey[600], fontSize: 9),
          ),
      ],
    );
  }

  Widget _buildNozzlesDialog() {
    if (_selectedPumpForNozzles == null) {
      return const SizedBox.shrink();
    }

    final pump = _selectedPumpForNozzles!;
    final screenWidth = MediaQuery.of(context).size.width;

    // 👈 التحكم الحقيقي في عرض الديالوج هنا
    final dialogWidth = screenWidth > 1200
        ? 520.0
        : screenWidth > 900
        ? 480.0
        : screenWidth > 768
        ? 460.0
        : screenWidth * 0.95;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: dialogWidth,
          constraints: const BoxConstraints(
            maxWidth: 520, // 👈 يمنع أي تمدد زيادة
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== Header =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getFuelTypeColor(pump.fuelType).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _closeNozzlesDialog,
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getFuelTypeColor(pump.fuelType),
                      ),
                      child: Center(
                        child: Text(
                          pump.pumpNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المضخة ${pump.pumpNumber}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            pump.fuelType,
                            style: TextStyle(
                              color: _getFuelTypeColor(pump.fuelType),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ===== Content =====
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: pump.nozzles.where((n) => n.isActive).map((
                      nozzle,
                    ) {
                      final key = _nozzleKey(pump, nozzle);
                      return Align(
                        alignment: Alignment.topCenter, // 👈 يمنع التمدد
                        child: _buildNozzleInputCard(
                          pump: pump,
                          nozzle: nozzle,
                          key: key,
                          sideColor: _getNozzleColor(nozzle.fuelType),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ===== Footer =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _closeNozzlesDialog,
                      child: const Text('إغلاق'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _closeNozzlesDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getFuelTypeColor(pump.fuelType),
                      ),
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNozzleSection({
    required String title,
    required List<Nozzle> nozzles,
    required Pump pump,
    required Color sideColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sideColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sideColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.ev_station, color: sideColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: sideColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: sideColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${nozzles.length} لي ',
                  style: TextStyle(
                    color: sideColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        ...nozzles.map((nozzle) {
          final key = _nozzleKey(pump, nozzle);
          return _buildNozzleInputCard(
            pump: pump,
            nozzle: nozzle,
            key: key,
            sideColor: sideColor,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildNozzleInputCard({
    required Pump pump,
    required Nozzle nozzle,
    required String key,
    required Color sideColor,
  }) {
    final controller = _nozzleControllers[key];
    final image = _nozzleImages[key];
    final Color nozzleColor = _getNozzleColor(nozzle.fuelType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Header =====
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nozzleColor,
                ),
                child: Center(
                  child: Text(
                    nozzle.nozzleNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لي ${nozzle.nozzleNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      nozzle.fuelType,
                      style: TextStyle(color: nozzleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ===== Reading Input =====
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'أدخل قراءة العداد',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),

            validator: _showValidationErrors
                ? (v) {
                    if (v == null || v.isEmpty) return 'مطلوب';
                    if (double.tryParse(v) == null) return 'رقم غير صالح';
                    return null;
                  }
                : null,
          ),

          const SizedBox(height: 14),

          // ===== Image Button =====
          ElevatedButton.icon(
            onPressed: () => _pickNozzleImage(key),
            icon: const Icon(Icons.camera_alt),
            label: Text(image == null ? 'التقاط صورة' : 'تغيير الصورة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: image == null ? sideColor : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Color _getFuelTypeColor(String fuelType) {
    if (fuelType.contains('91')) return Colors.green;
    if (fuelType.contains('95')) return Colors.red;
    if (fuelType.contains('ديزل')) return Colors.yellow[800]!;
    if (fuelType.contains('كيروسين')) return Colors.orange[700]!;
    return AppColors.primaryBlue;
  }

  Color _getNozzleColor(String fuelType) {
    return _getFuelTypeColor(fuelType);
  }

  Widget _buildTotalFuelStockSummary() {
    if (_selectedStation == null) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: AppColors.primaryBlue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'المخزون الإجمالي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // حساب المخزون الإجمالي من جميع المضخات
            _buildTotalStockFromPumps(),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStockFromPumps() {
    if (_fuelStockSummaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: Text(
            'لا توجد بيانات مخزون متاحة حالياً',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 768 ? screenWidth - 64 : 220.0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _fuelStockSummaries.map((summary) {
        return _buildTotalFuelStockCard(
          summary: summary, // ✅ نمرر الـ summary نفسه
          width: cardWidth,
        );
      }).toList(),
    );
  }

  Widget _buildTotalFuelStockCard({
    required FuelStockSummary summary,
    required double width,
  }) {
    final fuelType = summary.fuelType.trim();
    final fuelColor = _getFuelTypeColor(fuelType);
    final double balance = summary.postSalesBalance;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== Header =====
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: fuelColor.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fuelColor,
                  boxShadow: [
                    BoxShadow(
                      color: fuelColor.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_gas_station,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // ===== Body =====
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fuel type
                Text(
                  fuelType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: fuelColor,
                  ),
                ),

                const SizedBox(height: 6),

                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: balance > 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    balance > 0 ? 'متاح' : 'بدون مخزون',
                    style: TextStyle(
                      color: balance > 0 ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Progress bar
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 6,
                      width: (balance / 10000).clamp(0.0, 1.0) * (width - 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [fuelColor, fuelColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Quantity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المخزون',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      '${summary.postSalesBalance.toStringAsFixed(2)} لتر',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: summary.postSalesBalance > 0
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStationInfo(Station station) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.local_gas_station, color: AppColors.primaryBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(loc.AppStrings.assignedStationLabel),
                  style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${station.stationCode ?? ''} - ${station.stationName ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebLayout() {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final stations = stationProvider.stations;
    final bool isSalesManager = authProvider.role == 'sales_manager_statiun';
    final bool canEditSessionDateTime =
        isSalesManager || authProvider.isAdminLike;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRefreshStockFromProvider(stationProvider);
    });

    if (stationProvider.isStationsLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              context.tr(loc.AppStrings.openSessionTitle),
              style: const TextStyle(color: Colors.white),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFf8f9fa), Color(0xFFe9ecef)],
              ),
            ),
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'افتتاح قرائات  جديدة',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'yyyy/MM/dd HH:mm',
                            ).format(DateTime.now()),
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Control Panel
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Station Selection
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'المحطة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildWebStationSelector(
                                    stations,
                                    authProvider,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 15),

                            // Shift Selection
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الوردية',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildWebShiftSelector(),
                                ],
                              ),
                            ),

                            const SizedBox(width: 20),

                            // Session Date/Time display
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'تاريخ ووقت القرائات',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: canEditSessionDateTime
                                        ? _pickSessionDateTime
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            color: AppColors.primaryBlue,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _sessionDateController.text,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                          if (canEditSessionDateTime)
                                            Icon(
                                              Icons.edit_calendar,
                                              color: AppColors.primaryBlue,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 24),

                            // Action Buttons
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الإجراءات',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GradientButton(
                                          onPressed: _submitForm,
                                          text: 'حفظ القرائات',
                                          gradient: AppColors.accentGradient,
                                          isLoading: _isSubmitting,
                                          height: 48,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _resetNozzleControllers();
                                            if (_selectedPumps.isNotEmpty) {
                                              _prepareNozzlesForAllPumps(
                                                _selectedPumps,
                                              );
                                            }
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 18,
                                        ),
                                        label: const Text('تفريغ الحقول'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey[700],
                                          side: BorderSide(
                                            color: Colors.grey[400]!,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Main Content - عرض جميع المضخات تلقائياً
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Display ALL Pumps Automatically
                            if (_selectedStation != null) ...[
                              _buildAllPumpsDisplay(isWeb: true),
                              const SizedBox(height: 16),
                            ],

                            // Total Fuel Stock Summary - المخزون الإجمالي
                            if (_selectedStation != null) ...[
                              _buildTotalFuelStockSummary(),
                              const SizedBox(height: 16),
                            ],

                            // Session Summary
                            if (_selectedPumps.isNotEmpty) ...[
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ملخص القرائات',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _buildSessionInfoItem(
                                            'عدد المضخات',
                                            '${_selectedPumps.length}',
                                            Icons.local_gas_station,
                                          ),
                                          const SizedBox(width: 16),
                                          _buildSessionInfoItem(
                                            'الوردية',
                                            _selectedShiftType ?? 'صباحية',
                                            Icons.schedule,
                                          ),
                                          const SizedBox(width: 16),
                                          if (isSalesManager)
                                            _buildSessionInfoItem(
                                              'التاريخ',
                                              _sessionDateController.text,
                                              Icons.calendar_today,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_showNozzleDialog && _selectedPumpForNozzles != null)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(child: _buildNozzlesDialog()),
            ),
          ),
      ],
    );
  }

  Widget _buildSessionInfoItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebStationSelector(
    List<Station> stations,
    AuthProvider authProvider,
  ) {
    if (authProvider.isStationBoy) {
      return _selectedStation != null
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_gas_station,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedStation!.stationCode} - ${_selectedStation!.stationName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'المحطة المخصصة',
                          style: TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: _selectedStationId,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text('اختر المحطة', style: TextStyle(color: Colors.grey[500])),
        ),
        icon: Icon(
          Icons.arrow_drop_down,
          color: AppColors.primaryBlue,
          size: 24,
        ),
        items: stations.map((station) {
          return DropdownMenuItem<String>(
            value: station.id,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '${station.stationCode} - ${station.stationName}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          );
        }).toList(),
        onChanged: (value) async {
          if (value == null) return;

          final stationProvider = context.read<StationProvider>();

          setState(() {
            _selectedStationId = value;
            _selectedStation = null;
            _selectedPumps.clear();
            _resetNozzleControllers();
            _fuelStockSummaries.clear();
            _lastInventorySyncAt = null;
          });

          await stationProvider.fetchStationById(value);
          if (!mounted) return;

          _selectedStation = stationProvider.selectedStation;

          if (_selectedStation != null && _selectedStation!.pumps.isNotEmpty) {
            _selectedPumps.addAll(_selectedStation!.pumps);
            _prepareNozzlesForAllPumps(_selectedPumps);
          }

          setState(() {});

          // ✅ نفس صفحة التوريد
          await _loadLiveFuelStockFromInventory(value);
        },
      ),
    );
  }

  Widget _buildWebShiftSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: _selectedShiftType ?? _shiftTypes.first,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(
          Icons.arrow_drop_down,
          color: AppColors.primaryBlue,
          size: 24,
        ),
        items: _shiftTypes.map((shift) {
          final translatedShift = shift == 'صباحية'
              ? context.tr(loc.AppStrings.shiftTypeMorning)
              : context.tr(loc.AppStrings.shiftTypeEvening);

          return DropdownMenuItem<String>(
            value: shift,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                translatedShift,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedShiftType = value;
          });
        },
      ),
    );
  }

  Widget _buildStationDropdown(List<Station> stations, bool isLargeScreen) {
    final auth = context.read<AuthProvider>();

    if (stations.isEmpty && auth.isStationBoy) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'لا توجد محطة مخصصة لهذا المستخدم',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                  fontSize: isLargeScreen ? 14 : 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'اختر المحطة',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButton<String>(
            value: _selectedStationId,
            isExpanded: true,
            underline: const SizedBox(),
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(
                'اختر المحطة',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.primaryBlue,
              size: 24,
            ),
            items: stations.map((station) {
              return DropdownMenuItem<String>(
                value: station.id,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${station.stationCode} - ${station.stationName}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) async {
              if (value == null) return;

              final stationProvider = Provider.of<StationProvider>(
                context,
                listen: false,
              );

              setState(() {
                _selectedStationId = value;
                _selectedStation = null;
                _selectedPumps.clear();
                _resetNozzleControllers();
                _fuelStockSummaries = [];
                _fuelBalanceStationId = null;
                _fuelBalanceReportError = null;
                _loadingFuelBalanceStationId = null;
                _lastInventorySyncAt = null;
              });

              await stationProvider.fetchStationById(value);

              if (!mounted) return;

              setState(() {
                _selectedStation = stationProvider.selectedStation;

                // ✅ تحميل جميع مضخات المحطة تلقائياً
                if (_selectedStation != null &&
                    _selectedStation!.pumps.isNotEmpty) {
                  _selectedPumps.addAll(_selectedStation!.pumps);
                  _prepareNozzlesForAllPumps(_selectedPumps);
                }

                _refreshFuelPrices();
              });

              await _loadFuelBalanceReportForStation(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShiftDropdown(bool isLargeScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'الوردية',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButton<String>(
            value: _selectedShiftType ?? _shiftTypes.first,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.primaryBlue,
              size: 24,
            ),
            items: _shiftTypes.map((shift) {
              final translatedShift = shift == 'صباحية'
                  ? context.tr(loc.AppStrings.shiftTypeMorning)
                  : context.tr(loc.AppStrings.shiftTypeEvening);

              return DropdownMenuItem<String>(
                value: shift,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    translatedShift,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedShiftType = value;
              });
            },
          ),
        ),
      ],
    );
  }
}
