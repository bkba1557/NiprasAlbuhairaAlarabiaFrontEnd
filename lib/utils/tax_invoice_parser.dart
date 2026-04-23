import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'arabic_text_normalizer.dart';

class TaxInvoiceData {
  final String? invoiceNumber;
  final String? invoiceDateText;
  final String? supplierName;
  final String? supplierVatNumber;
  final String? supplierAddress;
  final String? supplierPostalCode;
  final String? supplierBuildingNumber;
  final String? supplierCommercialNumber;
  final String? customerName;
  final String? customerVatNumber;
  final String? customerAddress;
  final String? customerPostalCode;
  final String? customerBuildingNumber;
  final String? customerCommercialNumber;
  final String? referenceNumber;
  final String? transportOrderNumber;
  final String? itemDescription;
  final String? fromLocation;
  final String? toLocation;
  final double? quantity;
  final double? unitPriceBeforeVat;
  final double? subtotalBeforeVat;
  final double? vatAmount;
  final double? totalWithVat;
  final double? transportValueWithVat;

  const TaxInvoiceData({
    this.invoiceNumber,
    this.invoiceDateText,
    this.supplierName,
    this.supplierVatNumber,
    this.supplierAddress,
    this.supplierPostalCode,
    this.supplierBuildingNumber,
    this.supplierCommercialNumber,
    this.customerName,
    this.customerVatNumber,
    this.customerAddress,
    this.customerPostalCode,
    this.customerBuildingNumber,
    this.customerCommercialNumber,
    this.referenceNumber,
    this.transportOrderNumber,
    this.itemDescription,
    this.fromLocation,
    this.toLocation,
    this.quantity,
    this.unitPriceBeforeVat,
    this.subtotalBeforeVat,
    this.vatAmount,
    this.totalWithVat,
    this.transportValueWithVat,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
    if (invoiceDateText != null) 'invoiceDateText': invoiceDateText,
    if (supplierName != null) 'supplierName': supplierName,
    if (supplierVatNumber != null) 'supplierVatNumber': supplierVatNumber,
    if (supplierAddress != null) 'supplierAddress': supplierAddress,
    if (supplierPostalCode != null) 'supplierPostalCode': supplierPostalCode,
    if (supplierBuildingNumber != null)
      'supplierBuildingNumber': supplierBuildingNumber,
    if (supplierCommercialNumber != null)
      'supplierCommercialNumber': supplierCommercialNumber,
    if (customerName != null) 'customerName': customerName,
    if (customerVatNumber != null) 'customerVatNumber': customerVatNumber,
    if (customerAddress != null) 'customerAddress': customerAddress,
    if (customerPostalCode != null) 'customerPostalCode': customerPostalCode,
    if (customerBuildingNumber != null)
      'customerBuildingNumber': customerBuildingNumber,
    if (customerCommercialNumber != null)
      'customerCommercialNumber': customerCommercialNumber,
    if (referenceNumber != null) 'referenceNumber': referenceNumber,
    if (transportOrderNumber != null)
      'transportOrderNumber': transportOrderNumber,
    if (itemDescription != null) 'itemDescription': itemDescription,
    if (fromLocation != null) 'fromLocation': fromLocation,
    if (toLocation != null) 'toLocation': toLocation,
    if (quantity != null) 'quantity': quantity,
    if (unitPriceBeforeVat != null) 'unitPriceBeforeVat': unitPriceBeforeVat,
    if (subtotalBeforeVat != null) 'subtotalBeforeVat': subtotalBeforeVat,
    if (vatAmount != null) 'vatAmount': vatAmount,
    if (totalWithVat != null) 'totalWithVat': totalWithVat,
    if (transportValueWithVat != null)
      'transportValueWithVat': transportValueWithVat,
  };
}

class TaxInvoiceParser {
  static TaxInvoiceData parse(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final extractedText = extractor.extractText() ?? '';
      final layoutText = extractor.extractText(layoutText: true) ?? '';
      final extractedLines = extractor
          .extractTextLines()
          .map((line) => line.text)
          .toList();
      final lineText = extractedLines.join('\n');
      final formValues = _extractFormValues(document);

      final combinedRaw = '$layoutText\n$lineText\n$extractedText';
      final text = _normalizeMultiline(combinedRaw);
      final textFlat = _normalize(combinedRaw);
      final normalizedLines = _normalizeMultiline(lineText).split('\n');
      final normalizedForm = <String, String>{
        for (final entry in formValues.entries)
          _normalize(entry.key): _normalize(entry.value),
      };

      String sectionBetween({
        required String source,
        required String start,
        required String end,
      }) {
        final startIdx = source.indexOf(_normalize(start));
        if (startIdx < 0) return '';
        final endIdx = source.indexOf(_normalize(end), startIdx + 1);
        if (endIdx < 0) return source.substring(startIdx);
        return source.substring(startIdx, endIdx);
      }

      String? firstMatch(RegExp pattern, String source) {
        final match = pattern.firstMatch(source);
        if (match == null || match.groupCount < 1) return null;
        final value = match.group(1);
        if (value == null) return null;
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }

      String? pickFromFormOrText({
        required List<String> keys,
        required List<RegExp> patterns,
      }) {
        for (final key in keys) {
          for (final entry in normalizedForm.entries) {
            if (entry.key.contains(_normalize(key)) &&
                entry.value.trim().isNotEmpty) {
              return entry.value.trim();
            }
          }
        }
        for (final pattern in patterns) {
          final match =
              pattern.firstMatch(text) ?? pattern.firstMatch(textFlat);
          if (match != null && (match.groupCount >= 1)) {
            final value = match.group(1);
            if (value != null && value.trim().isNotEmpty) {
              return value.trim();
            }
          }
        }
        return null;
      }

      double? pickMoney({
        required List<String> keys,
        required List<RegExp> patterns,
      }) {
        final raw = pickFromFormOrText(keys: keys, patterns: patterns);
        return _parseMoney(raw);
      }

      RegExp moneyPattern(String labelAlternatives) {
        return RegExp(
          '(?:$labelAlternatives)\\s*[:\\-]?\\s*([0-9][0-9.,]*)',
          caseSensitive: false,
        );
      }

      double? pickMoneyAround(String labelAlternatives) {
        final after = firstMatch(
          RegExp(
            '(?:$labelAlternatives)\\s*[:\\-]?\\s*([0-9][0-9.,]*)',
            caseSensitive: false,
          ),
          text,
        );
        if (after != null) return _parseMoney(after);

        final before = firstMatch(
          RegExp(
            '([0-9][0-9.,]*)\\s*(?:$labelAlternatives)',
            caseSensitive: false,
          ),
          text,
        );
        if (before != null) return _parseMoney(before);

        return null;
      }

      final invoiceNumber = pickFromFormOrText(
        keys: const <String>[
          'invoice_number',
          'رقم الفاتورة',
          'رقم الفاتورة الضريبية',
          'رقم الفاتوره',
          'رقم الفاتوره الضريبيه',
          'invoice no',
          'invoice no.',
          'inv no',
        ],
        patterns: <RegExp>[
          RegExp(
            r'(?:رقم\s*الفاتور[هة](?:\s*الضريبي[هة])?|الفاتور[هة]\s*رقم|رقم\s*فاتور[هة](?:\s*ضريبي[هة])?|Invoice\s*No\.?)\s*[:\-]?\s*([A-Za-z0-9][A-Za-z0-9-\/_]{3,})',
            caseSensitive: false,
          ),
        ],
      );

      final invoiceDateText = pickFromFormOrText(
        keys: const <String>[
          'invoice_date',
          'تاريخ الفاتورة',
          'تاريخ الفاتورة الضريبية',
          'تاريخ الفاتوره',
          'تاريخ الفاتوره الضريبيه',
          'invoice date',
          'date',
        ],
        patterns: <RegExp>[
          RegExp(
            r'(?:تاريخ\s*الفاتور[هة](?:\s*الضريبي[هة])?|الفاتور[هة]\s*تاريخ|Invoice\s*Date|تاريخ)\s*[:\-]?\s*([0-9]{4}[/-][0-9]{1,2}[/-][0-9]{1,2}|[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})',
            caseSensitive: false,
          ),
        ],
      );

      final supplierNameDetected = pickFromFormOrText(
        keys: const <String>[
          'supplier_name',
          'البائع',
          'المورد',
          'اسم البائع',
          'اسم البائع/المورد',
          'Seller',
        ],
        patterns: <RegExp>[
          RegExp(
            r'(?:اسم\s*البائع(?:\s*/\s*المورد)?|البائع|Seller|المورد)\s*[:\-]?\s*([^\n]{3,80})',
            caseSensitive: false,
          ),
        ],
      );

      final supplierVatNumberDetected = pickFromFormOrText(
        keys: const <String>[
          'seller_vat',
          'رقم ضريبي البائع',
          'الرقم الضريبي',
          'الرقم الضريبي للبائع',
          'VAT No',
          'VAT Number',
        ],
        patterns: <RegExp>[
          RegExp(
            r'(?:الرقم\s*الضريبي(?:\s*للبائع)?|الضريبي\s*الرقم(?:\s*للبائع)?|رقم\s*ضريبي\s*البائع|VAT\s*(?:No\.?|Number))\s*[:\-]?\s*([0-9][0-9\\s]{9,30})',
            caseSensitive: false,
          ),
          RegExp(
            r'([0-9][0-9\\s]{9,30})\s*[:\-]?\s*(?:الرقم\s*الضريبي(?:\s*للبائع)?|الضريبي\s*الرقم(?:\s*للبائع)?|رقم\s*ضريبي\s*البائع|VAT\s*(?:No\.?|Number))',
            caseSensitive: false,
          ),
        ],
      );

      final customerNameDetected = pickFromFormOrText(
        keys: const <String>[
          'customer_name',
          'المشتري',
          'اسم المشتري',
          'اسم المشتري/العميل',
          'العميل',
          'Customer',
          'Buyer',
        ],
        patterns: <RegExp>[
          RegExp(
            r'(?:اسم\s*المشتري(?:\s*/\s*العميل)?|المشتري|العميل|Customer|Buyer)\s*[:\-]?\s*([^\n]{3,80})',
            caseSensitive: false,
          ),
        ],
      );

      final customerVatNumberDetected = pickFromFormOrText(
        keys: const <String>[
          'buyer_vat',
          'رقم ضريبي المشتري',
          'الرقم الضريبي للمشتري',
          'VAT No',
          'VAT Number',
        ],
        patterns: <RegExp>[
          RegExp(
            r'(?:الرقم\s*الضريبي\s*للمشتري|الضريبي\s*الرقم\s*للمشتري|رقم\s*ضريبي\s*المشتري|VAT\s*(?:No\.?|Number))\s*[:\-]?\s*([0-9][0-9\\s]{9,30})',
            caseSensitive: false,
          ),
          RegExp(
            r'([0-9][0-9\\s]{9,30})\s*[:\-]?\s*(?:الرقم\s*الضريبي\s*للمشتري|الضريبي\s*الرقم\s*للمشتري|رقم\s*ضريبي\s*المشتري|VAT\s*(?:No\.?|Number))',
            caseSensitive: false,
          ),
        ],
      );

      final quantity = pickMoney(
        keys: const <String>[
          'quantity',
          'الكمية',
          'كمية',
          'ltrs',
          'liters',
          'litres',
        ],
        patterns: <RegExp>[
          RegExp(
            r'(?:الكمية|كمية|Quantity|Ltrs|Liters|Litres)\s*[:\-]?\s*([0-9][0-9.,]*)',
            caseSensitive: false,
          ),
        ],
      );

      final unitPriceBeforeVat = pickMoney(
        keys: const <String>[
          'unit_price',
          'سعر الوحدة',
          'سعر اللتر',
          'سعر لتر',
          'سعر',
          'Unit Price',
        ],
        patterns: <RegExp>[
          moneyPattern(r'سعر\s*الوحدة|سعر\s*اللتر|سعر\s*لتر|Unit\s*Price'),
        ],
      );

      final subtotalBeforeVat = pickMoney(
        keys: const <String>[
          'subtotal',
          'الإجمالي قبل الضريبة',
          'المجموع قبل الضريبة',
          'صافي',
          'Sub Total',
          'Subtotal',
        ],
        patterns: <RegExp>[
          moneyPattern(
            r'الإجمالي\s*قبل\s*الضريب[هة]|المجموع\s*قبل\s*الضريب[هة]|صافي|Subtotal|Sub\s*Total',
          ),
        ],
      );

      final vatAmount = pickMoney(
        keys: const <String>[
          'vat',
          'قيمة الضريبة',
          'ضريبة القيمة المضافة',
          'VAT Amount',
          'Tax',
        ],
        patterns: <RegExp>[
          moneyPattern(
            r'قيمة\s*الضريب[هة]|ضريب[هة]\s*القيم[هة]\s*المضاف[هة]|VAT\s*Amount|Tax',
          ),
        ],
      );

      final totalWithVat = pickMoney(
        keys: const <String>[
          'total',
          'الإجمالي بعد الضريبة',
          'الإجمالي شامل الضريبة',
          'الإجمالي',
          'Total',
          'Total Amount',
        ],
        patterns: <RegExp>[
          moneyPattern(
            r'الإجمالي\s*(?:بعد|شامل)\s*الضريب[هة]|الإجمالي|Total\s*(?:Amount)?',
          ),
        ],
      );

      final transportValueWithVat = pickMoney(
        keys: const <String>['transport', 'قيمة النقل', 'Delivery', 'Shipping'],
        patterns: <RegExp>[moneyPattern(r'قيمة\s*النقل|Shipping|Delivery')],
      );

      final subtotalBeforeVatFromTemplate = pickMoneyAround(
        r'الاجمالي\s*قبل\s*الضريب[هة]|الضريب[هة]\s*قبل\s*الاجمالي|المجموع\s*قبل\s*الضريب[هة]|total\s*price(?!.*including)',
      );
      final vatAmountFromTemplate = pickMoneyAround(
        r'ضريب[هة]\s*القيم[هة]\s*المضاف[هة]|المضاف[هة]\s*القيم[هة]\s*ضريب[هة]|vat\s*%?\s*15|vat',
      );
      final totalWithVatFromTemplate = pickMoneyAround(
        r'صافي\s*السعر\s*الاجمالي\s*شامل\s*ضريب[هة]\s*القيم[هة]\s*المضاف[هة]|صافي\s*السعر\s*شامل\s*الاجمالي|total\s*price\s*including\s*vat|including\s*vat|الاجمالي\s*شامل\s*الضريب[هة]',
      );

      String bestSection({
        required List<String> starts,
        required List<String> ends,
      }) {
        for (final start in starts) {
          for (final end in ends) {
            final section = sectionBetween(
              source: text,
              start: start,
              end: end,
            );
            if (section.trim().isNotEmpty) return section;
          }
        }
        return '';
      }

      final companySection = bestSection(
        starts: const <String>[
          'بيانات الشركة',
          'بيانات الشركه',
          'بيانات الشركات',
          'company data',
        ],
        ends: const <String>[
          'بيانات العميل',
          'بيانات العملاء',
          'بيانات العميل/المشتري',
          'customer data',
          'client data',
        ],
      );
      final customerSection = bestSection(
        starts: const <String>[
          'بيانات العميل',
          'بيانات العملاء',
          'بيانات العميل/المشتري',
          'customer data',
          'client data',
        ],
        ends: const <String>[
          'اسم المادة',
          'اسم الماده',
          'المادة',
          'الماده',
          'material',
          'des',
          'qty',
          'unit price',
        ],
      );

      String? companyField(String labelAlternatives) => firstMatch(
        RegExp(
          '(?:$labelAlternatives)\\s*[:\\-]?\\s*([^\\n]{2,140})',
          caseSensitive: false,
        ),
        companySection,
      );

      String? customerField(String labelAlternatives) => firstMatch(
        RegExp(
          '(?:$labelAlternatives)\\s*[:\\-]?\\s*([^\\n]{2,140})',
          caseSensitive: false,
        ),
        customerSection,
      );

      final sectionSupplierName = firstMatch(
        RegExp(
          r'(?:الاسم|name)\s*[:\-]?\s*([^\n]{2,80})',
          caseSensitive: false,
        ),
        companySection,
      );
      final sectionSupplierVat = firstMatch(
        RegExp(
          r'(?:الرقم\s*الضريبي|vat\s*(?:no\.?|number)?)\s*[:\-]?\s*([0-9][0-9\\s]{9,30})',
          caseSensitive: false,
        ),
        companySection,
      );
      final sectionCustomerName = firstMatch(
        RegExp(
          r'(?:الاسم|name)\s*[:\-]?\s*([^\n]{2,80})',
          caseSensitive: false,
        ),
        customerSection,
      );
      final sectionCustomerVat = firstMatch(
        RegExp(
          r'(?:الرقم\s*الضريبي|vat\s*(?:no\.?|number)?)\s*[:\-]?\s*([0-9][0-9\\s]{9,30})',
          caseSensitive: false,
        ),
        customerSection,
      );

      String? digitsOnly(String? raw) {
        final trimmed = (raw ?? '').trim();
        if (trimmed.isEmpty) return null;
        final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '').trim();
        return digits.isEmpty ? null : digits;
      }

