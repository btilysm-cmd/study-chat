import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(Store());
  await state.init();
  runApp(StudyChatApp(state: state));
}

class StudyChatApp extends StatelessWidget {
  const StudyChatApp({super.key, required this.state});

  final AppState state;

  static const _seed = Color(0xFF4D6BFE);

  ThemeData _light() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed).copyWith(
      surface: const Color(0xFFEEF2FA),
      surfaceContainerHighest: const Color(0xFFDFE6F5),
      primaryContainer: const Color(0xFFDCE4FF),
      onSurface: const Color(0xFF0F1A30),
      outlineVariant: const Color(0xFFC6D0E4),
    );
    return _base(scheme);
  }

  ThemeData _dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF0A1222),
          surfaceContainerHighest: const Color(0xFF16203A),
          primaryContainer: const Color(0xFF1B2A4D),
          outlineVariant: const Color(0xFF27334B),
        );
    return _base(scheme);
  }

  ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.onSurface,
        contentTextStyle: TextStyle(color: scheme.surface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 15, height: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学习问答',
      debugShowCheckedModeBanner: false,
      theme: _light(),
      darkTheme: _dark(),
      themeMode: ThemeMode.system,
      home: HomeScreen(state: state),
    );
  }
}
