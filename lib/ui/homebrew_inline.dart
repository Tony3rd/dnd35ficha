import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../i18n.dart';
import 'homebrew_screen.dart';
import 'widgets.dart';

/// Cria uma entrada homebrew sem sair da tela atual (usado nas etapas do
/// assistente de criação). Pergunta em qual livro homebrew salvar (ou cria um
/// novo), abre o editor e, ao salvar, libera o livro na ficha [ctl].
Future<LibEntry?> createHomebrewInline(BuildContext context, CharacterController ctl, String kind,
    {Map<String, dynamic>? data, String name = ''}) async {
  final app = ctl.app;
  String? bookId;
  final books = app.library.homebrew;
  if (books.length == 1) {
    bookId = books.first.id;
  } else {
    bookId = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(tr('Salvar em qual livro homebrew?', 'Save to which homebrew book?')),
        children: [
          for (final b in books)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, b.id),
              child: ListTile(leading: const Icon(Icons.auto_fix_high), title: Text(b.title), subtitle: Text(b.id)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, ''),
            child: ListTile(leading: const Icon(Icons.add), title: Text(tr('Novo livro homebrew…', 'New homebrew book…'))),
          ),
        ],
      ),
    );
  }
  if (bookId == null || !context.mounted) return null;
  if (bookId.isEmpty || books.isEmpty) {
    final b = await editBookInfo(context, null);
    if (b == null || !context.mounted) return null;
    if (app.library.book(b.id) != null) {
      toast(context, tr('Já existe um livro com a abreviação ${b.id}.', 'A book with abbreviation ${b.id} already exists.'));
      return null;
    }
    await app.saveHomebrew(b);
    bookId = b.id;
  }
  if (!context.mounted) return null;
  final e = await Navigator.of(context).push<LibEntry>(MaterialPageRoute<LibEntry>(
      builder: (_) => EntryEditor(entry: LibEntry(kind: kind, name: name, book: bookId!, homebrew: true, data: data))));
  if (e == null) return null;
  final book = app.library.homebrew.firstWhere((b) => b.id == bookId);
  book.entries.add(e);
  await app.saveHomebrew(book);
  ctl.update((x) {
    if (x.allowedBooks != null) x.allowedBooks = {...x.allowedBooks!, bookId!};
  });
  return e;
}

/// Botão padrão "Criar … homebrew".
class HomebrewCreateButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final Future<void> Function() onPressed;
  const HomebrewCreateButton({super.key, required this.label, required this.onPressed, this.tooltip = ''});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip.isEmpty
            ? tr('Cria a entrada num livro homebrew seu; ela passa a valer para esta ficha.',
                'Creates the entry in one of your homebrew books; it becomes available to this character.')
            : tooltip,
        child: OutlinedButton.icon(icon: const Icon(Icons.auto_fix_high, size: 18), label: Text(label), onPressed: onPressed),
      );
}
