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
            ButtonSegment(value: 'all', label: Text(tr('Toda a base', 'Whole database'))),
            ButtonSegment(value: 'some', label: Text(tr('Livros escolhidos', 'Chosen books'))),
          ],
          selected: {all ? 'all' : 'some'},
          onSelectionChanged: (s) => widget.onChanged(s.first == 'all' ? null : (sel.isEmpty ? {...core} : sel), widget.policy),
        ),
        Text(tr('Versões repetidas:', 'Duplicate versions:')),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'ask', label: Text(tr('Perguntar', 'Ask'))),
            ButtonSegment(value: 'newest', label: Text(tr('Mais recente', 'Most recent'))),
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
