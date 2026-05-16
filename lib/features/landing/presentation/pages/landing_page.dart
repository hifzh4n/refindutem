import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_breakpoints.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDesktop = ResponsiveBreakpoints.isDesktop(width);

          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface,
                  AppColors.surfaceAlt,
                  Color(0xFFFFF3E0),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 56 : 24,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: isDesktop
                        ? const _DesktopLandingLayout()
                        : const _CompactLandingLayout(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DesktopLandingLayout extends StatelessWidget {
  const _DesktopLandingLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 11, child: _LandingContent(isExpanded: true)),
        SizedBox(width: 56),
        Expanded(flex: 9, child: _CampusFinderPanel()),
      ],
    );
  }
}

class _CompactLandingLayout extends StatelessWidget {
  const _CompactLandingLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LandingContent(isExpanded: false),
        SizedBox(height: 34),
        _CampusFinderPanel(),
      ],
    );
  }
}

class _LandingContent extends StatelessWidget {
  const _LandingContent({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
      child: Column(
        crossAxisAlignment: isExpanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LogoMark(),
          const SizedBox(height: 28),
          Text(
            AppConstants.appName,
            textAlign: isExpanded ? TextAlign.left : TextAlign.center,
            style: GoogleFonts.coiny(
              fontSize: isExpanded ? 64 : 46,
              height: 0.98,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              AppConstants.appDescription,
              textAlign: isExpanded ? TextAlign.left : TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.mutedInk,
                fontSize: isExpanded ? 22 : 18,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _AuthActions(isExpanded: isExpanded),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ReFind UTeM logo',
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 8),
                shape: BoxShape.circle,
              ),
            ),
            Positioned(
              right: 25,
              bottom: 24,
              child: Transform.rotate(
                angle: -0.72,
                child: Container(
                  width: 10,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 28,
              right: 29,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthActions extends StatelessWidget {
  const _AuthActions({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final children = [
      Expanded(
        child: FilledButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Log in'),
        ),
      ),
      const SizedBox(width: 14, height: 14),
      Expanded(
        child: OutlinedButton(
          onPressed: () => context.go(AppRoutes.register),
          child: const Text('Register'),
        ),
      ),
    ];

    if (isExpanded) {
      return SizedBox(width: 360, child: Row(children: children));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Log in'),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.register),
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}

class _CampusFinderPanel extends StatelessWidget {
  const _CampusFinderPanel();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = ResponsiveBreakpoints.isTablet(width);

    return AspectRatio(
      aspectRatio: width >= ResponsiveBreakpoints.desktop
          ? 0.9
          : isTablet
          ? 1.35
          : 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 36,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: const [
            Positioned.fill(child: _MapPattern()),
            Align(
              alignment: Alignment.topLeft,
              child: _FoundItemPin(label: 'Keys', color: AppColors.primary),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _FoundItemPin(label: 'Card', color: AppColors.green),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: _FoundItemPin(label: 'Bottle', color: AppColors.gold),
            ),
            Align(alignment: Alignment.center, child: _SearchPulse()),
          ],
        ),
      ),
    );
  }
}

class _MapPattern extends StatelessWidget {
  const _MapPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MapPatternPainter());
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.22)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mainRoute = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.62,
        size.width * 0.28,
        size.height * 0.24,
        size.width * 0.62,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.42,
        size.width * 0.72,
        size.height * 0.72,
        size.width * 0.92,
        size.height * 0.86,
      );

    final secondaryRoute = Path()
      ..moveTo(size.width * 0.18, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.46,
        size.height * 0.45,
        size.width * 0.72,
        size.height * 0.16,
      );

    canvas.drawPath(mainRoute, routePaint);
    canvas.drawPath(secondaryRoute, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FoundItemPin extends StatelessWidget {
  const _FoundItemPin({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.grandstander(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchPulse extends StatelessWidget {
  const _SearchPulse();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
      ),
    );
  }
}
