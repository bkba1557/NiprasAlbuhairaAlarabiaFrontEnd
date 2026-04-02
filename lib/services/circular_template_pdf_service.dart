import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CircularTemplatePdfService {
  static const PdfColor _blueDark = PdfColor.fromInt(0xFF1B4FA3);
  static const PdfColor _blueMedium = PdfColor.fromInt(0xFF2F6FBF);
  static const PdfColor _blueLight = PdfColor.fromInt(0xFF7FB3E6);

  static const String defaultCompanyArabicName = 'شركة البحيرة العربية';
  static const String defaultCompanyEnglishName = 'Al-Buhaira Al-Arabiya Co.';
  static const String defaultUnifiedNumber = '7011144750';

  static pw.MemoryImage? _cachedLogo;
  static pw.Font? _cachedCairoRegular;
  static pw.Font? _cachedCairoBold;

  static Future<pw.MemoryImage> _loadLogoImage() async {
    final cached = _cachedLogo;
    if (cached != null) return cached;
    final logoData = await rootBundle.load(AppImages.logo);
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    _cachedLogo = logoImage;
    return logoImage;
  }

  static Future<pw.Font> _loadCairoRegular() async {
    final cached = _cachedCairoRegular;
    if (cached != null) return cached;
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    _cachedCairoRegular = font;
    return font;
  }

  static Future<pw.Font> _loadCairoBold() async {
    final cached = _cachedCairoBold;
    if (cached != null) return cached;
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
    _cachedCairoBold = font;
    return font;
  }

  static Future<Uint8List> buildCircularPdfBytes({
    required String circularNumber,
    String? subject,
    String? body,
    DateTime? issuedAt,
    bool includeMetaRow = true,
    String subjectAlign = 'center',
    String bodyAlign = 'right',
    double subjectFontSize = 18,
    double bodyFontSize = 12,
    bool subjectBold = true,
    bool subjectUnderline = false,
    bool bodyBold = false,
    bool bodyUnderline = false,
    String companyArabicName = defaultCompanyArabicName,
    String companyEnglishName = defaultCompanyEnglishName,
    String unifiedNumber = defaultUnifiedNumber,
  }) async {
    final logoImage = await _loadLogoImage();
    final cairoRegular = await _loadCairoRegular();
    final cairoBold = await _loadCairoBold();

    final safeSubject = (subject ?? '').trim();
    final safeBody = (body ?? '').trim();
    final subjectTextAlign = _parseTextAlign(
      subjectAlign,
      fallback: pw.TextAlign.center,
    );
    final bodyTextAlign = _parseTextAlign(
      bodyAlign,
      fallback: pw.TextAlign.right,
    );
    final resolvedIssuedAt = issuedAt ?? DateTime.now();
    final issuedAtStr = DateFormat('yyyy/MM/dd').format(resolvedIssuedAt);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: cairoRegular,
        bold: cairoBold,
        fontFallback: [cairoRegular],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 16, 28, 22),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: cairoRegular,
            bold: cairoBold,
            fontFallback: [cairoRegular],
          ),
          buildBackground: (context) => _buildBackground(),
        ),
        header: (context) => _buildHeader(
          context: context,
          logoImage: logoImage,
          companyArabicName: companyArabicName,
          companyEnglishName: companyEnglishName,
          unifiedNumber: unifiedNumber,
        ),
        footer: (context) => _buildFooter(context: context),
        build: (_) => [
          pw.SizedBox(height: 14),
          if (includeMetaRow)
            _buildMetaRow(
              circularNumber: circularNumber,
              issuedAt: issuedAtStr,
            ),
          if (safeSubject.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              safeSubject,
              textAlign: subjectTextAlign,
              style: pw.TextStyle(
                fontSize: subjectFontSize,
                fontWeight: subjectBold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                decoration: subjectUnderline
                    ? pw.TextDecoration.underline
                    : pw.TextDecoration.none,
              ),
            ),
          ],
          if (safeBody.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              safeBody,
              textAlign: bodyTextAlign,
              style: pw.TextStyle(
                fontSize: bodyFontSize,
                height: 1.6,
                fontWeight: bodyBold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                decoration: bodyUnderline
                    ? pw.TextDecoration.underline
                    : pw.TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> printCircular({
    required String circularNumber,
    String? subject,
    String? body,
    DateTime? issuedAt,
    bool includeMetaRow = true,
    String subjectAlign = 'center',
    String bodyAlign = 'right',
    double subjectFontSize = 18,
    double bodyFontSize = 12,
    bool subjectBold = true,
    bool subjectUnderline = false,
    bool bodyBold = false,
    bool bodyUnderline = false,
  }) async {
    final bytes = await buildCircularPdfBytes(
      circularNumber: circularNumber,
      subject: subject,
      body: body,
      issuedAt: issuedAt,
      includeMetaRow: includeMetaRow,
      subjectAlign: subjectAlign,
      bodyAlign: bodyAlign,
      subjectFontSize: subjectFontSize,
      bodyFontSize: bodyFontSize,
      subjectBold: subjectBold,
      subjectUnderline: subjectUnderline,
      bodyBold: bodyBold,
      bodyUnderline: bodyUnderline,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'تعميم_$circularNumber.pdf',
    );
  }

  static pw.Widget _buildMetaRow({
    required String circularNumber,
    required String issuedAt,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildMetaItem('رقم التعميم', circularNumber),
        _buildMetaItem('التاريخ', issuedAt),
      ],
    );
  }

  static pw.Widget _buildMetaItem(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildHeader({
    required pw.Context context,
    required pw.MemoryImage logoImage,
    required String companyArabicName,
    required String companyEnglishName,
    required String unifiedNumber,
  }) {
    return pw.SizedBox(
      height: 150,
      child: pw.Stack(
        children: [
          pw.Positioned(
            right: 0,
            top: 0,
            child: pw.Text(
              context.pageNumber.toString(),
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Positioned(
            right: 0,
            top: 12,
            child: pw.Container(
              width: 86,
              height: 86,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ),
          pw.Positioned(
            left: 0,
            right: 98,
            top: 64,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  companyArabicName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  companyEnglishName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'الرقم الموحد: $unifiedNumber',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),
              ],
            ),
          ),
          pw.Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: pw.Container(height: 0.8, color: PdfColors.grey400),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter({required pw.Context context}) {
    return pw.SizedBox(
      height: 42,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: pw.Container(height: 2, color: _blueDark),
          ),
          pw.Positioned(
            left: 0,
            bottom: 0,
            child: pw.Text(
              context.pageNumber.toString(),
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Positioned(
            right: 125,
            bottom: 0,
            child: pw.Text(
              'ALBUHAIRA ALARABIA',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBackground() {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints?.maxWidth ?? PdfPageFormat.a4.width;
          final h = constraints?.maxHeight ?? PdfPageFormat.a4.height;

          final bottomShapeWidth = w * 0.25;
          final bottomShapeHeight = h * 0.14;

          return pw.Stack(
            children: [
              // Top stripes (light -> dark)
              pw.Polygon(
                points: [
                  PdfPoint(0, 28),
                  PdfPoint(w * 0.78, 28),
                  PdfPoint(w * 0.61, 64),
                  PdfPoint(0, 64),
                ],
                fillColor: _blueLight,
              ),
              pw.Polygon(
                points: [
                  PdfPoint(0, 14),
                  PdfPoint(w * 0.74, 14),
                  PdfPoint(w * 0.58, 46),
                  PdfPoint(0, 46),
                ],
                fillColor: _blueMedium,
              ),
              pw.Polygon(
                points: [
                  PdfPoint(0, 0),
                  PdfPoint(w * 0.70, 0),
                  PdfPoint(w * 0.55, 28),
                  PdfPoint(0, 28),
                ],
                fillColor: _blueDark,
              ),

              // Bottom-right shape
              pw.Polygon(
                points: [
                  PdfPoint(w, h - bottomShapeHeight),
                  PdfPoint(w, h),
                  PdfPoint(w - bottomShapeWidth, h),
                  PdfPoint(w - bottomShapeWidth * 0.25, h - bottomShapeHeight),
                ],
                fillColor: _blueDark,
              ),
            ],
          );
        },
      ),
    );
  }

  static pw.TextAlign _parseTextAlign(
    String value, {
    required pw.TextAlign fallback,
  }) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'left':
        return pw.TextAlign.left;
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      case 'justify':
        return pw.TextAlign.justify;
      default:
        return fallback;
    }
  }
}
