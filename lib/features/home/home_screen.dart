import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../focus/app_state.dart';
import '../focus/focus_page.dart';
import '../cards/cards_page.dart';
import '../streak/streak_page.dart';

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
        backgroundColor: AppColors.mantle,
        indicatorColor: AppColors.surface,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bolt_rounded), label: 'Focus'),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            label: 'Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Streak',
          ),
        ],
      ),
    );
  }
}