      final supplierName = supplierNameDetected ?? sectionSupplierName;
      String? supplierVatNumber =
          digitsOnly(supplierVatNumberDetected) ??
          digitsOnly(sectionSupplierVat);
      final customerName = customerNameDetected ?? sectionCustomerName;
      String? customerVatNumber =
          digitsOnly(customerVatNumberDetected) ??
          digitsOnly(sectionCustomerVat);

      String? supplierAddress = companyField('العنوان|address');
      String? supplierPostalCode = digitsOnly(
        firstMatch(
          RegExp(
            r'(?:الرمز\s*البريدي|postal\s*code)\s*[:\-]?\s*([0-9][0-9\\s]{2,15})',
          ),
          companySection,
        ),
      );
      String? supplierBuildingNumber = digitsOnly(
        firstMatch(
          RegExp(
            r'(?:رقم\s*المبنى|building\s*(?:no\.?|number))\s*[:\-]?\s*([0-9][0-9\\s]{0,15})',
          ),
          companySection,
        ),
      );
      String? supplierCommercialNumber = digitsOnly(
        firstMatch(
          RegExp(
            r'(?:السجل\s*التجاري|commercial\s*(?:register|reg(?:istration)?))\s*[:\-]?\s*([0-9][0-9\\s]{5,30})',
          ),
          companySection,
        ),
      );

