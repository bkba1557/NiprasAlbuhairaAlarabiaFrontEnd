// // ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unused_field, unused_element

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
// import 'package:intl/intl.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'dart:js' as js;

// class ExpenseItem {
//   String type;
//   double amount;
//   String? notes;

//   ExpenseItem({required this.type, required this.amount, this.notes});

//   Map<String, dynamic> toJson() => {
//     'type': type,
//     'category': type,
//     'description': notes?.isNotEmpty == true ? notes : type,
//     'amount': amount,
//     'notes': notes,
//   };
// }

// class CloseSessionScreen extends StatefulWidget {
//   const CloseSessionScreen({super.key});

//   @override
//   State<CloseSessionScreen> createState() => _CloseSessionScreenState();
// }

// class _CloseSessionScreenState extends State<CloseSessionScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _cashController = TextEditingController();
//   final TextEditingController _cardController = TextEditingController();
//   final TextEditingController _madaController = TextEditingController();
//   final TextEditingController _otherController = TextEditingController();
//   final TextEditingController _carriedForwardController =
//       TextEditingController();
//   final TextEditingController _fuelQuantityController = TextEditingController();
//   final TextEditingController _tankerNumberController = TextEditingController();
//   final TextEditingController _supplierNameController = TextEditingController();
//   final TextEditingController _notesController = TextEditingController();
//   final TextEditingController _shortageAmountController =
//       TextEditingController();

//   final TextEditingController _shortageReasonController =
//       TextEditingController();

//   final Map<String, TextEditingController> _closingControllers = {};
//   final Map<String, XFile?> _closingImages = {};
//   final ImagePicker _imagePicker = ImagePicker();
//   final Map<String, double> _stationFuelPrices = {};

//   String? _selectedFuelType;
//   String? _differenceReason;
//   double _totalLiters = 0;
//   double _totalAmount = 0;
//   double _totalSales = 0;
//   double _calculatedDifference = 0;
//   double _shortageAmount = 0.0;
//   String? _shortageReason;
//   bool _shortageResolved = false;

//   final List<ExpenseItem> _expenses = [];

//   final TextEditingController _expenseTypeController = TextEditingController();
//   final TextEditingController _expenseAmountController =
//       TextEditingController();
//   final TextEditingController _expenseNotesController = TextEditingController();

//   PumpSession? _session;

//   PumpSession get session => _session!;
//   late stt.SpeechToText _speech;
//   bool _isListeningExpenseType = false;
//   String? _arabicLocaleId;
//   final Map<String, double> _soldLitersByFuel = {};


//   final List<String> _differenceReasons = [
//     'عادي',
//     'تهوية',
//     'تسريب',
//     'خطأ في القراءة',
//     'أخرى',
//   ];

//   String _nozzleKey(NozzleReading n) {
//     return '${n.pumpId}_${n.nozzleNumber}_${n.side}_${n.fuelType}';
//   }

//   @override
//   void initState() {
//     super.initState();

