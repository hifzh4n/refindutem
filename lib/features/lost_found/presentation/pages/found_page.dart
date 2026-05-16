import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_page_shell.dart';
import '../../data/services/supabase_found_item_service.dart';
import '../widgets/report_browse_scaffold.dart';
import '../widgets/report_image_preview.dart';

class FoundPage extends StatefulWidget {
  const FoundPage({super.key});

  @override
  State<FoundPage> createState() => _FoundPageState();
}

class _FoundPageState extends State<FoundPage> {
  static const _categories = [
    'Student card',
    'Keys',
    'Wallet',
    'Electronics',
    'Bag',
    'Bottle',
    'Book',
    'Other',
  ];

  static const _handoverStatuses = [
    'Keeping safely',
    'Submitted to security',
    'Submitted to faculty office',
    'Submitted to library counter',
  ];

  static const _contactMethods = ['Phone', 'Email'];
  static const _openReportsPageSize = SupabaseFoundItemService.defaultPageSize;

  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _service = SupabaseFoundItemService();

  TextEditingController? _campusSearchControllerValue;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _selectedImageExtension;
  String? _selectedImageContentType;
  DateTime? _foundDate;
  String _category = _categories.first;
  String _campusCategoryFilter = 'All';
  String _handoverStatus = _handoverStatuses.first;
  String _contactMethod = _contactMethods.first;
  bool _isSubmitting = false;
  bool _isLoadingMoreOpenReports = false;
  bool _hasMoreOpenReports = true;
  int _openReportsPage = 0;
  Timer? _openReportsPollTimer;
  Future<List<FoundItemReport>>? _historyFutureValue;
  Future<List<FoundItemReport>>? _openReportsFutureValue;

  Future<List<FoundItemReport>> get _historyFuture =>
      _historyFutureValue ??= _service.fetchMyReports();

  Future<List<FoundItemReport>> get _openReportsFuture =>
      _openReportsFutureValue ??= _service.fetchOpenReports(
        page: 0,
        pageSize: _openReportsPageSize,
      );

  TextEditingController get _campusSearchController {
    return _campusSearchControllerValue ??= TextEditingController()
      ..addListener(_handleCampusSearchChanged);
  }

  set _historyFuture(Future<List<FoundItemReport>> value) {
    _historyFutureValue = value;
  }

  set _openReportsFuture(Future<List<FoundItemReport>> value) {
    _openReportsFutureValue = value;
  }

