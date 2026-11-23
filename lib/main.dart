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

  static const _seed = Color(0xFF4C6B4A);

  ThemeData _light() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed).copyWith(
      surface: const Color(0xFFF4F6EC),
      surfaceContainerHighest: const Color(0xFFE2E8D8),
      primaryContainer: const Color(0xFFDCE7D1),
      onSurface: const Color(0xFF1F241C),
      outlineVariant: const Color(0xFFCBD3C2),
    );
    return _base(scheme);
  }

  ThemeData _dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF151A14),
          surfaceContainerHighest: const Color(0xFF2A3228),
          primaryContainer: const Color(0xFF2F3D2C),
          outlineVariant: const Color(0xFF3D473A),
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
