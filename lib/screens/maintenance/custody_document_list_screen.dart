import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/custody_document_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/custody_document_provider.dart';
import 'package:order_tracker/screens/maintenance/custody_document_design.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class CustodyDocumentListScreen extends StatefulWidget {
  const CustodyDocumentListScreen({super.key});

  @override
  State<CustodyDocumentListScreen> createState() =>
      _CustodyDocumentListScreenState();
}

class _CustodyDocumentListScreenState extends State<CustodyDocumentListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustodyDocumentProvider>().refreshDocuments();
    });
  }

  Future<void> _changeStatus(
    CustodyDocument document,
    CustodyDocumentStatus status,
  ) async {
    final provider = context.read<CustodyDocumentProvider>();
    final reviewer = context.read<AuthProvider>().user?.name ?? 'المالك';

    await provider.updateStatus(document.id, status, reviewedBy: reviewer);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == CustodyDocumentStatus.approved
              ? 'تم اعتماد السند'
              : 'تم رفض السند',
        ),
      ),
    );
  }

  Future<void> _onApprove(CustodyDocument document) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('اعتماد السند'),
            content: const Text('هل أنت متأكد من اعتماد سند العهدة هذا؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('موافقة'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await _changeStatus(document, CustodyDocumentStatus.approved);
    }
  }

  Future<void> _onReject(CustodyDocument document) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('رفض السند'),
            content: const Text(
              'سيتم رفض السند وإرساله مرة أخرى. هل تريد الاستمرار؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('رفض'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await _changeStatus(document, CustodyDocumentStatus.rejected);
    }
  }

  Future<void> _printWithLoading(CustodyDocument document) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppImages.logo,
                height: 72,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text('جاري تجهيز الطباعة...'),
            ],
          ),
        ),
      ),
    );

    try {
      await printCustodyDocument(document);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تنفيذ الطباعة: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _onFinanceDisburse(CustodyDocument document) async {
    await context
        .read<CustodyDocumentProvider>()
        .updateFinanceStatus(document.id, CustodyFinanceStatus.disbursed);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم صرف العهدة')),
    );
  }

  Future<void> _onFinanceReject(CustodyDocument document) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض صرف العهدة'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (reason == null || reason.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال سبب الرفض')),
      );
      return;
    }

    await context.read<CustodyDocumentProvider>().updateFinanceStatus(
          document.id,
          CustodyFinanceStatus.rejected,
          reason: reason.trim(),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رفض الصرف')),
    );
  }

  Future<void> _requestReturn(CustodyDocument document) async {
    final controller = TextEditingController(
      text: document.returnAmount > 0 ? document.returnAmount.toString() : '',
    );

    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب مردود عهدة'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'مبلغ المردود',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );

    if (input == null) return;
    final value = double.tryParse(input.trim());
    if (value == null || value < 0 || value > document.amount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ صالح لا يتجاوز قيمة السند'),
        ),
      );
      return;
    }

    await context.read<CustodyDocumentProvider>().requestReturn(
          document.id,
          value,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال طلب المردود')),
    );
  }

  Future<void> _onApproveReturn(CustodyDocument document) async {
    await context
        .read<CustodyDocumentProvider>()
        .updateReturnStatus(document.id, CustodyReturnStatus.approved);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم اعتماد مردود العهدة')),
    );
  }

  Future<void> _onRejectReturn(CustodyDocument document) async {
    await context
        .read<CustodyDocumentProvider>()
        .updateReturnStatus(document.id, CustodyReturnStatus.rejected);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رفض مردود العهدة')),
    );
  }

  Future<void> _onDelete(CustodyDocument document) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف السند'),
            content: const Text('هل أنت متأكد من حذف هذا السند؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await context.read<CustodyDocumentProvider>().deleteDocument(document.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف السند')),
    );
  }

  void _showDocumentPreview(CustodyDocument document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: SingleChildScrollView(
          child: CustodyDocumentPreview(document: document),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _printWithLoading(document);
            },
            child: const Text('طباعة'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await saveCustodyDocumentPdf(document);
            },
            child: const Text('حفظ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustodyDocumentProvider>();
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.role == 'owner';
    final isAdmin = auth.role == 'admin';
    final isAdminOrOwner = isOwner || isAdmin;
    final isFinanceManager = auth.role == 'sales_manager_statiun';
    final documents = provider.documents;
    final currency = NumberFormat.currency(
      locale: 'ar',
      symbol: 'ر.س',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سندات العهدة',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refreshDocuments(),
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : documents.isEmpty
            ? const Center(child: Text('لا توجد سندات حتى الآن'))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1000, // ✅ عرض مناسب للويب
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      document.documentTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      document.financeStatus ==
                                              CustodyFinanceStatus.disbursed
                                          ? 'تم صرف العهدة'
                                          : document.status.displayTitle,
                                      style: TextStyle(
                                        color: document.financeStatus ==
                                                CustodyFinanceStatus.disbursed
                                            ? Colors.green
                                            : document.status.badgeColor,
                                      ),
                                    ),
                                    backgroundColor: (document.financeStatus ==
                                                CustodyFinanceStatus.disbursed
                                            ? Colors.green
                                            : document.status.badgeColor)
                                        .withOpacity(0.2),
                                  ),
                                  if (document.returnStatus !=
                                      CustodyReturnStatus.none) ...[
                                    const SizedBox(width: 6),
                                    Chip(
                                      label: Text(
                                        document.returnStatus.displayTitle,
                                        style: TextStyle(
                                          color: document
                                              .returnStatus
                                              .badgeColor,
                                        ),
                                      ),
                                      backgroundColor: document
                                          .returnStatus
                                          .badgeColor
                                          .withOpacity(0.2),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'رقم: ${document.documentNumber} • جهة: ${document.destinationType} - ${document.destinationName}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'تاريخ الإنشاء: ${DateFormat('yyyy-MM-dd').format(document.documentDate)} • بواسطة: ${document.createdBy}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'المبلغ: ${currency.format(document.amount)}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'معتمد بواسطة: ${document.reviewedBy?.isNotEmpty == true ? document.reviewedBy : '-'}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              if (document.returnStatus !=
                                  CustodyReturnStatus.none) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'مردود: ${currency.format(document.returnAmount)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'حالة الصرف: ${document.financeStatus.displayTitle}',
                                style: TextStyle(
                                  color: document.financeStatus.badgeColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (document.financeStatus ==
                                  CustodyFinanceStatus.disbursed) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'تم صرف العهدة بواسطة: ${document.financeReviewedBy?.isNotEmpty == true ? document.financeReviewedBy : '-'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (document.financeStatus ==
                                      CustodyFinanceStatus.rejected &&
                                  document.financeRejectReason
                                          ?.trim()
                                          .isNotEmpty ==
                                      true) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'تم رفض الصرف بواسطة: ${document.financeReviewedBy?.isNotEmpty == true ? document.financeReviewedBy : '-'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'سبب رفض الصرف: ${document.financeRejectReason}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showDocumentPreview(document),
                                    icon: const Icon(Icons.remove_red_eye),
                                    label: const Text('معاينة'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _printWithLoading(document),
                                    icon: const Icon(Icons.print),
                                    label: const Text('طباعة'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        saveCustodyDocumentPdf(document),
                                    icon: const Icon(Icons.download),
                                    label: const Text('حفظ'),
                                  ),
                                  if (document.status ==
                                          CustodyDocumentStatus.approved &&
                                      document.amount > 0 &&
                                      document.returnStatus ==
                                          CustodyReturnStatus.none)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _requestReturn(document),
                                      icon: const Icon(Icons.undo),
                                      label: const Text('طلب مردود'),
                                    ),
                                  if (isOwner)
                                    OutlinedButton.icon(
                                      onPressed: () => _onDelete(document),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('حذف'),
                                    ),
                                ],
                              ),
                              if (isAdminOrOwner &&
                                  document.status ==
                                      CustodyDocumentStatus.pending)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _onApprove(document),
                                          child: const Text('اعتماد السند'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _onReject(document),
                                          child: const Text('رفض السند'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isFinanceManager &&
                                  document.status ==
                                      CustodyDocumentStatus.approved &&
                                  document.financeStatus ==
                                      CustodyFinanceStatus.none)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _onFinanceDisburse(document),
                                          child: const Text('صرف العهدة'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _onFinanceReject(document),
                                          child: const Text('رفض الصرف'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isOwner &&
                                  document.returnStatus ==
                                      CustodyReturnStatus.pending)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _onApproveReturn(document),
                                          child: const Text('اعتماد مردود العهدة'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _onRejectReturn(document),
                                          child: const Text('رفض مردود العهدة'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.custodyDocumentForm),
        tooltip: 'إضافة سند عهدة',
        child: const Icon(Icons.add),
      ),
    );
  }
}
