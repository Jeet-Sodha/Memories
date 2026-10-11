import 'package:flutter/material.dart';
import '../state/memory_store.dart';
import '../widgets/animations.dart';
import '../widgets/bottom_nav.dart';
import 'create_memory_screen.dart';
import 'explore_screen.dart';
import 'memories_screen.dart';
import 'profile_screen.dart';

/// The 4-tab shell shown after login.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => memoryStore.load());
  }

  late final List<Widget> _tabs = [
    ExploreScreen(onCreateTap: () => _goTo(2)),
    MemoriesScreen(onCreateTap: () => _goTo(2)),
    CreateMemoryScreen(onCreated: () => _goTo(0)),
    const ProfileScreen(),
  ];

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab alive (the map doesn't reload).
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            TabFade(active: i == _index, child: _tabs[i]),
        ],
      ),
      bottomNavigationBar: BottomNav(currentIndex: _index, onTap: _goTo),
    );
  }
}
