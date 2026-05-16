import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/app_dependencies.dart';
import '../../app/router/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../features/admin/data/services/supabase_admin_service.dart';

class AppPageShell extends StatelessWidget {
  const AppPageShell({
    required this.currentRoute,
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String currentRoute;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SupabaseAdminService().isAdmin(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data == true;

        if (isAdmin && !_adminAllowedRoutes.contains(currentRoute)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(AppRoutes.admin);
            }
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = ResponsiveBreakpoints.isDesktop(
              constraints.maxWidth,
            );

            return Scaffold(
              backgroundColor: AppColors.surfaceAlt,
              body: SafeArea(
                child: Row(
                  children: [
                    if (isDesktop)
                      _SideNavigation(
                        currentRoute: currentRoute,
                        isAdmin: isAdmin,
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(
                            title: title,
                            subtitle: subtitle,
                            isDesktop: isDesktop,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1100,
                                ),
                                child:
                                    isAdmin &&
                                        !_adminAllowedRoutes.contains(
                                          currentRoute,
                                        )
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : child,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: isDesktop
                  ? null
                  : _BottomNavigation(
                      currentRoute: currentRoute,
                      isAdmin: isAdmin,
                    ),
            );
          },
        );
      },
    );
  }
}

class PagePlaceholder extends StatelessWidget {
  const PagePlaceholder({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 42),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.mutedInk,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.isDesktop,
  });

  final String title;
  final String subtitle;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 20, 18, 20, 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
          const _TopBarAvatarButton(),
        ],
      ),
    );
  }
}

class _TopBarAvatarButton extends StatefulWidget {
  const _TopBarAvatarButton();

  @override
  State<_TopBarAvatarButton> createState() => _TopBarAvatarButtonState();
}

class _TopBarAvatarButtonState extends State<_TopBarAvatarButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileRepository = AppDependencies.of(context).profileRepository;

    return FutureBuilder(
      future: profileRepository.getProfile(),
      builder: (context, avatarSnapshot) {
        final avatarUrl = avatarSnapshot.data?.avatarUrl;

        return Tooltip(
          message: l10n.profileTooltip,
          child: Semantics(
            button: true,
            label: l10n.profileTooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.go(AppRoutes.profile),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: AppColors.primaryDark,
                          size: 24,
                        )
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.currentRoute, required this.isAdmin});

  final String currentRoute;
  final bool isAdmin;

  Future<void> _signOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutQuestion),
        content: Text(l10n.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final signOut = AppDependencies.of(context).signOut;
    await signOut();

    if (context.mounted) {
      context.go(AppRoutes.landing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: 252,
      color: Colors.white,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppConstants.appName,
            style: GoogleFonts.coiny(fontSize: 28, color: AppColors.ink),
          ),
          const SizedBox(height: 28),
          ..._navItemsFor(isAdmin).map(
            (item) =>
                _NavTile(item: item, isSelected: item.route == currentRoute),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.logout),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.currentRoute, required this.isAdmin});

  final String currentRoute;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final items = _navItemsFor(isAdmin);
    final selectedIndex = items.indexWhere(
      (item) => item.route == currentRoute,
    );

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) => context.go(items[index].route),
      destinations: items
          .map(
            (item) =>
                NavigationDestination(icon: Icon(item.icon), label: item.label),
          )
          .toList(),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.isSelected});

  final _NavItem item;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        selected: isSelected,
        selectedColor: AppColors.primary,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(item.icon),
        title: Text(item.label),
        onTap: () => context.go(item.route),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    this.adminOnly = false,
  });

  final String route;
  final String label;
  final IconData icon;
  final bool adminOnly;
}

const _navItems = [
  _NavItem(route: AppRoutes.home, label: 'Home', icon: Icons.home_rounded),
  _NavItem(route: AppRoutes.lost, label: 'Lost', icon: Icons.search_rounded),
  _NavItem(
    route: AppRoutes.found,
    label: 'Found',
    icon: Icons.inventory_2_rounded,
  ),
  _NavItem(
    route: AppRoutes.profile,
    label: 'Profile',
    icon: Icons.person_rounded,
  ),
  _NavItem(
    route: AppRoutes.admin,
    label: 'Admin',
    icon: Icons.admin_panel_settings_rounded,
    adminOnly: true,
  ),
];

const _adminAllowedRoutes = {AppRoutes.admin, AppRoutes.profile};

List<_NavItem> _navItemsFor(bool isAdmin) {
  if (isAdmin) {
    return [
      _navItems.firstWhere((item) => item.route == AppRoutes.admin),
      _navItems.firstWhere((item) => item.route == AppRoutes.profile),
    ];
  }

  return _navItems.where((item) => !item.adminOnly).toList();
}
