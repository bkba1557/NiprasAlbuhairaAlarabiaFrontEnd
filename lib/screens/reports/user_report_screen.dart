import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/providers/report_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/reports/export_options.dart';
import 'package:order_tracker/widgets/reports/report_filters.dart';
import 'package:order_tracker/widgets/reports/report_summary.dart';
import 'package:order_tracker/widgets/reports/user_activity_chart.dart';

class UserReportScreen extends StatefulWidget {
  static const routeName = '/reports/users';

  const UserReportScreen({super.key});

  @override
  State<UserReportScreen> createState() => _UserReportScreenState();
}

class _UserReportScreenState extends State<UserReportScreen> {
  final ReportProvider _reportProvider = ReportProvider();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic> _filters = {};
  List<dynamic> _users = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  String _viewMode = 'grid'; // 'grid', 'list', or 'chart'

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreData();
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _reportProvider.userReports(
        filters: _filters,
        page: 1,
      );

      setState(() {
        _users = response['users'] ?? [];
        _summary = response['summary'] ?? {};
        _isLoading = false;
        _page = 2;
        _hasMore = _users.length >= 20;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final response = await _reportProvider.userReports(
        filters: _filters,
        page: _page,
      );

      final newUsers = response['users'] ?? [];
      setState(() {
        _users.addAll(newUsers);
        _isLoading = false;
        _page++;
        _hasMore = newUsers.length >= 20;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applyFilters(Map<String, dynamic> filters) async {
    setState(() {
      _filters = filters;
      _page = 1;
      _hasMore = true;
    });
    await _loadInitialData();
  }

  Future<void> _exportToPDF() async {
    try {
      await _reportProvider.exportPDF(reportType: 'users', filters: _filters);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تصدير التقرير إلى PDF')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
    }
  }

  Future<void> _exportToExcel() async {
    try {
      await _reportProvider.exportExcel(reportType: 'users', filters: _filters);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير التقرير إلى Excel')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1200;
    final isMediumScreen = screenWidth >= 600;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير المستخدمين'),
        actions: [
          if (isLargeScreen) ...[
            _buildDesktopViewToggle(),
            const SizedBox(width: 8),
            _buildDesktopExportButton(),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterSheet,
            tooltip: 'فلاتر',
          ),
          if (!isLargeScreen) ...[
            _buildMobileViewToggle(isLargeScreen),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _showExportOptions,
              tooltip: 'تصدير',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Filters Summary
          if (_filters.isNotEmpty) _buildFiltersSummary(isLargeScreen),

          // Report Summary
          ReportSummary(
            title: 'ملخص تقرير المستخدمين',
            statistics: _summary,
            period: _filters,
          ),

          // Header Section
          _buildHeaderSection(isLargeScreen, isMediumScreen, isSmallScreen),

          // Users Content
          Expanded(
            child: _isLoading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          size: 64,
                          color: AppColors.mediumGray,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد بيانات للمستخدمين',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  )
                : _viewMode == 'chart'
                ? UserActivityChart(users: _users, isLargeScreen: isLargeScreen)
                : _buildUsersView(isLargeScreen, isMediumScreen),
          ),
        ],
      ),
      floatingActionButton: isSmallScreen
          ? FloatingActionButton(
              onPressed: () => _showUserActivity(),
              child: const Icon(Icons.timeline),
              backgroundColor: AppColors.warningOrange,
            )
          : null,
    );
  }

  Widget _buildDesktopExportButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.download),
      tooltip: 'تصدير',
      onSelected: (value) {
        if (value == 'pdf') {
          _exportToPDF();
        } else if (value == 'excel') {
          _exportToExcel();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red),
              SizedBox(width: 8),
              Text('تصدير إلى PDF'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.table_chart, color: Colors.green),
              SizedBox(width: 8),
              Text('تصدير إلى Excel'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopViewToggle() {
    return ToggleButtons(
      isSelected: [
        _viewMode == 'grid',
        _viewMode == 'list',
        _viewMode == 'chart',
      ],
      onPressed: (index) {
        setState(() {
          if (index == 0) {
            _viewMode = 'grid';
          } else if (index == 1) {
            _viewMode = 'list';
          } else {
            _viewMode = 'chart';
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      selectedColor: Colors.white,
      fillColor: AppColors.warningOrange,
      constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.grid_view, size: 18),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.view_list, size: 18),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.bar_chart, size: 18),
        ),
      ],
    );
  }

  Widget _buildMobileViewToggle(bool isLargeScreen) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() => _viewMode = value);
      },
      icon: Icon(
        _viewMode == 'grid'
            ? Icons.grid_view
            : _viewMode == 'list'
            ? Icons.view_list
            : Icons.bar_chart,
      ),
      tooltip: 'تغيير العرض',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'grid',
          child: Row(
            children: [
              Icon(
                Icons.grid_view,
                color: _viewMode == 'grid' ? AppColors.warningOrange : null,
              ),
              const SizedBox(width: 8),
              const Text('عرض شبكي'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'list',
          child: Row(
            children: [
              Icon(
                Icons.view_list,
                color: _viewMode == 'list' ? AppColors.warningOrange : null,
              ),
              const SizedBox(width: 8),
              const Text('عرض قائمة'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'chart',
          child: Row(
            children: [
              Icon(
                Icons.bar_chart,
                color: _viewMode == 'chart' ? AppColors.warningOrange : null,
              ),
              const SizedBox(width: 8),
              const Text('عرض رسوم'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(
    bool isLargeScreen,
    bool isMediumScreen,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen
            ? 24
            : isMediumScreen
            ? 16
            : 12,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_users.length} مستخدم',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isLargeScreen ? 16 : 14,
              color: AppColors.mediumGray,
            ),
          ),
          if (!isLargeScreen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _viewMode == 'grid'
                        ? Icons.grid_view
                        : _viewMode == 'list'
                        ? Icons.view_list
                        : Icons.bar_chart,
                    size: 14,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getViewModeLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getViewModeLabel() {
    switch (_viewMode) {
      case 'grid':
        return 'عرض شبكي';
      case 'list':
        return 'عرض قائمة';
      case 'chart':
        return 'عرض رسوم';
      default:
        return 'شبكي';
    }
  }

  Widget _buildFiltersSummary(bool isLargeScreen) {
    final filtersList = _filters.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${_getFilterLabel(e.key)}: ${e.value}')
        .toList();

    if (filtersList.isEmpty) return const SizedBox();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 24 : 16,
        vertical: isLargeScreen ? 12 : 8,
      ),
      color: AppColors.backgroundGray,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: AppColors.mediumGray),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filtersList
                    .map(
                      (filter) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.lightGray),
                        ),
                        child: Text(
                          filter,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear, size: 16),
            onPressed: () => _applyFilters({}),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersView(bool isLargeScreen, bool isMediumScreen) {
    if (_viewMode == 'list') {
      return _buildUsersList();
    } else {
      // Grid view - adjust based on screen size
      if (isLargeScreen) {
        return _buildDesktopGrid();
      } else if (isMediumScreen) {
        return _buildTabletGrid();
      } else {
        return _buildMobileGrid();
      }
    }
  }

  Widget _buildMobileGrid() {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: _users.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return _hasMore
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox();
          }

          final user = _users[index];
          return _buildUserGridCard(user);
        },
      ),
    );
  }

  Widget _buildTabletGrid() {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _users.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return _hasMore
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox();
          }

          final user = _users[index];
          return _buildUserGridCard(user, isTablet: true);
        },
      ),
    );
  }

