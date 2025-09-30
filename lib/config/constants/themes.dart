import 'package:fluent_ui/fluent_ui.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF03256C);
  static const Color secondaryBlue = Color(0xFF2541B2);
  static const Color accent = Color(0xFF06BEE1);
  static const Color lightBlue = Color(0xFF1768AC);

  static const Color lightBackground = Color(0xFFFCFCFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF5F7FA);
  static const Color lightBorder = Color(0xFFE5E9F0);

  static const Color darkAccent = Color(0xFF06BEE1);
  static const Color darkBackground = Color(0xFF181818);
  static const Color darkSurface = Color(0xFF222222);
  static const Color darkBorder = Color(0xFF333333);
}

// Tema CHIARO
FluentThemeData lightmode = FluentThemeData(
  brightness: Brightness.light,
  accentColor: AppColors.primaryBlue.toAccentColor(),
  scaffoldBackgroundColor: AppColors.lightBackground,
  cardColor: AppColors.lightSurface,
  inactiveColor: AppColors.lightBorder,
  dividerTheme: const DividerThemeData(
    decoration: BoxDecoration(color: AppColors.lightBorder),
  ),
  buttonTheme: ButtonThemeData(
    filledButtonStyle: ButtonStyle(
      backgroundColor: ButtonState.all(AppColors.primaryBlue),
      foregroundColor: ButtonState.all(Colors.white),
      shape: ButtonState.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonStyle: ButtonStyle(
      foregroundColor: ButtonState.all(AppColors.primaryBlue),
      backgroundColor: ButtonState.all(AppColors.lightSurface),
      shape: ButtonState.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
        ),
      ),
    ),
    iconButtonStyle: ButtonStyle(
      foregroundColor: ButtonState.all(AppColors.secondaryBlue),
    ),
  ),
  navigationPaneTheme: NavigationPaneThemeData(
    backgroundColor: AppColors.lightBackground,
    highlightColor: AppColors.primaryBlue,
  ),
  typography: Typography.fromBrightness(
    brightness: Brightness.light,
    color: AppColors.primaryBlue,
  ),
);

// Tema SCURO
FluentThemeData darkmode = FluentThemeData(
  brightness: Brightness.dark,
  accentColor: AppColors.darkAccent.toAccentColor(),
  scaffoldBackgroundColor: AppColors.darkBackground,
  cardColor: AppColors.darkSurface,
  inactiveColor: AppColors.darkBorder,
  dividerTheme: const DividerThemeData(
    decoration: BoxDecoration(color: AppColors.darkBorder),
  ),
  buttonTheme: ButtonThemeData(
    filledButtonStyle: ButtonStyle(
      backgroundColor: ButtonState.all(AppColors.darkAccent),
      foregroundColor: ButtonState.all(AppColors.darkBackground),
      shape: ButtonState.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonStyle: ButtonStyle(
      foregroundColor: ButtonState.all(AppColors.darkAccent),
      backgroundColor: ButtonState.all(AppColors.darkSurface),
      shape: ButtonState.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        ),
      ),
    ),
    iconButtonStyle: ButtonStyle(
      foregroundColor: ButtonState.all(AppColors.darkAccent),
    ),
  ),
  navigationPaneTheme: const NavigationPaneThemeData(
    backgroundColor: AppColors.darkBackground,
    highlightColor: AppColors.darkAccent,
  ),
  typography: Typography.fromBrightness(
    brightness: Brightness.dark,
    color: AppColors.darkAccent,
  ),
);


class AppConstants {
  static const double projectContainerWidth = 900;
  static const double projectContainerHeight = 500;
  static const int maxProjectNameLength = 20;
  static const int projectsPerPage = 3;
  static const Duration animationDuration = Duration(milliseconds: 800);
  static const Duration staggerDelay = Duration(milliseconds: 100);
}

class AppStyles {
  static const double borderRadiusLarge = 24;
  static const double borderRadiusMedium = 16;
  static const double borderRadiusSmall = 12;
  static const double elevationLow = 4;
  static const double elevationMedium = 8;
  static const double elevationHigh = 16;
}
