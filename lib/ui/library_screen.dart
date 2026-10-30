import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../data/library.dart';
import '../i18n.dart';
import 'widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Biblioteca', 'Library')),
          bottom: TabBar(tabs: [
            Tab(text: tr('Buscar', 'Search')),
            Tab(text: tr('Livros', 'Books')),
          ]),
        ),
        body: const TabBarView(children: [_SearchView(), _BooksView()]),
      ),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();
  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  String q = '';
  final kinds = <String>{};
  final books = <String>{};
  bool fullText = false;
  bool grouped = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lib = app.library;
    final results = (q.isEmpty && kinds.isEmpty && books.isEmpty)
        ? <LibEntry>[]
        : lib.search(q, kinds: kinds.isEmpty ? null : kinds, books: books.isEmpty ? null : books, limit: 500);
    final pages = fullText && q.isNotEmpty ? lib.searchPages(q, books: books.isEmpty ? null : books) : <PageHit>[];
    // agrupado: um item por nome, listando livros
    final groups = <String, List<LibEntry>>{};
    for (final e in results) {
      groups.putIfAbsent(grouped ? e.key : '${e.key}@${e.book}@${e.page}', () => []).add(e);
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: tr('Nome ou termos (ex.: fireball, "ataque furtivo", cura)', 'Name or terms (e.g. fireball, sneak attack)'),
          ),
          onChanged: (v) => setState(() => q = v),
        ),
      ),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
          FilterChip(label: Text(tr('Texto das páginas', 'Page full text')), selected: fullText, onSelected: (v) => setState(() => fullText = v)),
          const SizedBox(width: 6),
          FilterChip(label: Text(tr('Agrupar versões', 'Group versions')), selected: grouped, onSelected: (v) => setState(() => grouped = v)),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.filter_list, size: 16),
            label: Text(books.isEmpty ? tr('Todos os livros', 'All books') : '${books.length} ${tr('livro(s)', 'book(s)')}'),
            onPressed: () async {
              final sel = await _pickBooks(context, lib.books, books);
              if (sel != null) setState(() => books..clear()..addAll(sel));
            },
          ),
          const SizedBox(width: 6),
          for (final k in allKinds)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                label: Text(kindName(k)),
                selected: kinds.contains(k),
                onSelected: (v) => setState(() => v ? kinds.add(k) : kinds.remove(k)),
              ),
            ),
        ]),
      ),
      if (!lib.hasDb)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
              tr('Base dos livros não encontrada: coloque rules.sqlite em ${app.paths.root.path}. Livros homebrew continuam pesquisáveis.',
                  'Book database not found: put rules.sqlite in ${app.paths.root.path}. Homebrew books remain searchable.'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      Expanded(
        child: ListView(children: [
          if (results.isNotEmpty) SectionTitle('${tr('Entradas', 'Entries')} (${groups.length})'),
          for (final g in groups.values)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 14, child: Text(kindName(g.first.kind).characters.first, style: const TextStyle(fontSize: 12))),
              title: Text(g.first.name),
              subtitle: Text('${kindName(g.first.kind)} · ${g.map((e) => e.sourceLabel).join(' · ')}'
                  '${g.first.summary.isNotEmpty ? '\n${g.first.summary}' : ''}',
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              onTap: () async {
                var e = g.first;
                if (g.length > 1) {
                  final v = await chooseVersion(context, g.map((x) => lib.full(x) ?? x).toList());
                  if (v == null) return;
                  e = v;
                }
                if (context.mounted) showEntry(context, e);
              },
            ),
          if (pages.isNotEmpty) SectionTitle('${tr('Páginas', 'Pages')} (${pages.length})'),
          for (final p in pages)
            ListTile(
              dense: true,
              leading: const Icon(Icons.article_outlined),
              title: Text('${lib.book(p.book)?.title ?? p.book} — p. ${p.page}'),
              subtitle: Text(p.snippet.replaceAll('\n', ' '), maxLines: 3, overflow: TextOverflow.ellipsis),
              onTap: () => _showPage(context, lib, p.book, p.page),
            ),
          if (q.isNotEmpty && results.isEmpty && pages.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(tr('Nada encontrado.', 'Nothing found.')))),
        ]),
      ),
    ]);
  }
}

