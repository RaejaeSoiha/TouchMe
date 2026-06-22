import 'package:flutter/material.dart';

/// Breakpoints aligned with Material adaptive layout guidance.
class Responsive {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) => widthOf(context) < compact;
  static bool isMedium(BuildContext context) =>
      widthOf(context) >= compact && widthOf(context) < expanded;
  static bool isExpanded(BuildContext context) => widthOf(context) >= expanded;

  static bool useRail(BuildContext context) => widthOf(context) >= compact;

  static int gridColumns(BuildContext context, {int max = 3}) {
    final width = widthOf(context);
    if (width >= expanded) return max.clamp(1, 3);
    if (width >= medium) return 2;
    return 1;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = widthOf(context);
    if (width >= expanded) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
    if (width >= compact) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }

  static double contentMaxWidth(BuildContext context) {
    if (isExpanded(context)) return 960;
    if (isMedium(context)) return 720;
    return double.infinity;
  }
}

/// Centers and constrains scrollable page content on tablets/desktop/web.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    required this.child,
    this.padding,
    super.key,
  });

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
        child: Padding(
          padding: padding ?? Responsive.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// List tile section header used in settings-style screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.6,
      ),
    ),
  );
}
