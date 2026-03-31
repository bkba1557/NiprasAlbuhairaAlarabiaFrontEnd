import 'package:flutter/material.dart';
import 'package:order_tracker/screens/archive/archive_document_details_screen.dart';
import 'package:order_tracker/screens/archive/archive_document_form_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_list_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_shared.dart';
import 'package:order_tracker/utils/constants.dart';

class ArchiveDocumentsScreen extends StatefulWidget {
  const ArchiveDocumentsScreen({super.key});

  @override
  State<ArchiveDocumentsScreen> createState() => _ArchiveDocumentsScreenState();
}

class _ArchiveDocumentsScreenState extends State<ArchiveDocumentsScreen> {
  bool _loading = false;
  String? _selectedDepartmentName;
  List<Map<String, dynamic>> _recent = const [];
  Map<String, dynamic> _metadata = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> get _departments =>
      ((_metadata['departments'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();

  List<Map<String, dynamic>> get _archives =>
      ((_metadata['archives'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final documents = await ArchiveDocumentsRepository.list(
        limit: 120,
        departmentName: _selectedDepartmentName,
      );
      final metadata = await ArchiveDocumentsRepository.metadata(
        departmentName: _selectedDepartmentName,
      );
      if (!mounted) return;
      setState(() {
        _recent = documents;
        _metadata = metadata;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل بيانات الأرشفة: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int _countByType(String type) =>
      _recent.where((item) => '${item['documentType']}' == type).length;

  int _countByStatus(String status) =>
      _recent.where((item) => '${item['status']}' == status).length;

  void _openCreate(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveDocumentFormScreen(
          initialType: type,
          initialDepartmentName: _selectedDepartmentName,
        ),
      ),
    ).then((_) => _load());
  }

  void _openList({
    String? archiveKey,
    String? documentType,
    String? departmentName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveDocumentsListScreen(
          initialArchiveKey: archiveKey,
          initialDocumentType: documentType,
          initialDepartmentName: departmentName ?? _selectedDepartmentName,
        ),
      ),
    ).then((_) => _load());
  }

  void _openDetails(Map<String, dynamic> document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveDocumentDetailsScreen(
          documentId: '${document['_id']}',
          initialDocument: document,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final incomingCount = _countByType('incoming');
    final outgoingCount = _countByType('outgoing');
    final transactionCount = _countByType('transaction');
    final handoverPendingCount = _countByStatus('handover_pending');
    final pagePadding = ArchiveDocsLayout.pagePadding(context);
    final maxWidth = ArchiveDocsLayout.maxContentWidth(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('الأرشيف والدوسيهات'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding,
              children: [
                _buildResponsiveSummaryHero(
                  incomingCount: incomingCount,
                  outgoingCount: outgoingCount,
                  transactionCount: transactionCount,
                  handoverPendingCount: handoverPendingCount,
                ),
                const SizedBox(height: 16),
                _buildResponsiveDepartmentBar(),
                const SizedBox(height: 16),
                _buildResponsiveArchivesSection(),
                const SizedBox(height: 16),
                _buildResponsiveRecentSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHero({
    required int incomingCount,
    required int outgoingCount,
    required int transactionCount,
    required int handoverPendingCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.appBarGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.appBarWaterDeep.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'لوحة الأرشفة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedDepartmentName == null
                ? 'إدارة الأرشيفات والدوسيهات والمعاملات بين الأقسام والموظفين'
                : 'القسم الحالي: $_selectedDepartmentName',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryTile('وارد', incomingCount, Icons.move_to_inbox_outlined),
              _summaryTile('صادر', outgoingCount, Icons.outbox_outlined),
              _summaryTile(
                'معاملات',
                transactionCount,
                Icons.description_outlined,
              ),
              _summaryTile(
                'بانتظار الاستلام',
                handoverPendingCount,
                Icons.mark_email_unread_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _openCreate('incoming'),
                icon: const Icon(Icons.add_to_drive_outlined),
                label: const Text('إضافة وارد'),
              ),
              FilledButton.icon(
                onPressed: () => _openCreate('outgoing'),
                icon: const Icon(Icons.outbox_outlined),
                label: const Text('إضافة صادر'),
              ),
              FilledButton.icon(
                onPressed: () => _openCreate('transaction'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('إضافة معاملة'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openList(),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('كل السجلات'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String title, int count, IconData icon) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentBar() {
    final departments = _departments;
    if (departments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'الأقسام',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('كل الأقسام'),
                  selected: _selectedDepartmentName == null,
                  onSelected: (_) {
                    setState(() => _selectedDepartmentName = null);
                    _load();
                  },
                ),
                ...departments.map(
                  (department) => ChoiceChip(
                    label: Text(department),
                    selected: _selectedDepartmentName == department,
                    onSelected: (_) {
                      setState(() => _selectedDepartmentName = department);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivesSection({required bool isWide}) {
    if (_loading && _archives.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_archives.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('لا توجد أرشيفات مسجلة حتى الآن'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'الأرشيفات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openList(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('عرض السجلات'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _archives.map((archive) {
            final officeNames =
                ((archive['officeNames'] as List?) ?? const [])
                    .map((item) => item.toString())
                    .where((item) => item.trim().isNotEmpty)
                    .toList();
            return SizedBox(
              width: isWide ? 360 : double.infinity,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openList(
                    archiveKey: archive['archiveKey']?.toString(),
                    departmentName: archive['departmentName']?.toString(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.appBarWaterBright.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.folder_copy_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    archive['archiveName']?.toString() ?? '-',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    archive['departmentName']?.toString().isNotEmpty ==
                                            true
                                        ? archive['departmentName'].toString()
                                        : 'بدون قسم',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _miniStat(
                              'سجلات',
                              archive['documentsCount']?.toString() ?? '0',
                            ),
                            _miniStat(
                              'دوسيهات',
                              archive['dossiersCount']?.toString() ?? '0',
                            ),
                            _miniStat(
                              'وارد',
                              archive['incomingCount']?.toString() ?? '0',
                            ),
                            _miniStat(
                              'صادر',
                              archive['outgoingCount']?.toString() ?? '0',
                            ),
                            _miniStat(
                              'معاملات',
                              archive['transactionCount']?.toString() ?? '0',
                            ),
                          ],
                        ),
                        if (officeNames.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'المكاتب: ${officeNames.join('، ')}',
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text('$label: $value'),
    );
  }

  Widget _buildRecentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'آخر المعاملات',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openList(),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && _recent.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recent.isEmpty)
              const Text('لا توجد سجلات أرشفة بعد')
            else
              ..._recent.take(8).map((document) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.appBarWaterBright.withOpacity(0.12),
                    child: Icon(
                      document['documentType'] == 'outgoing'
                          ? Icons.outbox_outlined
                          : document['documentType'] == 'transaction'
                              ? Icons.description_outlined
                              : Icons.move_to_inbox_outlined,
                    ),
                  ),
                  title: Text(
                    '${document['documentNumber'] ?? '-'} - ${document['subject'] ?? 'بدون موضوع'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${ArchiveDocsUi.typeWithClassLabel(document)} | الدوسيه: ${ArchiveDocsUi.dossierLabel(document)} | مع: ${document['currentHolderName'] ?? '-'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    onPressed: () => _openDetails(document),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  onTap: () => _openDetails(document),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveSummaryHero({
    required int incomingCount,
    required int outgoingCount,
    required int transactionCount,
    required int handoverPendingCount,
  }) {
    final isPhone = ArchiveDocsLayout.isPhone(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final statsPerRow = width >= 960 ? 4 : width >= 560 ? 2 : 1;
        final statsWidth = statsPerRow == 1
            ? width
            : (width - (12 * (statsPerRow - 1))) / statsPerRow;
        final actionFullWidth = width < 640;

        return Container(
          padding: EdgeInsets.all(isPhone ? 16 : 22),
          decoration: BoxDecoration(
            gradient: AppColors.appBarGradient,
            borderRadius: ArchiveDocsLayout.cardRadius(context),
            boxShadow: [
              BoxShadow(
                color: AppColors.appBarWaterDeep.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لوحة الأرشفة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isPhone ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedDepartmentName == null
                              ? 'إدارة الأرشيفات والدوسيهات والمعاملات بين الأقسام والموظفين من شاشة واحدة واضحة وسريعة.'
                              : 'القسم الحالي: $_selectedDepartmentName',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: isPhone ? 13 : 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isPhone) ...[
                    const SizedBox(width: 20),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: const Icon(
                        Icons.folder_copy_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: statsWidth,
                    child: _buildCompactSummaryTile(
                      title: 'وارد',
                      count: incomingCount,
                      icon: Icons.move_to_inbox_outlined,
                    ),
                  ),
                  SizedBox(
                    width: statsWidth,
                    child: _buildCompactSummaryTile(
                      title: 'صادر',
                      count: outgoingCount,
                      icon: Icons.outbox_outlined,
                    ),
                  ),
                  SizedBox(
                    width: statsWidth,
                    child: _buildCompactSummaryTile(
                      title: 'معاملات',
                      count: transactionCount,
                      icon: Icons.description_outlined,
                    ),
                  ),
                  SizedBox(
                    width: statsWidth,
                    child: _buildCompactSummaryTile(
                      title: 'بانتظار الاستلام',
                      count: handoverPendingCount,
                      icon: Icons.mark_email_unread_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildHeroAction(
                    label: 'إضافة وارد',
                    icon: Icons.add_to_drive_outlined,
                    width: actionFullWidth ? width : null,
                    onPressed: () => _openCreate('incoming'),
                  ),
                  _buildHeroAction(
                    label: 'إضافة صادر',
                    icon: Icons.outbox_outlined,
                    width: actionFullWidth ? width : null,
                    onPressed: () => _openCreate('outgoing'),
                  ),
                  _buildHeroAction(
                    label: 'إضافة معاملة',
                    icon: Icons.description_outlined,
                    width: actionFullWidth ? width : null,
                    onPressed: () => _openCreate('transaction'),
                  ),
                  SizedBox(
                    width: actionFullWidth ? width : null,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.24)),
                        padding: EdgeInsets.symmetric(
                          horizontal: isPhone ? 14 : 18,
                          vertical: isPhone ? 14 : 16,
                        ),
                      ),
                      onPressed: () => _openList(),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('كل السجلات'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    double? width,
  }) {
    final isPhone = ArchiveDocsLayout.isPhone(context);
    return SizedBox(
      width: width,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryBlue,
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 14 : 18,
            vertical: isPhone ? 14 : 16,
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  Widget _buildCompactSummaryTile({
    required String title,
    required int count,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: ArchiveDocsLayout.isPhone(context) ? 13 : 14,
                  ),
                ),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveDepartmentBar() {
    final departments = _departments;
    if (departments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: ArchiveDocsLayout.cardRadius(context),
        side: BorderSide(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(ArchiveDocsLayout.isPhone(context) ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.appBarWaterBright.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.account_tree_outlined),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'الأقسام',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('كل الأقسام'),
                  selected: _selectedDepartmentName == null,
                  onSelected: (_) {
                    setState(() => _selectedDepartmentName = null);
                    _load();
                  },
                ),
                ...departments.map(
                  (department) => ChoiceChip(
                    label: Text(department),
                    selected: _selectedDepartmentName == department,
                    onSelected: (_) {
                      setState(() => _selectedDepartmentName = department);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveArchivesSection() {
    if (_loading && _archives.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_archives.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('لا توجد أرشيفات مسجلة حتى الآن'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'الأرشيفات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openList(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('عرض السجلات'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1180 ? 3 : width >= 720 ? 2 : 1;
            final itemWidth = columns == 1
                ? width
                : (width - (12 * (columns - 1))) / columns;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _archives.map((archive) {
                final officeNames =
                    ((archive['officeNames'] as List?) ?? const [])
                        .map((item) => item.toString())
                        .where((item) => item.trim().isNotEmpty)
                        .toList();
                return SizedBox(
                  width: itemWidth,
                  child: Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: ArchiveDocsLayout.cardRadius(context),
                      side: BorderSide(color: Colors.blueGrey.withOpacity(0.08)),
                    ),
                    child: InkWell(
                      onTap: () => _openList(
                        archiveKey: archive['archiveKey']?.toString(),
                        departmentName: archive['departmentName']?.toString(),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(
                          ArchiveDocsLayout.isPhone(context) ? 14 : 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.appBarWaterBright.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.folder_copy_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        archive['archiveName']?.toString() ?? '-',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        archive['departmentName']?.toString().isNotEmpty ==
                                                true
                                            ? archive['departmentName'].toString()
                                            : 'بدون قسم',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_left_rounded),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _miniStat(
                                  'سجلات',
                                  archive['documentsCount']?.toString() ?? '0',
                                ),
                                _miniStat(
                                  'دوسيهات',
                                  archive['dossiersCount']?.toString() ?? '0',
                                ),
                                _miniStat(
                                  'وارد',
                                  archive['incomingCount']?.toString() ?? '0',
                                ),
                                _miniStat(
                                  'صادر',
                                  archive['outgoingCount']?.toString() ?? '0',
                                ),
                                _miniStat(
                                  'معاملات',
                                  archive['transactionCount']?.toString() ?? '0',
                                ),
                              ],
                            ),
                            if (officeNames.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'المكاتب: ${officeNames.join('، ')}',
                                style: TextStyle(color: Colors.grey.shade800),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildResponsiveRecentSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: ArchiveDocsLayout.cardRadius(context),
        side: BorderSide(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(ArchiveDocsLayout.isPhone(context) ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'آخر المعاملات',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openList(),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && _recent.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recent.isEmpty)
              const Text('لا توجد سجلات أرشفة بعد')
            else
              ..._recent.take(8).map(_buildResponsiveRecentItem),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveRecentItem(Map<String, dynamic> document) {
    final isPhone = ArchiveDocsLayout.isPhone(context);
    final icon = document['documentType'] == 'outgoing'
        ? Icons.outbox_outlined
        : document['documentType'] == 'transaction'
            ? Icons.description_outlined
            : Icons.move_to_inbox_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetails(document),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: isPhone
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.appBarWaterBright.withOpacity(0.12),
                          child: Icon(icon),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${document['documentNumber'] ?? '-'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openDetails(document),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      document['subject']?.toString().isNotEmpty == true
                          ? document['subject'].toString()
                          : 'بدون موضوع',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ArchiveDocsUi.typeWithClassLabel(document)} | الدوسيه: ${ArchiveDocsUi.dossierLabel(document)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'مع: ${document['currentHolderName'] ?? '-'}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.appBarWaterBright.withOpacity(0.12),
                      child: Icon(icon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${document['documentNumber'] ?? '-'} - ${document['subject'] ?? 'بدون موضوع'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ArchiveDocsUi.typeWithClassLabel(document)} | الدوسيه: ${ArchiveDocsUi.dossierLabel(document)} | مع: ${document['currentHolderName'] ?? '-'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openDetails(document),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('التفاصيل'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