//     _speech = stt.SpeechToText();

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       try {
//         final args = ModalRoute.of(context)?.settings.arguments;

//         if (args == null || args is! PumpSession) {
//           debugPrint('❌ CloseSessionScreen: session args is NULL');
//           if (mounted) Navigator.pop(context);
//           return;
//         }

//         _session = args;

//         _selectedFuelType =
//             (_session!.nozzleReadings != null &&
//                 _session!.nozzleReadings!.isNotEmpty)
//             ? _session!.nozzleReadings!.first.fuelType
//             : null;

//         for (final nozzle in _session!.nozzleReadings ?? []) {
//           final key = _nozzleKey(nozzle);

//           _closingControllers.putIfAbsent(
//             key,
//             () => TextEditingController(
//               text: nozzle.closingReading?.toString() ?? '',
//             ),
//           );

//           _closingImages.putIfAbsent(key, () => null);
//         }

//         _carriedForwardController.text = '0';
//         _fuelQuantityController.text = '0';

//         // ❌ لا تهيئة للصوت هنا على الويب
//         if (!kIsWeb) {
//           final available = await _speech.initialize();
//           if (available) {
//             final locales = await _speech.locales();
//             final arabic = locales.firstWhere(
//               (l) => l.localeId.startsWith('ar'),
//               orElse: () => locales.first,
//             );
//             _arabicLocaleId = arabic.localeId;
//           }
//         }

//         _recalculateTotals();

//         // ⏱️ حماية من تعليق API
//         await _loadStationFuelPrices().timeout(const Duration(seconds: 8));

//         if (mounted) setState(() {});
//       } catch (e, s) {
//         debugPrint('❌ CloseSession init error: $e');
//         debugPrintStack(stackTrace: s);
//       }
//     });
//   }

// void _recalculateTotals() {
//     if (_session == null) return;

//     double totalLiters = 0.0;
//     double theoreticalAmount = 0.0;
//     double expensesTotal = 0.0;

//     _soldLitersByFuel.clear(); // 🔥 مهم

//     final nozzleReadings = session.nozzleReadings ?? [];

//     for (final nozzle in nozzleReadings) {
//       if (nozzle.closingReading == null) continue;

//       final liters = _calculateNozzleLiters(nozzle);

//       if (liters <= 0) continue;

//       // ✅ إجمالي اليومية
//       totalLiters += liters;

//       // ✅ حسب نوع الوقود
//       final fuel = nozzle.fuelType.trim();
//       _soldLitersByFuel[fuel] = (_soldLitersByFuel[fuel] ?? 0) + liters;

//       // المبلغ
//       final amount = _calculateNozzleAmount(nozzle);
//       theoreticalAmount += amount;

//       nozzle.totalLiters = liters;
//       nozzle.totalAmount = amount;
//     }

//     final double cash = double.tryParse(_cashController.text) ?? 0;
//     final double card = double.tryParse(_cardController.text) ?? 0;
//     final double mada = double.tryParse(_madaController.text) ?? 0;
//     final double other = double.tryParse(_otherController.text) ?? 0;

//     final double actualSales = cash + card + mada + other;

//     for (final e in _expenses) {
//       expensesTotal += e.amount;
//     }

//     final rawDifference = actualSales - theoreticalAmount - expensesTotal;

//     setState(() {
//       _totalLiters = totalLiters;
//       _totalAmount = theoreticalAmount;
//       _totalSales = actualSales;
//       _calculatedDifference = _shortageResolved ? 0 : rawDifference;
//     });
//   }



//   double _calculateNozzleLiters(NozzleReading nozzle) {
//     final closing = nozzle.closingReading;
//     if (closing == null) return 0;
//     final diff = closing - nozzle.openingReading;
//     return diff > 0 ? diff : 0;
//   }

//   double _calculateNozzleAmount(NozzleReading nozzle) {
//     final pricePerLiter = _resolveNozzleUnitPrice(nozzle);
//     return _calculateNozzleLiters(nozzle) * pricePerLiter;
//   }

//   double _resolveNozzleUnitPrice(NozzleReading nozzle) {
//     if (nozzle.unitPrice != null && nozzle.unitPrice! > 0) {
//       return nozzle.unitPrice!;
//     }

//     final lookup = _stationFuelPrices[nozzle.fuelType];
//     if (lookup != null && lookup > 0) {
//       return lookup;
//     }

//     if (_session?.unitPrice != null && _session!.unitPrice! > 0) {
//       return _session!.unitPrice!;
//     }

//     return 0;
//   }

//   Future<void> _listenExpenseType() async {
//     if (!kIsWeb) return;

//     try {
//       final speechRecognition =
//           js.context['SpeechRecognition'] ??
//           js.context['webkitSpeechRecognition'];

//       if (speechRecognition == null) {
//         debugPrint('❌ SpeechRecognition API not available');
//         return;
//       }

//       final recognition = js.JsObject(speechRecognition);

//       recognition['lang'] = 'ar-SA';
//       recognition['continuous'] = false;
//       recognition['interimResults'] = false;

//       setState(() => _isListeningExpenseType = true);
//       recognition['onresult'] = js.allowInterop((dynamic event) {
//         final jsEvent = js.JsObject.fromBrowserObject(event);

//         final List results = jsEvent['results'] as List;
//         final List firstResult = results.first as List;
//         final Map firstAlternative = firstResult.first as Map;

//         final String transcript = firstAlternative['transcript'] as String;

//         debugPrint('🎧 WEB RESULT: $transcript');

//         setState(() {
//           _expenseTypeController.text = transcript;
//           _isListeningExpenseType = false;
//         });
//       });

//       recognition['onerror'] = js.allowInterop((dynamic event) {
//         final jsEvent = js.JsObject.fromBrowserObject(event);

//         final String error = jsEvent['error']?.toString() ?? 'unknown';

//         debugPrint('❌ WEB SPEECH ERROR: $error');

//         setState(() => _isListeningExpenseType = false);
//       });

//       recognition.callMethod('start');
//     } catch (e) {
//       debugPrint('❌ Web Speech exception: $e');
//       setState(() => _isListeningExpenseType = false);
//     }
//   }

//   Future<String> _uploadClosingImage({
//     required XFile image,
//     required PumpSession session,
//     required NozzleReading nozzle,
//   }) async {
//     final ref = FirebaseStorage.instance.ref().child(
//       'sessions/${session.id}/closing/'
//       'pump_${nozzle.pumpNumber}_nozzle_${nozzle.nozzleNumber}_${DateTime.now().millisecondsSinceEpoch}.jpg',
//     );

//     final bytes = await image.readAsBytes();
//     final uploadTask = await ref.putData(
//       bytes,
//       SettableMetadata(contentType: 'image/jpeg'),
//     );

//     return await uploadTask.ref.getDownloadURL();
//   }

//   Future<void> _loadStationFuelPrices() async {
//     if (_session == null) return;

//     final provider = Provider.of<StationProvider>(context, listen: false);
//     final station = await provider.fetchStationDetails(_session!.stationId);
//     if (!mounted) return;

//     setState(() {
//       _stationFuelPrices.clear();
//       if (station != null) {
//         for (final price in station.fuelPrices) {
//           _stationFuelPrices[price.fuelType] = price.price;
//         }
//       }
//     });

//     _recalculateTotals();
//   }

//   Future<void> _pickClosingImage(String key) async {
//     final picked = await _imagePicker.pickImage(
//       source: ImageSource.camera,
//       maxWidth: 1200,
//       imageQuality: 70,
//     );
//     if (picked == null || !mounted) return;

//     setState(() {
//       _closingImages[key] = picked;
//     });
//   }

//   Future<void> _submitForm() async {
//     if (_session == null) return;
//     final session = _session!;
//     if (!_formKey.currentState!.validate()) return;

//     final stationProvider = Provider.of<StationProvider>(
//       context,
//       listen: false,
//     );

//     // =========================
//     // 🔴 تحقق من قراءات الغلق والصور
//     // =========================
//     for (final nozzle in session.nozzleReadings ?? []) {
//       final key = _nozzleKey(nozzle);

//       if (nozzle.closingReading == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               context.tr(loc.AppStrings.enterClosingReadingForNozzle, {
//                 'nozzleNumber': nozzle.nozzleNumber,
//                 'pumpNumber': nozzle.pumpNumber,
//               }),
//             ),
//             backgroundColor: AppColors.errorRed,
//           ),
//         );
//         return;
//       }

//       if (_closingImages[key] == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               context.tr(loc.AppStrings.attachClosingImageForNozzle, {
//                 'nozzleNumber': nozzle.nozzleNumber,
//                 'pumpNumber': nozzle.pumpNumber,
//               }),
//             ),
//             backgroundColor: AppColors.errorRed,
//           ),
//         );
//         return;
//       }
//     }

//     try {
//       // =========================
//       // 🔹 رفع صور الغلق
//       // =========================
//       final List<Map<String, dynamic>> closingNozzles = [];

//       for (final nozzle in session.nozzleReadings ?? []) {
//         final key = _nozzleKey(nozzle);
//         final image = _closingImages[key]!;

//         final closingImageUrl = await _uploadClosingImage(
//           image: image,
//           session: session,
//           nozzle: nozzle,
//         );

//         closingNozzles.add({
//           'pumpId': nozzle.pumpId,
//           'nozzleId': nozzle.nozzleId,
//           'nozzleNumber': nozzle.nozzleNumber,
//           'closingReading': nozzle.closingReading,
//           'closingImageUrl': closingImageUrl,
//         });
//       }

//       // =========================
//       // 🔹 حساب المصروفات
//       // =========================
//       final double expensesTotal = _expenses.fold<double>(
//         0,
//         (sum, e) => sum + e.amount,
//       );

//       // =========================
//       // 🔹 هل يوجد عجز تمت تسويته؟
//       // =========================
//       final bool hasShortage =
//           _shortageResolved &&
//           _shortageAmount > 0 &&
//           _shortageReason != null &&
//           _shortageReason!.isNotEmpty;

//       // =========================
//       // 🔹 تجهيز بيانات الإغلاق
//       // =========================
//       final Map<String, dynamic> closingData = {
//         // 🔹 القراءات
//         'nozzleReadings': closingNozzles,

//         // 🔹 التحصيل
//         'paymentTypes': {
//           'cash': double.tryParse(_cashController.text) ?? 0,
//           'card': double.tryParse(_cardController.text) ?? 0,
//           'mada': double.tryParse(_madaController.text) ?? 0,
//           'other': double.tryParse(_otherController.text) ?? 0,
//         },

//         // 🔹 توريد الوقود (اختياري)
//         'fuelSupply':
//             _fuelQuantityController.text.isNotEmpty &&
//                 _fuelQuantityController.text != '0'
//             ? {
//                 'fuelType': _selectedFuelType,
//                 'quantity': double.tryParse(_fuelQuantityController.text) ?? 0,
//                 'tankerNumber': _tankerNumberController.text,
//                 'supplierName': _supplierNameController.text,
//               }
//             : null,

//         // 🔹 رصيد مرحّل
//         'carriedForwardBalance':
//             double.tryParse(_carriedForwardController.text) ?? 0,

//         // 🔹 المصروفات
//         'expenses': _expenses.map((e) => e.toJson()).toList(),
//         'expensesTotal': expensesTotal,

//         // 🔹 العجز (لو موجود)
//         'shortage': hasShortage
//             ? {'amount': _shortageAmount, 'reason': _shortageReason}
//             : null,

//         // 🔹 الفرق النهائي
//         'actualDifference': hasShortage ? 0 : _calculatedDifference,
//         'differenceReason': hasShortage ? 'تمت تسوية العجز' : _differenceReason,

//         // 🔹 ملاحظات
//         'notes': _notesController.text,
//       };

//       // =========================
//       // 🚀 إرسال الإغلاق
//       // =========================
//       final success = await stationProvider.closeSession(
//         session.id,
//         closingData,
//       );

//       if (!mounted) return;

//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(context.tr(loc.AppStrings.closingSessionSuccess)),
//             backgroundColor: AppColors.successGreen,
//           ),
//         );
//         Navigator.pop(context);
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
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             context.tr(loc.AppStrings.closeSessionError, {
//               'error': e.toString(),
//             }),
//           ),
//           backgroundColor: AppColors.errorRed,
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final stationProvider = Provider.of<StationProvider>(context);
//     final isLargeScreen = MediaQuery.of(context).size.width > 768;
//     final screenWidth = MediaQuery.of(context).size.width;

//     if (_session == null) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           context.tr(loc.AppStrings.closeSessionTitle),
//           style: const TextStyle(color: Colors.white),
//         ),
//         centerTitle: isLargeScreen,
//       ),
//       body: Center(
//         child: Form(
//           key: _formKey,
//           child: SingleChildScrollView(
//             padding: EdgeInsets.symmetric(
//               horizontal: isLargeScreen ? screenWidth * 0.08 : 16,
//               vertical: 16,
//             ),
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 maxWidth: isLargeScreen ? 1000 : double.infinity,
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (isLargeScreen)
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(
//                           flex: 2,
//                           child: Column(
//                             children: [
//                               _buildSessionInfoCard(
//                                 context,
//                                 session,
//                                 isLargeScreen,
//                               ),
//                               const SizedBox(height: 16),
//                               _buildNozzleReadingsCard(isLargeScreen),
//                               const SizedBox(height: 16),
//                               _buildFuelSupplyCard(isLargeScreen),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           flex: 2,
//                           child: Column(
//                             children: [
//                               _buildPaymentsCard(isLargeScreen),
//                               const SizedBox(height: 16),
//                               _buildExpensesCard(isLargeScreen),
//                               const SizedBox(height: 16),
//                               _buildBalanceAndDifferenceCard(isLargeScreen),
//                               const SizedBox(height: 16),
//                               const SizedBox(height: 16),
//                               _buildShortageResolutionCard(isLargeScreen),

//                               _buildNotesCard(isLargeScreen),
//                               const SizedBox(height: 32),
//                               _buildSubmitButton(
//                                 stationProvider,
//                                 isLargeScreen,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     )
//                   else
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         _buildSessionInfoCard(context, session, isLargeScreen),
//                         const SizedBox(height: 16),

//                         _buildNozzleReadingsCard(isLargeScreen),
//                         const SizedBox(height: 16),

//                         _buildPaymentsCard(isLargeScreen),
//                         const SizedBox(height: 16),

//                         // ✅ كارت المصروفات (مهم)
//                         _buildExpensesCard(isLargeScreen),
//                         const SizedBox(height: 16),

//                         _buildFuelSupplyCard(isLargeScreen),
//                         const SizedBox(height: 16),

//                         _buildBalanceAndDifferenceCard(isLargeScreen),
//                         const SizedBox(height: 16),
//                         const SizedBox(height: 16),
//                         _buildShortageResolutionCard(isLargeScreen),

//                         _buildNotesCard(isLargeScreen),
//                         const SizedBox(height: 32),

//                         _buildSubmitButton(stationProvider, isLargeScreen),
//                       ],
//                     ),

//                   const SizedBox(height: 20),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNozzleReadingsCard(bool isLargeScreen) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.closingReadingsTitle),
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             ...session.nozzleReadings!.map((nozzle) {
//               final key = _nozzleKey(nozzle);
//               final controller = _closingControllers[key]!;
//               final image = _closingImages[key];

//               final sideLabel = nozzle.side == 'left'
//                   ? context.tr(loc.AppStrings.sideLeft)
//                   : context.tr(loc.AppStrings.sideRight);
//               return Container(
//                 margin: const EdgeInsets.only(bottom: 20),
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: AppColors.lightGray),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       context.tr(loc.AppStrings.nozzleLabel, {
//                         'pumpNumber': nozzle.pumpNumber,
//                         'fuelType': nozzle.fuelType,
//                         'side': sideLabel,
//                       }),
//                       style: const TextStyle(fontWeight: FontWeight.w600),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       context.tr(loc.AppStrings.openingReadingDetail, {
//                         'value':
//                             nozzle.openingReading?.toStringAsFixed(2) ?? '0',
//                       }),
//                       style: const TextStyle(color: Colors.grey),
//                     ),
//                     const SizedBox(height: 12),

//                     CustomTextField(
//                       controller: controller,
//                       labelText: context.tr(loc.AppStrings.closingReadingLabel),
//                       keyboardType: const TextInputType.numberWithOptions(
//                         decimal: true,
//                       ),
//                       validator: (v) {
//                         final value = double.tryParse(v ?? '');
//                         if (value == null) {
//                           return context.tr(loc.AppStrings.enterValidNumber);
//                         }
//                         if (value <= nozzle.openingReading) {
//                           return context.tr(
//                             loc.AppStrings.mustBeGreaterThanOpening,
//                             {'reading': nozzle.openingReading.toString()},
//                           );
//                         }
//                         return null;
//                       },
//                       onChanged: (v) {
//                         nozzle.closingReading = double.tryParse(v);
//                         _recalculateTotals();
//                       },
//                     ),

//                     const SizedBox(height: 12),

//                     OutlinedButton.icon(
//                       onPressed: () => _pickClosingImage(key),
//                       icon: const Icon(Icons.camera_alt),
//                       label: Text(
//                         image == null
//                             ? context.tr(loc.AppStrings.attachClosingMeterImage)
//                             : context.tr(loc.AppStrings.changeImage),
//                       ),
//                     ),

//                     if (image != null) ...[
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.check_circle,
//                             color: AppColors.successGreen,
//                           ),
//                           const SizedBox(width: 8),
//                           Text(
//                             context.tr(loc.AppStrings.imageAttachedSuccess),
//                             style: TextStyle(
//                               color: AppColors.successGreen,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//               );
//             }).toList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMetricBlock(
//     String label,
//     String value,
//     Color color, {
//     required bool isLargeScreen,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             color: AppColors.mediumGray,
//             fontSize: isLargeScreen ? 14 : 12,
//           ),
//         ),
//         const SizedBox(height: 6),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: isLargeScreen ? 22 : 18,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _infoItemWidget(String label, Widget value, bool isLargeScreen) {
//     return SizedBox(
//       width: isLargeScreen ? 260 : double.infinity,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             label,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               color: AppColors.mediumGray,
//               fontSize: isLargeScreen ? 14 : 13,
//               fontWeight: FontWeight.w600,
//               fontFamily: "Cairo",
//             ),
//           ),
//           const SizedBox(height: 8),

//           DefaultTextStyle(
//             style: TextStyle(
//               fontSize: isLargeScreen ? 16 : 14,
//               fontWeight: FontWeight.bold,
//               color: AppColors.darkGray,
//               fontFamily: "Cairo",
//             ),
//             child: value,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVehicleLitersBreakdown(bool isLargeScreen) {
//     final entries = (session.nozzleReadings ?? [])
//         .where((nozzle) => _calculateNozzleLiters(nozzle) > 0)
//         .toList();
//     if (entries.isEmpty) return const SizedBox.shrink();

//     return Card(
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.vehicleLitersBreakdown),
//               style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 fontSize: isLargeScreen ? 20 : 18,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Column(
//               children: entries.map((nozzle) {
//                 final liters = _calculateNozzleLiters(nozzle);
//                 final amount = _calculateNozzleAmount(nozzle);
//                 return Padding(
//                   padding: const EdgeInsets.only(bottom: 12),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           context.tr(loc.AppStrings.pumpNozzleTemplate, {
//                             'pumpNumber': nozzle.pumpNumber,
//                             'nozzleNumber': nozzle.nozzleNumber,
//                           }),
//                           style: const TextStyle(fontWeight: FontWeight.w600),
//                         ),
//                       ),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             context.tr(loc.AppStrings.litersTemplate, {
//                               'liters': liters.toStringAsFixed(2),
//                             }),
//                             style: TextStyle(
//                               fontSize: isLargeScreen ? 14 : 12,
//                               color: AppColors.darkGray,
//                             ),
//                           ),
//                           Text(
//                             context.tr(loc.AppStrings.amountTemplate, {
//                               'amount': amount.toStringAsFixed(2),
//                             }),
//                             style: TextStyle(
//                               fontSize: isLargeScreen ? 14 : 12,
//                               color: AppColors.successGreen,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSessionInfoCard(
//     BuildContext context,
//     PumpSession session,
//     bool isLargeScreen,
//   ) {
//     return Card(
//       elevation: isLargeScreen ? 4 : 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 28 : 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.sessionInfoTitle),
//               style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 fontFamily: "Cairo",
//                 fontSize: isLargeScreen ? 22 : 18,
//               ),
//             ),
//             const SizedBox(height: 24),

//             Wrap(
//               spacing: 24,
//               runSpacing: 20,
//               children: [
//                 _infoItemWidget(
//                   context.tr(loc.AppStrings.sessionNumberColumn),
//                   Text(session.sessionNumber),
//                   isLargeScreen,
//                 ),

//                 _infoItemWidget(
//                   context.tr(loc.AppStrings.stationColumn),
//                   Text(session.stationName),
//                   isLargeScreen,
//                 ),

//                 _infoItemWidget(
//                   context.tr(loc.AppStrings.nozzleCountTitle),
//                   Text(
//                     context.tr(loc.AppStrings.nozzleCountLabel, {
//                       'count': '${session.nozzleReadings?.length ?? 0}',
//                     }),
//                   ),
//                   isLargeScreen,
//                 ),

//                 _infoItemWidget(
//                   context.tr(loc.AppStrings.fuelType),
//                   Text(context.tr(loc.AppStrings.multipleFuelTypes)),
//                   isLargeScreen,
//                 ),

//                 _infoItemWidget(
//                   context.tr(loc.AppStrings.openingTotalLabel),
//                   _buildOpeningTotalsByFuel(),
//                   isLargeScreen,
//                 ),

//                 _infoItemWidget(
//                   context.tr(loc.AppStrings.shiftColumn),
//                   Text(session.shiftType),
//                   isLargeScreen,
//                 ),

//                 _infoItemWidget(
//                   context.tr(loc.AppStrings.openingDate),
//                   Text(
//                     DateFormat('yyyy/MM/dd HH:mm').format(session.openingTime),
//                   ),
//                   isLargeScreen,
//                 ),

//                 _infoItemWidget(
//                   context.tr(loc.AppStrings.openingEmployee),
//                   Text(session.openingEmployeeName ?? '-'),
//                   isLargeScreen,
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildOpeningTotalsByFuel() {
//     if (_session!.nozzleReadings == null || _session!.nozzleReadings!.isEmpty) {
//       return const Text('-');
//     }

//     final Map<String, double> totals = {};

//     for (final n in _session!.nozzleReadings!) {
//       totals[n.fuelType] = (totals[n.fuelType] ?? 0) + n.openingReading;
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: totals.entries.map((e) {
//         return Padding(
//           padding: const EdgeInsets.only(bottom: 4),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: AppColors.primaryBlue.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   e.key,
//                   style: const TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 e.value.toStringAsFixed(2),
//                 style: const TextStyle(fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildClosingReadingCard(bool isLargeScreen) {
//     return Card(
//       elevation: isLargeScreen ? 4 : 2,
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.closingReadingLabel),
//               style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 fontSize: isLargeScreen ? 20 : 18,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               children: [
//                 Expanded(
//                   child: Container(
//                     padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
//                     decoration: BoxDecoration(
//                       color: AppColors.primaryBlue.withOpacity(0.05),
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(
//                         color: AppColors.primaryBlue.withOpacity(0.2),
//                       ),
//                     ),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Text(
//                           context.tr(loc.AppStrings.openingReadingLabel),
//                           style: TextStyle(
//                             color: AppColors.mediumGray,
//                             fontSize: isLargeScreen ? 15 : 14,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           session.openingReading.toStringAsFixed(2),
//                           style: TextStyle(
//                             fontSize: isLargeScreen ? 32 : 24,
//                             fontWeight: FontWeight.bold,
//                             color: AppColors.primaryBlue,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 Padding(
//                   padding: EdgeInsets.symmetric(
//                     horizontal: isLargeScreen ? 24 : 16,
//                   ),
//                   child: Icon(
//                     Icons.arrow_forward,
//                     size: isLargeScreen ? 32 : 24,
//                     color: AppColors.lightGray,
//                   ),
//                 ),
//                 Expanded(
//                   child: Container(
//                     padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
//                     decoration: BoxDecoration(
//                       color: AppColors.successGreen.withOpacity(0.05),
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(
//                         color: AppColors.successGreen.withOpacity(0.2),
//                       ),
//                     ),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Text(
//                           context.tr(loc.AppStrings.closingReadingLabel),
//                           style: TextStyle(
//                             color: AppColors.mediumGray,
//                             fontSize: isLargeScreen ? 15 : 14,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Column(
//                           children: (session.nozzleReadings ?? []).map((
//                             nozzle,
//                           ) {
//                             return Padding(
//                               padding: const EdgeInsets.only(bottom: 12),
//                               child: CustomTextField(
//                                 labelText: context.tr(
//                                   loc.AppStrings.closingNozzleLabel,
//                                   {
//                                     'pumpNumber': nozzle.pumpNumber,
//                                     'nozzleNumber': nozzle.nozzleNumber,
//                                     'side': nozzle.side == 'left'
//                                         ? context.tr(loc.AppStrings.sideLeft)
//                                         : context.tr(loc.AppStrings.sideRight),
//                                   },
//                                 ),
//                                 prefixIcon: null,
//                                 keyboardType: TextInputType.number,
//                                 textAlign: TextAlign.center,
//                                 textStyle: TextStyle(
//                                   fontSize: isLargeScreen ? 20 : 18,
//                                   fontWeight: FontWeight.bold,
//                                   color: AppColors.successGreen,
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 12,
//                                 ),
//                                 initialValue: nozzle.closingReading?.toString(),
//                                 validator: (value) {
//                                   if (value == null || value.trim().isEmpty) {
//                                     return context.tr(
//                                       loc.AppStrings.enterClosingReading,
//                                     );
//                                   }
//                                   final reading = double.tryParse(value);
//                                   if (reading == null) {
//                                     return context.tr(
//                                       loc.AppStrings.enterValidNumber,
//                                     );
//                                   }
//                                   if (reading <= nozzle.openingReading) {
//                                     return context.tr(
//                                       loc.AppStrings.mustBeGreaterThanOpening,
//                                       {
//                                         'reading': nozzle.openingReading
//                                             .toString(),
//                                       },
//                                     );
//                                   }
//                                   return null;
//                                 },
//                                 onChanged: (value) {
//                                   nozzle.closingReading = double.tryParse(
//                                     value,
//                                   );
//                                   _recalculateTotals();
//                                 },
//                               ),
//                             );
//                           }).toList(),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             if (_totalLiters > 0 || _totalAmount > 0) ...[
//               const SizedBox(height: 20),
//               Container(
//                 padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
//                 decoration: BoxDecoration(
//                   color: AppColors.successGreen.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(color: AppColors.successGreen),
//                 ),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: _buildMetricBlock(
//                         context.tr(loc.AppStrings.totalLiters),
//                         context.tr(loc.AppStrings.litersTemplate, {
//                           'liters': _totalLiters.toStringAsFixed(2),
//                         }),
//                         AppColors.successGreen,
//                         isLargeScreen: isLargeScreen,
//                       ),
//                     ),
//                     if (_totalAmount > 0) ...[
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: _buildMetricBlock(
//                           context.tr(loc.AppStrings.expectedAmount),
//                           context.tr(loc.AppStrings.amountTemplate, {
//                             'amount': _totalAmount.toStringAsFixed(2),
//                           }),
//                           AppColors.successGreen,
//                           isLargeScreen: isLargeScreen,
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ],
//             if ((session.nozzleReadings ?? []).any(
//               (nozzle) => _calculateNozzleLiters(nozzle) > 0,
//             )) ...[
//               const SizedBox(height: 16),
//               _buildVehicleLitersBreakdown(isLargeScreen),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPaymentsCard(bool isLargeScreen) {
//     final currencyFormat = NumberFormat('#,##0.00', 'ar');

//     return Card(
//       elevation: isLargeScreen ? 4 : 2,
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.paymentTypesTitle),
//               style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 fontSize: isLargeScreen ? 20 : 18,
//               ),
//             ),
//             const SizedBox(height: 20),

//             if (isLargeScreen)
//               GridView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   crossAxisSpacing: 16,
//                   mainAxisSpacing: 16,
//                   childAspectRatio: 2.5,
//                 ),
//                 itemCount: 4,
//                 itemBuilder: (context, index) {
//                   return _buildPaymentField(index, isLargeScreen);
//                 },
//               )
//             else
//               Column(
//                 children: List.generate(
//                   4,
//                   (index) => Padding(
//                     padding: const EdgeInsets.only(bottom: 16),
//                     child: _buildPaymentField(index, isLargeScreen),
//                   ),
//                 ),
//               ),

//             if (_totalSales > 0) ...[
//               const SizedBox(height: 20),
//               Container(
//                 padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
//                 decoration: BoxDecoration(
//                   color: AppColors.warningOrange.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(color: AppColors.warningOrange),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           context.tr(loc.AppStrings.totalSales),
//                           style: TextStyle(
//                             color: AppColors.warningOrange,
//                             fontWeight: FontWeight.w600,
//                             fontSize: isLargeScreen ? 16 : 14,
//                           ),
//                         ),
//                         if (isLargeScreen) ...[
//                           const SizedBox(height: 4),
//                           Text(
//                             context.tr(loc.AppStrings.sumOfAllPayments),
//                             style: TextStyle(
//                               color: AppColors.warningOrange.withOpacity(0.8),
//                               fontSize: 14,
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                     Text(
//                       'ريال ${currencyFormat.format(_totalSales)}',
//                       style: TextStyle(
//                         fontSize: isLargeScreen ? 28 : 20,
//                         fontWeight: FontWeight.bold,
//                         color: AppColors.warningOrange,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildExpensesCard(bool isLargeScreen) {
//     final currencyFormat = NumberFormat('#,##0.00', 'ar');

//     return Card(
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.expensesTitle),
//               style: Theme.of(
//                 context,
//               ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             // ===== نوع المصروف + المايك =====
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Expanded(
//                   child: CustomTextField(
//                     controller: _expenseTypeController,
//                     labelText: context.tr(loc.AppStrings.expenseType),
//                     prefixIcon: Icons.category,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 GestureDetector(
//                   onTap: _listenExpenseType,
//                   child: Container(
//                     height: 48,
//                     width: 48,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: _isListeningExpenseType
//                           ? AppColors.errorRed.withOpacity(0.15)
//                           : AppColors.primaryBlue.withOpacity(0.1),
//                       border: Border.all(
//                         color: _isListeningExpenseType
//                             ? AppColors.errorRed
//                             : AppColors.primaryBlue,
//                       ),
//                     ),
//                     child: Icon(
//                       _isListeningExpenseType ? Icons.mic : Icons.mic_none,
//                       color: _isListeningExpenseType
//                           ? AppColors.errorRed
//                           : AppColors.primaryBlue,
//                     ),
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 12),

//             // ===== قيمة المصروف =====
//             CustomTextField(
//               controller: _expenseAmountController,
//               labelText: context.tr(loc.AppStrings.expenseAmount),
//               prefixIcon: Icons.money_off,
//               keyboardType: TextInputType.number,
//             ),
//             const SizedBox(height: 12),

//             // ===== ملاحظات =====
//             CustomTextField(
//               controller: _expenseNotesController,
//               labelText: context.tr(loc.AppStrings.expenseNotesOptional),
//               prefixIcon: Icons.note,
//             ),
//             const SizedBox(height: 16),

//             // ===== زر الإضافة =====
//             Align(
//               alignment: Alignment.centerLeft,
//               child: ElevatedButton.icon(
//                 icon: const Icon(Icons.add),
//                 label: Text(context.tr(loc.AppStrings.addExpense)),
//                 onPressed: () {
//                   final amount = double.tryParse(_expenseAmountController.text);

//                   if (_expenseTypeController.text.isEmpty || amount == null) {
//                     return;
//                   }

//                   setState(() {
//                     _expenses.add(
//                       ExpenseItem(
//                         type: _expenseTypeController.text.trim(),
//                         amount: amount,
//                         notes: _expenseNotesController.text.trim(),
//                       ),
//                     );

//                     _expenseTypeController.clear();
//                     _expenseAmountController.clear();
//                     _expenseNotesController.clear();

//                     // 🔥 الخصم من الفرق يتم هنا فورًا
//                     _recalculateTotals();
//                   });
//                 },
//               ),
//             ),

//             const SizedBox(height: 20),

//             // ===== قائمة المصروفات =====
//             if (_expenses.isEmpty)
//               Text(
//                 context.tr(loc.AppStrings.noExpensesAdded),
//                 style: TextStyle(color: AppColors.mediumGray),
//               )
//             else
//               ..._expenses.asMap().entries.map((entry) {
//                 final index = entry.key;
//                 final e = entry.value;

//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 8),
//                   child: ListTile(
//                     leading: const Icon(
//                       Icons.receipt_long,
//                       color: AppColors.primaryBlue,
//                     ),
//                     title: Text(
//                       e.type,
//                       style: const TextStyle(fontWeight: FontWeight.w600),
//                     ),
//                     subtitle: e.notes?.isNotEmpty == true
//                         ? Text(e.notes!)
//                         : null,

//                     // ✅ هنا التعديل المهم
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           'ريال ${currencyFormat.format(e.amount)}',
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         const SizedBox(width: 8),
//                         IconButton(
//                           icon: const Icon(Icons.delete, color: Colors.red),
//                           onPressed: () {
//                             setState(() {
//                               _expenses.removeAt(index);

//                               // 🔥 يرجّع الفرق يتحدث
//                               _recalculateTotals();
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               }).toList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPaymentField(int index, bool isLargeScreen) {
//     TextEditingController controller;
//     String label;
//     IconData icon;
//     Color color;

//     switch (index) {
//       case 0:
//         controller = _cashController;
//         label = context.tr(loc.AppStrings.cashLabel);
//         icon = Icons.money;
//         color = AppColors.successGreen;
//         break;
//       case 1:
//         controller = _cardController;
//         label = context.tr(loc.AppStrings.cardLabel);
//         icon = Icons.credit_card;
//         color = AppColors.infoBlue;
//         break;
//       case 2:
//         controller = _madaController;
//         label = context.tr(loc.AppStrings.madaLabel);
//         icon = Icons.payment;
//         color = AppColors.primaryBlue;
//         break;
//       default:
//         controller = _otherController;
//         label = context.tr(loc.AppStrings.otherLabel);
//         icon = Icons.more_horiz;
//         color = AppColors.mediumGray;
//     }

//     return Container(
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.2)),
//       ),
//       child: CustomTextField(
//         controller: controller,
//         labelText: label,
//         prefixIcon: icon,
//         keyboardType: TextInputType.number,
//         onChanged: (value) {
//           _recalculateTotals();
//         },
//         contentPadding: EdgeInsets.symmetric(
//           horizontal: isLargeScreen ? 16 : 12,
//           vertical: isLargeScreen ? 16 : 12,
//         ),
//         labelStyle: TextStyle(color: color),
//       ),
//     );
//   }

//   Widget _buildShortageResolutionCard(bool isLargeScreen) {
//     if (_calculatedDifference >= 0 || _shortageResolved) {
//       return const SizedBox.shrink();
//     }

//     final controller = TextEditingController(
//       text: _shortageAmount > 0 ? _shortageAmount.toString() : '',
//     );

//     return Card(
//       elevation: 3,
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'تسوية العجز',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             /// مبلغ العجز
//             CustomTextField(
//               controller: controller,
//               labelText: 'مبلغ العجز',
//               onChanged: (v) {
//                 _shortageAmount = double.tryParse(v) ?? 0;
//               },
//             ),

//             CustomTextField(
//               labelText: 'سبب العجز',
//               onChanged: (v) => _shortageReason = v,
//             ),

//             const SizedBox(height: 16),

//             /// زر اعتماد العجز
//             Align(
//               alignment: Alignment.centerLeft,
//               child: ElevatedButton.icon(
//                 icon: const Icon(Icons.check_circle),
//                 label: const Text('اعتماد العجز'),
//                 onPressed: () {
//                   final amount = _shortageAmount;
//                   final reason = _shortageReason?.trim() ?? '';

//                   if (amount <= 0 || reason.isEmpty) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content: Text('يرجى إدخال مبلغ العجز وسببه'),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                     return;
//                   }

//                   setState(() {
//                     _shortageResolved = true;
//                   });

//                   _recalculateTotals();

//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('✅ تم اعتماد العجز'),
//                       backgroundColor: Colors.green,
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFuelSupplyCard(bool isLargeScreen) {
//     return Card(
//       elevation: isLargeScreen ? 4 : 2,
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.fuelSupplyTitle),
//               style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 fontSize: isLargeScreen ? 20 : 18,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Text(
//               context.tr(loc.AppStrings.fuelSupplyInfo),
//               style: TextStyle(
//                 color: AppColors.mediumGray,
//                 fontSize: isLargeScreen ? 15 : 14,
//               ),
//             ),
//             const SizedBox(height: 16),
//             if (isLargeScreen)
//               GridView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   crossAxisSpacing: 16,
//                   mainAxisSpacing: 16,
//                   childAspectRatio: 2.5,
//                 ),
//                 itemCount: 4,
//                 itemBuilder: (context, index) {
//                   return _buildFuelSupplyField(index, isLargeScreen);
//                 },
//               )
//             else
//               Column(
//                 children: List.generate(
//                   4,
//                   (index) => Padding(
//                     padding: EdgeInsets.only(bottom: 16),
//                     child: _buildFuelSupplyField(index, isLargeScreen),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFuelSupplyField(int index, bool isLargeScreen) {
//     TextEditingController controller;
//     String label;
//     IconData icon;

//     switch (index) {
//       case 0:
//         controller = _fuelQuantityController;
//         label = context.tr(loc.AppStrings.fuelQuantity);
//         icon = Icons.local_gas_station;
//         break;
//       case 1:
//         controller = _tankerNumberController;
//         label = context.tr(loc.AppStrings.tankerNumber);
//         icon = Icons.confirmation_number;
//         break;
//       case 2:
//         controller = _supplierNameController;
//         label = context.tr(loc.AppStrings.supplierName);
//         icon = Icons.business;
//         break;
//       default:
//         controller = TextEditingController(text: _selectedFuelType ?? '');
//         label = context.tr(loc.AppStrings.fuelType);
//         icon = Icons.local_gas_station;
//     }

//     return Container(
//       decoration: BoxDecoration(
//         color: AppColors.infoBlue.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.infoBlue.withOpacity(0.2)),
//       ),
//       child: index == 3
//           ? Container(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isLargeScreen ? 16 : 12,
//                 vertical: isLargeScreen ? 8 : 4,
//               ),
//               child: Row(
//                 children: [
//                   Icon(icon, color: AppColors.infoBlue),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       _selectedFuelType ?? session.fuelType,
//                       style: TextStyle(
//                         fontSize: isLargeScreen ? 15 : 14,
//                         color: AppColors.darkGray,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : CustomTextField(
//               controller: controller,
//               labelText: label,
//               prefixIcon: icon,
//               keyboardType: index == 0 ? TextInputType.number : null,
//               contentPadding: EdgeInsets.symmetric(
//                 horizontal: isLargeScreen ? 16 : 12,
//                 vertical: isLargeScreen ? 16 : 12,
//               ),
//               labelStyle: TextStyle(color: AppColors.infoBlue),
//             ),
//     );
//   }

//   Widget _buildBalanceAndDifferenceCard(bool isLargeScreen) {
//     final currencyFormat = NumberFormat('#,##0.00', 'ar');
//     final diff = _calculatedDifference;

//     return Card(
//       elevation: isLargeScreen ? 4 : 2,
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.balanceAndDifferenceTitle),
//               style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 fontSize: isLargeScreen ? 20 : 18,
//               ),
//             ),
//             const SizedBox(height: 20),

//             Container(
//               decoration: BoxDecoration(
//                 color: AppColors.primaryBlue.withOpacity(0.05),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                   color: AppColors.primaryBlue.withOpacity(0.2),
//                 ),
//               ),
//               child: CustomTextField(
//                 controller: _carriedForwardController,
//                 labelText: context.tr(loc.AppStrings.carriedForwardBalance),
//                 prefixIcon: Icons.account_balance_wallet,
//                 keyboardType: TextInputType.number,
//                 contentPadding: EdgeInsets.symmetric(
//                   horizontal: isLargeScreen ? 16 : 12,
//                   vertical: isLargeScreen ? 16 : 12,
//                 ),
//               ),
//             ),

//             if (diff != 0) ...[
//               const SizedBox(height: 20),
//               Container(
//                 padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
//                 decoration: BoxDecoration(
//                   color: diff >= 0
//                       ? AppColors.successGreen.withOpacity(0.1)
//                       : AppColors.errorRed.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(
//                     color: diff >= 0
//                         ? AppColors.successGreen
//                         : AppColors.errorRed,
//                   ),
//                 ),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               context.tr(loc.AppStrings.calculatedDifference),
//                               style: TextStyle(
//                                 color: diff >= 0
//                                     ? AppColors.successGreen
//                                     : AppColors.errorRed,
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: isLargeScreen ? 16 : 14,
//                               ),
//                             ),
//                             if (isLargeScreen) ...[
//                               const SizedBox(height: 4),
//                               Text(
//                                 diff >= 0
//                                     ? context.tr(
//                                         loc.AppStrings.salesGreaterThanExpected,
//                                       )
//                                     : context.tr(
//                                         loc.AppStrings.salesLessThanExpected,
//                                       ),
//                                 style: TextStyle(
//                                   color:
//                                       (diff >= 0
//                                               ? AppColors.successGreen
//                                               : AppColors.errorRed)
//                                           .withOpacity(0.8),
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ],
//                         ),
//                         Text(
//                           'ريال ${currencyFormat.format(diff.abs())}',
//                           style: TextStyle(
//                             fontSize: isLargeScreen ? 28 : 20,
//                             fontWeight: FontWeight.bold,
//                             color: diff >= 0
//                                 ? AppColors.successGreen
//                                 : AppColors.errorRed,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     Text(
//                       diff >= 0
//                           ? context.tr(loc.AppStrings.salesIncrease)
//                           : context.tr(loc.AppStrings.salesShortage),
//                       style: TextStyle(
//                         color: diff >= 0
//                             ? AppColors.successGreen
//                             : AppColors.errorRed,
//                         fontSize: isLargeScreen ? 15 : 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNotesCard(bool isLargeScreen) {
//     return Card(
//       elevation: isLargeScreen ? 4 : 2,
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               context.tr(loc.AppStrings.notesLabel),
//               style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 fontSize: isLargeScreen ? 20 : 18,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Container(
//               decoration: BoxDecoration(
//                 color: AppColors.backgroundGray,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: AppColors.lightGray),
//               ),
//               child: CustomTextField(
//                 controller: _notesController,
//                 labelText: context.tr(loc.AppStrings.additionalNotes),
//                 prefixIcon: Icons.note,
//                 maxLines: isLargeScreen ? 6 : 4,
//                 contentPadding: EdgeInsets.all(isLargeScreen ? 20 : 16),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSubmitButton(
//     StationProvider stationProvider,
//     bool isLargeScreen,
//   ) {
//     return GradientButton(
//       onPressed: stationProvider.isLoading ? null : _submitForm,
//       text: stationProvider.isLoading
//           ? context.tr(loc.AppStrings.loadingClosingSession)
//           : context.tr(loc.AppStrings.closeSession),
//       gradient: AppColors.accentGradient,
//       isLoading: stationProvider.isLoading,
//       height: isLargeScreen ? 60 : 50,
//       width: isLargeScreen ? double.infinity : null,
//     );
//   }
// }


// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/localization/app_localizations.dart' as loc;
import 'package:order_tracker/utils/constants.dart' show AppColors;
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ExpenseItem {
  String type;
  double amount;
  String? notes;

  ExpenseItem({required this.type, required this.amount, this.notes});

  Map<String, dynamic> toJson() => {
    'type': type,
    'category': type,
    'description': notes?.isNotEmpty == true ? notes : type,
    'amount': amount,
    'notes': notes,
  };
}

class CloseSessionScreen extends StatefulWidget {
  const CloseSessionScreen({super.key});

  @override
  State<CloseSessionScreen> createState() => _CloseSessionScreenState();
}

class _CloseSessionScreenState extends State<CloseSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();
  final TextEditingController _madaController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  final TextEditingController _carriedForwardController =
      TextEditingController();
  final TextEditingController _fuelQuantityController = TextEditingController();
  final TextEditingController _tankerNumberController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _shortageAmountController =
      TextEditingController();

  final TextEditingController _shortageReasonController =
      TextEditingController();
  final TextEditingController _returnFuelQuantityController =
      TextEditingController();
  final TextEditingController _returnReasonController = TextEditingController();

  final Map<String, TextEditingController> _closingControllers = {};
  final Map<String, XFile?> _closingImages = {};
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, double> _stationFuelPrices = {};

  String? _selectedFuelType;
  String? _selectedReturnFuelType;
  String? _differenceReason;
  double _totalLiters = 0;
  double _totalAmount = 0;
  double _totalSales = 0;
  double _calculatedDifference = 0;
  double _expensesTotal = 0;
  double _returnAmount = 0;
  final List<_FuelReturnEntry> _fuelReturnEntries = [];
  double _shortageAmount = 0.0;
  String? _shortageReason;
  bool _shortageResolved = false;

  final List<ExpenseItem> _expenses = [];

  final TextEditingController _expenseTypeController = TextEditingController();
  final TextEditingController _expenseAmountController =
      TextEditingController();
  final TextEditingController _expenseNotesController = TextEditingController();

  PumpSession? _session;

  PumpSession get session => _session!;
  late stt.SpeechToText _speech;
  bool _isListeningExpenseType = false;
  String? _arabicLocaleId;
  final Map<String, double> _soldLitersByFuel = {};
  final Map<String, double> _baseStockByFuel = {};
  final Map<String, double> _priorSalesByFuel = {};
  final Map<String, double> _priorReturnsByFuel = {};
  final Map<String, double> _priorSuppliesByFuel = {};
  Map<String, double> _stockBeforeSalesByFuel = {};
  Map<String, double> _stockAfterSalesByFuel = {};
  bool _isStockLoading = false;
  String? _stockError;

  // Web table state
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _showValidationErrors = false;

  final List<String> _differenceReasons = [
    'عادي',
    'تهوية',
    'تسريب',
    'خطأ في القراءة',
    'أخرى',
  ];

  String _nozzleKey(NozzleReading n) {
    return '${n.pumpId}_${n.nozzleNumber}_${n.side}_${n.fuelType}';
  }

  @override
  void initState() {
    super.initState();

    _speech = stt.SpeechToText();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final args = ModalRoute.of(context)?.settings.arguments;

        if (args == null || args is! PumpSession) {
          debugPrint('❌ CloseSessionScreen: session args is NULL');
          if (mounted) Navigator.pop(context);
          return;
        }

        _session = args;

        _selectedFuelType =
            (_session!.nozzleReadings != null &&
                _session!.nozzleReadings!.isNotEmpty)
            ? _session!.nozzleReadings!.first.fuelType
            : null;
        _selectedReturnFuelType ??= _selectedFuelType;

        for (final nozzle in _session!.nozzleReadings ?? []) {
          final key = _nozzleKey(nozzle);

          _closingControllers.putIfAbsent(
            key,
            () => TextEditingController(
              text: nozzle.closingReading?.toString() ?? '',
            ),
          );

          _closingImages.putIfAbsent(key, () => null);
        }

        _carriedForwardController.text = '0';
        _fuelQuantityController.text = '0';
        _returnFuelQuantityController.text = '0';

        // ❌ لا تهيئة للصوت هنا على الويب
        if (!kIsWeb) {
          final available = await _speech.initialize();
          if (available) {
            final locales = await _speech.locales();
            final arabic = locales.firstWhere(
              (l) => l.localeId.startsWith('ar'),
              orElse: () => locales.first,
            );
            _arabicLocaleId = arabic.localeId;
          }
        }

        _recalculateTotals();

        // ⏱️ حماية من تعليق API
        await _loadStationFuelPrices().timeout(const Duration(seconds: 8));
        await _loadFuelStockSummary().timeout(const Duration(seconds: 12));

        if (mounted) setState(() {});
      } catch (e, s) {
        debugPrint('❌ CloseSession init error: $e');
        debugPrintStack(stackTrace: s);
      }
    });
  }

  void _recalculateTotals() {
    if (_session == null) return;

    double totalLiters = 0.0;
    double theoreticalAmount = 0.0;
    double expensesTotal = 0.0;

    _soldLitersByFuel.clear();

    final nozzleReadings = session.nozzleReadings ?? [];

    for (final nozzle in nozzleReadings) {
      if (nozzle.closingReading == null) continue;

      final liters = _calculateNozzleLiters(nozzle);

      if (liters <= 0) continue;

      // ✅ إجمالي اليومية
      totalLiters += liters;

      // ✅ حسب نوع الوقود
      final fuelKey = _normalizeFuelType(nozzle.fuelType);
      if (fuelKey.isNotEmpty) {
        _soldLitersByFuel[fuelKey] = (_soldLitersByFuel[fuelKey] ?? 0) + liters;
      }

      // المبلغ
      final amount = _calculateNozzleAmount(nozzle);
      theoreticalAmount += amount;

      nozzle.totalLiters = liters;
      nozzle.totalAmount = amount;
    }

    final double cash = double.tryParse(_cashController.text) ?? 0;
    final double card = double.tryParse(_cardController.text) ?? 0;
    final double mada = double.tryParse(_madaController.text) ?? 0;
    final double other = double.tryParse(_otherController.text) ?? 0;

    final double actualSales = cash + card + mada + other;

    for (final e in _expenses) {
      expensesTotal += e.amount;
    }

    final returnByFuel = _returnsByFuel();
    final double returnAmount = _totalReturnAmount();

    final netRequired = theoreticalAmount - expensesTotal - returnAmount;
    final rawDifference = actualSales - netRequired;

    final normalizedBase = _normalizeFuelMap(_baseStockByFuel);
    final normalizedPriorSales = _normalizeFuelMap(_priorSalesByFuel);
    final normalizedPriorReturns = _normalizeFuelMap(_priorReturnsByFuel);
    final normalizedPriorSupplies = _normalizeFuelMap(_priorSuppliesByFuel);
    final adjustedBase = _addFuelMaps(
      _addFuelMaps(
        _subtractFuelMaps(normalizedBase, normalizedPriorSales),
        normalizedPriorSupplies,
      ),
      normalizedPriorReturns,
    );
    final stockBefore = Map<String, double>.from(adjustedBase);
    final stockAfter = _addFuelMaps(
      _calculateStockAfterSales(adjustedBase, _soldLitersByFuel),
      _normalizeFuelMap(returnByFuel),
    );

    setState(() {
      _totalLiters = totalLiters;
      _totalAmount = netRequired;
      _totalSales = actualSales;
      _calculatedDifference = _shortageResolved ? 0 : rawDifference;
      _expensesTotal = expensesTotal;
      _returnAmount = returnAmount;
      if (normalizedBase.isNotEmpty) {
        _stockBeforeSalesByFuel = stockBefore;
        _stockAfterSalesByFuel = stockAfter;
      }
    });
  }

  double _calculateNozzleLiters(NozzleReading nozzle) {
    final closing = nozzle.closingReading;
    if (closing == null) return 0;
    final diff = closing - nozzle.openingReading;
    return diff > 0 ? diff : 0;
  }

  double _calculateNozzleAmount(NozzleReading nozzle) {
    final pricePerLiter = _resolveNozzleUnitPrice(nozzle);
    return _calculateNozzleLiters(nozzle) * pricePerLiter;
  }

  double _resolveNozzleUnitPrice(NozzleReading nozzle) {
    if (nozzle.unitPrice != null && nozzle.unitPrice! > 0) {
      return nozzle.unitPrice!;
    }

    final lookup = _stationFuelPrices[nozzle.fuelType];
    if (lookup != null && lookup > 0) {
      return lookup;
    }

    if (_session?.unitPrice != null && _session!.unitPrice! > 0) {
      return _session!.unitPrice!;
    }

    return 0;
  }

  double _resolveFuelUnitPrice(String fuelType) {
    final direct = _stationFuelPrices[fuelType];
    if (direct != null && direct > 0) return direct;

    final normalized = _normalizeFuelType(fuelType);
    for (final entry in _stationFuelPrices.entries) {
      if (_normalizeFuelType(entry.key) == normalized && entry.value > 0) {
        return entry.value;
      }
    }

    final match = (session.nozzleReadings ?? [])
        .firstWhere(
          (n) => _normalizeFuelType(n.fuelType) == normalized,
          orElse: () => NozzleReading(
            nozzleId: '',
            nozzleNumber: '',
            position: 'left',
            fuelType: fuelType,
            pumpId: '',
            pumpNumber: '',
            openingReading: 0,
          ),
        );
    if (match.unitPrice != null && match.unitPrice! > 0) {
      return match.unitPrice!;
    }

    if (_session?.unitPrice != null && _session!.unitPrice! > 0) {
      return _session!.unitPrice!;
    }

    return 0;
  }

  Map<String, double> _returnsByFuel() {
    final result = <String, double>{};
    for (final entry in _fuelReturnEntries) {
      if (entry.quantity <= 0) continue;
      final key = _normalizeFuelType(entry.fuelType);
      if (key.isEmpty) continue;
      result[key] = (result[key] ?? 0) + entry.quantity;
    }
    return result;
  }

  double _totalReturnAmount() {
    double total = 0;
    for (final entry in _fuelReturnEntries) {
      if (entry.quantity <= 0) continue;
      total += entry.quantity * _resolveFuelUnitPrice(entry.fuelType);
    }
    return total;
  }

  Map<String, double> _addFuelMaps(
    Map<String, double> base,
    Map<String, double> delta,
  ) {
    final result = <String, double>{};
    final keys = <String>{...base.keys, ...delta.keys};
    for (final key in keys) {
      result[key] = (base[key] ?? 0) + (delta[key] ?? 0);
    }
    return result;
  }

  List<String> _availableFuelTypes() {
    final types = <String>{};
    for (final nozzle in session.nozzleReadings ?? []) {
      final fuel = nozzle.fuelType.trim();
      if (fuel.isNotEmpty) types.add(fuel);
    }
    for (final fuel in _stationFuelPrices.keys) {
      final key = fuel.trim();
      if (key.isNotEmpty) types.add(key);
    }
    return types.toList()..sort();
  }

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

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, double> _normalizeFuelMap(Map<String, double> input) {
    final result = <String, double>{};
    input.forEach((key, value) {
      final normalizedKey = _normalizeFuelType(key);
      if (normalizedKey.isEmpty) return;
      result[normalizedKey] = (result[normalizedKey] ?? 0) + value;
    });
    return result;
  }

  String _compactFuelKey(String value) {
    return _normalizeFuelType(value).replaceAll(' ', '');
  }

  Map<String, double> _compactFuelMap(Map<String, double> input) {
    final result = <String, double>{};
    input.forEach((key, value) {
      final compactKey = _compactFuelKey(key);
      if (compactKey.isEmpty) return;
      result[compactKey] = (result[compactKey] ?? 0) + value;
    });
    return result;
  }

  Map<String, double> _calculateStockAfterSales(
    Map<String, double> baseStockByFuel,
    Map<String, double> soldByFuel,
  ) {
    final normalizedBase = _normalizeFuelMap(baseStockByFuel);
    final normalizedSold = _normalizeFuelMap(soldByFuel);
    final allFuelTypes = <String>{
      ...normalizedBase.keys,
      ...normalizedSold.keys,
    };

    final result = <String, double>{};
    for (final fuel in allFuelTypes) {
      final before = normalizedBase[fuel] ?? 0;
      final sold = normalizedSold[fuel] ?? 0;
      result[fuel] = before - sold;
    }
    return result;
  }

  Map<String, double> _subtractFuelMaps(
    Map<String, double> base,
    Map<String, double> delta,
  ) {
    final result = <String, double>{};
    final keys = <String>{...base.keys, ...delta.keys};
    for (final key in keys) {
      result[key] = (base[key] ?? 0) - (delta[key] ?? 0);
    }
    return result;
  }

  Map<String, double> _buildBaseStockFromReport(
    List<FuelBalanceReportRow> rows,
    DateTime sessionDate,
  ) {
    final Map<String, FuelBalanceReportRow> latestByFuel = {};
    final targetDate = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
    );

    bool isSameOrBeforeDay(DateTime d) {
      final dd = DateTime(d.year, d.month, d.day);
      return !dd.isAfter(targetDate);
    }

    for (final row in rows) {
      if (!isSameOrBeforeDay(row.date)) continue;
      final key = _normalizeFuelType(row.fuelType);
      if (key.isEmpty) continue;

      final existing = latestByFuel[key];
      if (existing == null || row.date.isAfter(existing.date)) {
        latestByFuel[key] = row;
      }
    }

    final result = <String, double>{};
    for (final entry in latestByFuel.entries) {
      final row = entry.value;
      final double baseStock =
          row.actualBalance ??
          row.calculatedBalance ??
          (row.openingBalance + row.received - row.sales);
      result[entry.key] = baseStock;
    }
    return result;
  }

  double _extractCurrentStockBalance(Map<String, dynamic> item) {
    const keys = [
      'balance',
      'availableStock',
      'currentBalance',
      'actualBalance',
      'calculatedBalance',
      'quantity',
      'remaining',
    ];
    for (final key in keys) {
      final value = item[key];
      if (value != null) {
        return _toDouble(value);
      }
    }
    return 0;
  }

  Map<String, double> _buildBaseStockFromCurrentStock(
    List<Map<String, dynamic>> items,
  ) {
    final result = <String, double>{};
    for (final item in items) {
      final fuelType = item['fuelType']?.toString() ?? '';
      final key = _normalizeFuelType(fuelType);
      if (key.isEmpty) continue;
      final balance = _extractCurrentStockBalance(item);
      result[key] = (result[key] ?? 0) + balance;
    }
    return result;
  }

  Map<String, double> _calculatePriorSalesByFuel(
    List<PumpSession> sessions,
    PumpSession currentSession,
  ) {
    final result = <String, double>{};
    for (final s in sessions) {
      if (s.id == currentSession.id) continue;
      if (s.stationId != currentSession.stationId) continue;
      if (s.openingTime.isAfter(currentSession.openingTime)) continue;

      if (s.nozzleReadings != null && s.nozzleReadings!.isNotEmpty) {
        for (final nozzle in s.nozzleReadings!) {
          if (nozzle.closingReading == null) continue;
          final liters = nozzle.closingReading! - nozzle.openingReading;
          if (liters <= 0) continue;
          final key = _normalizeFuelType(nozzle.fuelType);
          if (key.isEmpty) continue;
          result[key] = (result[key] ?? 0) + liters;
        }
        continue;
      }

      if (s.totalLiters != null && s.totalLiters! > 0) {
        final key = _normalizeFuelType(s.fuelType);
        if (key.isEmpty) continue;
        result[key] = (result[key] ?? 0) + s.totalLiters!;
      }
    }
    return result;
  }

  Map<String, double> _calculatePriorReturnsByFuel(
    List<PumpSession> sessions,
    PumpSession currentSession,
  ) {
    final result = <String, double>{};
    for (final s in sessions) {
      if (s.id == currentSession.id) continue;
      if (s.stationId != currentSession.stationId) continue;
      if (s.openingTime.isAfter(currentSession.openingTime)) continue;

      if (s.fuelReturns.isEmpty) continue;
      for (final ret in s.fuelReturns) {
        if (ret.quantity <= 0) continue;
        final key = _normalizeFuelType(ret.fuelType);
        if (key.isEmpty) continue;
        result[key] = (result[key] ?? 0) + ret.quantity;
      }
    }
    return result;
  }

  Map<String, double> _calculatePriorSuppliesByFuel(
    List<PumpSession> sessions,
    PumpSession currentSession,
  ) {
    final result = <String, double>{};
    for (final s in sessions) {
      if (s.id == currentSession.id) continue;
      if (s.stationId != currentSession.stationId) continue;
      if (s.openingTime.isAfter(currentSession.openingTime)) continue;

      final supply = s.fuelSupply;
      if (supply == null || supply.quantity <= 0) continue;
      final key = _normalizeFuelType(supply.fuelType);
      if (key.isEmpty) continue;
      result[key] = (result[key] ?? 0) + supply.quantity;
    }
    return result;
  }

  Future<Map<String, double>> _loadBaseStockFromInventoriesFallback(
    StationProvider provider,
    String stationId,
    DateTime sessionDate,
  ) async {
    String _formatDate(DateTime date) =>
        date.toIso8601String().split('T').first;

    try {
      await provider.fetchInventories(
        filters: {
          'stationId': stationId,
          'endDate': _formatDate(sessionDate),
        },
      );
    } catch (_) {
      return {};
    }

    final targetDate = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
    );

    final latestByFuel = <String, DailyInventory>{};
    for (final inventory in provider.inventories) {
      final invDate = DateTime(
        inventory.inventoryDate.year,
        inventory.inventoryDate.month,
        inventory.inventoryDate.day,
      );
      if (invDate.isAfter(targetDate)) continue;

      final key = _normalizeFuelType(inventory.fuelType);
      if (key.isEmpty) continue;

      final existing = latestByFuel[key];
      if (existing == null ||
          inventory.inventoryDate.isAfter(existing.inventoryDate)) {
        latestByFuel[key] = inventory;
      }
    }

    final result = <String, double>{};
    for (final entry in latestByFuel.entries) {
      final inventory = entry.value;
      final double baseStock =
          inventory.actualBalance ??
          inventory.calculatedBalance ??
          (inventory.previousBalance +
              inventory.receivedQuantity -
              inventory.totalSales);
      result[entry.key] = baseStock;
    }
    return result;
  }

  Future<void> _loadFuelStockSummary() async {
    if (_session == null) return;

    setState(() {
      _isStockLoading = true;
      _stockError = null;
    });

    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    try {
      await stationProvider.fetchCurrentStock(session.stationId);

      Map<String, double> baseStock =
          _buildBaseStockFromCurrentStock(stationProvider.currentStock);
      bool usingCurrentStock = baseStock.isNotEmpty;

      if (!usingCurrentStock) {
        await stationProvider.fetchFuelBalanceReport(
          stationId: session.stationId,
          startDate: DateTime(2000),
          endDate: session.sessionDate,
        );

        final rows = stationProvider.fuelBalanceReport
            .where((row) => !row.date.isAfter(session.sessionDate))
            .toList();

        baseStock = _buildBaseStockFromReport(rows, session.sessionDate);

        final inventoryBaseStock = await _loadBaseStockFromInventoriesFallback(
          stationProvider,
          session.stationId,
          session.sessionDate,
        );
        if (inventoryBaseStock.isNotEmpty) {
          baseStock.addAll(inventoryBaseStock);
        }
      }

      final normalizedBase = _normalizeFuelMap(baseStock);
      final priorSales = _calculatePriorSalesByFuel(
        stationProvider.sessions,
        session,
      );
      final priorReturns = _calculatePriorReturnsByFuel(
        stationProvider.sessions,
        session,
      );
      final priorSupplies = _calculatePriorSuppliesByFuel(
        stationProvider.sessions,
        session,
      );

      final normalizedPriorSales = _normalizeFuelMap(priorSales);
      final normalizedPriorReturns = _normalizeFuelMap(priorReturns);
      final normalizedPriorSupplies = _normalizeFuelMap(priorSupplies);
      final adjustedBase = _addFuelMaps(
        _addFuelMaps(
          _subtractFuelMaps(normalizedBase, normalizedPriorSales),
          normalizedPriorSupplies,
        ),
        normalizedPriorReturns,
      );
      final returnByFuel = _normalizeFuelMap(_returnsByFuel());
      final stockBefore = Map<String, double>.from(adjustedBase);
      final stockAfter = _addFuelMaps(
        _calculateStockAfterSales(adjustedBase, _soldLitersByFuel),
        returnByFuel,
      );

      if (!mounted) return;
      setState(() {
        _baseStockByFuel
          ..clear()
          ..addAll(normalizedBase);
        _priorSalesByFuel
          ..clear()
          ..addAll(normalizedPriorSales);
        _priorReturnsByFuel
          ..clear()
          ..addAll(normalizedPriorReturns);
        _priorSuppliesByFuel
          ..clear()
          ..addAll(normalizedPriorSupplies);
        _stockBeforeSalesByFuel = stockBefore;
        _stockAfterSalesByFuel = stockAfter;
        _isStockLoading = false;
      });

      _recalculateTotals();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isStockLoading = false;
        _stockError = 'فشل جلب المخزون الحالي من الخادم';
      });
    }
  }

  // Future<void> _listenExpenseType() async {
  //   if (!kIsWeb) return;

  //   try {
  //     final speechRecognition =
  //         js.context['SpeechRecognition'] ??
  //         js.context['webkitSpeechRecognition'];

  //     if (speechRecognition == null) {
  //       debugPrint('❌ SpeechRecognition API not available');
  //       return;
  //     }

  //     final recognition = js.JsObject(speechRecognition);

  //     recognition['lang'] = 'ar-SA';
  //     recognition['continuous'] = false;
  //     recognition['interimResults'] = false;

  //     setState(() => _isListeningExpenseType = true);
  //     recognition['onresult'] = js.allowInterop((dynamic event) {
  //       final jsEvent = js.JsObject.fromBrowserObject(event);

  //       final List results = jsEvent['results'] as List;
  //       final List firstResult = results.first as List;
  //       final Map firstAlternative = firstResult.first as Map;

  //       final String transcript = firstAlternative['transcript'] as String;

  //       debugPrint('🎧 WEB RESULT: $transcript');

  //       setState(() {
  //         _expenseTypeController.text = transcript;
  //         _isListeningExpenseType = false;
  //       });
  //     });

  //     recognition['onerror'] = js.allowInterop((dynamic event) {
  //       final jsEvent = js.JsObject.fromBrowserObject(event);

  //       final String error = jsEvent['error']?.toString() ?? 'unknown';

  //       debugPrint('❌ WEB SPEECH ERROR: $error');

  //       setState(() => _isListeningExpenseType = false);
  //     });

  //     recognition.callMethod('start');
  //   } catch (e) {
  //     debugPrint('❌ Web Speech exception: $e');
  //     setState(() => _isListeningExpenseType = false);
  //   }
  // }



  Future<String> _uploadClosingImage({
    required XFile image,
    required PumpSession session,
    required NozzleReading nozzle,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(
      'sessions/${session.id}/closing/'
      'pump_${nozzle.pumpNumber}_nozzle_${nozzle.nozzleNumber}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final bytes = await image.readAsBytes();
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> _loadStationFuelPrices() async {
    if (_session == null) return;

    final provider = Provider.of<StationProvider>(context, listen: false);
    final station = await provider.fetchStationDetails(_session!.stationId);
    if (!mounted) return;

    setState(() {
      _stationFuelPrices.clear();
      if (station != null) {
        for (final price in station.fuelPrices) {
          _stationFuelPrices[price.fuelType] = price.price;
        }
      }
    });

    _recalculateTotals();
  }

  Future<void> _pickClosingImage(String key) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 70,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _closingImages[key] = picked;
    });
  }

 Future<void> _submitForm() async {
    if (_session == null) return;
    final session = _session!;

    setState(() => _showValidationErrors = true);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    // =========================
    // 🔴 تحقق من قراءات الغلق والصور
    // =========================
    for (final nozzle in session.nozzleReadings ?? []) {
      final key = _nozzleKey(nozzle);

      // ✅ تحقق قراءة الغلق
      if (nozzle.closingReading == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يرجى إدخال قراءة الغلق لخرطوم '
              '${nozzle.nozzleNumber} (${nozzle.fuelType})',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      // ✅ السماح بالتساوي – المنع فقط لو الغلق أقل من الفتح
      if (nozzle.closingReading! < nozzle.openingReading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'قراءة الغلق لا يمكن أن تكون أقل من قراءة الفتح '
              'لخرطوم ${nozzle.nozzleNumber} (${nozzle.fuelType})',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      // ✅ تحقق وجود صورة الغلق
      if (_closingImages[key] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يرجى إرفاق صورة الغلق لخرطوم '
              '${nozzle.nozzleNumber} (${nozzle.fuelType})',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
    }

    try {
      // =========================
      // 🔹 رفع صور الغلق وتجهيز القراءات
      // =========================
      final List<Map<String, dynamic>> closingNozzles = [];

      for (final nozzle in session.nozzleReadings ?? []) {
        final key = _nozzleKey(nozzle);
        final image = _closingImages[key]!;

        final closingImageUrl = await _uploadClosingImage(
          image: image,
          session: session,
          nozzle: nozzle,
        );

        // ✅ حساب اللترات (يسمح بـ 0)
        final liters = nozzle.closingReading! - nozzle.openingReading;
        nozzle.totalLiters = liters > 0 ? liters : 0;

        closingNozzles.add({
          'pumpId': nozzle.pumpId,
          'nozzleId': nozzle.nozzleId,
          'nozzleNumber': nozzle.nozzleNumber,
          'fuelType': nozzle.fuelType,
          'openingReading': nozzle.openingReading,
          'closingReading': nozzle.closingReading,
          'totalLiters': nozzle.totalLiters,
          'closingImageUrl': closingImageUrl,
        });
      }

      // =========================
      // 🔹 حساب المصروفات
      // =========================
      final double expensesTotal = _expenses.fold(
        0,
        (sum, e) => sum + e.amount,
      );
      final fuelReturns = _fuelReturnEntries
          .where((e) => e.quantity > 0)
          .map((e) {
            final amount = e.quantity * _resolveFuelUnitPrice(e.fuelType);
            return {
              'fuelType': e.fuelType,
              'quantity': e.quantity,
              'reason': e.reason,
              'amount': amount,
            };
          })
          .toList();

      // =========================
      // 🔹 هل يوجد عجز تمت تسويته؟
      // =========================
      final bool hasShortage =
          _shortageResolved &&
          _shortageAmount > 0 &&
          _shortageReason != null &&
          _shortageReason!.isNotEmpty;

      // =========================
      // 🔹 تجهيز بيانات الإغلاق
      // =========================
      final Map<String, dynamic> closingData = {
        'nozzleReadings': closingNozzles,

        'paymentTypes': {
          'cash': double.tryParse(_cashController.text) ?? 0,
          'card': double.tryParse(_cardController.text) ?? 0,
          'mada': double.tryParse(_madaController.text) ?? 0,
          'other': double.tryParse(_otherController.text) ?? 0,
        },

        'fuelSupply':
            _fuelQuantityController.text.isNotEmpty &&
                _fuelQuantityController.text != '0'
            ? {
                'fuelType': _selectedFuelType,
                'quantity': double.tryParse(_fuelQuantityController.text) ?? 0,
                'tankerNumber': _tankerNumberController.text,
                'supplierName': _supplierNameController.text,
              }
            : null,
        'fuelReturns': fuelReturns.isNotEmpty ? fuelReturns : null,
        'fuelReturn': fuelReturns.isNotEmpty ? fuelReturns.first : null,

        'carriedForwardBalance':
            double.tryParse(_carriedForwardController.text) ?? 0,

        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'expensesTotal': expensesTotal,

        'shortage': hasShortage
            ? {'amount': _shortageAmount, 'reason': _shortageReason}
            : null,

        'actualDifference': hasShortage ? 0 : _calculatedDifference,
        'differenceReason': hasShortage ? 'تمت تسوية العجز' : _differenceReason,

        'notes': _notesController.text,
      };

      // =========================
      // 🚀 إرسال الإغلاق
      // =========================
      final success = await stationProvider.closeSession(
        session.id,
        closingData,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(loc.AppStrings.closingSessionSuccess)),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(loc.AppStrings.closeSessionError, {
              'error': e.toString(),
            }),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
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

    if (_session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(loc.AppStrings.closeSessionTitle),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات اليومية',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMobileSessionInfo(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Nozzle Readings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قراءات الخراطيم',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMobileNozzleReadings(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Payments
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التحصيل النقدي',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMobilePayments(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Expenses
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المصروفات',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMobileExpenses(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Fuel Return
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إرجاع وقود للخزان',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMobileFuelReturn(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Fuel Supply
              // Card(
              //   child: Padding(
              //     padding: const EdgeInsets.all(16),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Text(
              //           'توريد الوقود',
              //           style: const TextStyle(
              //             fontWeight: FontWeight.bold,
              //             fontSize: 16,
              //           ),
              //         ),
              //         const SizedBox(height: 12),
              //         _buildMobileFuelSupply(),
              //       ],
              //     ),
              //   ),
              // ),

              // const SizedBox(height: 16),

              // Balance & Difference
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد والفرق',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMobileBalanceDifference(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Shortage Resolution
              if (_calculatedDifference < 0 && !_shortageResolved)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسوية العجز',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMobileShortageResolution(),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Notes
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMobileNotes(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              GradientButton(
                onPressed: stationProvider.isLoading ? null : _submitForm,
                text: stationProvider.isLoading
                    ? context.tr(loc.AppStrings.loadingClosingSession)
                    : context.tr(loc.AppStrings.closeSession),
                gradient: AppColors.accentGradient,
                isLoading: stationProvider.isLoading,
                height: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSessionInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('رقم اليومية', session.sessionNumber),
        _buildInfoRow('المحطة', session.stationName),
        _buildInfoRow('عدد الخراطيم', '${session.nozzleReadings?.length ?? 0}'),
        _buildInfoRow('الوردية', session.shiftType),
        _buildInfoRow(
          'تاريخ الفتح',
          DateFormat('yyyy/MM/dd HH:mm').format(session.openingTime),
        ),
        _buildInfoRow('موظف الفتح', session.openingEmployeeName ?? '-'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.mediumGray, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNozzleReadings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: (session.nozzleReadings ?? []).map((nozzle) {
        final key = _nozzleKey(nozzle);
        final controller = _closingControllers[key]!;
        final image = _closingImages[key];

        final sideLabel = nozzle.side == 'left'
            ? context.tr(loc.AppStrings.sideLeft)
            : context.tr(loc.AppStrings.sideRight);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lightGray),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المضخة ${nozzle.pumpNumber} - لي ${nozzle.nozzleNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${nozzle.fuelType} - $sideLabel',
                style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'قراءة الفتح: ${nozzle.openingReading.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: controller,
                labelText: 'قراءة الإغلاق',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  final value = double.tryParse(v ?? '');
                  if (value == null) {
                    return 'أدخل رقم صالح';
                  }
                  if (value <= nozzle.openingReading) {
                    return 'يجب أن تكون أكبر من قراءة الفتح';
                  }
                  return null;
                },
                onChanged: (v) {
                  nozzle.closingReading = double.tryParse(v);
                  _recalculateTotals();
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickClosingImage(key),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(image == null ? 'إضافة صورة' : 'تغيير الصورة'),
              ),
              if (image != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.successGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        image.name,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobilePayments() {
    final payments = [
      {'controller': _cashController, 'label': 'نقدي', 'icon': Icons.money},
      {
        'controller': _cardController,
        'label': 'شبكة (مدى)',
        'icon': Icons.credit_card,
      },
      // {'controller': _madaController, 'label': 'مدى', 'icon': Icons.payment},
      {
        'controller': _otherController,
        'label': 'أخرى',
        'icon': Icons.more_horiz,
      },
    ];

    return Column(
      children: payments.map((payment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CustomTextField(
            controller: payment['controller'] as TextEditingController,
            labelText: payment['label'] as String,
            prefixIcon: payment['icon'] as IconData,
            keyboardType: TextInputType.number,
            onChanged: (v) => _recalculateTotals(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileExpenses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _expenseTypeController,
          labelText: 'نوع المصروف',
          prefixIcon: Icons.category,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _expenseAmountController,
          labelText: 'القيمة',
          prefixIcon: Icons.money_off,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _expenseNotesController,
          labelText: 'ملاحظات (اختياري)',
          prefixIcon: Icons.note,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            final amount = double.tryParse(_expenseAmountController.text);
            if (_expenseTypeController.text.isEmpty || amount == null) return;

            setState(() {
              _expenses.add(
                ExpenseItem(
                  type: _expenseTypeController.text.trim(),
                  amount: amount,
                  notes: _expenseNotesController.text.trim(),
                ),
              );

              _expenseTypeController.clear();
              _expenseAmountController.clear();
              _expenseNotesController.clear();

              _recalculateTotals();
            });
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة مصروف'),
        ),
        const SizedBox(height: 16),
        if (_expenses.isNotEmpty)
          ..._expenses.asMap().entries.map((entry) {
            final index = entry.key;
            final e = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(e.type),
                subtitle: e.notes?.isNotEmpty == true ? Text(e.notes!) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${e.amount.toStringAsFixed(2)} ريال'),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _expenses.removeAt(index);
                          _recalculateTotals();
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildMobileFuelSupply() {
    return Column(
      children: [
        CustomTextField(
          controller: _fuelQuantityController,
          labelText: 'كمية الوقود',
          prefixIcon: Icons.local_gas_station,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _tankerNumberController,
          labelText: 'رقم التانكر',
          prefixIcon: Icons.confirmation_number,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _supplierNameController,
          labelText: 'اسم المورد',
          prefixIcon: Icons.business,
        ),
      ],
    );
  }

  Widget _buildMobileFuelReturn() {
    final fuelOptions = _availableFuelTypes();
    final selectedValue =
        fuelOptions.contains(_selectedReturnFuelType) ? _selectedReturnFuelType : null;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedValue,
          items: fuelOptions
              .map(
                (fuel) => DropdownMenuItem(
                  value: fuel,
                  child: Text(fuel),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedReturnFuelType = value;
            });
            _recalculateTotals();
          },
          decoration: InputDecoration(
            labelText: 'نوع الوقود',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _returnFuelQuantityController,
          labelText: 'كمية الإرجاع (لتر)',
          prefixIcon: Icons.local_gas_station,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _recalculateTotals(),
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _returnReasonController,
          labelText: 'سبب الإرجاع',
          prefixIcon: Icons.info_outline,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            final qty =
                double.tryParse(_returnFuelQuantityController.text) ?? 0;
            final fuelType = _selectedReturnFuelType;
            if (fuelType == null || fuelType.isEmpty || qty <= 0) return;

            setState(() {
              _fuelReturnEntries.add(
                _FuelReturnEntry(
                  fuelType: fuelType,
                  quantity: qty,
                  reason: _returnReasonController.text.trim(),
                ),
              );
              _returnFuelQuantityController.clear();
              _returnReasonController.clear();
              _recalculateTotals();
            });
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة إرجاع'),
        ),
        if (_fuelReturnEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._fuelReturnEntries.map(
            (entry) {
              final amount =
                  entry.quantity * _resolveFuelUnitPrice(entry.fuelType);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${entry.fuelType} - ${entry.quantity.toStringAsFixed(2)} لتر'),
                  subtitle: entry.reason?.isNotEmpty == true
                      ? Text(entry.reason!)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${amount.toStringAsFixed(2)} ريال'),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _fuelReturnEntries.remove(entry);
                            _recalculateTotals();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMobileBalanceDifference() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _carriedForwardController,
          labelText: 'الرصيد المرحل',
          prefixIcon: Icons.account_balance_wallet,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        if (_calculatedDifference != 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _calculatedDifference >= 0
                  ? AppColors.successGreen.withOpacity(0.1)
                  : AppColors.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _calculatedDifference >= 0
                    ? AppColors.successGreen
                    : AppColors.errorRed,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _calculatedDifference >= 0 ? 'فائض' : 'عجز',
                  style: TextStyle(
                    color: _calculatedDifference >= 0
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_calculatedDifference.abs().toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _calculatedDifference >= 0
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMobileShortageResolution() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _shortageAmountController,
          labelText: 'مبلغ العجز',
          keyboardType: TextInputType.number,
          onChanged: (v) => _shortageAmount = double.tryParse(v) ?? 0,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _shortageReasonController,
          labelText: 'سبب العجز',
          onChanged: (v) => _shortageReason = v,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            final amount = double.tryParse(_shortageAmountController.text) ?? 0;
            if (amount <= 0 || _shortageReasonController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('يرجى إدخال مبلغ العجز وسببه'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setState(() {
              _shortageResolved = true;
              _shortageAmount = amount;
              _shortageReason = _shortageReasonController.text;
            });

            _recalculateTotals();
          },
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('اعتماد العجز'),
        ),
      ],
    );
  }

  Widget _buildMobileNotes() {
    return CustomTextField(
      controller: _notesController,
      labelText: 'ملاحظات إضافية',
      prefixIcon: Icons.note,
      maxLines: 3,
    );
  }

  Widget _buildWebLayout() {
    final stationProvider = Provider.of<StationProvider>(context);

    if (_session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(loc.AppStrings.closeSessionTitle),
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GradientButton(
              onPressed: stationProvider.isLoading ? null : _submitForm,
              text: stationProvider.isLoading
                  ? context.tr(loc.AppStrings.loadingClosingSession)
                  : context.tr(loc.AppStrings.closeSession),
              gradient: AppColors.accentGradient,
              isLoading: stationProvider.isLoading,
              height: 36,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إغلاق يومية ${session.sessionNumber}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'المحطة: ${session.stationName}',
                              style: TextStyle(
                                color: AppColors.mediumGray,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'الوردية: ${session.shiftType}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'تاريخ الفتح: ${DateFormat('yyyy/MM/dd HH:mm').format(session.openingTime)}',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Main Content
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table Header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'بيانات إغلاق اليومية',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.timer,
                                      size: 16,
                                      color: AppColors.primaryBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'آخر تحديث: ${DateFormat('HH:mm').format(DateTime.now())}',
                                      style: const TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Data Table
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.lightGray,
                                width: 1,
                              ),
                            ),
                            child: _buildWebDataTable(stationProvider),
                          ),
                        ),

                        // Summary Section
                        const SizedBox(height: 16),
                        _buildWebSummaryTables(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildWebDataTable(StationProvider stationProvider) {
    final nozzleReadings = session.nozzleReadings ?? [];
    final returnFuelOptions = _availableFuelTypes();
    final returnFuelValue = returnFuelOptions.contains(_selectedReturnFuelType)
        ? _selectedReturnFuelType
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // نسب الأعمدة من عرض الشاشة
        final pumpW = width * 0.06;
        final nozzleW = width * 0.06;
        final fuelW = width * 0.10;
        final sideW = width * 0.08;
        final openW = width * 0.09;
        final closeW = width * 0.10;
       final beforeW = width * 0.08;
        final literW = width * 0.07;
        final afterW = width * 0.08;
        final amountW = width * 0.10;
        final actionsW = width * 0.18; 
        final columnWidths = _TableColumnWidths(
          pump: pumpW,
          nozzle: nozzleW,
          fuel: fuelW,
          side: sideW,
          open: openW,
          close: closeW,
          liter: literW,
          before: beforeW,
          after: afterW,
          amount: amountW,
          actions: actionsW,
        );
        return Scrollbar(
          controller: _verticalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            child: DataTable(
              columnSpacing: 0,
              horizontalMargin: 0,
              headingRowHeight: 48,
              dataRowHeight: 56,
              dividerThickness: 0,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              headingRowColor: MaterialStateProperty.all(
                AppColors.primaryBlue.withOpacity(0.05),
              ),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
              dataTextStyle: const TextStyle(fontSize: 14),

              columns: [
                _header('المضخة', pumpW),
                _header('لي', nozzleW),
                _header('الوقود', fuelW),
                _header('الجهة', sideW),
                _header('فتح', openW),
                _header('غلق', closeW),
                 _header('رصيد الخزان قبل', beforeW),
                _header('لترات', literW),
                _header('رصيد الخزان بعد', afterW),
                _header('قيمة', amountW),
                _header('الإجراءات', actionsW),
              ],

              rows: [
                // ================= Nozzles =================
                ...nozzleReadings.map((nozzle) {
                  final key = _nozzleKey(nozzle);
                  final controller = _closingControllers[key]!;
                  final image = _closingImages[key];
                  final liters = _calculateNozzleLiters(nozzle);
                  final amount = _calculateNozzleAmount(nozzle);
                  final stockKey = _normalizeFuelType(nozzle.fuelType);
                  final compactKey = _compactFuelKey(nozzle.fuelType);
                  final compactBefore =
                      _compactFuelMap(_stockBeforeSalesByFuel);
                  final compactSold = _compactFuelMap(_soldLitersByFuel);
                  final compactReturns = _compactFuelMap(_returnsByFuel());
                  final beforeStock = compactBefore[compactKey];
                  final afterStock = _stockAfterSalesByFuel[stockKey];
                  final computedAfter =
                      beforeStock == null
                          ? null
                          : beforeStock -
                              (compactSold[compactKey] ?? 0) +
                              (compactReturns[compactKey] ?? 0);
                  final beforeText = _isStockLoading
                      ? '...'
                      : (beforeStock == null
                          ? '-'
                          : beforeStock.toStringAsFixed(2));
                  final afterText = _isStockLoading
                      ? '...'
                      : (computedAfter != null
                          ? computedAfter.toStringAsFixed(2)
                          : (afterStock == null
                              ? '-'
                              : afterStock.toStringAsFixed(2)));

                  return DataRow(
                    cells: [
                      _cell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            nozzle.pumpNumber,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        pumpW,
                      ),

                      _cell(Text(nozzle.nozzleNumber), nozzleW),
                      _cell(Text(nozzle.fuelType), fuelW),

                      _cell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: nozzle.side == 'left'
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            nozzle.side == 'left' ? 'يسار' : 'يمين',
                            style: TextStyle(
                              color: nozzle.side == 'left'
                                  ? Colors.blue
                                  : Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        sideW,
                      ),

                      _cell(
                        Text(nozzle.openingReading.toStringAsFixed(2)),
                        openW,
                      ),

                      DataCell(
                        SizedBox(
                          width: closeW,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextFormField(
                              controller: controller,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color:
                                        _showValidationErrors &&
                                            (controller.text.isEmpty ||
                                                nozzle.closingReading == null)
                                        ? AppColors.errorRed
                                        : AppColors.lightGray,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (v) {
                                nozzle.closingReading = double.tryParse(v);
                                _recalculateTotals();
                              },
                            ),
                          ),
                        ),
                      ),

                        _cell(
                        Text(
                          beforeText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGray,
                          ),
                        ),
                        beforeW,
                      ),

                      _cell(
                        Text(
                          liters.toStringAsFixed(2),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGray,
                          ),
                        ),
                        literW,
                      ),
                    
                      _cell(
                        Text(
                          afterText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGray,
                          ),
                        ),
                        afterW,
                      ),
                      _cell(
                        Text(
                          amount.toStringAsFixed(2),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        amountW,
                      ),

                      DataCell(
                        SizedBox(
                          width: actionsW,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickClosingImage(key),
                                icon: const Icon(Icons.camera_alt, size: 14),
                                label: Text(
                                  image == null ? 'صورة' : 'تغيير',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              if (image != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.successGreen.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: AppColors.successGreen,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          image.name,
                                          style: const TextStyle(fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),


                // ================= Fuel Stock Section =================
                // _buildSectionRow('المخزون بالخزان'),
                // _buildStockHeaderRow(columnWidths),
                // ..._buildFuelStockRows(columnWidths),

                // ================= Expenses Section =================
                _buildSectionRow('المصروفات'),
                ..._expenses.map(
                  (e) => DataRow(
                    cells: [
                      _cell(Text('مصروف'), pumpW),
                      _cell(const Text(''), nozzleW),
                      DataCell(
                        SizedBox(
                          width: fuelW,
                          child: Center(
                            child: Text(
                              e.type,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: sideW,
                          child: Center(
                            child: Text(
                              e.notes?.isNotEmpty == true ? e.notes! : '-',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _cell(const Text(''), openW),
                      _cell(const Text(''), closeW),
                      _cell(const Text(''), literW),
                      _cell(const Text(''), beforeW),
                      _cell(const Text(''), afterW),
                      DataCell(
                        SizedBox(
                          width: amountW,
                          child: Center(
                            child: Text(
                              '${e.amount.toStringAsFixed(2)} ريال',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.warningOrange,
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: actionsW,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _expenses.remove(e);
                                  _recalculateTotals();
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= Add Expense Row =================
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: pumpW,
                        child: Center(
                          child: Text(
                            'إضافة',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: nozzleW,
                        child: Center(
                          child: Text(
                            'مصروف',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: fuelW,
                        child: TextFormField(
                          controller: _expenseTypeController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'النوع',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppColors.lightGray,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: sideW,
                        child: TextFormField(
                          controller: _expenseNotesController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'ملاحظات',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppColors.lightGray,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    _cell(const Text(''), openW),
                    _cell(const Text(''), closeW),
                    DataCell(
                      SizedBox(
                        width: literW,
                        child: TextFormField(
                          controller: _expenseAmountController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'المبلغ',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppColors.lightGray,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    _cell(const Text(''), beforeW),
                    _cell(const Text(''), afterW),
                    _cell(const Text(''), amountW),
                    DataCell(
                      SizedBox(
                        width: actionsW,
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final amount = double.tryParse(
                                _expenseAmountController.text,
                              );
                              if (_expenseTypeController.text.isEmpty ||
                                  amount == null)
                                return;

                              setState(() {
                                _expenses.add(
                                  ExpenseItem(
                                    type: _expenseTypeController.text.trim(),
                                    amount: amount,
                                    notes: _expenseNotesController.text.trim(),
                                  ),
                                );

                                _expenseTypeController.clear();
                                _expenseAmountController.clear();
                                _expenseNotesController.clear();

                                _recalculateTotals();
                              });
                            },
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text(
                              'إضافة',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                DataRow(
                  color: MaterialStateProperty.all(
                    AppColors.backgroundGray.withOpacity(0.2),
                  ),
                  cells: [
                    DataCell(
                      SizedBox(
                        width: pumpW,
                        child: Center(
                          child: Text(
                            'إجمالي المصروفات',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _cell(const Text(''), nozzleW),
                    _cell(const Text(''), fuelW),
                    _cell(const Text(''), sideW),
                    _cell(const Text(''), openW),
                    _cell(const Text(''), closeW),
                    _cell(const Text(''), literW),
                    _cell(const Text(''), beforeW),
                    _cell(const Text(''), afterW),
                    DataCell(
                      SizedBox(
                        width: amountW,
                        child: Center(
                          child: Text(
                            '${_expensesTotal.toStringAsFixed(2)} ريال',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warningOrange,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _cell(const Text(''), actionsW),
                  ],
                ),

                // ================= Fuel Return Section =================
                _buildSectionRow('إرجاع وقود للخزان'),
                ..._fuelReturnEntries.map(
                  (entry) {
                    final amount =
                        entry.quantity * _resolveFuelUnitPrice(entry.fuelType);
                    return DataRow(
                      cells: [
                        _cell(Text('إرجاع'), pumpW),
                        _cell(const Text(''), nozzleW),
                        DataCell(
                          SizedBox(
                            width: fuelW,
                            child: Center(
                              child: Text(
                                entry.fuelType,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: sideW,
                            child: Center(
                              child: Text(
                                entry.reason?.isNotEmpty == true
                                    ? entry.reason!
                                    : '-',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mediumGray,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _cell(const Text(''), openW),
                        _cell(const Text(''), closeW),
                        DataCell(
                          SizedBox(
                            width: literW,
                            child: Center(
                              child: Text(
                                entry.quantity.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _cell(const Text(''), beforeW),
                        _cell(const Text(''), afterW),
                        DataCell(
                          SizedBox(
                            width: amountW,
                            child: Center(
                              child: Text(
                                '${amount.toStringAsFixed(2)} ريال',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warningOrange,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: actionsW,
                            child: Center(
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _fuelReturnEntries.remove(entry);
                                    _recalculateTotals();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: pumpW,
                        child: Center(
                          child: Text(
                            'إضافة',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: nozzleW,
                        child: Center(
                          child: Text(
                            'إرجاع',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: fuelW,
                        child: DropdownButtonFormField<String>(
                          value: returnFuelValue,
                          items: returnFuelOptions
                              .map(
                                (fuel) => DropdownMenuItem(
                                  value: fuel,
                                  child: Text(
                                    fuel,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedReturnFuelType = value;
                            });
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: AppColors.lightGray,
                              ),
                            ),
                          ),
                          hint: const Text('اختر'),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: sideW,
                        child: TextFormField(
                          controller: _returnReasonController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'سبب الإرجاع',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppColors.lightGray,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    _cell(const Text(''), openW),
                    _cell(const Text(''), closeW),
                    DataCell(
                      SizedBox(
                        width: literW,
                        child: TextFormField(
                          controller: _returnFuelQuantityController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'الكمية',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppColors.lightGray,
                              ),
                            ),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    _cell(const Text(''), beforeW),
                    _cell(const Text(''), afterW),
                    _cell(const Text(''), amountW),
                    DataCell(
                      SizedBox(
                        width: actionsW,
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final qty = double.tryParse(
                                _returnFuelQuantityController.text,
                              );
                              final fuelType = _selectedReturnFuelType;
                              if (fuelType == null ||
                                  fuelType.isEmpty ||
                                  qty == null ||
                                  qty <= 0) {
                                return;
                              }

                              setState(() {
                                _fuelReturnEntries.add(
                                  _FuelReturnEntry(
                                    fuelType: fuelType,
                                    quantity: qty,
                                    reason: _returnReasonController.text.trim(),
                                  ),
                                );
                                _returnFuelQuantityController.clear();
                                _returnReasonController.clear();
                                _recalculateTotals();
                              });
                            },
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text(
                              'إضافة',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ================= Fuel Supply Section =================
                // _buildSectionRow('توريد الوقود'),
                // _buildSupplyRow('الكمية', _fuelQuantityController, columnWidths),
                // _buildSupplyRow('رقم التانكر', _tankerNumberController, columnWidths),
                // _buildSupplyRow('المورد', _supplierNameController, columnWidths),

                // ================= Balance & Notes =================
                _buildSectionRow('الرصيد والملاحظات'),
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: pumpW,
                        child: Center(
                          child: Text(
                            'رصيد مرحّل',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _cell(const Text(''), nozzleW),
                    _cell(const Text(''), fuelW),
                    _cell(const Text(''), sideW),
                    _cell(const Text(''), openW),
                    DataCell(
                      SizedBox(
                        width: closeW,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextFormField(
                            controller: _carriedForwardController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: AppColors.lightGray,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    _cell(const Text(''), literW),
                    _cell(const Text(''), beforeW),
                    _cell(const Text(''), afterW),
                    _cell(const Text(''), amountW),
                    DataCell(
                      SizedBox(
                        width: actionsW,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'ملاحظات إضافية...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: AppColors.lightGray,
                                ),
                              ),
                            ),
                            maxLines: 2,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ================= Shortage Resolution =================
                if (_calculatedDifference < 0 && !_shortageResolved) ...[
                  _buildSectionRow('تسوية العجز'),
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: pumpW,
                          child: Center(
                            child: Text(
                              'المبلغ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _cell(const Text(''), nozzleW),
                      _cell(const Text(''), fuelW),
                      _cell(const Text(''), sideW),
                      _cell(const Text(''), openW),
                      DataCell(
                        SizedBox(
                          width: closeW,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextFormField(
                              controller: _shortageAmountController,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'مبلغ العجز',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: AppColors.lightGray,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              onChanged: (v) =>
                                  _shortageAmount = double.tryParse(v) ?? 0,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: literW,
                          child: TextFormField(
                            controller: _shortageReasonController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'السبب',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: AppColors.lightGray,
                                ),
                              ),
                            ),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (v) => _shortageReason = v,
                          ),
                        ),
                      ),
                      _cell(const Text(''), beforeW),
                      _cell(const Text(''), afterW),
                      _cell(const Text(''), amountW),
                      DataCell(
                        SizedBox(
                          width: actionsW,
                          child: Center(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final amount =
                                    double.tryParse(
                                      _shortageAmountController.text,
                                    ) ??
                                    0;
                                if (amount <= 0 ||
                                    _shortageReasonController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'يرجى إدخال مبلغ العجز وسببه',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setState(() {
                                  _shortageResolved = true;
                                  _shortageAmount = amount;
                                  _shortageReason =
                                      _shortageReasonController.text;
                                });

                                _recalculateTotals();
                              },
                              icon: const Icon(Icons.check_circle, size: 14),
                              label: const Text(
                                'اعتماد العجز',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                backgroundColor: AppColors.successGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebSummaryTables() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 980;

        final totalsCard = _buildSummaryCard(
          title: 'الإجماليات',
          rows: [
            _buildSummaryRow(
              'إجمالي اللترات',
              '${_totalLiters.toStringAsFixed(2)} لتر',
            ),
            _buildSummaryRow(
              'المبلغ المطلوب',
              '${_totalAmount.toStringAsFixed(2)} ريال',
            ),
            _buildSummaryRow(
              'إجمالي المصروفات',
              '${_expensesTotal.toStringAsFixed(2)} ريال',
            ),
            _buildSummaryRow(
              'خصم إرجاع الوقود',
              '${_returnAmount.toStringAsFixed(2)} ريال',
            ),
            _buildSummaryRow(
              'إجمالي التحصيل',
              '${_totalSales.toStringAsFixed(2)} ريال',
            ),
            _buildDifferenceSummaryRow(),
          ],
        );

        final paymentsCard = _buildSummaryCard(
          title: 'التحصيل النقدي',
          rows: [
            _buildSummaryWidgetRow(
              'نقدي',
              _buildSummaryInput(_cashController),
            ),
            _buildSummaryWidgetRow(
              'شبكة (مدى)',
              _buildSummaryInput(_cardController),
            ),
            _buildSummaryWidgetRow(
              'أخرى',
              _buildSummaryInput(_otherController),
            ),
          ],
        );

        if (isStacked) {
          return Column(
            children: [
              totalsCard,
              const SizedBox(height: 16),
              paymentsCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: totalsCard),
            const SizedBox(width: 16),
            Expanded(child: paymentsCard),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required List<TableRow> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGray),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.backgroundGray.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: BorderSide(color: AppColors.lightGray),
              verticalInside: BorderSide(color: AppColors.lightGray),
            ),
            children: rows,
          ),
        ],
      ),
    );
  }

  TableRow _buildSummaryRow(String label, String value) {
    return _buildSummaryWidgetRow(
      label,
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: AppColors.darkGray,
        ),
      ),
    );
  }

  TableRow _buildSummaryWidgetRow(String label, Widget value) {
    return TableRow(
      children: [
        _summaryCell(
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        _summaryCell(value),
      ],
    );
  }

  TableRow _buildDifferenceSummaryRow() {
    final isPositive = _calculatedDifference >= 0;
    final shortageResolved = _calculatedDifference < 0 && _shortageResolved;

    final label = shortageResolved ? 'عجز مسوّى' : (isPositive ? 'فائض' : 'عجز');
    final accentColor = shortageResolved
        ? AppColors.warningOrange
        : (isPositive ? AppColors.successGreen : AppColors.errorRed);
    final valueText = shortageResolved
        ? 'مسوّى'
        : '${_calculatedDifference.abs().toStringAsFixed(2)} ريال';

    return _buildSummaryWidgetRow(
      label,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor),
        ),
        child: Text(
          valueText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: accentColor,
          ),
        ),
      ),
    );
  }

  Widget _summaryCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Center(child: child),
    );
  }

  Widget _buildSummaryInput(TextEditingController controller) {
    return SizedBox(
      width: 110,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          hintText: '0',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.lightGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.primaryBlue),
          ),
        ),
        style: const TextStyle(fontSize: 12),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _recalculateTotals(),
      ),
    );
  }


  DataRow _buildSectionRow(String title) {
    return DataRow(
      color: MaterialStateProperty.all(
        AppColors.backgroundGray.withOpacity(0.5),
      ),
      cells: List.generate(
        11,
        (index) => DataCell(
          index == 0
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : const Text(''),
        ),
      ),
    );
  }

  DataRow _buildStockHeaderRow(_TableColumnWidths widths) {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: AppColors.darkGray,
    );

    return DataRow(
      color: MaterialStateProperty.all(
        AppColors.backgroundGray.withOpacity(0.2),
      ),
      cells: [
        DataCell(
          SizedBox(
            width: widths.pump,
            child: Center(child: Text('البيان', style: headerStyle)),
          ),
        ),
        _cell(const Text(''), widths.nozzle),
        DataCell(
          SizedBox(
            width: widths.fuel,
            child: Center(child: Text('الوقود', style: headerStyle)),
          ),
        ),
        _cell(const Text(''), widths.side),
        _cell(const Text(''), widths.open),
        _cell(const Text(''), widths.close),
        DataCell(
          SizedBox(
            width: widths.liter,
            child: Center(child: Text('المبيعات', style: headerStyle)),
          ),
        ),
        DataCell(
          SizedBox(
            width: widths.before,
            child: Center(child: Text('قبل المبيعات', style: headerStyle)),
          ),
        ),
        DataCell(
          SizedBox(
            width: widths.after,
            child: Center(child: Text('بعد المبيعات', style: headerStyle)),
          ),
        ),
        _cell(const Text(''), widths.amount),
        _cell(const Text(''), widths.actions),
      ],
    );
  }

  List<DataRow> _buildFuelStockRows(_TableColumnWidths widths) {
    if (_isStockLoading) {
      return [
        DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: widths.pump,
                child: const Center(child: Text('جاري تحميل المخزون...')),
              ),
            ),
            _cell(const Text(''), widths.nozzle),
            _cell(const Text(''), widths.fuel),
            _cell(const Text(''), widths.side),
            _cell(const Text(''), widths.open),
            _cell(const Text(''), widths.close),
            _cell(const Text(''), widths.liter),
            _cell(const Text(''), widths.before),
            _cell(const Text(''), widths.after),
            _cell(const Text(''), widths.amount),
            _cell(const Text(''), widths.actions),
          ],
        ),
      ];
    }

    if (_stockError != null) {
      return [
        DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: widths.pump,
                child: Center(
                  child: Text(
                    _stockError!,
                    style: const TextStyle(color: AppColors.errorRed),
                  ),
                ),
              ),
            ),
            _cell(const Text(''), widths.nozzle),
            _cell(const Text(''), widths.fuel),
            _cell(const Text(''), widths.side),
            _cell(const Text(''), widths.open),
            _cell(const Text(''), widths.close),
            _cell(const Text(''), widths.liter),
            _cell(const Text(''), widths.before),
            _cell(const Text(''), widths.after),
            _cell(const Text(''), widths.amount),
            _cell(const Text(''), widths.actions),
          ],
        ),
      ];
    }

    final before = _stockBeforeSalesByFuel;
    final after = _stockAfterSalesByFuel;
    final sold = _normalizeFuelMap(_soldLitersByFuel);
    final returns = _normalizeFuelMap(_returnsByFuel());
    final compactBefore = _compactFuelMap(before);
    final compactSold = _compactFuelMap(sold);
    final compactReturns = _compactFuelMap(returns);
    final allFuelTypes = <String>{
      ...before.keys,
      ...after.keys,
      ...sold.keys,
      ...returns.keys,
    }.toList()
      ..sort();

    if (allFuelTypes.isEmpty) {
      return [
        DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: widths.pump,
                child: const Center(child: Text('لا توجد بيانات مخزون')),
              ),
            ),
            _cell(const Text(''), widths.nozzle),
            _cell(const Text(''), widths.fuel),
            _cell(const Text(''), widths.side),
            _cell(const Text(''), widths.open),
            _cell(const Text(''), widths.close),
            _cell(const Text(''), widths.liter),
            _cell(const Text(''), widths.before),
            _cell(const Text(''), widths.after),
            _cell(const Text(''), widths.amount),
            _cell(const Text(''), widths.actions),
          ],
        ),
      ];
    }

    return allFuelTypes.map((fuelType) {
      final compactKey = _compactFuelKey(fuelType);
      final beforeValue = compactBefore[compactKey] ?? 0;
      final afterValue = beforeValue -
          (compactSold[compactKey] ?? 0) +
          (compactReturns[compactKey] ?? 0);
      final soldValue = sold[fuelType] ?? 0;

      return DataRow(
        cells: [
          DataCell(
            SizedBox(
              width: widths.pump,
              child: const Center(
                child: Text(
                  'رصيد الخزان',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          _cell(const Text(''), widths.nozzle),
          DataCell(
            SizedBox(
              width: widths.fuel,
              child: Center(
                child: Text(
                  fuelType,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          _cell(const Text(''), widths.side),
          _cell(const Text(''), widths.open),
          _cell(const Text(''), widths.close),
          DataCell(
            SizedBox(
              width: widths.liter,
              child: Center(
                child: Text(soldValue.toStringAsFixed(2)),
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: widths.before,
              child: Center(
                child: Text(beforeValue.toStringAsFixed(2)),
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: widths.after,
              child: Center(
                child: Text(afterValue.toStringAsFixed(2)),
              ),
            ),
          ),
          _cell(const Text(''), widths.amount),
          _cell(const Text(''), widths.actions),
        ],
      );
    }).toList();
  }

  DataRow _buildSupplyRow(
    String label,
    TextEditingController controller,
    _TableColumnWidths widths,
  ) {
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: widths.pump,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
        _cell(const Text(''), widths.nozzle),
        _cell(const Text(''), widths.fuel),
        _cell(const Text(''), widths.side),
        _cell(const Text(''), widths.open),
        DataCell(
          SizedBox(
            width: widths.close,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: AppColors.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.primaryBlue),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
        _cell(const Text(''), widths.liter),
        _cell(const Text(''), widths.before),
        _cell(const Text(''), widths.after),
        _cell(const Text(''), widths.amount),
        _cell(const Text(''), widths.actions),
      ],
    );
  }



  DataColumn _header(String title, double width) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Center(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  DataCell _cell(Widget child, double width) {
    return DataCell(
      SizedBox(
        width: width,
        child: Center(child: child),
      ),
    );
  }



  // Widget _buildWebSummarySection() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: AppColors.backgroundGray,
  //       borderRadius: BorderRadius.circular(8),
  //     ),
  //     child: Row(
  //       children: [
  //         // Add Expense Form
  //         Expanded(
  //           child: Card(
  //             elevation: 1,
  //             child: Padding(
  //               padding: const EdgeInsets.all(16),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     'إضافة مصروف',
  //                     style: TextStyle(
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 15,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 12),
  //                   Row(
  //                     children: [
  //                       Expanded(
  //                         child: CustomTextField(
  //                           controller: _expenseTypeController,
  //                           labelText: 'نوع المصروف',
  //                           prefixIcon: Icons.category,
  //                         ),
  //                       ),
  //                       const SizedBox(width: 12),
  //                       Expanded(
  //                         child: CustomTextField(
  //                           controller: _expenseAmountController,
  //                           labelText: 'القيمة',
  //                           prefixIcon: Icons.money_off,
  //                           keyboardType: TextInputType.number,
  //                         ),
  //                       ),
  //                       const SizedBox(width: 12),
  //                       ElevatedButton.icon(
  //                         onPressed: () {
  //                           final amount = double.tryParse(
  //                             _expenseAmountController.text,
  //                           );
  //                           if (_expenseTypeController.text.isEmpty ||
  //                               amount == null)
  //                             return;

  //                           setState(() {
  //                             _expenses.add(
  //                               ExpenseItem(
  //                                 type: _expenseTypeController.text.trim(),
  //                                 amount: amount,
  //                                 notes: _expenseNotesController.text.trim(),
  //                               ),
  //                             );

  //                             _expenseTypeController.clear();
  //                             _expenseAmountController.clear();
  //                             _expenseNotesController.clear();

  //                             _recalculateTotals();
  //                           });
  //                         },
  //                         icon: const Icon(Icons.add, size: 18),
  //                         label: const Text('إضافة'),
  //                         style: ElevatedButton.styleFrom(
  //                           backgroundColor: AppColors.primaryBlue,
  //                           foregroundColor: Colors.white,
  //                           minimumSize: const Size(100, 50),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                   if (_expenseNotesController.text.isNotEmpty)
  //                     Padding(
  //                       padding: const EdgeInsets.only(top: 12),
  //                       child: CustomTextField(
  //                         controller: _expenseNotesController,
  //                         labelText: 'ملاحظات',
  //                         prefixIcon: Icons.note,
  //                       ),
  //                     ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),

  //         const SizedBox(width: 16),

  //         // Additional Controls
  //         SizedBox(
  //           width: 300,
  //           child: Card(
  //             elevation: 1,
  //             child: Padding(
  //               padding: const EdgeInsets.all(16),
  //               child: Column(
  //                 children: [
  //                   CustomTextField(
  //                     controller: _carriedForwardController,
  //                     labelText: 'الرصيد المرحل',
  //                     prefixIcon: Icons.account_balance_wallet,
  //                     keyboardType: TextInputType.number,
  //                   ),
  //                   const SizedBox(height: 12),
  //                   CustomTextField(
  //                     controller: _notesController,
  //                     labelText: 'ملاحظات إضافية',
  //                     prefixIcon: Icons.note,
  //                     maxLines: 2,
  //                   ),
  //                   if (_calculatedDifference < 0 && !_shortageResolved) ...[
  //                     const SizedBox(height: 12),
  //                     const Divider(),
  //                     const SizedBox(height: 8),
  //                     const Text(
  //                       'تسوية العجز',
  //                       style: TextStyle(
  //                         fontWeight: FontWeight.bold,
  //                         fontSize: 14,
  //                       ),
  //                     ),
  //                     const SizedBox(height: 8),
  //                     CustomTextField(
  //                       controller: _shortageAmountController,
  //                       labelText: 'مبلغ العجز',
  //                       keyboardType: TextInputType.number,
  //                     ),
  //                     const SizedBox(height: 8),
  //                     CustomTextField(
  //                       controller: _shortageReasonController,
  //                       labelText: 'سبب العجز',
  //                     ),
  //                     const SizedBox(height: 8),
  //                     ElevatedButton.icon(
  //                       onPressed: () {
  //                         final amount =
  //                             double.tryParse(_shortageAmountController.text) ??
  //                             0;
  //                         if (amount <= 0 ||
  //                             _shortageReasonController.text.isEmpty) {
  //                           ScaffoldMessenger.of(context).showSnackBar(
  //                             const SnackBar(
  //                               content: Text('يرجى إدخال مبلغ العجز وسببه'),
  //                               backgroundColor: Colors.red,
  //                             ),
  //                           );
  //                           return;
  //                         }

  //                         setState(() {
  //                           _shortageResolved = true;
  //                           _shortageAmount = amount;
  //                           _shortageReason = _shortageReasonController.text;
  //                         });

  //                         _recalculateTotals();
  //                       },
  //                       icon: const Icon(Icons.check_circle, size: 16),
  //                       label: const Text('اعتماد العجز'),
  //                       style: ElevatedButton.styleFrom(
  //                         backgroundColor: AppColors.successGreen,
  //                         foregroundColor: Colors.white,
  //                         minimumSize: const Size(double.infinity, 44),
  //                       ),
  //                     ),
  //                   ],
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }



  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _returnFuelQuantityController.dispose();
    _returnReasonController.dispose();
    super.dispose();
  }
}

class _TableColumnWidths {
  const _TableColumnWidths({
    required this.pump,
    required this.nozzle,
    required this.fuel,
    required this.side,
    required this.open,
    required this.close,
    required this.liter,
    required this.before,
    required this.after,
    required this.amount,
    required this.actions,
  });

  final double pump;
  final double nozzle;
  final double fuel;
  final double side;
  final double open;
  final double close;
  final double liter;
  final double before;
  final double after;
  final double amount;
  final double actions;
}

class _FuelReturnEntry {
  _FuelReturnEntry({
    required this.fuelType,
    required this.quantity,
    this.reason,
  });

  final String fuelType;
  final double quantity;
  final String? reason;
}