      String? customerAddress = customerField('العنوان|address');
      String? customerPostalCode = digitsOnly(
        firstMatch(
          RegExp(
            r'(?:الرمز\s*البريدي|postal\s*code)\s*[:\-]?\s*([0-9][0-9\\s]{2,15})',
          ),
          customerSection,
        ),
      );
      String? customerBuildingNumber = digitsOnly(
        firstMatch(
          RegExp(
            r'(?:رقم\s*المبنى|building\s*(?:no\.?|number))\s*[:\-]?\s*([0-9][0-9\\s]{0,15})',
          ),
          customerSection,
        ),
      );
      String? customerCommercialNumber = digitsOnly(
        firstMatch(
          RegExp(
            r'(?:السجل\s*التجاري|commercial\s*(?:register|reg(?:istration)?))\s*[:\-]?\s*([0-9][0-9\\s]{5,30})',
          ),
          customerSection,
        ),
      );

      List<String> numbersFrom(String source) {
        return RegExp(r'[0-9][0-9\\s]{2,30}')
            .allMatches(source)
            .map((match) => digitsOnly(match.group(0)))
            .whereType<String>()
            .toList();
      }

      String? firstByLength(List<String> items, int length) {
        for (final item in items) {
          if (item.length == length) return item;
        }
        return null;
      }

