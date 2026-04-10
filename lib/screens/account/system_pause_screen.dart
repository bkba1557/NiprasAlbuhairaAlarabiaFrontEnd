import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/system_pause_notice_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/system_pause_provider.dart';
import 'package:order_tracker/providers/user_management_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

enum _PauseAudienceScope { all, selected }

class SystemPauseScreen extends StatefulWidget {
  const SystemPauseScreen({super.key});

  @override
  State<SystemPauseScreen> createState() => _SystemPauseScreenState();
}

class _SystemPauseScreenState extends State<SystemPauseScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _userSearchController = TextEditingController();
  final UserManagementProvider _userProvider = UserManagementProvider();
  final Set<String> _selectedUserIds = <String>{};

  bool _primedFromServer = false;
  _PauseAudienceScope _audienceScope = _PauseAudienceScope.all;

  @override
  void initState() {
    super.initState();
    _userSearchController.addListener(_handleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _primeDefaults();

      final auth = context.read<AuthProvider>();
      final isOwner = (auth.user?.role ?? '').trim().toLowerCase() == 'owner';

      await context.read<SystemPauseProvider>().refresh(silent: true);
      if (isOwner) {
        await _userProvider.fetchAllUsers();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _userSearchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _userProvider.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  void _primeDefaults() {
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = 'تنبيه: توقف مؤقت للنظام';
    }
    if (_messageController.text.trim().isEmpty) {
      _messageController.text =
          'النظام متوقف مؤقتاً بسبب أعمال تطوير أو تحديث.\nيرجى الانتظار حتى يتم استئناف العمل.';
    }
  }

  void _primeFromNoticeIfNeeded() {
    if (_primedFromServer) return;

    final notice = context.read<SystemPauseProvider>().notice;
    if (notice == null) return;

    _titleController.text = notice.title.trim().isEmpty
        ? _titleController.text
        : notice.title;
    _messageController.text = notice.message.trim().isEmpty
        ? _messageController.text
        : notice.message;
    _audienceScope = notice.targetsAll
        ? _PauseAudienceScope.all
        : _PauseAudienceScope.selected;
    _selectedUserIds
      ..clear()
      ..addAll(notice.targetUserIds);

    _primedFromServer = true;
    if (mounted) setState(() {});
  }

  Future<void> _refreshAll() async {
    await context.read<SystemPauseProvider>().refresh();
    await _userProvider.fetchAllUsers();
  }

  Future<void> _activate() async {
    final provider = context.read<SystemPauseProvider>();
    final auth = context.read<AuthProvider>();
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final actorName = (auth.user?.name ?? '').trim();
    final targetScope = _audienceScope == _PauseAudienceScope.all
        ? 'all'
        : 'selected';

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة نص الإشعار قبل التفعيل'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (_audienceScope == _PauseAudienceScope.selected &&
        _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدد مستخدماً واحداً على الأقل أو اختر الجميع'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final ok = await provider.activate(
      title: title,
      message: message,
      actorName: actorName,
      targetScope: targetScope,
      targetUserIds: _selectedUserIds.toList(),
    );

    if (!mounted) return;

    final audienceLabel = _audienceScope == _PauseAudienceScope.all
        ? '\u062C\u0645\u064A\u0639 \u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645\u064A\u0646 \u0645\u0627 \u0639\u062F\u0627 \u0627\u0644\u0645\u0627\u0644\u0643'
        : '${_selectedUserIds.length} مستخدم';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'تم تفعيل التوقف المؤقت وإرساله إلى $audienceLabel'
              : (provider.error ?? 'تعذر تفعيل التوقف المؤقت'),
        ),
        backgroundColor: ok ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  Future<void> _deactivate() async {
    final provider = context.read<SystemPauseProvider>();
    final resumeController = TextEditingController(
      text:
          'تم الانتهاء من الأعمال المؤقتة.\nيمكنكم الآن استخدام النظام بشكل طبيعي.\nشكراً لتفهمكم.',
    );

    final resumeMessage = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('استئناف النظام', textAlign: TextAlign.right),
        content: TextField(
          controller: resumeController,
          maxLines: 5,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'رسالة الاستئناف',
            filled: true,
            fillColor: const Color(0xFFF8FAFD),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, resumeController.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('استئناف النظام'),
          ),
        ],
      ),
    );

    resumeController.dispose();
    if (resumeMessage == null) return;

    final ok = await provider.deactivate(resumeMessage: resumeMessage);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'تم إلغاء التوقف المؤقت وإرسال إشعار الاستئناف'
              : (provider.error ?? 'تعذر إلغاء التوقف المؤقت'),
        ),
        backgroundColor: ok ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  void _toggleAudienceScope(_PauseAudienceScope scope) {
    if (_audienceScope == scope) return;
    setState(() => _audienceScope = scope);
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _selectVisibleUsers(List<User> users) {
    setState(() {
      _selectedUserIds.addAll(users.map((user) => user.id));
    });
  }

  void _clearSelectedUsers() {
    if (_selectedUserIds.isEmpty) return;
    setState(() => _selectedUserIds.clear());
  }

  List<User> _visibleUsers(UserManagementProvider provider, AuthProvider auth) {
    final query = _userSearchController.text.trim().toLowerCase();
    final currentUserId = auth.user?.id.trim();

    final users = provider.users.where((user) {
      final normalizedRole = user.role.trim().toLowerCase();
      if (normalizedRole == 'owner') return false;
      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          user.id.trim() == currentUserId) {
        return false;
      }

      if (query.isEmpty) return true;

      final searchableFields = <String>[
        user.name,
        user.username,
        user.email,
        user.phone ?? '',
        user.role,
        user.company,
      ];

      return searchableFields.any(
        (field) => field.toLowerCase().contains(query),
      );
    }).toList();

    users.sort((a, b) {
      final aSelected = _selectedUserIds.contains(a.id);
      final bSelected = _selectedUserIds.contains(b.id);
      if (aSelected != bSelected) {
        return aSelected ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    return users;
  }

  List<User> _selectedUsers(UserManagementProvider provider) {
    final usersById = <String, User>{
      for (final user in provider.users) user.id: user,
    };

    final selectedUsers = _selectedUserIds
        .map((userId) => usersById[userId])
        .whereType<User>()
        .toList();

    selectedUsers.sort((a, b) => a.name.compareTo(b.name));
    return selectedUsers;
  }

  String _draftAudienceLabel() {
    if (_audienceScope == _PauseAudienceScope.all) {
      return '\u062C\u0645\u064A\u0639 \u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645\u064A\u0646 \u0645\u0627 \u0639\u062F\u0627 \u0627\u0644\u0645\u0627\u0644\u0643';
    }
    if (_selectedUserIds.isEmpty) {
      return 'اختر مستخدمين محددين';
    }
    if (_selectedUserIds.length == 1) {
      return 'مستخدم واحد';
    }
    return '${_selectedUserIds.length} مستخدمين محددين';
  }

  String _actorName(AuthProvider auth, {SystemPauseNotice? notice}) {
    if (notice != null && notice.isActive) {
      return notice.actorDisplayName;
    }

    final name = (auth.user?.name ?? '').trim();
    return name.isEmpty ? 'مستخدم النظام' : name;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'غير متاح';
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)}  ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'admin':
        return 'مدير النظام';
      case 'manager':
        return 'مدير';
      case 'movement':
        return 'قسم الحركة';
      case 'archive':
        return 'الأرشفة';
      case 'driver':
        return 'سائق';
      case 'employee':
        return 'موظف';
      case 'maintenance':
        return 'صيانة';
      case 'finance_manager':
        return 'مدير مالي';
      default:
        return role.trim().isEmpty ? 'مستخدم' : role.trim();
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    final compact = _isWideWebLayout(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 12 : 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        borderSide: BorderSide(
          color: AppColors.primaryBlue.withValues(alpha: 0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        borderSide: BorderSide(
          color: AppColors.primaryBlue.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        borderSide: const BorderSide(color: AppColors.primaryBlue),
      ),
    );
  }

  bool _isWideWebLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1180;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = (auth.user?.role ?? '').trim().toLowerCase() == 'owner';

    return ChangeNotifierProvider<UserManagementProvider>.value(
      value: _userProvider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6FB),
        appBar: AppBar(
          title: const Text('إدارة التوقف المؤقت'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: isOwner
            ? _buildOwnerBody(context, auth)
            : _buildUnauthorizedBody(),
      ),
    );
  }

  Widget _buildUnauthorizedBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: AppColors.errorRed,
              ),
              SizedBox(height: 14),
              Text(
                'هذه الصفحة متاحة للمالك فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.primaryDarkBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerBody(BuildContext context, AuthProvider auth) {
    return Consumer2<SystemPauseProvider, UserManagementProvider>(
      builder: (context, provider, userProvider, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _primeFromNoticeIfNeeded();
        });

        final notice = provider.notice;
        final isActive = notice?.isActive ?? false;
        final visibleUsers = _visibleUsers(userProvider, auth);
        final selectedUsers = _selectedUsers(userProvider);
        final actorName = _actorName(auth, notice: notice);

        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _isWideWebLayout(context) ? 1360 : double.infinity,
              ),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  _buildOverviewCard(
                    provider: provider,
                    notice: notice,
                    actorName: actorName,
                    isActive: isActive,
                  ),
                  const SizedBox(height: 12),
                  if (_isWideWebLayout(context))
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _buildAudienceSection(
                            provider: userProvider,
                            notice: notice,
                            visibleUsers: visibleUsers,
                            selectedUsers: selectedUsers,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _buildContentSection(),
                              const SizedBox(height: 12),
                              _buildPreviewSection(
                                actorName: actorName,
                                activeNotice: notice,
                              ),
                              const SizedBox(height: 12),
                              _buildActionSection(
                                provider: provider,
                                isActive: isActive,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildAudienceSection(
                      provider: userProvider,
                      notice: notice,
                      visibleUsers: visibleUsers,
                      selectedUsers: selectedUsers,
                    ),
                    const SizedBox(height: 12),
                    _buildContentSection(),
                    const SizedBox(height: 12),
                    _buildPreviewSection(
                      actorName: actorName,
                      activeNotice: notice,
                    ),
                    const SizedBox(height: 12),
                    _buildActionSection(provider: provider, isActive: isActive),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard({
    required SystemPauseProvider provider,
    required SystemPauseNotice? notice,
    required String actorName,
    required bool isActive,
  }) {
    final compact = _isWideWebLayout(context);
    final activeAudience = notice?.audienceSummary ?? _draftAudienceLabel();

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryDarkBlue, AppColors.primaryBlue],
        ),
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.28),
            blurRadius: compact ? 18 : 26,
            offset: Offset(0, compact ? 8 : 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 48 : 56,
                height: compact ? 48 : 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(compact ? 16 : 20),
                ),
                child: Icon(
                  isActive
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: compact ? 26 : 30,
                ),
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isActive
                          ? 'التوقف المؤقت مفعل الآن'
                          : 'النظام يعمل بشكل طبيعي',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 19 : 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      isActive
                          ? 'يمكنك مراجعة الرسالة والجمهور المستهدف أو استئناف النظام عند الانتهاء.'
                          : 'جهّز الرسالة وحدد من تريد إيقافه مؤقتاً قبل التفعيل.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: compact ? 12.5 : null,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 12 : 18),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              _OverviewPill(
                icon: isActive
                    ? Icons.pause_circle_outline_rounded
                    : Icons.check_circle_outline_rounded,
                label: 'الحالة',
                value: isActive ? 'مفعل' : 'غير مفعل',
              ),
              _OverviewPill(
                icon: Icons.groups_rounded,
                label: 'المستهدفون',
                value: activeAudience,
              ),
              _OverviewPill(
                icon: Icons.person_outline_rounded,
                label: 'بواسطة',
                value: actorName,
              ),
              _OverviewPill(
                icon: Icons.schedule_rounded,
                label: 'آخر تحديث',
                value: _formatDateTime(
                  notice?.updatedAt ?? notice?.activatedAt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceSection({
    required UserManagementProvider provider,
    required SystemPauseNotice? notice,
    required List<User> visibleUsers,
    required List<User> selectedUsers,
  }) {
    final compact = _isWideWebLayout(context);
    final fallbackNames = notice?.targetUserNames ?? const <String>[];

    return _SectionCard(
      icon: Icons.group_add_rounded,
      title: 'الجمهور المستهدف',
      subtitle:
          'اختر جميع المستخدمين أو مجموعة محددة. سيظهر الحظر فقط للمستخدمين المستهدفين.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final everyoneCard = Expanded(
                child: _AudienceOptionCard(
                  title: 'الجميع',
                  subtitle: 'إيقاف مؤقت لكل المستخدمين باستثناء المالك',
                  icon: Icons.groups_rounded,
                  selected: _audienceScope == _PauseAudienceScope.all,
                  onTap: () => _toggleAudienceScope(_PauseAudienceScope.all),
                ),
              );
              final selectedCard = Expanded(
                child: _AudienceOptionCard(
                  title: 'مستخدمون محددون',
                  subtitle: 'اختر مستخدماً واحداً أو عدة مستخدمين فقط',
                  icon: Icons.person_search_rounded,
                  selected: _audienceScope == _PauseAudienceScope.selected,
                  onTap: () =>
                      _toggleAudienceScope(_PauseAudienceScope.selected),
                ),
              );

              if (wide) {
                return Row(
                  children: [
                    everyoneCard,
                    const SizedBox(width: 12),
                    selectedCard,
                  ],
                );
              }

              return Column(
                children: [
                  Row(children: [everyoneCard]),
                  const SizedBox(height: 12),
                  Row(children: [selectedCard]),
                ],
              );
            },
          ),
          if (_audienceScope == _PauseAudienceScope.selected) ...[
            SizedBox(height: compact ? 12 : 16),
            TextField(
              controller: _userSearchController,
              textAlign: TextAlign.right,
              decoration: _fieldDecoration(
                'ابحث عن مستخدم',
                hint: 'اسم المستخدم أو البريد أو الهاتف',
              ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
            ),
            SizedBox(height: compact ? 10 : 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedUserIds.isEmpty
                        ? 'لم يتم تحديد أي مستخدم بعد'
                        : 'تم تحديد ${_selectedUserIds.length} مستخدم',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: visibleUsers.isEmpty
                      ? null
                      : () => _selectVisibleUsers(visibleUsers),
                  icon: const Icon(Icons.select_all_rounded),
                  label: const Text('تحديد الظاهر'),
                ),
                TextButton.icon(
                  onPressed: _selectedUserIds.isEmpty
                      ? null
                      : _clearSelectedUsers,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('مسح'),
                ),
              ],
            ),
            if (selectedUsers.isNotEmpty) ...[
              SizedBox(height: compact ? 8 : 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedUsers.map((user) {
                  return InputChip(
                    label: Text(user.name),
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.primaryBlue.withValues(
                        alpha: 0.10,
                      ),
                      child: Text(
                        user.name.trim().isEmpty ? '?' : user.name.trim()[0],
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    onDeleted: () => _toggleUserSelection(user.id),
                  );
                }).toList(),
              ),
            ] else if (_selectedUserIds.isNotEmpty &&
                fallbackNames.isNotEmpty) ...[
              SizedBox(height: compact ? 8 : 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fallbackNames
                    .map((name) => Chip(label: Text(name)))
                    .toList(),
              ),
            ],
            SizedBox(height: compact ? 10 : 14),
            Container(
              constraints: BoxConstraints(maxHeight: compact ? 260 : 340),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBFF),
                borderRadius: BorderRadius.circular(compact ? 18 : 22),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                ),
              ),
              child: Builder(
                builder: (context) {
                  if (provider.isLoading && provider.users.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null && provider.users.isEmpty) {
                    return _EmptyAudienceState(
                      icon: Icons.error_outline_rounded,
                      title: 'تعذر تحميل المستخدمين',
                      message: provider.error!,
                    );
                  }

                  if (visibleUsers.isEmpty) {
                    return const _EmptyAudienceState(
                      icon: Icons.person_search_rounded,
                      title: 'لا توجد نتائج',
                      message: 'جرّب تغيير البحث أو اختر الجميع بدلاً من ذلك.',
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(compact ? 8 : 10),
                    itemCount: visibleUsers.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: compact ? 6 : 8),
                    itemBuilder: (context, index) {
                      final user = visibleUsers[index];
                      final isSelected = _selectedUserIds.contains(user.id);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue.withValues(alpha: 0.07)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(
                            compact ? 14 : 18,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryBlue.withValues(alpha: 0.24)
                                : AppColors.silverLight,
                          ),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              compact ? 14 : 18,
                            ),
                          ),
                          dense: compact,
                          visualDensity: compact
                              ? const VisualDensity(horizontal: 0, vertical: -2)
                              : VisualDensity.standard,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 16,
                            vertical: compact ? 2 : 6,
                          ),
                          onTap: () => _toggleUserSelection(user.id),
                          leading: SizedBox(
                            width: compact ? 36 : 40,
                            height: compact ? 36 : 40,
                            child: CircleAvatar(
                              backgroundColor: AppColors.primaryBlue.withValues(
                                alpha: 0.10,
                              ),
                              child: Text(
                                user.name.trim().isEmpty
                                    ? '?'
                                    : user.name.trim()[0],
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 13 : 15,
                                ),
                              ),
                            ),
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            activeColor: AppColors.primaryBlue,
                            onChanged: (_) => _toggleUserSelection(user.id),
                          ),
                          title: Text(
                            user.name,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDarkBlue,
                              fontSize: compact ? 13 : 15,
                            ),
                          ),
                          subtitle: Text(
                            '${_roleLabel(user.role)} • ${user.email}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              height: 1.4,
                              fontSize: compact ? 11.5 : 13,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            Text(
              'سيبقى المالك خارج الحظر حتى يمكنه إدارة الصفحة واستئناف النظام عند الحاجة.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: compact ? 11 : 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    final compact = _isWideWebLayout(context);
    return _SectionCard(
      icon: Icons.edit_note_rounded,
      title: 'محتوى الإشعار',
      subtitle: 'العنوان اختياري، لكن نص الرسالة الأساسية مطلوب.',
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            textAlign: TextAlign.right,
            decoration: _fieldDecoration('العنوان'),
          ),
          SizedBox(height: compact ? 10 : 14),
          TextField(
            controller: _messageController,
            maxLines: compact ? 5 : 6,
            textAlign: TextAlign.right,
            decoration: _fieldDecoration(
              'نص الإشعار',
              hint: 'الرسالة التي ستظهر للمستخدمين المستهدفين',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection({
    required String actorName,
    required SystemPauseNotice? activeNotice,
  }) {
    final compact = _isWideWebLayout(context);
    final previewTitle = _titleController.text.trim().isEmpty
        ? 'تنبيه: توقف مؤقت للنظام'
        : _titleController.text.trim();
    final previewMessage = _messageController.text.trim().isEmpty
        ? 'اكتب نص الإشعار هنا ليظهر للمستخدمين.'
        : _messageController.text.trim();

    return _SectionCard(
      icon: Icons.visibility_outlined,
      title: 'معاينة ما سيظهر للمستخدم',
      subtitle:
          'تمت إزالة حقل اسم المطور. سيظهر للمستخدمين اسم من قام بتفعيل الإيقاف.',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 18 : 24),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.primaryDarkBlue, AppColors.primaryBlue],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              previewTitle,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 17 : 20,
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            Container(
              padding: EdgeInsets.all(compact ? 12 : 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(compact ? 14 : 18),
              ),
              child: Text(
                previewMessage,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.darkGray,
                  height: 1.7,
                  fontSize: compact ? 12.5 : 14,
                ),
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                _PreviewBadge(
                  icon: Icons.person_outline_rounded,
                  label: 'بواسطة: $actorName',
                ),
                _PreviewBadge(
                  icon: Icons.groups_rounded,
                  label: activeNotice?.isActive == true
                      ? activeNotice!.audienceSummary
                      : _draftAudienceLabel(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection({
    required SystemPauseProvider provider,
    required bool isActive,
  }) {
    final compact = _isWideWebLayout(context);
    final audienceHint = _audienceScope == _PauseAudienceScope.all
        ? 'سيتم إرسال الإشعار داخل النظام وPush والبريد إلى جميع المستخدمين المستهدفين.'
        : 'سيتم إرسال الإشعار فقط إلى المستخدمين المحددين في هذه الصفحة.';

    return _SectionCard(
      icon: Icons.settings_backup_restore_rounded,
      title: 'التنفيذ',
      subtitle: 'راجع الجمهور والرسالة قبل تنفيذ العملية.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            audienceHint,
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.grey.shade700, height: 1.6),
          ),
          SizedBox(height: compact ? 12 : 16),
          if (!isActive)
            FilledButton.icon(
              onPressed: provider.isLoading ? null : _activate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: compact ? 14 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(compact ? 14 : 18),
                ),
              ),
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: const Text('تفعيل التوقف المؤقت'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;

                final updateButton = OutlinedButton.icon(
                  onPressed: provider.isLoading ? null : _activate,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: compact ? 14 : 16),
                    side: BorderSide(
                      color: AppColors.primaryBlue.withValues(alpha: 0.26),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(compact ? 14 : 18),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تحديث الإشعار'),
                );

                final resumeButton = FilledButton.icon(
                  onPressed: provider.isLoading ? null : _deactivate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: compact ? 14 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(compact ? 14 : 18),
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('استئناف النظام'),
                );

                if (compact) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: updateButton),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: resumeButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: updateButton),
                    const SizedBox(width: 12),
                    Expanded(child: resumeButton),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width >= 1180;
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(color: AppColors.silverLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: compact ? 12 : 16,
            offset: Offset(0, compact ? 5 : 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 40 : 46,
                height: compact ? 40 : 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(compact ? 12 : 16),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryBlue,
                  size: compact ? 20 : 24,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: compact ? 12 : 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),
          child,
        ],
      ),
    );
  }
}

class _OverviewPill extends StatelessWidget {
  const _OverviewPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width >= 1180;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceOptionCard extends StatelessWidget {
  const _AudienceOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width >= 1180;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            color: selected
                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                : const Color(0xFFF9FBFF),
            border: Border.all(
              color: selected
                  ? AppColors.primaryBlue.withValues(alpha: 0.32)
                  : AppColors.silverLight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 40 : 46,
                height: compact ? 40 : 46,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryBlue.withValues(alpha: 0.14)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(compact ? 12 : 16),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? AppColors.primaryBlue
                      : AppColors.mediumGray,
                  size: compact ? 20 : 24,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primaryBlue,
                            size: 18,
                          ),
                        if (selected) SizedBox(width: compact ? 4 : 6),
                        Flexible(
                          child: Text(
                            title,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDarkBlue,
                              fontSize: compact ? 14 : 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: compact ? 11.5 : 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width >= 1180;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: Colors.white),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAudienceState extends StatelessWidget {
  const _EmptyAudienceState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.mediumGray),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

