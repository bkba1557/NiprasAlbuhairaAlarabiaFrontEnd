import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/customer_treasury_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class CustomerTreasuryBranchesScreen extends StatefulWidget {
  const CustomerTreasuryBranchesScreen({super.key});

  @override
  State<CustomerTreasuryBranchesScreen> createState() =>
      _CustomerTreasuryBranchesScreenState();
}

class _CustomerTreasuryBranchesScreenState
    extends State<CustomerTreasuryBranchesScreen> {
  bool _loading = false;
  bool _changed = false;
  String? _error;
  List<CustomerTreasuryBranch> _branches = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.loadToken();
      final uri =
          Uri.parse('${ApiEndpoints.baseUrl}/customer-treasury/branches');
      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الفروع');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final list = decoded is Map ? decoded['branches'] : decoded;
      final branches = (list as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) =>
              CustomerTreasuryBranch.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() => _branches = branches);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBranchForm({CustomerTreasuryBranch? branch}) async {
    final nameController = TextEditingController(text: branch?.name ?? '');
    final codeController = TextEditingController(text: branch?.code ?? '');
    var isActive = branch?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(branch == null ? 'إضافة فرع' : 'تعديل الفرع'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم الفرع',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: 'كود الفرع (اختياري)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('فعال'),
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final code = codeController.text.trim();
                    if (name.isEmpty) return;

                    Navigator.pop(dialogContext, true);
                    await _saveBranch(
                      branchId: branch?.id,
                      name: name,
                      code: code,
                      isActive: isActive,
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    codeController.dispose();

    if (result != true) return;
  }

  Future<void> _saveBranch({
    required String? branchId,
    required String name,
    required String code,
    required bool isActive,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = branchId == null || branchId.isEmpty
          ? Uri.parse('${ApiEndpoints.baseUrl}/customer-treasury/branches')
          : Uri.parse(
              '${ApiEndpoints.baseUrl}/customer-treasury/branches/$branchId',
            );

      final body = json.encode({
        'name': name,
        'code': code,
        'isActive': isActive,
      });

      final response = branchId == null || branchId.isEmpty
          ? await http.post(uri, headers: ApiService.headers, body: body)
          : await http.put(uri, headers: ApiService.headers, body: body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('فشل حفظ الفرع');
      }

      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'حدث خطأ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _close() {
    Navigator.pop(context, _changed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة فروع الخزينة'),
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _close,
        ),
        actions: [
          IconButton(
            tooltip: 'إضافة فرع',
            onPressed: _loading ? null : () => _openBranchForm(),
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _branches.isEmpty
                        ? Center(
                            child: AppSurfaceCard(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.account_tree_outlined,
                                    size: 54,
                                    color: AppColors.primaryBlue,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'لا توجد فروع بعد.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _openBranchForm(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('إضافة أول فرع'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              if (_error != null) ...[
                                AppSurfaceCard(
                                  color: AppColors.errorRed.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: Border.all(
                                    color: AppColors.errorRed.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppColors.errorRed,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _branches.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final branch = _branches[index];
                                    final activeColor = branch.isActive
                                        ? AppColors.successGreen
                                        : AppColors.warningOrange;

                                    return AppSurfaceCard(
                                      onTap: () => _openBranchForm(
                                        branch: branch,
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppColors.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Icon(
                                              Icons.account_balance_wallet_outlined,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  branch.code.trim().isEmpty
                                                      ? branch.name
                                                      : '${branch.name} (${branch.code})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color:
                                                        AppColors.primaryBlue,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  branch.isActive
                                                      ? 'فعال'
                                                      : 'غير فعال',
                                                  style: TextStyle(
                                                    color: activeColor,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(
                                            Icons.chevron_left,
                                            color: Colors.grey.shade600,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
