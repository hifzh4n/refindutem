import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_page_shell.dart';
import '../../data/services/supabase_admin_service.dart';
import '../../../lost_found/presentation/widgets/report_image_preview.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _service = SupabaseAdminService();

  late Future<bool> _adminFuture;
  late Future<_AdminData> _dataFuture;
  int _tabIndex = 0;

  static const _tabs = ['Overview', 'Users', 'Lost', 'Found'];

  @override
  void initState() {
    super.initState();
    _adminFuture = _service.isAdmin();
    _dataFuture = _loadData();
  }

  Future<_AdminData> _loadData() async {
    final results = await Future.wait([
      _service.fetchStats(),
      _service.fetchUsers(),
      _service.fetchLostReports(),
      _service.fetchFoundReports(),
    ]);

    return _AdminData(
      stats: results[0] as AdminDashboardStats,
      users: results[1] as List<AdminUserRow>,
      lost: results[2] as List<AdminLostReportRow>,
      found: results[3] as List<AdminFoundReportRow>,
    );
  }

  void _refresh() {
    setState(() {
      _adminFuture = _service.isAdmin();
      _dataFuture = _loadData();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primaryDark : AppColors.green,
      ),
    );
  }

  Future<void> _editUser(AdminUserRow user) async {
    final result = await showDialog<AdminUserInput>(
      context: context,
      builder: (context) => _UserDialog(user: user),
    );
    if (result == null) {
      return;
    }

    try {
      await _service.updateUser(result);
      _showMessage('User updated.');
      _refresh();
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _deleteUser(AdminUserRow user) async {
    final shouldDelete = await _confirm(
      title: 'Delete user?',
      message: 'This removes ${user.email} and cascades their reports.',
      action: 'Delete user',
    );
    if (!shouldDelete) {
      return;
    }

    try {
      await _service.deleteUser(user.id);
      _showMessage('User deleted.');
      _refresh();
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _editLost(AdminLostReportRow? report, _AdminData data) async {
    final result = await showDialog<AdminLostReportInput>(
      context: context,
      builder: (context) =>
          _LostReportDialog(report: report, users: data.users),
    );
    if (result == null) {
      return;
    }

    try {
      await _service.upsertLostReport(result);
      _showMessage(
        report == null ? 'Lost report created.' : 'Lost report updated.',
      );
      _refresh();
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _deleteLost(AdminLostReportRow report) async {
    final shouldDelete = await _confirm(
      title: 'Delete lost report?',
      message: 'This removes "${report.itemName}" permanently.',
      action: 'Delete report',
    );
    if (!shouldDelete) {
      return;
    }

    try {
      await _service.deleteLostReport(report.id);
      _showMessage('Lost report deleted.');
      _refresh();
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _editFound(AdminFoundReportRow? report, _AdminData data) async {
    final result = await showDialog<AdminFoundReportInput>(
      context: context,
      builder: (context) =>
          _FoundReportDialog(report: report, users: data.users),
    );
    if (result == null) {
      return;
    }

    try {
      await _service.upsertFoundReport(result);
      _showMessage(
        report == null ? 'Found report created.' : 'Found report updated.',
      );
      _refresh();
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _deleteFound(AdminFoundReportRow report) async {
    final shouldDelete = await _confirm(
      title: 'Delete found report?',
      message: 'This removes "${report.itemName}" permanently.',
      action: 'Delete report',
    );
    if (!shouldDelete) {
      return;
    }

    try {
      await _service.deleteFoundReport(report.id);
      _showMessage('Found report deleted.');
      _refresh();
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      currentRoute: AppRoutes.admin,
      title: 'Admin',
      subtitle: 'Manage users, lost reports, and found reports',
      child: FutureBuilder<bool>(
        future: _adminFuture,
        builder: (context, adminSnapshot) {
          if (adminSnapshot.connectionState == ConnectionState.waiting) {
            return const _AdminCard(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (adminSnapshot.data != true) {
            return const PagePlaceholder(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin access required',
              description:
                  'Your account is signed in, but it has not been granted admin access.',
            );
          }

          return FutureBuilder<_AdminData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _AdminCard(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        snapshot.error.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminTabs(
                    tabs: _tabs,
                    selectedIndex: _tabIndex,
                    onChanged: (index) => setState(() => _tabIndex = index),
                  ),
                  const SizedBox(height: 20),
                  switch (_tabIndex) {
                    0 => _OverviewPanel(data: data),
                    1 => _UsersAdminTable(
                      users: data.users,
                      onEdit: _editUser,
                      onDelete: _deleteUser,
                    ),
                    2 => _LostAdminTable(
                      data: data,
                      onCreate: () => _editLost(null, data),
                      onEdit: (report) => _editLost(report, data),
                      onDelete: _deleteLost,
                    ),
                    _ => _FoundAdminTable(
                      data: data,
                      onCreate: () => _editFound(null, data),
                      onEdit: (report) => _editFound(report, data),
                      onDelete: _deleteFound,
                    ),
                  },
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminData {
  const _AdminData({
    required this.stats,
    required this.users,
    required this.lost,
    required this.found,
  });

  final AdminDashboardStats stats;
  final List<AdminUserRow> users;
  final List<AdminLostReportRow> lost;
  final List<AdminFoundReportRow> found;
}

class _AdminTabs extends StatelessWidget {
  const _AdminTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<int>(
        segments: [
          for (var index = 0; index < tabs.length; index++)
            ButtonSegment(value: index, label: Text(tabs[index])),
        ],
        selected: {selectedIndex},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.data});

  final _AdminData data;

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 640
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatTile(
              width: width,
              icon: Icons.people_alt_outlined,
              label: 'Users',
              value: stats.users.toString(),
            ),
            _StatTile(
              width: width,
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admins',
              value: stats.admins.toString(),
            ),
            _StatTile(
              width: width,
              icon: Icons.search_rounded,
              label: 'Open lost',
              value: '${stats.lostOpen}/${stats.lostTotal}',
            ),
            _StatTile(
              width: width,
              icon: Icons.inventory_2_outlined,
              label: 'Open found',
              value: '${stats.foundOpen}/${stats.foundTotal}',
            ),
            _StatTile(
              width: width,
              icon: Icons.check_circle_outline_rounded,
              label: 'Closed reports',
              value:
                  '${stats.lostTotal - stats.lostOpen + stats.foundTotal - stats.foundOpen}',
            ),
          ],
        );
      },
    );
  }
}

// ignore: unused_element
class _UsersPanel extends StatelessWidget {
  const _UsersPanel({
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminUserRow> users;
  final ValueChanged<AdminUserRow> onEdit;
  final ValueChanged<AdminUserRow> onDelete;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: 'Users',
      child: Column(
        children: [
          for (final user in users)
            _AdminListTile(
              icon: user.isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_outline_rounded,
              title: user.name,
              subtitle:
                  '${user.email}${user.phone.isEmpty ? '' : ' • ${user.phone}'}',
              meta: user.isAdmin ? 'Admin' : 'User',
              onEdit: () => onEdit(user),
              onDelete: () => onDelete(user),
            ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LostPanel extends StatelessWidget {
  const _LostPanel({
    required this.data,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final _AdminData data;
  final VoidCallback onCreate;
  final ValueChanged<AdminLostReportRow> onEdit;
  final ValueChanged<AdminLostReportRow> onDelete;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: 'Lost reports',
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New lost'),
      ),
      child: Column(
        children: [
          for (final report in data.lost)
            _AdminListTile(
              icon: Icons.search_rounded,
              title: report.itemName,
              subtitle: '${report.category} • ${report.location}',
              meta: report.status,
              onEdit: () => onEdit(report),
              onDelete: () => onDelete(report),
            ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _FoundPanel extends StatelessWidget {
  const _FoundPanel({
    required this.data,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final _AdminData data;
  final VoidCallback onCreate;
  final ValueChanged<AdminFoundReportRow> onEdit;
  final ValueChanged<AdminFoundReportRow> onDelete;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: 'Found reports',
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New found'),
      ),
      child: Column(
        children: [
          for (final report in data.found)
            _AdminListTile(
              icon: Icons.inventory_2_outlined,
              title: report.itemName,
              subtitle: '${report.category} • ${report.location}',
              meta: report.status,
              onEdit: () => onEdit(report),
              onDelete: () => onDelete(report),
            ),
        ],
      ),
    );
  }
}

class _UsersAdminTable extends StatefulWidget {
  const _UsersAdminTable({
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminUserRow> users;
  final ValueChanged<AdminUserRow> onEdit;
  final ValueChanged<AdminUserRow> onDelete;

  @override
  State<_UsersAdminTable> createState() => _UsersAdminTableState();
}

class _UsersAdminTableState extends State<_UsersAdminTable> {
  final _search = TextEditingController();
  String _roleFilter = 'All';
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminUserRow> get _filteredUsers {
    final query = _search.text.trim().toLowerCase();

    return widget.users.where((user) {
      final matchesRole =
          _roleFilter == 'All' ||
          (_roleFilter == 'Admins' && user.isAdmin) ||
          (_roleFilter == 'Users' && !user.isAdmin);
      final searchable = [
        user.name,
        user.email,
        user.phone,
      ].join(' ').toLowerCase();

      return matchesRole && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filteredUsers;
    final pageItems = _pageItems(filteredUsers, _page);

    return _AdminCard(
      title: 'Users',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableControls(
            searchController: _search,
            searchHint: 'Search users...',
            filterValue: _roleFilter,
            filters: const ['All', 'Admins', 'Users'],
            onSearchChanged: () => setState(() => _page = 0),
            onFilterChanged: (value) => setState(() {
              _roleFilter = value;
              _page = 0;
            }),
          ),
          const SizedBox(height: 14),
          for (final user in pageItems)
            _AdminDataRow(
              leading: _UserAvatar(user: user),
              title: user.name,
              subtitle: user.email,
              meta: user.isAdmin ? 'Admin' : 'User',
              onEdit: () => widget.onEdit(user),
              onDelete: () => widget.onDelete(user),
            ),
          _Pager(
            totalItems: filteredUsers.length,
            page: _page,
            onPageChanged: (page) => setState(() => _page = page),
          ),
        ],
      ),
    );
  }
}

class _LostAdminTable extends StatefulWidget {
  const _LostAdminTable({
    required this.data,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final _AdminData data;
  final VoidCallback onCreate;
  final ValueChanged<AdminLostReportRow> onEdit;
  final ValueChanged<AdminLostReportRow> onDelete;

  @override
  State<_LostAdminTable> createState() => _LostAdminTableState();
}

class _LostAdminTableState extends State<_LostAdminTable> {
  final _search = TextEditingController();
  String _statusFilter = 'All';
  String _categoryFilter = 'All';
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminLostReportRow> get _filteredReports {
    final query = _search.text.trim().toLowerCase();

    return widget.data.lost.where((report) {
      final matchesStatus =
          _statusFilter == 'All' || report.status == _statusFilter;
      final matchesCategory =
          _categoryFilter == 'All' || report.category == _categoryFilter;
      final searchable = [
        report.itemName,
        report.category,
        report.location,
        report.description,
        report.contactDetail,
      ].join(' ').toLowerCase();

      return matchesStatus &&
          matchesCategory &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = _filteredReports;
    final pageItems = _pageItems(filteredReports, _page);

    return _AdminCard(
      title: 'Lost reports',
      action: FilledButton.icon(
        onPressed: widget.onCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New lost'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableControls(
            searchController: _search,
            searchHint: 'Search lost reports...',
            filterValue: _statusFilter,
            filters: const ['All', 'open', 'matched', 'closed'],
            secondaryFilterValue: _categoryFilter,
            secondaryFilters: const ['All', ..._categories],
            onSearchChanged: () => setState(() => _page = 0),
            onFilterChanged: (value) => setState(() {
              _statusFilter = value;
              _page = 0;
            }),
            onSecondaryFilterChanged: (value) => setState(() {
              _categoryFilter = value;
              _page = 0;
            }),
          ),
          const SizedBox(height: 14),
          for (final report in pageItems)
            _AdminDataRow(
              leading: _ReportThumb(
                imageUrl: report.imageUrl,
                title: report.itemName,
                fallbackIcon: Icons.search_rounded,
              ),
              title: report.itemName,
              subtitle: '${report.category} • ${report.location}',
              meta: report.status,
              onEdit: () => widget.onEdit(report),
              onDelete: () => widget.onDelete(report),
            ),
          _Pager(
            totalItems: filteredReports.length,
            page: _page,
            onPageChanged: (page) => setState(() => _page = page),
          ),
        ],
      ),
    );
  }
}

class _FoundAdminTable extends StatefulWidget {
  const _FoundAdminTable({
    required this.data,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final _AdminData data;
  final VoidCallback onCreate;
  final ValueChanged<AdminFoundReportRow> onEdit;
  final ValueChanged<AdminFoundReportRow> onDelete;

  @override
  State<_FoundAdminTable> createState() => _FoundAdminTableState();
}

class _FoundAdminTableState extends State<_FoundAdminTable> {
  final _search = TextEditingController();
  String _statusFilter = 'All';
  String _categoryFilter = 'All';
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminFoundReportRow> get _filteredReports {
    final query = _search.text.trim().toLowerCase();

    return widget.data.found.where((report) {
      final matchesStatus =
          _statusFilter == 'All' || report.status == _statusFilter;
      final matchesCategory =
          _categoryFilter == 'All' || report.category == _categoryFilter;
      final searchable = [
        report.itemName,
        report.category,
        report.location,
        report.description,
        report.handoverStatus,
        report.contactDetail,
      ].join(' ').toLowerCase();

      return matchesStatus &&
          matchesCategory &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = _filteredReports;
    final pageItems = _pageItems(filteredReports, _page);

    return _AdminCard(
      title: 'Found reports',
      action: FilledButton.icon(
        onPressed: widget.onCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New found'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableControls(
            searchController: _search,
            searchHint: 'Search found reports...',
            filterValue: _statusFilter,
            filters: const ['All', 'open', 'claimed', 'closed'],
            secondaryFilterValue: _categoryFilter,
            secondaryFilters: const ['All', ..._categories],
            onSearchChanged: () => setState(() => _page = 0),
            onFilterChanged: (value) => setState(() {
              _statusFilter = value;
              _page = 0;
            }),
            onSecondaryFilterChanged: (value) => setState(() {
              _categoryFilter = value;
              _page = 0;
            }),
          ),
          const SizedBox(height: 14),
          for (final report in pageItems)
            _AdminDataRow(
              leading: _ReportThumb(
                imageUrl: report.imageUrl,
                title: report.itemName,
                fallbackIcon: Icons.inventory_2_outlined,
              ),
              title: report.itemName,
              subtitle: '${report.category} • ${report.location}',
              meta: report.status,
              onEdit: () => widget.onEdit(report),
              onDelete: () => widget.onDelete(report),
            ),
          _Pager(
            totalItems: filteredReports.length,
            page: _page,
            onPageChanged: (page) => setState(() => _page = page),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child, this.title, this.action});

  final String? title;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 18),
          ],
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _AdminCard(
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminListTile extends StatelessWidget {
  const _AdminListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            meta,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _AdminDataRow extends StatelessWidget {
  const _AdminDataRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onEdit,
    required this.onDelete,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            meta,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _TableControls extends StatelessWidget {
  const _TableControls({
    required this.searchController,
    required this.searchHint,
    required this.filterValue,
    required this.filters,
    required this.onSearchChanged,
    required this.onFilterChanged,
    this.secondaryFilterValue,
    this.secondaryFilters,
    this.onSecondaryFilterChanged,
  });

  final TextEditingController searchController;
  final String searchHint;
  final String filterValue;
  final List<String> filters;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final String? secondaryFilterValue;
  final List<String>? secondaryFilters;
  final ValueChanged<String>? onSecondaryFilterChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 680;
        final search = TextField(
          controller: searchController,
          onChanged: (_) => onSearchChanged(),
          decoration: InputDecoration(
            hintText: searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        );
        final primaryFilter = _FilterDropdown(
          value: filterValue,
          values: filters,
          onChanged: onFilterChanged,
        );
        final secondaryFilter =
            secondaryFilterValue == null || secondaryFilters == null
            ? null
            : _FilterDropdown(
                value: secondaryFilterValue!,
                values: secondaryFilters!,
                onChanged: onSecondaryFilterChanged!,
              );

        if (stack) {
          return Column(
            children: [
              search,
              const SizedBox(height: 12),
              primaryFilter,
              if (secondaryFilter != null) ...[
                const SizedBox(height: 12),
                secondaryFilter,
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 12),
            Expanded(child: primaryFilter),
            if (secondaryFilter != null) ...[
              const SizedBox(width: 12),
              Expanded(child: secondaryFilter),
            ],
          ],
        );
      },
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter',
        prefixIcon: Icon(Icons.filter_list_rounded),
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) => onChanged(value!),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.totalItems,
    required this.page,
    required this.onPageChanged,
  });

  final int totalItems;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount(totalItems);
    final clampedPage = page.clamp(0, pageCount - 1);
    final first = totalItems == 0 ? 0 : (clampedPage * _adminPageSize) + 1;
    final last = totalItems == 0
        ? 0
        : (first + _adminPageSize - 1).clamp(1, totalItems);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              totalItems == 0
                  ? 'No results'
                  : 'Showing $first-$last of $totalItems',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: clampedPage == 0
                ? null
                : () => onPageChanged(clampedPage - 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('${clampedPage + 1}/$pageCount'),
          IconButton(
            tooltip: 'Next page',
            onPressed: clampedPage >= pageCount - 1
                ? null
                : () => onPageChanged(clampedPage + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final AdminUserRow user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      foregroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
      child: avatarUrl == null
          ? const Icon(Icons.person_rounded, color: AppColors.primaryDark)
          : null,
    );

    if (avatarUrl == null) {
      return avatar;
    }

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => showReportImagePreview(
        context: context,
        imageUrl: avatarUrl,
        title: user.name,
      ),
      child: avatar,
    );
  }
}

class _ReportThumb extends StatelessWidget {
  const _ReportThumb({
    required this.imageUrl,
    required this.title,
    required this.fallbackIcon,
  });

  final String? imageUrl;
  final String title;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return SizedBox.square(
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(fallbackIcon, color: AppColors.primary),
        ),
      );
    }

    return SizedBox(
      width: 56,
      height: 44,
      child: ReportImagePreview(
        imageUrl: imageUrl!,
        title: title,
        compact: true,
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.user});

  final AdminUserRow user;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.user.firstName);
  late final _lastName = TextEditingController(text: widget.user.lastName);
  late bool _isAdmin = widget.user.isAdmin;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user.email),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isAdmin,
                onChanged: (value) => setState(() => _isAdmin = value),
                title: const Text('Admin access'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(
            AdminUserInput(
              id: widget.user.id,
              firstName: _firstName.text,
              lastName: _lastName.text,
              isAdmin: _isAdmin,
            ),
          ),
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _LostReportDialog extends StatefulWidget {
  const _LostReportDialog({required this.report, required this.users});

  final AdminLostReportRow? report;
  final List<AdminUserRow> users;

  @override
  State<_LostReportDialog> createState() => _LostReportDialogState();
}

class _LostReportDialogState extends State<_LostReportDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _userId = widget.report?.userId ?? widget.users.first.id;
  late String _category = widget.report?.category ?? _categories.first;
  late String _status = widget.report?.status ?? 'open';
  late String _contactMethod = widget.report?.contactMethod ?? 'Phone';
  late DateTime _date = widget.report?.lostDate ?? DateTime.now();
  late final _item = TextEditingController(text: widget.report?.itemName ?? '');
  late final _location = TextEditingController(
    text: widget.report?.location ?? '',
  );
  late final _description = TextEditingController(
    text: widget.report?.description ?? '',
  );
  late final _contact = TextEditingController(
    text: widget.report?.contactDetail ?? '',
  );

  @override
  void dispose() {
    _item.dispose();
    _location.dispose();
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ReportDialogShell(
      title: widget.report == null ? 'New lost report' : 'Edit lost report',
      child: Form(
        key: _formKey,
        child: _ReportFields(
          users: widget.users,
          userId: _userId,
          onUserChanged: (value) => setState(() => _userId = value),
          item: _item,
          location: _location,
          description: _description,
          contact: _contact,
          date: _date,
          dateLabel: 'Date lost',
          onPickDate: () async {
            final picked = await _pickDate(context, _date);
            if (picked != null) {
              setState(() => _date = picked);
            }
          },
          category: _category,
          onCategoryChanged: (value) => setState(() => _category = value),
          status: _status,
          statuses: const ['open', 'matched', 'closed'],
          onStatusChanged: (value) => setState(() => _status = value),
          contactMethod: _contactMethod,
          onContactMethodChanged: (value) =>
              setState(() => _contactMethod = value),
        ),
      ),
      onSave: () {
        if (!(_formKey.currentState?.validate() ?? false)) {
          return;
        }
        Navigator.of(context).pop(
          AdminLostReportInput(
            id: widget.report?.id,
            userId: _userId,
            itemName: _item.text,
            category: _category,
            lostDate: _date,
            location: _location.text,
            description: _description.text,
            contactMethod: _contactMethod,
            contactDetail: _contact.text,
            status: _status,
          ),
        );
      },
    );
  }
}

class _FoundReportDialog extends StatefulWidget {
  const _FoundReportDialog({required this.report, required this.users});

  final AdminFoundReportRow? report;
  final List<AdminUserRow> users;

  @override
  State<_FoundReportDialog> createState() => _FoundReportDialogState();
}

class _FoundReportDialogState extends State<_FoundReportDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _userId = widget.report?.userId ?? widget.users.first.id;
  late String _category = widget.report?.category ?? _categories.first;
  late String _handover =
      widget.report?.handoverStatus ?? _handoverStatuses.first;
  late String _status = widget.report?.status ?? 'open';
  late String _contactMethod = widget.report?.contactMethod ?? 'Phone';
  late DateTime _date = widget.report?.foundDate ?? DateTime.now();
  late final _item = TextEditingController(text: widget.report?.itemName ?? '');
  late final _location = TextEditingController(
    text: widget.report?.location ?? '',
  );
  late final _description = TextEditingController(
    text: widget.report?.description ?? '',
  );
  late final _contact = TextEditingController(
    text: widget.report?.contactDetail ?? '',
  );

  @override
  void dispose() {
    _item.dispose();
    _location.dispose();
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ReportDialogShell(
      title: widget.report == null ? 'New found report' : 'Edit found report',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ReportFields(
              users: widget.users,
              userId: _userId,
              onUserChanged: (value) => setState(() => _userId = value),
              item: _item,
              location: _location,
              description: _description,
              contact: _contact,
              date: _date,
              dateLabel: 'Date found',
              onPickDate: () async {
                final picked = await _pickDate(context, _date);
                if (picked != null) {
                  setState(() => _date = picked);
                }
              },
              category: _category,
              onCategoryChanged: (value) => setState(() => _category = value),
              status: _status,
              statuses: const ['open', 'claimed', 'closed'],
              onStatusChanged: (value) => setState(() => _status = value),
              contactMethod: _contactMethod,
              onContactMethodChanged: (value) =>
                  setState(() => _contactMethod = value),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _handover,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Handover status'),
              items: _handoverStatuses
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _handover = value!),
            ),
          ],
        ),
      ),
      onSave: () {
        if (!(_formKey.currentState?.validate() ?? false)) {
          return;
        }
        Navigator.of(context).pop(
          AdminFoundReportInput(
            id: widget.report?.id,
            userId: _userId,
            itemName: _item.text,
            category: _category,
            foundDate: _date,
            location: _location.text,
            description: _description.text,
            handoverStatus: _handover,
            contactMethod: _contactMethod,
            contactDetail: _contact.text,
            status: _status,
          ),
        );
      },
    );
  }
}

class _ReportDialogShell extends StatelessWidget {
  const _ReportDialogShell({
    required this.title,
    required this.child,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              child,
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save'),
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
}

class _ReportFields extends StatelessWidget {
  const _ReportFields({
    required this.users,
    required this.userId,
    required this.onUserChanged,
    required this.item,
    required this.location,
    required this.description,
    required this.contact,
    required this.date,
    required this.dateLabel,
    required this.onPickDate,
    required this.category,
    required this.onCategoryChanged,
    required this.status,
    required this.statuses,
    required this.onStatusChanged,
    required this.contactMethod,
    required this.onContactMethodChanged,
  });

  final List<AdminUserRow> users;
  final String userId;
  final ValueChanged<String> onUserChanged;
  final TextEditingController item;
  final TextEditingController location;
  final TextEditingController description;
  final TextEditingController contact;
  final DateTime date;
  final String dateLabel;
  final VoidCallback onPickDate;
  final String category;
  final ValueChanged<String> onCategoryChanged;
  final String status;
  final List<String> statuses;
  final ValueChanged<String> onStatusChanged;
  final String contactMethod;
  final ValueChanged<String> onContactMethodChanged;

  @override
  Widget build(BuildContext context) {
    final formattedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(date);

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: userId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Owner'),
          items: users
              .map(
                (user) =>
                    DropdownMenuItem(value: user.id, child: Text(user.email)),
              )
              .toList(),
          onChanged: (value) => onUserChanged(value!),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: item,
          decoration: const InputDecoration(labelText: 'Item name'),
          validator: _required,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => onCategoryChanged(value!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: statuses
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => onStatusChanged(value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPickDate,
          child: InputDecorator(
            decoration: InputDecoration(labelText: dateLabel),
            child: Text(formattedDate),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: location,
          decoration: const InputDecoration(labelText: 'Location'),
          validator: _required,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: description,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description'),
          validator: _required,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: contactMethod,
                decoration: const InputDecoration(labelText: 'Contact method'),
                items: const ['Phone', 'Email']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => onContactMethodChanged(value!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: contact,
                decoration: const InputDecoration(labelText: 'Contact detail'),
                validator: _required,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(now.year - 3),
    lastDate: DateTime(now.year + 1),
  );
}

String? _required(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return 'Required.';
  }
  return null;
}

const _adminPageSize = 8;

int _pageCount(int totalItems) {
  if (totalItems == 0) {
    return 1;
  }

  return (totalItems / _adminPageSize).ceil();
}

List<T> _pageItems<T>(List<T> items, int page) {
  if (items.isEmpty) {
    return const [];
  }

  final clampedPage = page.clamp(0, _pageCount(items.length) - 1);
  final start = clampedPage * _adminPageSize;
  final end = (start + _adminPageSize).clamp(start, items.length);

  return items.sublist(start, end);
}

const _categories = [
  'Student card',
  'Keys',
  'Wallet',
  'Electronics',
  'Bag',
  'Bottle',
  'Book',
  'Other',
];

const _handoverStatuses = [
  'Keeping safely',
  'Submitted to security',
  'Submitted to faculty office',
  'Submitted to library counter',
];
