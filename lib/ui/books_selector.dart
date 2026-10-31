import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/library.dart';
import '../i18n.dart';

/// Seleção de livros permitidos para uma ficha (null = todos) + política de versões.
class BooksSelector extends StatefulWidget {
  final Set<String>? selected;
  final String policy;
  final void Function(Set<String>? books, String policy) onChanged;
  const BooksSelector({super.key, required this.selected, required this.policy, required this.onChanged});
  @override
  State<BooksSelector> createState() => _BooksSelectorState();
}

class _BooksSelectorState extends State<BooksSelector> {
  String filter = '';

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final books = app.library.books;
    final all = widget.selected == null;
    final sel = widget.selected ?? <String>{};
    final core = {'PH', 'DMG', 'MM'};
    final groups = <String, List<BookInfo>>{};
    for (final b in books) {
      final g = b.homebrew ? 'Homebrew' : (b.category.isEmpty ? tr('Outros', 'Other') : b.category);
      groups.putIfAbsent(g, () => []).add(b);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'all',
                label: Text(tr('Toda a base', 'Whole database')),
                tooltip: tr('A ficha pode usar qualquer livro da base e do homebrew.', 'The character may use any book.')),
            ButtonSegment(
                value: 'some',
                label: Text(tr('Livros escolhidos', 'Chosen books')),
                tooltip: tr('Só os livros marcados abaixo aparecem nas escolhas desta ficha.', 'Only the books checked below appear in this character\'s choices.')),
          ],
          selected: {all ? 'all' : 'some'},
          onSelectionChanged: (s) => widget.onChanged(s.first == 'all' ? null : (sel.isEmpty ? {...core} : sel), widget.policy),
        ),
        Text(tr('Versões repetidas:', 'Duplicate versions:')),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'ask',
                label: Text(tr('Perguntar', 'Ask')),
                tooltip: tr('Quando um item existir em mais de um livro, pergunta qual versão usar.', 'Ask which version to use when an item is in several books.')),
            ButtonSegment(
                value: 'newest',
                label: Text(tr('Mais recente', 'Most recent')),
                tooltip: tr('Usa automaticamente a versão do livro mais recente.', 'Automatically use the most recent book.')),
          ],
          selected: {widget.policy},
          onSelectionChanged: (s) => widget.onChanged(widget.selected, s.first),
        ),
      ]),
      if (!all) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Filtrar livros', 'Filter books')),
              onChanged: (v) => setState(() => filter = v.toLowerCase()),
            ),
          ),
          TextButton(onPressed: () => widget.onChanged({...core}, widget.policy), child: Text(tr('Só núcleo', 'Core only'))),
          TextButton(onPressed: () => widget.onChanged({for (final b in books) b.id}, widget.policy), child: Text(tr('Marcar todos', 'Select all'))),
        ]),
        if (books.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(tr('Nenhum livro na base. O núcleo SRD (PH/DMG) está sempre disponível.', 'No books in the database. The SRD core (PH/DMG) is always available.')),
          ),
        for (final g in groups.entries) ...[
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(g.key, style: const TextStyle(fontWeight: FontWeight.bold))),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final b in g.value)
              if (filter.isEmpty || b.title.toLowerCase().contains(filter) || b.id.toLowerCase().contains(filter))
                FilterChip(
                  label: Text('${b.title} (${b.id})', style: const TextStyle(fontSize: 12)),
                  selected: sel.contains(b.id),
                  onSelected: (v) {
                    final n = {...sel};
                    v ? n.add(b.id) : n.remove(b.id);
                    widget.onChanged(n, widget.policy);
                  },
                ),
          ]),
        ],
      ],
    ]);
  }
}

/// Mostra só os livros escolhidos da ficha, com um botão que abre uma janela
/// para adicionar ou remover livros.
class ChosenBooks extends StatelessWidget {
  final Set<String>? selected;
  final String policy;
  final void Function(Set<String>? books, String policy) onChanged;
  const ChosenBooks({super.key, required this.selected, required this.policy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    String title(String id) => app.library.book(id)?.title ?? id;
    final sel = (selected ?? <String>{}).toList()..sort((a, b) => title(a).compareTo(title(b)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (selected == null)
          Chip(avatar: const Icon(Icons.all_inclusive, size: 16), label: Text(tr('Toda a base', 'Whole database')))
        else if (sel.isEmpty)
          Text(tr('Nenhum livro escolhido.', 'No books chosen.'))
        else
          for (final id in sel)
            Tooltip(
              message: '${title(id)} ($id)',
              child: InputChip(
                label: Text(id == title(id) ? id : '${title(id)} ($id)', style: const TextStyle(fontSize: 12)),
                onDeleted: () => onChanged({...selected!}..remove(id), policy),
                deleteButtonTooltipMessage: tr('Remover este livro da ficha', 'Remove this book'),
              ),
            ),
        Tooltip(
          message: tr('Abre uma janela com todos os livros para adicionar novos à ficha.', 'Opens a window with all books to add more.'),
          child: ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: Text(tr('Adicionar livros…', 'Add books…')),
            onPressed: () => showBooksDialog(context, selected: selected, policy: policy, onChanged: onChanged),
          ),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
            '${tr('Versões repetidas', 'Duplicate versions')}: ${policy == 'newest' ? tr('usar a mais recente', 'use most recent') : tr('perguntar', 'ask')}',
            style: Theme.of(context).textTheme.bodySmall),
      ),
    ]);
  }
}

Future<void> showBooksDialog(BuildContext context,
    {required Set<String>? selected, required String policy, required void Function(Set<String>?, String) onChanged}) {
  var sel = selected == null ? null : {...selected};
  var pol = policy;
  return showDialog(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setS) => AlertDialog(
        title: Text(tr('Livros desta ficha', 'Books for this character')),
        content: SizedBox(
          width: 820,
          height: 560,
          child: SingleChildScrollView(
            child: BooksSelector(
              selected: sel,
              policy: pol,
              onChanged: (b, p) => setS(() {
                sel = b;
                pol = p;
              }),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('Cancelar', 'Cancel'))),
          FilledButton(
            onPressed: () {
              onChanged(sel, pol);
              Navigator.pop(d);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}