  Widget _buildDesktopGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isExtraLargeScreen = screenWidth >= 1600;
    final crossAxisCount = isExtraLargeScreen ? 5 : 4;

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _users.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return _hasMore
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox();
          }

          final user = _users[index];
          return _buildUserGridCard(user, isDesktop: true);
        },
      ),
    );
  }

  Widget _buildUsersList() {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return _hasMore
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox();
          }

          final user = _users[index];
          return _buildUserListCard(user);
        },
      ),
    );
  }

  Widget _buildUserGridCard(
    Map<String, dynamic> user, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final totalOrders = user['totalOrders'] ?? 0;
    final successRate = user['successRate'] ?? 0;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Name
              Row(
                children: [
                  CircleAvatar(
                    radius: isDesktop
                        ? 24
                        : isTablet
                        ? 22
                        : 20,
                    backgroundColor: _getRoleColor(user['userRole']),
                    child: Text(
                      user['userName']?.substring(0, 1) ?? '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['userName'] ?? 'غير معروف',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 16 : 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(
                              user['userRole'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getRoleLabel(user['userRole']),
                            style: TextStyle(
                              fontSize: isDesktop ? 12 : 10,
                              color: _getRoleColor(user['userRole']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: isDesktop ? 16 : 12),

              // Contact Info
              if (user['userEmail'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email,
                        size: isDesktop ? 16 : 14,
                        color: AppColors.mediumGray,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user['userEmail']!,
                          style: TextStyle(fontSize: isDesktop ? 14 : 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              if (user['userPhone'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: isDesktop ? 16 : 14,
                        color: AppColors.mediumGray,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user['userPhone']!,
                        style: TextStyle(fontSize: isDesktop ? 14 : 12),
                      ),
                    ],
                  ),
                ),

              // Stats
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildUserStat(
                      'طلبات',
                      totalOrders.toString(),
                      isDesktop: isDesktop,
                    ),
                    _buildUserStat(
                      'نسبة',
                      '${_formatNumber(successRate)}%',
                      isDesktop: isDesktop,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Activity Types
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActivityType(
                    'عميل',
                    user['totalCustomerOrders'] ?? 0,
                    AppColors.primaryBlue,
                    isDesktop: isDesktop,
                  ),
                  _buildActivityType(
                    'مورد',
                    user['totalSupplierOrders'] ?? 0,
                    AppColors.secondaryTeal,
                    isDesktop: isDesktop,
                  ),
                  _buildActivityType(
                    'مدمج',
                    user['totalMixedOrders'] ?? 0,
                    AppColors.successGreen,
                    isDesktop: isDesktop,
                  ),
                ],
              ),

              if (isDesktop) const SizedBox(height: 12),

              // Actions for Desktop
              if (isDesktop)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: AppColors.mediumGray,
                        size: 20,
                      ),
                      onPressed: () => _showUserOptions(user),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserListCard(Map<String, dynamic> user) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1200;
    final isMediumScreen = screenWidth >= 600;

    return Card(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isMediumScreen ? 24 : 16,
        right: isMediumScreen ? 24 : 16,
      ),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: isLargeScreen ? 28 : 24,
                backgroundColor: _getRoleColor(user['userRole']),
                child: Text(
                  user['userName']?.substring(0, 1) ?? '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isLargeScreen ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(width: isLargeScreen ? 20 : 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            user['userName'] ?? 'غير معروف',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isLargeScreen ? 18 : 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(
                              user['userRole'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getRoleLabel(user['userRole']),
                            style: TextStyle(
                              fontSize: isLargeScreen ? 14 : 12,
                              color: _getRoleColor(user['userRole']),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (user['userEmail'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: isLargeScreen ? 18 : 16,
                              color: AppColors.mediumGray,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user['userEmail']!,
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 15 : 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (user['userCompany'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: isLargeScreen ? 18 : 16,
                              color: AppColors.mediumGray,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              user['userCompany']!,
                              style: TextStyle(
                                fontSize: isLargeScreen ? 15 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Performance
                    if (isLargeScreen) _buildDesktopPerformance(user),
                    if (!isLargeScreen) _buildMobilePerformance(user),
                  ],
                ),
              ),

              SizedBox(width: isLargeScreen ? 20 : 16),

              // Stats Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user['totalOrders'] ?? 0} طلب',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isLargeScreen ? 16 : 14,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatNumber(user['totalAmount'] ?? 0)} ريال',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 14 : 12,
                      color: AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(user['userCreatedAt']),
                    style: TextStyle(
                      fontSize: isLargeScreen ? 12 : 10,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPerformance(Map<String, dynamic> user) {
    return Row(
      children: [
        Expanded(
          child: _buildPerformanceMeter(
            'الأداء',
            user['successRate'] ?? 0,
            AppColors.successGreen,
            isDesktop: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPerformanceMeter(
            'النشاط',
            _calculateActivityLevel(user),
            AppColors.primaryBlue,
            isDesktop: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPerformanceMeter(
            'الانضباط',
            user['punctualityRate'] ?? 0,
            AppColors.secondaryTeal,
            isDesktop: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePerformance(Map<String, dynamic> user) {
    return Column(
      children: [
        _buildPerformanceMeter(
          'الأداء',
          user['successRate'] ?? 0,
          AppColors.successGreen,
          isDesktop: false,
        ),
        const SizedBox(height: 8),
        _buildPerformanceMeter(
          'النشاط',
          _calculateActivityLevel(user),
          AppColors.primaryBlue,
          isDesktop: false,
        ),
      ],
    );
  }

  Widget _buildUserStat(String label, String value, {bool isDesktop = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 16 : 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 12 : 10,
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityType(
    String label,
    int count,
    Color color, {
    bool isDesktop = false,
  }) {
    return Column(
      children: [
        Container(
          width: isDesktop ? 36 : 32,
          height: isDesktop ? 36 : 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isDesktop ? 14 : 12,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 12 : 10,
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMeter(
    String label,
    double percentage,
    Color color, {
    bool isDesktop = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: isDesktop ? 14 : 12)),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: isDesktop ? 14 : 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: isDesktop ? 8 : 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return AppColors.primaryBlue;
      case 'manager':
        return AppColors.secondaryTeal;
      case 'maintenance':
        return AppColors.successGreen;
      case 'viewer':
        return AppColors.warningOrange;
      case 'supervisor':
        return AppColors.infoBlue;
      default:
        return AppColors.mediumGray;
    }
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'manager':
        return 'مشرف';
      case 'maintenance':
        return 'فني صيانة';
      case 'viewer':
        return 'مشاهد';
      case 'supervisor':
        return 'مشرف';
      default:
        return 'غير محدد';
    }
  }

  double _calculateActivityLevel(Map<String, dynamic> user) {
    final totalOrders = user['totalOrders'] ?? 0;
    final activityPeriod = user['activityPeriod'] ?? 0;

    if (activityPeriod <= 0) return 0;

    final ordersPerDay = totalOrders / activityPeriod;

    if (ordersPerDay >= 5) return 100;
    if (ordersPerDay >= 3) return 75;
    if (ordersPerDay >= 1) return 50;
    if (ordersPerDay >= 0.5) return 25;
    return 10;
  }

  String _formatNumber(dynamic number) {
    final formatter = NumberFormat('#,##0.##');
    return formatter.format(double.tryParse(number.toString()) ?? 0);
  }

  String _formatDate(dynamic date) {
    if (date == null) return '--/--/----';
    try {
      return DateFormat('yyyy/MM/dd').format(DateTime.parse(date.toString()));
    } catch (e) {
      return '--/--/----';
    }
  }

  String _getFilterLabel(String key) {
    final labels = {
      'startDate': 'من تاريخ',
      'endDate': 'إلى تاريخ',
      'role': 'الدور',
      'userId': 'المستخدم',
      'company': 'الشركة',
    };
    return labels[key] ?? key;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ReportFilters(initialFilters: _filters, onApply: _applyFilters);
      },
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ExportOptions(
          onExportPDF: _exportToPDF,
          onExportExcel: _exportToExcel,
        );
      },
    );
  }

  void _showUserOptions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('عرض التفاصيل'),
                onTap: () {
                  Navigator.pop(context);
                  _showUserDetails(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('سجل النشاط'),
                onTap: () {
                  Navigator.pop(context);
                  _showUserActivityHistory(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('تصدير البيانات'),
                onTap: () {
                  Navigator.pop(context);
                  _exportUserData(user);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    // عرض تفاصيل المستخدم
  }

  void _showUserActivityHistory(Map<String, dynamic> user) {
    // عرض سجل نشاط المستخدم
  }

  void _showUserActivity() {
    setState(() {
      _viewMode = 'chart';
    });
  }

  void _exportUserData(Map<String, dynamic> user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جارٍ تصدير بيانات ${user['userName']}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
