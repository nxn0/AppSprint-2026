import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'data/local_store.dart';
import 'features/focus/app_state.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(store)..initialize(),
      child: const PomlyApp(),
    ),
  );
}

class PomlyApp extends StatelessWidget {
  const PomlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pomly',
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