      final supplierNumbers = numbersFrom(companySection);
      final customerNumbers = numbersFrom(customerSection);

      final supplierVatFallback = firstByLength(supplierNumbers, 15);
      final customerVatFallback = firstByLength(customerNumbers, 15);

      final supplierCommercialFallback = firstByLength(
        supplierNumbers.where((n) => n.length == 10).toList(),
        10,
      );
      final customerCommercialFallback = firstByLength(
        customerNumbers.where((n) => n.length == 10).toList(),
        10,
      );

      final supplierPostalFallback = firstByLength(supplierNumbers, 5);
      final customerPostalFallback = firstByLength(customerNumbers, 5);

      final supplierBuildingFallback = firstByLength(supplierNumbers, 4);
      final customerBuildingFallback = firstByLength(customerNumbers, 4);

      // VAT numbers: some PDFs (like "نموذج الفواتير.pdf") extract Arabic labels
      // in presentation forms, which can break section parsing. As a fallback,
      // scan the whole document for 15-digit VAT numbers.
      final globalVatNumbers = RegExp(r'(^|[^0-9])([0-9]{15})(?=[^0-9]|$)')
          .allMatches(textFlat)
          .map((m) => m.group(2))
          .whereType<String>()
          .toList();
      if (supplierVatNumber == null && globalVatNumbers.isNotEmpty) {
        supplierVatNumber = globalVatNumbers.first;
      }
      if (customerVatNumber == null && globalVatNumbers.length >= 2) {
        customerVatNumber = globalVatNumbers[1];
      }

