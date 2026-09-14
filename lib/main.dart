import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'services.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  runApp(ChangeNotifierProvider(
      create: (_) => AppState(store)..initialize(),
      child: const PulseMeshApp()));
}

class PulseMeshApp extends StatelessWidget {
  const PulseMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    const text = Color(0xffcdd6f4);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pulse Mesh',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff1e1e2e),
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          surface: Color(0xff1e1e2e),
          primary: Color(0xffcba6f7),
          secondary: Color(0xff94e2d5),
          onSurface: text,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: text, fontSize: 14, height: 1.35),
          bodySmall: TextStyle(color: Color(0xffa6adc8), fontSize: 12),
          titleLarge: TextStyle(
              color: text,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0),
          titleMedium:
              TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xff181825),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xffcba6f7))),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FocusPage(),
      const CardsPage(),
      const StreakPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        backgroundColor: const Color(0xff181825),
        indicatorColor: const Color(0xff313244),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bolt_rounded), label: 'Focus'),
          NavigationDestination(
              icon: Icon(Icons.style_outlined), label: 'Cards'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), label: 'Streak'),
        ],
      ),
    );
  }
}
