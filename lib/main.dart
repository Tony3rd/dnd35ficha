import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'i18n.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  app.init();
  runApp(ChangeNotifierProvider.value(value: app, child: const GrimorioApp()));
}

class GrimorioApp extends StatelessWidget {
  const GrimorioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dark = app.ready ? app.settings.darkMode : true;
    return MaterialApp(
      title: 'Grimório 3.5',
      debugShowCheckedModeBanner: false,
      theme: GrimTheme.build(dark),
      locale: Locale(Lang.code),
      supportedLocales: const [Locale('pt'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: app.error != null
          ? Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: SelectableText(app.error!)))
          : !app.ready
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : const HomeShell(),
    );
  }
}