  @override
  void initState() {
    super.initState();
    _openReportsPollTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshOpenReports(silent: true),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _openReportsPollTimer?.cancel();
    _campusSearchControllerValue
      ?..removeListener(_handleCampusSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleCampusSearchChanged() {
    setState(() {});
  }

  Future<void> _refreshOpenReports({bool silent = false}) async {
    try {
      final reports = await _service.fetchOpenReports(
        page: 0,
        pageSize: _openReportsPageSize,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _openReportsPage = 0;
        _hasMoreOpenReports = reports.length == _openReportsPageSize;
        _openReportsFuture = Future.value(reports);
      });
    } catch (error) {
      if (mounted && !silent) {
        _showMessage(_friendlyError(error), isError: true);
      }
    }
  }

  Future<void> _loadMoreOpenReports(
    List<FoundItemReport> currentReports,
  ) async {
    if (_isLoadingMoreOpenReports || !_hasMoreOpenReports) {
      return;
    }

    setState(() => _isLoadingMoreOpenReports = true);

    try {
      final nextPage = _openReportsPage + 1;
      final nextReports = await _service.fetchOpenReports(
        page: nextPage,
        pageSize: _openReportsPageSize,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _openReportsPage = nextPage;
        _hasMoreOpenReports = nextReports.length == _openReportsPageSize;
        _openReportsFuture = Future.value([...currentReports, ...nextReports]);
      });
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMoreOpenReports = false);
      }
    }
  }

  Future<void> _pickFoundDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _foundDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => _foundDate = picked);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) {
      return;
    }

    setState(() {
      _selectedImageBytes = file.bytes;
      _selectedImageName = file.name;
      _selectedImageExtension = file.extension ?? 'jpg';
      _selectedImageContentType = _contentTypeFor(file.extension);
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedImageExtension = null;
      _selectedImageContentType = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_foundDate == null) {
      _showMessage('Select the date you found the item.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _service.reportFoundItem(
        itemName: _itemNameController.text,
        category: _category,
        foundDate: _foundDate!,
        location: _locationController.text,
        description: _descriptionController.text,
        handoverStatus: _handoverStatus,
        contactMethod: _contactMethod,
        imageBytes: _selectedImageBytes,
        imageExtension: _selectedImageExtension,
        imageContentType: _selectedImageContentType,
      );

      if (!mounted) {
        return;
      }

      _formKey.currentState?.reset();
      _itemNameController.clear();
      _locationController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
        _selectedImageExtension = null;
        _selectedImageContentType = null;
        _foundDate = null;
        _category = _categories.first;
        _handoverStatus = _handoverStatuses.first;
        _contactMethod = _contactMethods.first;
        _historyFuture = _service.fetchMyReports();
        _openReportsPage = 0;
        _hasMoreOpenReports = true;
        _openReportsFuture = _service.fetchOpenReports(
          page: 0,
          pageSize: _openReportsPageSize,
        );
      });
      _showMessage('Found item report submitted.');
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('found_item_reports')) {
      return 'Found item reports are not configured yet. Please run the database setup.';
    }

    return AppErrorMapper.friendly(error);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primaryDark : AppColors.green,
      ),
    );
  }

  String _contentTypeFor(String? extension) {
    return switch (extension?.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      currentRoute: AppRoutes.found,
      title: 'Found',
      subtitle: 'Post items discovered around campus',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = ResponsiveBreakpoints.isDesktop(
            constraints.maxWidth,
          );

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _reportForm(context),
                      const SizedBox(height: 20),
                      _reportHistory(context),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _otherReports(context),
                      const SizedBox(height: 20),
                      _reportGuidance(context),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _reportForm(context),
              const SizedBox(height: 20),
              _reportHistory(context),
              const SizedBox(height: 20),
              _otherReports(context),
              const SizedBox(height: 20),
              _reportGuidance(context),
            ],
          );
        },
      ),
    );
  }

  Widget _reportForm(BuildContext context) {
    return _FoundSection(
      title: 'Report found item',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _itemNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'Student card, keys, tumbler...',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (value) => _required(value, 'Item name'),
            ),
            const SizedBox(height: 16),
            _ResponsivePair(
              first: DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                selectedItemBuilder: (context) =>
                    _categories.map(_dropdownSelectedLabel).toList(),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _category = value!),
              ),
              second: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _isSubmitting ? null : _pickFoundDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date found',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(
                    _foundDate == null
                        ? 'Select date'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(_foundDate!),
                    style: TextStyle(
                      color: _foundDate == null
                          ? AppColors.mutedInk
                          : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Found location',
                hintText: 'Library, FTKIP cafe, Main Hall...',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (value) => _required(value, 'Found location'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Color, brand, marks, stickers, condition...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              validator: (value) => _required(value, 'Description'),
            ),
            const SizedBox(height: 16),
            _ImagePickerField(
              imageBytes: _selectedImageBytes,
              imageName: _selectedImageName,
              onPick: _isSubmitting ? null : _pickImage,
              onRemove: _isSubmitting ? null : _removeImage,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _handoverStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Handover status',
                prefixIcon: Icon(Icons.volunteer_activism_outlined),
              ),
              selectedItemBuilder: (context) =>
                  _handoverStatuses.map(_dropdownSelectedLabel).toList(),
              items: _handoverStatuses
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _handoverStatus = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _contactMethod,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Contact preference',
                helperText:
                    'We will use the matching email or phone from your profile.',
                prefixIcon: Icon(Icons.contact_phone_outlined),
              ),
              selectedItemBuilder: (context) =>
                  _contactMethods.map(_dropdownSelectedLabel).toList(),
              items: _contactMethods
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(method, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _contactMethod = value!),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportGuidance(BuildContext context) {
    return _FoundSection(
      title: 'Owner handover tips',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuidanceItem(
            icon: Icons.fact_check_rounded,
            title: 'Verify before returning',
            text:
                'Ask the claimant to describe details that are not visible in the listing.',
          ),
          const SizedBox(height: 18),
          _GuidanceItem(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Use official counters',
            text:
                'For valuable items, hand them to security, library, or faculty office.',
          ),
          const SizedBox(height: 18),
          _GuidanceItem(
            icon: Icons.privacy_tip_rounded,
            title: 'Protect private details',
            text:
                'Do not post full student IDs, card numbers, passwords, or sensitive contents.',
          ),
        ],
      ),
    );
  }

  Widget _reportHistory(BuildContext context) {
    return _FoundSection(
      title: 'Report history',
      child: FutureBuilder<List<FoundItemReport>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _HistoryError(
              message: _friendlyError(snapshot.error!),
              onRetry: () =>
                  setState(() => _historyFuture = _service.fetchMyReports()),
            );
          }

          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return _EmptyHistoryText(
              text: 'Your submitted found item reports will appear here.',
            );
          }

          return Column(
            children: [
              for (var index = 0; index < reports.length; index++) ...[
                _FoundReportHistoryTile(
                  report: reports[index],
                  onMarkSolved: reports[index].status == 'open'
                      ? () => _markFoundReportSolved(reports[index])
                      : null,
                ),
                if (index != reports.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _otherReports(BuildContext context) {
    return _FoundSection(
      title: 'Found around campus',
      child: FutureBuilder<List<FoundItemReport>>(
        future: _openReportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _HistoryError(
              message: _friendlyError(snapshot.error!),
              onRetry: () => setState(() {
                _openReportsPage = 0;
                _hasMoreOpenReports = true;
                _openReportsFuture = _service.fetchOpenReports(
                  page: 0,
                  pageSize: _openReportsPageSize,
                );
              }),
            );
          }

          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const _EmptyHistoryText(
              text: 'No other open found reports yet.',
            );
          }

          final filteredReports = _filterCampusReports(reports);

          return ReportBrowseScaffold(
            searchController: _campusSearchController,
            categories: const ['All', ..._categories],
            selectedCategory: _campusCategoryFilter,
            onCategoryChanged: (value) =>
                setState(() => _campusCategoryFilter = value),
            totalCount: reports.length,
            visibleCount: filteredReports.length,
            emptyText: 'No open found reports match your filters.',
            children: [
              ...filteredReports.map(
                (report) =>
                    _FoundReportHistoryTile(report: report, compact: true),
              ),
              if (_hasMoreOpenReports)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingMoreOpenReports
                        ? null
                        : () => _loadMoreOpenReports(reports),
                    icon: _isLoadingMoreOpenReports
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      _isLoadingMoreOpenReports
                          ? 'Loading...'
                          : 'Load more reports',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<FoundItemReport> _filterCampusReports(List<FoundItemReport> reports) {
    final query = _campusSearchController.text.trim().toLowerCase();

    return reports.where((report) {
      final matchesCategory =
          _campusCategoryFilter == 'All' ||
          report.category == _campusCategoryFilter;
      final searchable = [
        report.itemName,
        report.category,
        report.location,
        report.description,
        report.handoverStatus,
        report.contactMethod,
        report.contactDetail,
      ].join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || searchable.contains(query);

      return matchesCategory && matchesQuery;
    }).toList();
  }

  Future<void> _markFoundReportSolved(FoundItemReport report) async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark report solved?'),
        content: Text(
          'Close "${report.itemName}" once it has been returned to the owner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Mark solved'),
          ),
        ],
      ),
    );

    if (shouldClose != true) {
      return;
    }

    try {
      await _service.markReportSolved(report.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _historyFuture = _service.fetchMyReports();
        _openReportsPage = 0;
        _hasMoreOpenReports = true;
        _openReportsFuture = _service.fetchOpenReports(
          page: 0,
          pageSize: _openReportsPageSize,
        );
      });
      _showMessage('Found report marked as solved.');
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error), isError: true);
      }
    }
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required.';
    }

    return null;
  }

  Widget _dropdownSelectedLabel(String value) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _FoundSection extends StatelessWidget {
  const _FoundSection({required this.title, required this.child});

  final String title;
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
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }

        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.imageBytes,
    required this.imageName,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? imageBytes;
  final String? imageName;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 74,
              height: 74,
              color: AppColors.surfaceAlt,
              child: hasImage
                  ? Image.memory(imageBytes!, fit: BoxFit.cover)
                  : const Icon(
                      Icons.image_outlined,
                      color: AppColors.mutedInk,
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item image',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasImage
                      ? imageName ?? 'Selected image'
                      : 'Add a clear photo of the found item.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (hasImage)
            IconButton(
              tooltip: 'Remove image',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            )
          else
            IconButton(
              tooltip: 'Add image',
              onPressed: onPick,
              icon: const Icon(Icons.add_photo_alternate_rounded),
            ),
        ],
      ),
    );
  }
}

