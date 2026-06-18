import 'package:flutter/material.dart';

const appInkLight = Color(0xFF25221F);
const appPaperLight = Color(0xFFF7F1E7);
const appSurfaceLight = Color(0xFFFFFCF6);
const appSageLight = Color(0xFF355C4B);
const appTeal = Color(0xFF1F6E73);
const appGoldLight = Color(0xFFC8953E);
const appRose = Color(0xFF8E4352);
const appInkDark = Color(0xFFF0E6D8);
const appPaperDark = Color(0xFF101512);
const appSurfaceDark = Color(0xFF1B241F);
const appSageDark = Color(0xFF8DB99E);
const appGoldDark = Color(0xFFD8AC5C);

Color appInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? appInkDark : appInkLight;
Color appPaper(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? appPaperDark
    : appPaperLight;
Color appSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? appSurfaceDark
    : appSurfaceLight;
Color appSage(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? appSageDark
    : appSageLight;
Color appGold(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? appGoldDark
    : appGoldLight;

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final paper = isDark ? appPaperDark : appPaperLight;
  final surface = isDark ? appSurfaceDark : appSurfaceLight;
  final ink = isDark ? appInkDark : appInkLight;
  final sage = isDark ? appSageDark : appSageLight;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: paper,
    colorScheme: ColorScheme.fromSeed(seedColor: sage, brightness: brightness),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
