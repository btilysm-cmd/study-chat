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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学习问答',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D6FD6)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D6FD6),
          brightness: Brightness.dark,
        ),
      ),
      home: HomeScreen(state: state),
    );
  }
}