      // Some templates put both labels (transport order + Aramco reference) on
      // one line, and both numbers on the next line in the same order.
      String? transportOrderNumberFromLines;
      String? referenceNumberFromLines;
      for (int i = 0; i < normalizedLines.length; i++) {
        final line = normalizedLines[i];
        final hasTransport =
            line.contains('نقل') &&
            (line.contains('امر') || line.contains('أمر'));
        final hasAramco = line.contains('ارامكو') || line.contains('ارمكو');
        final hasRef = line.contains('مرجع') && line.contains('رقم');
        if (!(hasTransport && hasAramco && hasRef)) continue;

        final combined = i + 1 < normalizedLines.length
            ? '$line ${normalizedLines[i + 1]}'
            : line;
        final numbers = RegExp(r'\b[0-9]{6,}\b')
            .allMatches(combined)
            .map((m) => m.group(0))
            .whereType<String>()
            .toList();
        if (numbers.length >= 2) {
          transportOrderNumberFromLines ??= numbers[0];
          referenceNumberFromLines ??= numbers[1];
        }
      }

      if (transportOrderNumberFromLines == null ||
          referenceNumberFromLines == null) {
        final refIdx = textFlat.indexOf('مرجع');
        if (refIdx >= 0) {
          int start = refIdx - 160;
          if (start < 0) start = 0;
          int end = refIdx + 260;
          if (end > textFlat.length) end = textFlat.length;
          final window = textFlat.substring(start, end);
          final pair = RegExp(r'([0-9]{8,})\s+([0-9]{8,})').firstMatch(window);
          if (pair != null) {
            transportOrderNumberFromLines ??= pair.group(1);
            referenceNumberFromLines ??= pair.group(2);
          }
        }
      }

