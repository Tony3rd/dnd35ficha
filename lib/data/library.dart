// Biblioteca de regras: base SQLite gerada a partir dos livros do usuário
// (tools/dbbuild) + livros homebrew. Toda entrada tem livro e página.
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../engine/defs.dart';
import '../engine/ruleset.dart';
import '../i18n.dart';
import 'homebrew.dart';

class BookInfo {
  final String id, title, publisher, setting, category, language;
  final int released, pages, entryCount;
  final bool homebrew;
  BookInfo({
    required this.id,
    required this.title,
    this.publisher = '',
    this.setting = '',
    this.category = '',
    this.language = 'en',
    this.released = 0,
    this.pages = 0,
    this.entryCount = 0,
    this.homebrew = false,
  });
}

class PageHit {
  final String book;
  final int page;
  final String snippet;
  PageHit(this.book, this.page, this.snippet);
}

class Library {
  Database? _db;
  final List<HomebrewBook> homebrew = [];
  final Map<String, BookInfo> _books = {};
  String? dbError;

  bool get hasDb => _db != null;

  void openDb(File f) {
    _db?.dispose();
    _db = null;
    dbError = null;
    if (!f.existsSync()) return;
    try {
      _db = sqlite3.open(f.path, mode: OpenMode.readOnly);
      _loadBooks();
    } catch (e) {
      dbError = '$e';
      _db = null;
    }
  }

  bool _hasPt = false;
  String get _ptCols => _hasPt ? 'e.name_pt,e.summary_pt' : "'' AS name_pt,'' AS summary_pt";
  String get _ptCols2 => _hasPt ? 'name_pt,summary_pt' : "'' AS name_pt,'' AS summary_pt";

  void _loadBooks() {
    _books.removeWhere((k, v) => !v.homebrew);
    final db = _db;
    if (db == null) return;
    _hasPt = db.select('PRAGMA table_info(entries)').any((r) => r['name'] == 'name_pt');
    _ptNames.clear();
    if (_hasPt) {
      for (final r in db.select("SELECT key, name_pt FROM entries WHERE name_pt <> '' GROUP BY key")) {
        _ptNames[r['key'] as String] = r['name_pt'] as String;
      }
    }
    final counts = <String, int>{};
    for (final r in db.select('SELECT book, COUNT(*) AS n FROM entries GROUP BY book')) {
      counts[r['book'] as String] = r['n'] as int;
    }
    for (final r in db.select('SELECT * FROM books ORDER BY released, title')) {
      final id = r['id'] as String;
      _books[id] = BookInfo(
        id: id,
        title: (r['title'] as String?) ?? id,
        publisher: (r['publisher'] as String?) ?? '',
        setting: (r['setting'] as String?) ?? '',
        category: (r['category'] as String?) ?? '',
        language: (r['language'] as String?) ?? 'en',
        released: (r['released'] as int?) ?? 0,
        pages: (r['pages'] as int?) ?? 0,
        entryCount: counts[id] ?? 0,
      );
    }
  }

  // ---------------------------------------------------------- homebrew
  Future<void> loadHomebrew(Directory dir) async {
    homebrew.clear();
    _books.removeWhere((k, v) => v.homebrew);
    if (!await dir.exists()) return;
    await for (final f in dir.list()) {
      if (f is File && f.path.toLowerCase().endsWith('.$bookExt')) {
        try {
          addHomebrew(HomebrewBook.fromXml(await f.readAsString(), path: f.path));
        } catch (_) {/* arquivo inválido: ignora */}
      }
    }
  }

  void addHomebrew(HomebrewBook b) {
    homebrew.removeWhere((x) => x.id == b.id);
    homebrew.add(b);
    _books[b.id] = BookInfo(
      id: b.id,
      title: b.title,
      publisher: b.author,
      category: 'homebrew',
      released: int.parse('${b.created.year}${b.created.month.toString().padLeft(2, '0')}'),
      entryCount: b.entries.length,
      homebrew: true,
    );
  }

