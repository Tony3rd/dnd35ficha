import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import 'books_selector.dart';
import 'help.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final st = app.settings;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Configurações', 'Settings'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        SectionTitle(tr('Aparência', 'Appearance')),
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(tr('Idioma', 'Language')),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'pt', label: Text('Português')), ButtonSegment(value: 'en', label: Text('English'))],
            selected: {st.language},
            onSelectionChanged: (v) {
              st.language = v.first;
              app.saveSettings();
            },
          ),
          withHelp(tr('Tema escuro', 'Dark theme'), FilterChip(
            label: Text(tr('Tema escuro', 'Dark theme')),
            selected: st.darkMode,
            onSelected: (v) {
              st.darkMode = v;
              app.saveSettings();
            },
          )),
        ]),
        SectionTitle(tr('Padrões para novas fichas', 'Defaults for new characters')),
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(tr('PV por nível', 'HP per level')),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'average', label: Text(tr('Média', 'Average')), tooltip: fieldHelp(tr('Média', 'Average'))),
              ButtonSegment(value: 'max', label: Text(tr('Máximo', 'Max')), tooltip: fieldHelp(tr('Máximo', 'Max'))),
              ButtonSegment(value: 'roll', label: Text(tr('Rolar', 'Roll')), tooltip: fieldHelp(tr('Rolar', 'Roll'))),
            ],
            selected: {st.hpMethod},
            onSelectionChanged: (v) {
              st.hpMethod = v.first;
              app.saveSettings();
            },
          ),
          Text(tr('Compra de pontos', 'Point buy')),
          NumStepper(value: st.pointBuy, min: 0, max: 100, onChanged: (v) {
            st.pointBuy = v.toInt();
            app.saveSettings();
          }),
        ]),
        const SizedBox(height: 8),
        BooksSelector(
          selected: st.defaultBooks,
          policy: st.defaultVersionPolicy,
          onChanged: (b, p) {
            st.defaultBooks = b;
            st.defaultVersionPolicy = p;
            app.saveSettings();
          },
        ),
        SectionTitle(tr('Dados e base de regras', 'Data & rules database')),
        ListTile(
          leading: Icon(app.paths.portable ? Icons.usb : Icons.folder),
          title: Text(app.paths.root.path),
          subtitle: Text(app.paths.portable
              ? tr('Modo portátil: tudo fica ao lado do executável (pendrive/HD externo).', 'Portable mode: everything lives next to the executable (USB/external drive).')
              : tr('Pasta do usuário (a pasta do executável não é gravável).', 'User folder (the executable folder is not writable).')),
        ),
        ListTile(
          leading: Icon(app.library.hasDb ? Icons.check_circle : Icons.error_outline,
              color: app.library.hasDb ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error),
          title: Text(app.library.hasDb
              ? tr('Base de regras carregada: ${app.library.books.where((b) => !b.homebrew).length} livros',
                  'Rules database loaded: ${app.library.books.where((b) => !b.homebrew).length} books')
              : tr('Base de regras ausente (rules.sqlite)', 'Rules database missing (rules.sqlite)')),
          subtitle: Text(app.library.dbError ?? app.paths.rulesDb.path),
          trailing: Wrap(spacing: 8, children: [
            OutlinedButton(
              onPressed: () async {
                final r = await FilePicker.platform.pickFiles(type: FileType.any, dialogTitle: tr('Escolher rules.sqlite', 'Choose rules.sqlite'));
                final p = r?.files.single.path;
                if (p == null) return;
                app.library.dispose();
                await File(p).copy(app.paths.rulesDb.path);
                await app.reloadRules();
                if (context.mounted) toast(context, tr('Base importada.', 'Database imported.'));
              },
              child: Text(tr('Importar base…', 'Import database…')),
            ),
            OutlinedButton(onPressed: () => app.reloadRules(), child: Text(tr('Recarregar', 'Reload'))),
          ]),
        ),
        SectionTitle(tr('Sobre', 'About')),
        ListTile(
          title: const Text('Grimório 3.5 — v0.1'),
          subtitle: Text(tr(
              'Gerenciador de fichas de D&D 3.5. Regras do núcleo baseadas no SRD 3.5 (Open Game License v1.0a). '
                  'A base de livros é gerada localmente a partir dos seus próprios PDFs e não é distribuída com o app; '
                  'somente livros homebrew podem ser exportados.',
              'D&D 3.5 character manager. Core rules based on the 3.5 SRD (Open Game License v1.0a). '
                  'The book database is built locally from your own PDFs and is not distributed with the app; '
                  'only homebrew books can be exported.')),
        ),
      ]),
    );
  }
}