      final normalizedSupplierVat = supplierVatNumber ?? supplierVatFallback;
      final normalizedCustomerVat = customerVatNumber ?? customerVatFallback;
      supplierCommercialNumber ??= supplierCommercialFallback;
      customerCommercialNumber ??= customerCommercialFallback;
      supplierPostalCode ??= supplierPostalFallback;
      customerPostalCode ??= customerPostalFallback;
      supplierBuildingNumber ??= supplierBuildingFallback;
      customerBuildingNumber ??= customerBuildingFallback;

      final referenceNumber =
          referenceNumberFromLines ??
          firstMatch(
            RegExp(
              r'(?:رقم\\s*مرجع\\s*ارامكو|ارامكو\\s*مرجع\\s*رقم|مرجع\\s*رقم\\s*ارامكو|Aramco\\s*Ref(?:erence)?\\s*No\\.?)\\s*[:\\-]?\\s*([A-Za-z0-9-\\/_]+)',
              caseSensitive: false,
            ),
            text,
          );
      final transportOrderNumber =
          transportOrderNumberFromLines ??
          firstMatch(
            RegExp(
              r'(?:امر\\s*نقل\\s*رقم|رقم\\s*امر\\s*نقل|رقم\\s*نقل\\s*امر|Transport\\s*Order\\s*No\\.?)\\s*[:\\-]?\\s*([A-Za-z0-9-\\/_]+)',
              caseSensitive: false,
            ),
            text,
          );

      String? invoiceNumberFromLines;
      for (int i = 0; i < normalizedLines.length && i < 20; i++) {
        final line = normalizedLines[i];
        if (line.contains('الفاتورة') && line.contains('رقم')) {
          final combined = i + 1 < normalizedLines.length
              ? '$line ${normalizedLines[i + 1]}'
              : line;
          final match = RegExp(r'\b[0-9]{6,12}\b').firstMatch(combined);
          if (match != null) {
            invoiceNumberFromLines = match.group(0);
            break;
          }
        }
      }
      invoiceNumberFromLines ??= (() {
        for (int i = 0; i < normalizedLines.length && i < 12; i++) {
          final line = normalizedLines[i];
          if (line.contains('/') || line.contains('-'))
            continue; // ignore dates
          final match = RegExp(r'\b[0-9]{6,8}\b').firstMatch(line);
          if (match != null) return match.group(0);
        }
        return null;
      })();

      String? safeInvoiceNumber = invoiceNumber;
      if (safeInvoiceNumber != null &&
          !RegExp(r'[0-9]').hasMatch(safeInvoiceNumber)) {
        safeInvoiceNumber = null;
      }

      final resolvedInvoiceNumber =
          invoiceNumberFromLines ??
          safeInvoiceNumber ??
          referenceNumber ??
          transportOrderNumber;

      final itemDescription = firstMatch(
        RegExp(
          r'(?:DES|اسم\s*المادة)\s*[:\-]?\s*([^\n]{2,80})',
          caseSensitive: false,
        ),
        text,
      );
      final fromLocation = firstMatch(
        RegExp(
          r'(?:From|موقع\s*التحميل)\s*[:\-]?\s*([^\n]{2,60})',
          caseSensitive: false,
        ),
        text,
      );
      final toLocation = firstMatch(
        RegExp(
          r'(?:To|موقع\s*التنزيل)\s*[:\-]?\s*([^\n]{2,60})',
          caseSensitive: false,
        ),
        text,
      );

      String? sanitizeField(
        String? value, {
        required int maxLen,
        required RegExp reject,
      }) {
        final trimmed = (value ?? '').trim();
        if (trimmed.isEmpty || trimmed.length > maxLen) return null;
        if (reject.hasMatch(trimmed)) return null;
        return trimmed;
      }

      final sanitizedItemDescription = sanitizeField(
        itemDescription,
        maxLen: 80,
        reject: RegExp(
          r'(?:^des$|des|qty|unit\s*price|vat|total\s*price|including\s*vat|اسم\s*الماد[هة]|المادة\s*اسم|ةداملا\s*مسا)',
          caseSensitive: false,
        ),
      );
      final sanitizedFromLocation = sanitizeField(
        fromLocation,
        maxLen: 40,
        reject: RegExp(
          r'(?:from|qty|unit\s*price|vat|total\s*price|including\s*vat|موقع|الكمية|الضريبة|الاجمالي)',
          caseSensitive: false,
        ),
      );
      final sanitizedToLocation = sanitizeField(
        toLocation,
        maxLen: 40,
        reject: RegExp(
          r'(?:to|qty|unit\s*price|vat|total\s*price|including\s*vat|موقع|الكمية|الضريبة|الاجمالي|price)',
          caseSensitive: false,
        ),
      );

