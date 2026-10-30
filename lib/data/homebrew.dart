// Livros homebrew: criados pelo usuário, tratados como qualquer outro livro,
// e os ÚNICOS que podem ser exportados (.d35book) para outras cópias do app.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../engine/defs.dart';
import '../i18n.dart';
import '../model/character.dart' show newId;

const bookRoot = 'grimorio35-book';
const bookExt = 'd35book';

class LibEntry {
  /// Para entradas da base: rowid; para homebrew: id local.
  final String uid;
  String kind;
  String name;
  String book;
  int? page;
  String summary;
  String body;
  /// Dados estruturados (mesmo esquema do core.json): permite ao motor usar o item.
  Map<String, dynamic> data;
  bool homebrew;
  /// Tradução para o português (quando existir na base).
  String namePt, summaryPt, bodyPt;

  LibEntry({
    String? uid,
    required this.kind,
    required this.name,
    required this.book,
    this.page,
    this.summary = '',
    this.body = '',
    Map<String, dynamic>? data,
    this.homebrew = false,
    this.namePt = '',
    this.summaryPt = '',
    this.bodyPt = '',
  })  : uid = uid ?? newId(),
        data = data ?? {};

  String get key => '$kind:${slugify(name)}';

  /// Nome para exibição: em português com o original entre parênteses.
  String get label => Lang.isPt && namePt.isNotEmpty && namePt != name ? '$namePt ($name)' : name;
  String get shownSummary => Lang.isPt && summaryPt.isNotEmpty ? summaryPt : summary;
  String get sourceLabel => page == null ? book : '$book p.$page';
}

class HomebrewBook {
  String id; // abreviação usada como "livro" (ex.: "HB-Ana")
  String title;
  String author;
  String description;
  String version;
  DateTime created;
  final List<LibEntry> entries;
  String? filePath;

  HomebrewBook({
    required this.id,
    required this.title,
    this.author = '',
    this.description = '',
    this.version = '1.0',
    DateTime? created,
    List<LibEntry>? entries,
    this.filePath,
  })  : created = created ?? DateTime.now(),
        entries = entries ?? [];

  String toXml() {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8"');
    b.element(bookRoot, nest: () {
      b.attribute('format', '1');
      b.attribute('id', id);
      b.attribute('title', title);
      b.attribute('author', author);
      b.attribute('version', version);
      b.attribute('created', created.toIso8601String());
      b.element('description', nest: description);
      for (final e in entries) {
        b.element('entry', nest: () {
          b.attribute('kind', e.kind);
          b.attribute('name', e.name);
          if (e.page != null) b.attribute('page', '${e.page}');
          b.element('summary', nest: e.summary);
          b.element('text', nest: e.body);
          if (e.data.isNotEmpty) {
            b.element('data', nest: () => b.cdata(jsonEncode(e.data)));
          }
        });
      }
    });
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  static HomebrewBook fromXml(String src, {String? path}) {
    final doc = XmlDocument.parse(src);
    final r = doc.rootElement;
    if (r.name.local != bookRoot) throw const FormatException('Arquivo não é um livro homebrew do Grimório 3.5.');
    final id = r.getAttribute('id') ?? 'HB';
    final book = HomebrewBook(
      id: id,
      title: r.getAttribute('title') ?? id,
      author: r.getAttribute('author') ?? '',
      version: r.getAttribute('version') ?? '1.0',
      created: DateTime.tryParse(r.getAttribute('created') ?? ''),
      description: r.findElements('description').isEmpty ? '' : r.findElements('description').first.innerText,
      filePath: path,
    );
    for (final x in r.findElements('entry')) {
      String txt(String n) => x.findElements(n).isEmpty ? '' : x.findElements(n).first.innerText;
      Map<String, dynamic> data = {};
      final d = txt('data').trim();
      if (d.isNotEmpty) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(d) as Map);
        } catch (_) {}
      }
      book.entries.add(LibEntry(
        kind: x.getAttribute('kind') ?? 'rule',
        name: x.getAttribute('name') ?? '',
        book: id,
        page: int.tryParse(x.getAttribute('page') ?? ''),
        summary: txt('summary'),
        body: txt('text'),
        data: data,
        homebrew: true,
      ));
    }
    return book;
  }

  Future<void> save(Directory dir) async {
    final path = filePath ?? p.join(dir.path, '${slugify(id)}.$bookExt');
    filePath = path;
    await File(path).writeAsString(toXml());
  }
}