Future<Set<String>?> _pickBooks(BuildContext context, List<BookInfo> all, Set<String> current) {
  final sel = {...current};
  String f = '';
  return showDialog<Set<String>>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text(tr('Filtrar por livros', 'Filter by books')),
        content: SizedBox(
          width: 520,
          height: 480,
          child: Column(children: [
            TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Filtrar', 'Filter')), onChanged: (v) => setS(() => f = v.toLowerCase())),
            Expanded(
              child: ListView(children: [
                for (final b in all)
                  if (f.isEmpty || b.title.toLowerCase().contains(f) || b.id.toLowerCase().contains(f))
                    CheckboxListTile(
                      dense: true,
                      value: sel.contains(b.id),
                      title: Text('${b.title} (${b.id})'),
                      subtitle: Text('${b.entryCount} ${tr('entradas', 'entries')}${b.homebrew ? ' · homebrew' : ''}'),
                      onChanged: (v) => setS(() => v == true ? sel.add(b.id) : sel.remove(b.id)),
                    ),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, <String>{}), child: Text(tr('Limpar', 'Clear'))),
          FilledButton(onPressed: () => Navigator.pop(c, sel), child: const Text('OK')),
        ],
      ),
    ),
  );
}

void _showPage(BuildContext context, Library lib, String book, int page) {
  showDialog(
    context: context,
    builder: (c) {
      var p = page;
      return StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text('${lib.book(book)?.title ?? book} — p. $p'),
          content: SizedBox(
            width: 680,
            height: 560,
            child: SingleChildScrollView(child: SelectableText(lib.pageText(book, p).isEmpty ? tr('(página sem texto)', '(no text)') : lib.pageText(book, p))),
          ),
          actions: [
            IconButton(onPressed: p > 1 ? () => setS(() => p--) : null, icon: const Icon(Icons.chevron_left)),
            IconButton(onPressed: () => setS(() => p++), icon: const Icon(Icons.chevron_right)),
            FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('Fechar', 'Close'))),
          ],
        ),
      );
    },
  );
}

class _BooksView extends StatefulWidget {
  const _BooksView();
  @override
  State<_BooksView> createState() => _BooksViewState();
}

class _BooksViewState extends State<_BooksView> {
  String f = '';
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final books = app.library.books.where((b) => f.isEmpty || b.title.toLowerCase().contains(f) || b.id.toLowerCase().contains(f)).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Filtrar livros', 'Filter books')),
            onChanged: (v) => setState(() => f = v.toLowerCase())),
      ),
      Expanded(
        child: ListView(children: [
          for (final b in books)
            ListTile(
              leading: Icon(b.homebrew ? Icons.auto_fix_high : Icons.menu_book),
              title: Text(b.title),
              subtitle: Text([
                b.id,
                if (b.publisher.isNotEmpty) b.publisher,
                if (b.setting.isNotEmpty) b.setting,
                if (b.released > 0) '${b.released ~/ 100}',
                '${b.entryCount} ${tr('entradas', 'entries')}',
                if (b.language != 'en') b.language,
              ].join(' · ')),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookContentsScreen(bookId: b.id))),
            ),
        ]),
      ),
    ]);
  }
}

/// Todo o conteúdo de um livro, por tipo, com página.
class BookContentsScreen extends StatefulWidget {
  final String bookId;
  const BookContentsScreen({super.key, required this.bookId});
  @override
  State<BookContentsScreen> createState() => _BookContentsScreenState();
}

class _BookContentsScreenState extends State<BookContentsScreen> {
  String? kind;
  String f = '';
  bool byPage = false;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lib = app.library;
    final info = lib.book(widget.bookId);
    final counts = lib.kindCounts(widget.bookId);
    var entries = lib.entriesOfBook(widget.bookId, kind: kind).where((e) => f.isEmpty || e.name.toLowerCase().contains(f)).toList();
    if (byPage) entries.sort((a, b) => (a.page ?? 0).compareTo(b.page ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(info?.title ?? widget.bookId)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(label: Text('${tr('Tudo', 'All')} (${counts.values.fold<int>(0, (a, b) => a + b)})'), selected: kind == null, onSelected: (_) => setState(() => kind = null)),
            for (final e in counts.entries)
              ChoiceChip(label: Text('${kindName(e.key)} (${e.value})'), selected: kind == e.key, onSelected: (_) => setState(() => kind = e.key)),
            FilterChip(label: Text(tr('Ordenar por página', 'Sort by page')), selected: byPage, onSelected: (v) => setState(() => byPage = v)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Filtrar', 'Filter')),
              onChanged: (v) => setState(() => f = v.toLowerCase())),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (c, i) {
              final e = entries[i];
              return ListTile(
                dense: true,
                title: Text(e.name),
                subtitle: Text('${kindName(e.kind)}${e.page != null ? ' · p. ${e.page}' : ''}${e.summary.isNotEmpty ? ' — ${e.summary}' : ''}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => showEntry(context, e),
              );
            },
          ),
        ),
      ]),
    );
  }
}