      double? derivedSubtotalBeforeVat =
          subtotalBeforeVat ?? subtotalBeforeVatFromTemplate;
      double? derivedVatAmount = vatAmount ?? vatAmountFromTemplate;
      double? derivedTotalWithVat = totalWithVat ?? totalWithVatFromTemplate;
      double? derivedQuantity = quantity;
      double? derivedUnitPriceBeforeVat = unitPriceBeforeVat;

      String? resolvedInvoiceDateText = invoiceDateText;
      if (resolvedInvoiceDateText == null) {
        final datePattern = RegExp(
          r'\b[0-9]{4}[/-][0-9]{1,2}[/-][0-9]{1,2}\b|\b[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}\b',
        );
        for (int i = 0; i < normalizedLines.length; i++) {
          final line = normalizedLines[i];
          if (!(line.contains('الفاتورة') && line.contains('تاريخ'))) continue;
          for (final j in <int>[i - 2, i - 1, i, i + 1, i + 2]) {
            if (j < 0 || j >= normalizedLines.length) continue;
            final match = datePattern.firstMatch(normalizedLines[j]);
            if (match != null) {
              resolvedInvoiceDateText = match.group(0);
              break;
            }
          }
          if (resolvedInvoiceDateText != null) break;
        }
        resolvedInvoiceDateText ??= datePattern.firstMatch(textFlat)?.group(0);
      }

      if (derivedSubtotalBeforeVat == null ||
          derivedVatAmount == null ||
          derivedTotalWithVat == null) {
        final candidates =
            RegExp(r'([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]+|[0-9]+\.[0-9]+)')
                .allMatches(textFlat)
                .map((m) => _parseMoney(m.group(1)))
                .whereType<double>()
                .where((v) => v > 0 && v < 1000000000)
                .toSet()
                .toList()
              ..sort();

        if (candidates.length >= 2) {
          const vatRate = 0.15;
          double? inferredSubtotal;
          double? inferredVat;
          double? inferredTotal;

          for (
            int t = candidates.length - 1;
            t >= 0 && inferredTotal == null;
            t--
          ) {
            final totalCandidate = candidates[t];
            for (int s = t - 1; s >= 0; s--) {
              final subtotalCandidate = candidates[s];
              if (subtotalCandidate <= 0 || subtotalCandidate >= totalCandidate)
                continue;
              final vatCandidate = totalCandidate - subtotalCandidate;
              final rate = vatCandidate / subtotalCandidate;
              if ((rate - vatRate).abs() <= 0.03) {
                inferredSubtotal = subtotalCandidate;
                inferredVat = vatCandidate;
                inferredTotal = totalCandidate;
                break;
              }
            }
          }

          inferredTotal ??= candidates.isNotEmpty ? candidates.last : null;
          inferredSubtotal ??= candidates.length >= 2
              ? candidates[candidates.length - 2]
              : null;
          inferredVat ??=
              (inferredTotal != null &&
                  inferredSubtotal != null &&
                  inferredTotal > inferredSubtotal)
              ? (inferredTotal - inferredSubtotal)
              : null;

          derivedSubtotalBeforeVat ??= inferredSubtotal;
          derivedVatAmount ??= inferredVat;
          derivedTotalWithVat ??= inferredTotal;
        }
      }

      if (derivedSubtotalBeforeVat == null &&
          derivedQuantity != null &&
          derivedUnitPriceBeforeVat != null &&
          derivedQuantity > 0) {
        derivedSubtotalBeforeVat = derivedQuantity * derivedUnitPriceBeforeVat;
      }

      if (derivedVatAmount == null &&
          derivedTotalWithVat != null &&
          derivedSubtotalBeforeVat != null) {
        derivedVatAmount = derivedTotalWithVat - derivedSubtotalBeforeVat;
      }

      if (derivedTotalWithVat == null &&
          derivedSubtotalBeforeVat != null &&
          derivedVatAmount != null) {
        derivedTotalWithVat = derivedSubtotalBeforeVat + derivedVatAmount;
      }

      if (derivedSubtotalBeforeVat == null &&
          derivedTotalWithVat != null &&
          derivedVatAmount != null) {
        derivedSubtotalBeforeVat = derivedTotalWithVat - derivedVatAmount;
      }

      if (derivedUnitPriceBeforeVat == null &&
          derivedSubtotalBeforeVat != null &&
          derivedQuantity != null &&
          derivedQuantity > 0) {
        derivedUnitPriceBeforeVat = derivedSubtotalBeforeVat / derivedQuantity;
      }

      if (derivedQuantity == null &&
          derivedSubtotalBeforeVat != null &&
          derivedUnitPriceBeforeVat != null &&
          derivedUnitPriceBeforeVat > 0) {
        derivedQuantity = derivedSubtotalBeforeVat / derivedUnitPriceBeforeVat;
      }

