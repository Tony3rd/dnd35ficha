import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import 'characters_screen.dart';
import 'dice_screen.dart';
import 'homebrew_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final pages = const [CharactersScreen(), LibraryScreen(), HomebrewScreen(), DiceScreen(), SettingsScreen()];
    final dests = [
      (Icons.person_outline, Icons.person, tr('Fichas', 'Characters')),
      (Icons.menu_book_outlined, Icons.menu_book, tr('Biblioteca', 'Library')),
      (Icons.auto_fix_normal_outlined, Icons.auto_fix_high, 'Homebrew'),
      (Icons.casino_outlined, Icons.casino, tr('Dados', 'Dice')),
      (Icons.settings_outlined, Icons.settings, tr('Configurações', 'Settings')),
    ];
    final wide = MediaQuery.of(context).size.width >= 720;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                Icon(Icons.auto_stories, size: 34, color: Theme.of(context).colorScheme.secondary),
                const Text('Grimório 3.5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[index]),
        ]),
      );
    }
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
      ),
    );
  }
}
