class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  static const tablet = 700.0;
  static const desktop = 1024.0;

  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
}
