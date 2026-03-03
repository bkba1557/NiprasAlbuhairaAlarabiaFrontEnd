import 'package:flutter/material.dart';
import 'package:order_tracker/models/supplier_model.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/attachment_item.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class SupplierDetailsScreen extends StatefulWidget {
  final String supplierId;
  final Supplier? supplier;

  const SupplierDetailsScreen({
    super.key,
    required this.supplierId,
    this.supplier,
  });

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen> {
  int _selectedTab = 0;
  String get _effectiveSupplierId =>
      widget.supplier?.id ?? widget.supplierId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSupplierDetails();
    });
  }

  Future<void> _loadSupplierDetails() async {
    if (_effectiveSupplierId.isEmpty) {
      return;
    }
    await Provider.of<SupplierProvider>(
      context,
      listen: false,
    ).fetchSupplierById(_effectiveSupplierId);
  }

  @override
  Widget build(BuildContext context) {
    final supplierProvider = Provider.of<SupplierProvider>(context);
    final supplier = supplierProvider.selectedSupplier ?? widget.supplier;

    if (supplierProvider.isLoading && supplier == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (supplier == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المورد')),
        body: const Center(child: Text('المورد غير موجود')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(supplier.name),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.supplierForm,
                  arguments: supplier,
                );
              },
              icon: const Icon(Icons.edit),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteDialog();
                }
              },
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(text: 'التفاصيل'),
              Tab(text: 'الطلبات'),
              Tab(text: 'سجل الحركات'),
            ],
            onTap: (index) {
              setState(() {
                _selectedTab = index;
              });
            },
          ),
        ),
        body: TabBarView(
          children: [
            // Details Tab
            _buildDetailsTab(supplier),
            // Orders Tab
            _buildOrdersTab(),
            // Activities Tab
            _buildActivitiesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(Supplier supplier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Supplier Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ملخص المورد',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: supplier.isActive
                                  ? AppColors.successGreen.withOpacity(0.1)
                                  : AppColors.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: supplier.isActive
                                    ? AppColors.successGreen
                                    : AppColors.errorRed,
                              ),
                            ),
                            child: Text(
                              supplier.isActive ? 'نشط' : 'غير نشط',
                              style: TextStyle(
                                color: supplier.isActive
                                    ? AppColors.successGreen
                                    : AppColors.errorRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getSupplierTypeColor(
                                supplier.supplierType,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getSupplierTypeColor(
                                  supplier.supplierType,
                                ),
                              ),
                            ),
                            child: Text(
                              supplier.supplierType,
                              style: TextStyle(
                                color: _getSupplierTypeColor(
                                  supplier.supplierType,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Rating
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return Icon(
                              index < supplier.rating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 32,
                              color: AppColors.warningOrange,
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${supplier.rating.toStringAsFixed(1)} / 5.0',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Contact Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معلومات الاتصال',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('الشركة', supplier.company),
                  _buildInfoRow('جهة الاتصال', supplier.contactPerson),
                  if (supplier.email != null)
                    _buildInfoRow('البريد الإلكتروني', supplier.email!),
                  _buildInfoRow('الهاتف', supplier.phone),
                  if (supplier.secondaryPhone != null)
                    _buildInfoRow('هاتف احتياطي', supplier.secondaryPhone!),
                  if (supplier.address != null)
                    _buildInfoRow('العنوان', supplier.address!),
                  if (supplier.city != null)
                    _buildInfoRow('المدينة', supplier.city!),
                  if (supplier.country != null)
                    _buildInfoRow('البلد', supplier.country!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Financial Information
          if (supplier.taxNumber != null || supplier.bankName != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المعلومات المالية',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (supplier.taxNumber != null)
                      _buildInfoRow('الرقم الضريبي', supplier.taxNumber!),
                    if (supplier.commercialNumber != null)
                      _buildInfoRow(
                        'السجل التجاري',
                        supplier.commercialNumber!,
                      ),
                    if (supplier.bankName != null)
                      _buildInfoRow('اسم البنك', supplier.bankName!),
                    if (supplier.bankAccountNumber != null)
                      _buildInfoRow('رقم الحساب', supplier.bankAccountNumber!),
                    if (supplier.bankAccountName != null)
                      _buildInfoRow('اسم الحساب', supplier.bankAccountName!),
                    if (supplier.iban != null)
                      _buildInfoRow('رقم الآيبان', supplier.iban!),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Contract Information
          if (supplier.contractStartDate != null ||
              supplier.contractEndDate != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معلومات العقد',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (supplier.contractStartDate != null)
                      _buildInfoRow(
                        'بداية العقد',
                        DateFormat(
                          'yyyy/MM/dd',
                        ).format(supplier.contractStartDate!),
                      ),
                    if (supplier.contractEndDate != null)
                      _buildInfoRow(
                        'نهاية العقد',
                        DateFormat(
                          'yyyy/MM/dd',
                        ).format(supplier.contractEndDate!),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Documents
          if (supplier.documents.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المستندات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...supplier.documents.map(
                      (document) => AttachmentItem(
                        fileName: document.filename,
                        fileSize: 'موجود على السيرفر',
                        onDelete: () {
                          _deleteDocument(document.id);
                        },
                        canDelete: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Notes
          if (supplier.notes != null && supplier.notes!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملاحظات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      supplier.notes!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Created Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معلومات الإنشاء',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'تم الإنشاء بواسطة',
                    supplier.createdByName ?? 'غير معروف',
                  ),
                  _buildInfoRow(
                    'تاريخ الإنشاء',
                    DateFormat('yyyy/MM/dd HH:mm').format(supplier.createdAt),
                  ),
                  _buildInfoRow(
                    'آخر تحديث',
                    DateFormat('yyyy/MM/dd HH:mm').format(supplier.updatedAt),
                  ),
                  if (supplier.updatedByName != null)
                    _buildInfoRow('تم التحديث بواسطة', supplier.updatedByName!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    // TODO: Implement supplier orders list
    return const Center(child: Text('قائمة الطلبات قريباً...'));
  }

  Widget _buildActivitiesTab() {
    // TODO: Implement supplier activities list
    return const Center(child: Text('سجل الحركات قريباً...'));
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.darkGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSupplierTypeColor(String type) {
    switch (type) {
      case 'وقود':
        return AppColors.primaryBlue;
      case 'صيانة':
        return AppColors.warningOrange;
      case 'خدمات لوجستية':
        return AppColors.successGreen;
      case 'أخرى':
        return AppColors.mediumGray;
      default:
        return AppColors.lightGray;
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    final supplierProvider = Provider.of<SupplierProvider>(
      context,
      listen: false,
    );
    final success = await supplierProvider.deleteDocument(
      widget.supplierId,
      documentId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المستند بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المورد'),
        content: const Text(
          'هل أنت متأكد من حذف هذا المورد؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final supplierProvider = Provider.of<SupplierProvider>(
                context,
                listen: false,
              );
              final success = await supplierProvider.deleteSupplier(
                widget.supplierId,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف المورد بنجاح'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