class _GuidanceItem extends StatelessWidget {
  const _GuidanceItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedInk,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FoundReportHistoryTile extends StatelessWidget {
  const _FoundReportHistoryTile({
    required this.report,
    this.compact = false,
    this.onMarkSolved,
  });

  final FoundItemReport report;
  final bool compact;
  final VoidCallback? onMarkSolved;

  @override
  Widget build(BuildContext context) {
    final foundDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(report.foundDate);

    if (compact) {
      return _FoundCompactReportTile(report: report, foundDate: foundDate);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.imageUrl != null && report.imageUrl!.isNotEmpty) ...[
            ReportImagePreview(
              imageUrl: report.imageUrl!,
              title: report.itemName,
              compact: compact,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  report.itemName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(status: report.status),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _HistoryMeta(
                icon: Icons.category_outlined,
                text: report.category,
              ),
              _HistoryMeta(icon: Icons.event_rounded, text: foundDate),
              _HistoryMeta(icon: Icons.place_outlined, text: report.location),
              _HistoryMeta(
                icon: Icons.volunteer_activism_outlined,
                text: report.handoverStatus,
              ),
              _HistoryMeta(
                icon: Icons.contact_phone_outlined,
                text: _contactLabel(report.contactMethod, report.contactDetail),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _HistoryDescription(
            text: report.description,
            maxLines: compact ? 2 : 3,
          ),
          if (onMarkSolved != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onMarkSolved,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Mark solved'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FoundCompactReportTile extends StatelessWidget {
  const _FoundCompactReportTile({
    required this.report,
    required this.foundDate,
  });

  final FoundItemReport report;
  final String foundDate;

  @override
  Widget build(BuildContext context) {
    final imageUrl = report.imageUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactReportThumb(imageUrl: imageUrl, title: report.itemName),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        report.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(status: report.status),
                  ],
                ),
                const SizedBox(height: 10),
                _CompactMetaGrid(
                  items: [
                    _HistoryMeta(
                      icon: Icons.category_outlined,
                      text: report.category,
                    ),
                    _HistoryMeta(icon: Icons.event_rounded, text: foundDate),
                    _HistoryMeta(
                      icon: Icons.place_outlined,
                      text: report.location,
                    ),
                    _HistoryMeta(
                      icon: Icons.volunteer_activism_outlined,
                      text: report.handoverStatus,
                    ),
                    _HistoryMeta(
                      icon: Icons.contact_phone_outlined,
                      text: _contactLabel(
                        report.contactMethod,
                        report.contactDetail,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _HistoryDescription(text: report.description, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _contactLabel(String method, String detail) {
  final normalizedMethod = method.trim();
  final normalizedDetail = detail.trim();

  if (normalizedDetail.isEmpty) {
    return 'Contact not provided';
  }

  if (normalizedMethod.isEmpty) {
    return normalizedDetail;
  }

  return '$normalizedMethod: $normalizedDetail';
}

class _CompactReportThumb extends StatelessWidget {
  const _CompactReportThumb({required this.imageUrl, required this.title});

  final String? imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.mutedInk,
        ),
      );
    }

    return SizedBox(
      width: 88,
      height: 88,
      child: ReportImagePreview(
        imageUrl: imageUrl!,
        title: title,
        compact: true,
      ),
    );
  }
}

class _CompactMetaGrid extends StatelessWidget {
  const _CompactMetaGrid({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 360
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final item in items) SizedBox(width: itemWidth, child: item),
          ],
        );
      },
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _EmptyHistoryText extends StatelessWidget {
  const _EmptyHistoryText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.mutedInk,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _HistoryMeta extends StatelessWidget {
  const _HistoryMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.mutedInk),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryDescription extends StatelessWidget {
  const _HistoryDescription({required this.text, required this.maxLines});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.notes_rounded, size: 16, color: AppColors.mutedInk),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedInk,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status.isEmpty
        ? 'Open'
        : '${status[0].toUpperCase()}${status.substring(1)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
