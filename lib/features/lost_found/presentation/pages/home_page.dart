import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_page_shell.dart';
import '../../data/services/supabase_found_item_service.dart';
import '../../data/services/supabase_lost_item_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _lostService = SupabaseLostItemService();
  final _foundService = SupabaseFoundItemService();

  late Future<List<LostItemReport>> _recentLostFuture;
  late Future<List<FoundItemReport>> _recentFoundFuture;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _recentLostFuture = _lostService.fetchOpenReports(page: 0, pageSize: 5);
    _recentFoundFuture = _foundService.fetchOpenReports(page: 0, pageSize: 5);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _refresh({bool silent = false}) {
    setState(() {
      _recentLostFuture = _lostService.fetchOpenReports(page: 0, pageSize: 5);
      _recentFoundFuture = _foundService.fetchOpenReports(page: 0, pageSize: 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      currentRoute: AppRoutes.home,
      title: 'Home',
      subtitle: 'Campus lost and found overview',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = ResponsiveBreakpoints.isDesktop(
            constraints.maxWidth,
          );

          if (isDesktop) {
            return Column(
              children: [
                _WelcomeBanner(onRefresh: _refresh),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _QuickActions(
                        onReportLost: () => context.go(AppRoutes.lost),
                        onReportFound: () => context.go(AppRoutes.found),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: _HowItWorks()),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _RecentLostSection(future: _recentLostFuture),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _RecentFoundSection(future: _recentFoundFuture),
                    ),
                  ],
                ),
              ],
            );
          }

          return Column(
            children: [
              _WelcomeBanner(onRefresh: _refresh),
              const SizedBox(height: 20),
              _QuickActions(
                onReportLost: () => context.go(AppRoutes.lost),
                onReportFound: () => context.go(AppRoutes.found),
              ),
              const SizedBox(height: 20),
              _RecentLostSection(future: _recentLostFuture),
              const SizedBox(height: 20),
              _RecentFoundSection(future: _recentFoundFuture),
              const SizedBox(height: 20),
              _HowItWorks(),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome Banner
// ---------------------------------------------------------------------------

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to ReFind UTeM',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Help the UTeM family reunite with their belongings. '
                  'Report lost items or post what you have found around campus.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Actions
// ---------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onReportLost,
    required this.onReportFound,
  });

  final VoidCallback onReportLost;
  final VoidCallback onReportFound;

  @override
  Widget build(BuildContext context) {
    return _HomeSection(
      title: 'Quick actions',
      child: Column(
        children: [
          _ActionCard(
            icon: Icons.search_rounded,
            title: 'Report lost item',
            description:
                'Lost something on campus? Let others help you find it.',
            buttonLabel: 'Report lost',
            onPressed: onReportLost,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.inventory_2_rounded,
            title: 'Report found item',
            description:
                'Found something? Post it so the owner can claim it back.',
            buttonLabel: 'Report found',
            onPressed: onReportFound,
            color: AppColors.green,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactLayout = constraints.maxWidth < 430;
        final content = _ActionCardContent(
          icon: icon,
          title: title,
          description: description,
          color: color,
        );
        final button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            minimumSize: Size(useCompactLayout ? double.infinity : 0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: Text(
            buttonLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: useCompactLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content, const SizedBox(height: 14), button],
                )
              : Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 14),
                    button,
                  ],
                ),
        );
      },
    );
  }
}

class _ActionCardContent extends StatelessWidget {
  const _ActionCardContent({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedInk,
                  height: 1.35,
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

// ---------------------------------------------------------------------------
// Recent Lost Items
// ---------------------------------------------------------------------------

class _RecentLostSection extends StatelessWidget {
  const _RecentLostSection({required this.future});

  final Future<List<LostItemReport>> future;

  @override
  Widget build(BuildContext context) {
    return _HomeSection(
      title: 'Recent lost items',
      trailing: TextButton.icon(
        onPressed: () => context.go(AppRoutes.lost),
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: const Text('View all'),
      ),
      child: FutureBuilder<List<LostItemReport>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingIndicator();
          }

          if (snapshot.hasError) {
            return _ErrorMessage(
              message: AppErrorMapper.friendly(snapshot.error!),
            );
          }

          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const _EmptyMessage(text: 'No open lost item reports yet.');
          }

          return Column(
            children: [
              for (var i = 0; i < reports.length; i++) ...[
                _LostItemTile(report: reports[i]),
                if (i < reports.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LostItemTile extends StatelessWidget {
  const _LostItemTile({required this.report});

  final LostItemReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: report.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      report.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.category} · ${report.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DateChip(date: report.lostDate),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Found Items
// ---------------------------------------------------------------------------

class _RecentFoundSection extends StatelessWidget {
  const _RecentFoundSection({required this.future});

  final Future<List<FoundItemReport>> future;

  @override
  Widget build(BuildContext context) {
    return _HomeSection(
      title: 'Recent found items',
      trailing: TextButton.icon(
        onPressed: () => context.go(AppRoutes.found),
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: const Text('View all'),
      ),
      child: FutureBuilder<List<FoundItemReport>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingIndicator();
          }

          if (snapshot.hasError) {
            return _ErrorMessage(
              message: AppErrorMapper.friendly(snapshot.error!),
            );
          }

          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const _EmptyMessage(text: 'No open found item reports yet.');
          }

          return Column(
            children: [
              for (var i = 0; i < reports.length; i++) ...[
                _FoundItemTile(report: reports[i]),
                if (i < reports.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FoundItemTile extends StatelessWidget {
  const _FoundItemTile({required this.report});

  final FoundItemReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: report.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      report.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.green,
                        size: 20,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.green,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.category} · ${report.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DateChip(date: report.foundDate),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// How It Works
// ---------------------------------------------------------------------------

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return _HomeSection(
      title: 'How it works',
      child: Column(
        children: const [
          _StepItem(
            step: '1',
            title: 'Report',
            description:
                'Lost something? Submit a report with details and a photo.',
          ),
          SizedBox(height: 14),
          _StepItem(
            step: '2',
            title: 'Browse',
            description: 'Check found items posted by others around campus.',
          ),
          SizedBox(height: 14),
          _StepItem(
            step: '3',
            title: 'Connect',
            description:
                'Contact the finder or owner through the listed contact method.',
          ),
          SizedBox(height: 14),
          _StepItem(
            step: '4',
            title: 'Reunite',
            description: 'Verify ownership and get your item back safely.',
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.step,
    required this.title,
    required this.description,
  });

  final String step;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
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
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (trailing != null) ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    final label = switch (diff) {
      0 => 'Today',
      1 => 'Yesterday',
      _ when diff < 7 => '${diff}d ago',
      _ => '${(diff / 7).floor()}w ago',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.mutedInk,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.mutedInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
