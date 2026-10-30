import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../model/character.dart';
import '../model/xml_io.dart';
import 'character_screen.dart';
import 'widgets.dart';
import 'wizard.dart';

class CharactersScreen extends StatelessWidget {
  const CharactersScreen({super.key});

  Future<void> _open(BuildContext context, String path) async {
    final app = context.read<AppState>();
    try {
      final c = await app.loadCharacter(path);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CharacterScreen(character: c)));
      await app.refreshCharacters();
    } catch (e) {
      if (context.mounted) toast(context, '${tr('Erro ao abrir', 'Error opening')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Fichas', 'Characters')),
        actions: [
          IconButton(
            tooltip: tr('Importar ficha (.d35x)', 'Import character (.d35x)'),
            icon: const Icon(Icons.file_open_outlined),
            onPressed: () async {
              final r = await FilePicker.platform.pickFiles(type: FileType.any);
              final path = r?.files.single.path;
              if (path == null) return;
              try {
                await app.importCharacter(path);
                if (context.mounted) toast(context, tr('Ficha importada.', 'Character imported.'));
              } catch (e) {
                if (context.mounted) toast(context, '$e');
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.auto_awesome),
        label: Text(tr('Nova ficha', 'New character')),
        onPressed: () async {
          final c = await Navigator.of(context).push<Character>(MaterialPageRoute<Character>(builder: (_) => const CreationWizard()));
          if (c == null) return;
          final path = await app.saveCharacter(c);
          if (context.mounted) await _open(context, path);
        },
      ),
      body: app.characters.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield_moon_outlined, size: 72, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 12),
                  Text(tr('Nenhuma ficha ainda. Use o assistente para criar um personagem de qualquer nível — inclusive épico.',
                      'No characters yet. Use the wizard to build a character of any level — epic included.'),
                      textAlign: TextAlign.center),
                  if (!app.library.hasDb) ...[
                    const SizedBox(height: 16),
                    Text(
                        tr('Base de regras dos livros não encontrada em ${app.paths.rulesDb.path}. O app funciona com o núcleo SRD embutido; a busca nos livros exige o arquivo rules.sqlite.',
                            'Book database not found at ${app.paths.rulesDb.path}. The app works with the embedded SRD core; book search needs rules.sqlite.'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final f in app.characters)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(f.name.isEmpty ? '?' : f.name.characters.first.toUpperCase())),
                      title: Text(f.name),
                      subtitle: Text(f.summary),
                      onTap: () => _open(context, f.path),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'delete') {
                            if (await confirm(context, tr('Apagar "${f.name}"?', 'Delete "${f.name}"?'))) {
                              await app.deleteCharacter(f.path);
                            }
                          } else if (v == 'export') {
                            final c = await app.loadCharacter(f.path);
                            final out = await FilePicker.platform.saveFile(
                                dialogTitle: tr('Exportar ficha', 'Export character'),
                                fileName: '${c.name.isEmpty ? 'personagem' : c.name}.$characterExt');
                            if (out != null) {
                              await app.saveCharacter(c, path: out);
                              if (context.mounted) toast(context, tr('Exportado.', 'Exported.'));
                            }
                          } else if (v == 'duplicate') {
                            final c = await app.loadCharacter(f.path);
                            final copy = characterFromXml(characterToXml(c).replaceFirst('id="${c.id}"', 'id="x${DateTime.now().millisecondsSinceEpoch}"'));
                            copy.name = '${c.name} (${tr('cópia', 'copy')})';
                            await app.saveCharacter(copy, path: app.pathFor(copy));
                          }
                        },
                        itemBuilder: (c) => [
                          PopupMenuItem(value: 'export', child: Text(tr('Exportar…', 'Export…'))),
                          PopupMenuItem(value: 'duplicate', child: Text(tr('Duplicar', 'Duplicate'))),
                          PopupMenuItem(value: 'delete', child: Text(tr('Apagar', 'Delete'))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
