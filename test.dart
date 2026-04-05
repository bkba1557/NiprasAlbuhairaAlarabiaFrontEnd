import 'package:flutter/material.dart';

class MovementDashboardScr extends StatefulWidget {
  const MovementDashboardScr({super.key});

  @override
  State<MovementDashboardScr> createState() => _MovementDashboardScrState();
}

class _MovementDashboardScrState extends State<MovementDashboardScr> {
static const List<String> _fuelType = <String>[
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
];

static const Map<String, String> _arabicDigitMap = <String, String>{
  '0': '٠',
  '1': '١',
  '2': '٢',
  '3': '٣',
  '4': '٤',
  '5': '٥',
  '6': '٦',
  '7': '٧',
  '8': '٨',
  '9': '٩',
};

final GlobalKey<FormatState> _formatKey = GlobalKey<FormatState>(); 
 

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}