  void refreshHomebrewInfo(HomebrewBook b) => addHomebrew(b);

  // ---------------------------------------------------------- consultas
  List<BookInfo> get books => _books.values.toList()
    ..sort((a, b) => a.homebrew == b.homebrew ? a.title.compareTo(b.title) : (a.homebrew ? 1 : -1));

  BookInfo? book(String id) => _books[id];

  Map<String, int> get bookDates => {for (final b in _books.values) b.id: b.released};

  static String _fts(String q) {
    final toks = q
        .replaceAll(RegExp(r'["()*:^]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !const {'AND', 'OR', 'NOT', 'NEAR'}.contains(t))
        .map((t) => '"$t"*');
    return toks.join(' ');
  }

  /// Nomes em português por chave (kind:slug), para listas que guardam só o nome original.
  final Map<String, String> _ptNames = {};
  String ptName(String kind, String name) => _ptNames['$kind:${slugify(name)}'] ?? '';
  String labelOf(String kind, String name) {
    final pt = ptName(kind, name);
    return Lang.isPt && pt.isNotEmpty && pt != name ? '$pt ($name)' : name;
  }

  static String? _s(Row r, String c) {
    try {
      return r[c] as String?;
    } catch (_) {
      return null;
    }
  }

  LibEntry _row(Row r, {bool withBody = false}) => LibEntry(
        namePt: _s(r, 'name_pt') ?? '',
        summaryPt: _s(r, 'summary_pt') ?? '',
        bodyPt: withBody ? (_s(r, 'body_pt') ?? '') : '',
        uid: 'db:${r['id']}',
        kind: r['kind'] as String,
        name: r['name'] as String,
        book: r['book'] as String,
        page: r['page'] as int?,
        summary: (r['summary'] as String?) ?? '',
        body: withBody ? ((r['body'] as String?) ?? '') : '',
        data: withBody && r['data'] != null && (r['data'] as String).isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map)
            : {},
      );

  String _inList(String col, Iterable<String> vals, List<Object?> params) {
    params.addAll(vals);
    return '$col IN (${List.filled(vals.length, '?').join(',')})';
  }

  bool _hbMatch(LibEntry e, String q, Set<String>? kinds, Set<String>? books) {
    if (kinds != null && !kinds.contains(e.kind)) return false;
    if (books != null && !books.contains(e.book)) return false;
    if (q.isEmpty) return true;
    final h = '${e.name} ${e.summary} ${e.body}'.toLowerCase();
    return q.toLowerCase().split(RegExp(r'\s+')).every(h.contains);
  }

  /// Busca por nome/termos em todas as entradas (FTS5), com filtros.
  List<LibEntry> search(String query, {Set<String>? kinds, Set<String>? books, int limit = 300, bool fullText = true}) {
    final out = <LibEntry>[];
    final db = _db;
    final q = query.trim();
    // consultas curtas: só pelo começo do nome (rápido); evita varrer o texto inteiro
    final short = q.isNotEmpty && q.length < 3;
    if (db != null) {
      final params = <Object?>[];
      final where = <String>[];
      String sql;
      if (q.isEmpty || short) {
        sql = 'SELECT e.id,e.kind,e.name,e.book,e.page,e.summary,$_ptCols FROM entries e';
        if (short) {
          where.add(_hasPt ? '(e.name LIKE ? OR e.name_pt LIKE ?)' : 'e.name LIKE ?');
          params.add('$q%');
          if (_hasPt) params.add('$q%');
        }
      } else {
        sql = 'SELECT e.id,e.kind,e.name,e.book,e.page,e.summary,$_ptCols FROM entries_fts f JOIN entries e ON e.id=f.rowid';
        where.add('entries_fts MATCH ?');
        params.add(fullText ? _fts(q) : '{${_hasPt ? 'name name_pt summary summary_pt' : 'name summary'}} : (${_fts(q)})');
      }
      if (kinds != null && kinds.isNotEmpty) where.add(_inList('e.kind', kinds, params));
      if (books != null && books.isNotEmpty) where.add(_inList('e.book', books, params));
      if (where.isNotEmpty) sql += ' WHERE ${where.join(' AND ')}';
      sql += (q.isEmpty || short) ? ' ORDER BY e.name' : (_hasPt
          ? ' ORDER BY (lower(e.name)=lower(?) OR lower(e.name_pt)=lower(?)) DESC, bm25(entries_fts, 10.0, 2.0, 1.0, 10.0, 2.0, 1.0)'
          : ' ORDER BY (lower(e.name)=lower(?)) DESC, bm25(entries_fts, 10.0, 2.0, 1.0)');
      if (q.isNotEmpty && !short) {
        params.add(q);
        if (_hasPt) params.add(q);
      }
      sql += ' LIMIT $limit';
      try {
        for (final r in db.select(sql, params)) {
          out.add(_row(r));
        }
      } catch (_) {/* consulta malformada */}
    }
    for (final hb in homebrew) {
      out.addAll(hb.entries.where((e) => _hbMatch(e, q, kinds, books)));
    }
    return out;
  }

  /// Busca de termos dentro do texto integral das páginas dos livros.
  List<PageHit> searchPages(String query, {Set<String>? books, int limit = 200}) {
    final db = _db;
    if (db == null || query.trim().isEmpty) return [];
    final params = <Object?>[_fts(query)];
    var sql = "SELECT p.book, p.page, snippet(pages_fts, 0, '«', '»', '…', 24) AS snip "
        'FROM pages_fts JOIN pages p ON p.rowid = pages_fts.rowid WHERE pages_fts MATCH ?';
    if (books != null && books.isNotEmpty) sql += ' AND ${_inList('p.book', books, params)}';
    sql += ' ORDER BY rank LIMIT $limit';
    try {
      return db.select(sql, params).map((r) => PageHit(r['book'] as String, (r['page'] as int?) ?? 0, r['snip'] as String)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Texto integral de uma página (para o leitor de referências).
  String pageText(String book, int page) {
    final db = _db;
    if (db == null) return '';
    final r = db.select('SELECT text FROM pages WHERE book=? AND page=? ORDER BY pdf_page LIMIT 1', [book, page]);
    return r.isEmpty ? '' : (r.first['text'] as String? ?? '');
  }

  List<LibEntry> entriesOfBook(String book, {String? kind}) {
    final hb = homebrew.where((b) => b.id == book);
    if (hb.isNotEmpty) {
      return hb.first.entries.where((e) => kind == null || e.kind == kind).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
    final db = _db;
    if (db == null) return [];
    final rows = kind == null
        ? db.select('SELECT id,kind,name,book,page,summary,$_ptCols2 FROM entries WHERE book=? ORDER BY kind, name', [book])
        : db.select('SELECT id,kind,name,book,page,summary,$_ptCols2 FROM entries WHERE book=? AND kind=? ORDER BY name', [book, kind]);
    return rows.map((r) => _row(r)).toList();
  }

  Map<String, int> kindCounts(String book) {
    final out = <String, int>{};
    for (final e in homebrew.where((b) => b.id == book).expand((b) => b.entries)) {
      out[e.kind] = (out[e.kind] ?? 0) + 1;
    }
    final db = _db;
    if (db != null) {
      for (final r in db.select('SELECT kind, COUNT(*) n FROM entries WHERE book=? GROUP BY kind', [book])) {
        out[r['kind'] as String] = r['n'] as int;
      }
    }
    return out;
  }

  /// Todas as versões (uma por livro) de um item com o mesmo nome.
  List<LibEntry> versionsOf(String kind, String name, {Set<String>? books}) {
    final key = '$kind:${slugify(name)}';
    final out = <LibEntry>[];
    final db = _db;
    if (db != null) {
      for (final r in db.select('SELECT * FROM entries WHERE key=? ORDER BY book', [key])) {
        out.add(_row(r, withBody: true));
      }
    }
    for (final hb in homebrew) {
      out.addAll(hb.entries.where((e) => e.key == key));
    }
    if (books != null) out.removeWhere((e) => !books.contains(e.book));
    out.sort((a, b) => (bookDates[b.book] ?? 0).compareTo(bookDates[a.book] ?? 0));
    return out;
  }

  /// Todos os livros em que um item aparece (independente do filtro).
  List<LibEntry> appearances(String kind, String name) => versionsOf(kind, name);

  LibEntry? full(LibEntry e) {
    if (e.homebrew || !e.uid.startsWith('db:')) return e;
    final db = _db;
    if (db == null) return e;
    final r = db.select('SELECT * FROM entries WHERE id=?', [int.parse(e.uid.substring(3))]);
    return r.isEmpty ? e : _row(r.first, withBody: true);
  }

  /// Lista entradas de um tipo (ex.: todas as magias permitidas na ficha).
  List<LibEntry> byKind(String kind, {Set<String>? books, bool withData = false}) {
    final out = <LibEntry>[];
    final db = _db;
    if (db != null) {
      final params = <Object?>[kind];
      var sql = 'SELECT ${withData ? '*' : 'id,kind,name,book,page,summary,$_ptCols2'} FROM entries WHERE kind=?';
      if (books != null && books.isNotEmpty) sql += ' AND ${_inList('book', books, params)}';
      sql += ' ORDER BY name';
      out.addAll(db.select(sql, params).map((r) => _row(r, withBody: withData)));
    }
    for (final hb in homebrew) {
      out.addAll(hb.entries.where((e) => e.kind == kind && (books == null || books.contains(e.book))));
    }
    return out;
  }

  /// Magias disponíveis para uma lista de classe (ex.: 'Sor/Wiz') e nível.
  List<LibEntry> spellsFor(String list, int level, {Set<String>? books}) {
    final all = byKind('spell', books: books, withData: true);
    return all.where((e) {
      final lv = e.data['levels'];
      if (lv is! Map) return false;
      final v = lv[list];
      return v is num && v.toInt() == level;
    }).toList();
  }

  /// Carrega no motor as entradas com dados estruturados (classes, raças,
  /// talentos, armas, armaduras) da base e do homebrew.
  void loadStructuredInto(Ruleset r) {
    r.bookDates.addAll(bookDates);
    void add(LibEntry e, bool rep) {
      if (e.data.isEmpty) return;
      final d = Map<String, dynamic>.from(e.data)
        ..putIfAbsent('name', () => e.name)
        ..['book'] = e.book
        ..putIfAbsent('page', () => e.page);
      try {
        switch (e.kind) {
          case 'class':
          case 'prestige':
            if (d['hit_die'] == null) return;
            if (e.kind == 'prestige') d['prestige'] = true;
            r.addClass(ClassDef.fromJson(d), replace: rep);
            break;
          case 'race':
            r.addRace(RaceDef.fromJson(d), replace: rep);
            break;
          case 'feat':
            r.addFeat(FeatDef.fromJson(d), replace: rep);
            break;
          case 'weapon':
            if (d['dmg_m'] == null) return;
            r.addWeapon(WeaponDef.fromJson(d), replace: rep);
            break;
          case 'armor':
            if (d['bonus'] == null) return;
            r.addArmor(ArmorDef.fromJson(d), replace: rep);
            break;
        }
      } catch (_) {/* dados incompletos */}
    }

    final db = _db;
    if (db != null) {
      for (final row in db.select(
          "SELECT * FROM entries WHERE data IS NOT NULL AND data <> '' AND kind IN ('class','prestige','race','feat','weapon','armor')")) {
        add(_row(row, withBody: true), false);
      }
    }
    for (final hb in homebrew) {
      for (final e in hb.entries) {
        add(e, true);
      }
    }
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
