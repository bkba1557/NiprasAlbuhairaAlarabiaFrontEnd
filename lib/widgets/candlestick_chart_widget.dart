// lib/widgets/candlestick_chart_widget.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';

class CandlestickStatChart extends StatefulWidget {
  final List<Map<String, dynamic>> statsData;
  final String title;
  final bool showGrid;
  final bool isCompact;

  const CandlestickStatChart({
    super.key,
    required this.statsData,
    required this.title,
    this.showGrid = true,
    this.isCompact = false,
  });

  @override
  State<CandlestickStatChart> createState() => _CandlestickStatChartState();
}

class _CandlestickStatChartState extends State<CandlestickStatChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.statsData.isEmpty) {
      return _buildEmptyChart();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: widget.isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkBlue,
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
                    '${widget.statsData.length} فئة',
                    style: TextStyle(
                      fontSize: widget.isCompact ? 10 : 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chart
          SizedBox(
            height: widget.isCompact ? 220 : 280,
            child: Stack(
              children: [
                // Candlestick Chart
                BarChart(
                  _buildChartData(),
                  swapAnimationDuration: const Duration(milliseconds: 500),
                ),

                // Touch indicator
                if (_touchedIndex != -1)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TouchIndicatorPainter(
                        touchedIndex: _touchedIndex,
                        barGroups: _buildBarGroups(),
                        maxY: _getMaxValue(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Legend
          _buildChartLegend(),
        ],
      ),
    );
  }

  BarChartData _buildChartData() {
    return BarChartData(
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.black87,
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 0,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final stat = widget.statsData[groupIndex];
            return BarTooltipItem(
              '${stat['label']}\n',
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: '${stat['value']} طلب',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
        touchCallback: (event, response) {
          if (response?.spot != null && event is FlTapUpEvent) {
            setState(() {
              _touchedIndex = response!.spot!.touchedBarGroupIndex;
            });
          }
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < widget.statsData.length) {
                final stat = widget.statsData[index];
                final label = stat['label'] as String;
                // اختصار النص الطويل
                if (label.length > 10) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${label.substring(0, 10)}...',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return const Text('');
            },
            reservedSize: widget.isCompact ? 28 : 40,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
            reservedSize: widget.isCompact ? 28 : 40,
            interval: _getInterval(),
          ),
        ),
      ),
      borderData: FlBorderData(
        show: widget.showGrid,
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      gridData: FlGridData(
        show: widget.showGrid,
        drawVerticalLine: false,
        horizontalInterval: _getInterval(),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade100,
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      barGroups: _buildBarGroups(),
      maxY: _getMaxValue(),
      alignment: BarChartAlignment.spaceAround,
      groupsSpace: 12,
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(widget.statsData.length, (index) {
      final stat = widget.statsData[index];
      final value = stat['value'] as int;
      final color = stat['color'] as Color;
      final isTouched = index == _touchedIndex;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value.toDouble(),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(isTouched ? 1.0 : 0.8),
                color.withOpacity(isTouched ? 0.7 : 0.5),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: isTouched ? 20 : 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxValue(),
              color: Colors.grey.shade50,
            ),
          ),
        ],
        showingTooltipIndicators: isTouched ? [0] : [],
      );
    });
  }

  double _getMaxValue() {
    if (widget.statsData.isEmpty) return 100;
    final max = widget.statsData
        .map<int>((stat) => stat['value'] as int)
        .reduce((a, b) => a > b ? a : b);
    return (max * 1.2).toDouble(); // Add 20% margin
  }

  double _getInterval() {
    final max = _getMaxValue();
    if (max <= 10) return 2;
    if (max <= 50) return 10;
    if (max <= 100) return 20;
    return 50;
  }

  Widget _buildChartLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: widget.statsData.map((stat) {
          final label = stat['label'] as String;
          final value = stat['value'] as int;
          final color = stat['color'] as Color;
          final isTouched = widget.statsData.indexOf(stat) == _touchedIndex;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isTouched ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(isTouched ? 0.8 : 0.3),
                width: isTouched ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$value',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label.length > 12 ? '${label.substring(0, 12)}...' : label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 60,
            color: AppColors.primaryBlue.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد بيانات كافية',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف المزيد من الطلبات لعرض الإحصائيات',
            style: TextStyle(fontSize: 12, color: AppColors.lightGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TouchIndicatorPainter extends CustomPainter {
  final int touchedIndex;
  final List<BarChartGroupData> barGroups;
  final double maxY;

  _TouchIndicatorPainter({
    required this.touchedIndex,
    required this.barGroups,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (touchedIndex < 0 || touchedIndex >= barGroups.length) return;

    final barGroup = barGroups[touchedIndex];
    final barRod = barGroup.barRods.first;
    final centerX = barGroup.x * (size.width / (barGroups.length - 1));
    final barTop = size.height - (barRod.toY / maxY) * size.height;

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw vertical line
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), paint);

    // Draw horizontal line at bar top
    canvas.drawLine(Offset(0, barTop), Offset(size.width, barTop), paint);

    // Draw circle at intersection
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(centerX, barTop), 6, circlePaint);
    canvas.drawCircle(Offset(centerX, barTop), 6, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