      return TaxInvoiceData(
        invoiceNumber: resolvedInvoiceNumber,
        invoiceDateText: resolvedInvoiceDateText,
        supplierName: supplierName,
        supplierVatNumber: normalizedSupplierVat,
        supplierAddress: supplierAddress,
        supplierPostalCode: supplierPostalCode,
        supplierBuildingNumber: supplierBuildingNumber,
        supplierCommercialNumber: supplierCommercialNumber,
        customerName: customerName,
        customerVatNumber: normalizedCustomerVat,
        customerAddress: customerAddress,
        customerPostalCode: customerPostalCode,
        customerBuildingNumber: customerBuildingNumber,
        customerCommercialNumber: customerCommercialNumber,
        referenceNumber: referenceNumber,
        transportOrderNumber: transportOrderNumber,
        itemDescription: sanitizedItemDescription,
        fromLocation: sanitizedFromLocation,
        toLocation: sanitizedToLocation,
        quantity: derivedQuantity,
        unitPriceBeforeVat: derivedUnitPriceBeforeVat,
        subtotalBeforeVat: derivedSubtotalBeforeVat,
        vatAmount: derivedVatAmount,
        totalWithVat: derivedTotalWithVat,
        transportValueWithVat: transportValueWithVat,
      );
    } finally {
      document.dispose();
    }
  }

  static Map<String, String> _extractFormValues(PdfDocument document) {
    final result = <String, String>{};
    final form = document.form;
    if (form == null) return result;

    for (int i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      final name = (field.name ?? '').trim();
      if (name.isEmpty) continue;

      String? value;
      if (field is PdfTextBoxField) {
        value = field.text;
      } else if (field is PdfComboBoxField) {
        value = field.selectedValue;
      } else if (field is PdfListBoxField) {
        // ListBox may have multiple selections; use first if present.
        value = field.selectedValues.isNotEmpty
            ? field.selectedValues.first
            : null;
      } else if (field is PdfCheckBoxField) {
        value = field.isChecked ? 'true' : 'false';
      }

      final normalized = (value ?? '').trim();
      if (normalized.isNotEmpty) {
        result[name] = normalized;
      }
    }

    return result;
  }

  static String _normalize(String value) {
    final compat = nfkcArabicPresentationForms(value);
    final raw = compat
        .replaceAll(
          RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069\u200B]'),
          '',
        )
        .replaceAll('\u0640', '')
        .replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _toEnglishDigits(raw).toLowerCase();
  }

  static String _normalizeMultiline(String value) {
    final normalizedNewlines = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final compat = nfkcArabicPresentationForms(normalizedNewlines);
    final raw = compat
        .replaceAll(
          RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069\u200B]'),
          '',
        )
        .replaceAll('\u0640', '')
        .replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[ \t\f\v]+'), ' ')
        .replaceAll(RegExp(r'\n+'), '\n')
        .trim();
    return _toEnglishDigits(raw).toLowerCase();
  }

  static String _toEnglishDigits(String value) {
    const map = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };
    var out = value;
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  static double? _parseMoney(String? raw) {
    if (raw == null) return null;
    var cleaned = _toEnglishDigits(
      raw,
    ).replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
    if (cleaned.isEmpty) return null;

    // Heuristic handling of thousands/decimal separators.
    final hasComma = cleaned.contains(',');
    final hasDot = cleaned.contains('.');
    if (hasComma && hasDot) {
      final lastComma = cleaned.lastIndexOf(',');
      final lastDot = cleaned.lastIndexOf('.');
      final decimalSep = lastComma > lastDot ? ',' : '.';
      final thousandSep = decimalSep == ',' ? '.' : ',';
      cleaned = cleaned.replaceAll(thousandSep, '');
      cleaned = cleaned.replaceAll(decimalSep, '.');
    } else if (hasComma) {
      final parts = cleaned.split(',');
      final last = parts.isNotEmpty ? parts.last : '';
      final allGroupsThree =
          parts.length > 1 &&
          parts.sublist(1).every((p) => p.length == 3) &&
          last.length == 3;
      if (allGroupsThree) {
        cleaned = parts.join('');
      } else {
        cleaned = cleaned.replaceAll(',', '.');
      }
    } else if (hasDot) {
      final parts = cleaned.split('.');
      final last = parts.isNotEmpty ? parts.last : '';
      final allGroupsThree =
          parts.length > 1 &&
          parts.sublist(1).every((p) => p.length == 3) &&
          last.length == 3;
      if (allGroupsThree) {
        cleaned = parts.join('');
      }
    }

    final value = double.tryParse(cleaned);
    if (value == null || !value.isFinite) return null;
    return value;
  }
}
