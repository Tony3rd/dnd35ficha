import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'data/homebrew.dart';
import 'data/library.dart';
import 'data/settings.dart';
import 'engine/calc.dart';
import 'engine/dice.dart';
import 'engine/ruleset.dart';
import 'i18n.dart';
import 'model/character.dart';
import 'model/xml_io.dart';

class CharacterFile {
  final String path;
  final String name;
  final String summary;
  final DateTime modified;
  CharacterFile(this.path, this.name, this.summary, this.modified);
}

class AppState extends ChangeNotifier {
  late AppPaths paths;
  late Settings settings;
  late Ruleset rules;
  late Calculator calc;
  final library = Library();
  final dice = Dice();
  final List<RollResult> rollLog = [];
  List<CharacterFile> characters = [];
  String? coreJson;
  bool ready = false;
  String? error;

  Future<void> init() async {
    try {
      paths = await AppPaths.init();
      settings = await Settings.load(paths.settings);
      Lang.code = settings.language;
      coreJson = await rootBundle.loadString('assets/srd/core.json');
      await reloadRules();
      await refreshCharacters();
      ready = true;
    } catch (e, st) {
      error = '$e\n$st';
    }
    notifyListeners();
  }

  /// Recarrega base + homebrew e reconstrói o conjunto de regras.
  Future<void> reloadRules() async {
    await assembleDbParts();
    library.openDb(paths.rulesDb);
    await library.loadHomebrew(paths.homebrew);
    rules = Ruleset.fromCoreJson(coreJson!);
    library.loadStructuredInto(rules);
    calc = Calculator(rules);
    notifyListeners();
  }

  /// A base pode vir compactada e dividida (rules.sqlite.gz.part1, part2...)
  /// para caber em anexos/transferências. Monta e descompacta na primeira execução.
  Future<void> assembleDbParts() async {
    final parts = <File>[];
    await for (final f in paths.root.list()) {
      final n = p.basename(f.path).toLowerCase();
      if (f is File && (n == 'rules.sqlite.gz' || n.startsWith('rules.sqlite.gz.part'))) parts.add(f);
    }
    if (parts.isEmpty) return;
    int num(File f) => int.tryParse(RegExp(r'(\d+)$').firstMatch(f.path)?.group(1) ?? '0') ?? 0;
    parts.sort((a, b) => num(a).compareTo(num(b)));
    final tmp = File('${paths.rulesDb.path}.tmp');
    Stream<List<int>> joined() async* {
      for (final f in parts) {
        yield* f.openRead();
      }
    }
    library.dispose();
    await joined().transform(gzip.decoder).pipe(tmp.openWrite());
    if (await paths.rulesDb.exists()) await paths.rulesDb.delete();
    await tmp.rename(paths.rulesDb.path);
    for (final f in parts) {
      await f.delete();
    }
  }

  Future<void> saveSettings() async {
    Lang.code = settings.language;
    await settings.save(paths.settings);
    notifyListeners();
  }

  // ---------------------------------------------------------------- fichas
  Future<void> refreshCharacters() async {
    final out = <CharacterFile>[];
    await for (final f in paths.characters.list()) {
      if (f is File && f.path.toLowerCase().endsWith('.$characterExt')) {
        try {
          final c = characterFromXml(await f.readAsString());
          out.add(CharacterFile(f.path, c.name.isEmpty ? p.basenameWithoutExtension(f.path) : c.name, summaryOf(c),
              await f.lastModified()));
        } catch (_) {
          out.add(CharacterFile(f.path, p.basename(f.path), tr('arquivo inválido', 'invalid file'), DateTime(2000)));
        }
      }
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    characters = out;
    notifyListeners();
  }

  String summaryOf(Character c) {
    final race = rules.raceById(c.raceId, book: c.raceBook)?.displayName(Lang.isPt) ?? c.raceId;
    final cls = c.classLevelCounts.entries.map((e) {
      final n = rules.classById(e.key)?.displayName(Lang.isPt) ?? e.key;
      return '$n ${e.value}';
    }).join(' / ');
    return '$race · ${cls.isEmpty ? tr('sem classe', 'no class') : cls} · ${tr('nível', 'level')} ${c.characterLevel}';
  }

  String pathFor(Character c) {
    final safe = (c.name.isEmpty ? 'personagem' : c.name).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return p.join(paths.characters.path, '${safe}_${c.id.substring(0, 6)}.$characterExt');
  }

  Future<String> saveCharacter(Character c, {String? path}) async {
    final target = path ?? _existingPath(c) ?? pathFor(c);
    c.modified = DateTime.now();
    await File(target).writeAsString(characterToXml(c));
    await refreshCharacters();
    return target;
  }

  String? _existingPath(Character c) {
    for (final f in characters) {
      try {
        final txt = File(f.path).readAsStringSync();
        if (txt.contains('id="${c.id}"')) return f.path;
      } catch (_) {}
    }
    return null;
  }

  Future<Character> loadCharacter(String path) async => characterFromXml(await File(path).readAsString());

  Future<void> deleteCharacter(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
    await refreshCharacters();
  }

  Future<void> importCharacter(String path) async {
    final c = characterFromXml(await File(path).readAsString());
    await saveCharacter(c, path: pathFor(c));
  }

  // ---------------------------------------------------------------- homebrew
  Future<void> saveHomebrew(HomebrewBook b) async {
    await b.save(paths.homebrew);
    await reloadRules();
  }

  Future<void> deleteHomebrew(HomebrewBook b) async {
    if (b.filePath != null && await File(b.filePath!).exists()) await File(b.filePath!).delete();
    await reloadRules();
  }

  Future<HomebrewBook> importHomebrew(String path) async {
    final b = HomebrewBook.fromXml(await File(path).readAsString());
    if (library.book(b.id) != null && !library.book(b.id)!.homebrew) {
      throw FormatException(tr('A abreviação "${b.id}" já é usada por um livro oficial.',
          'Abbreviation "${b.id}" is already used by an official book.'));
    }
    b.filePath = null;
    await saveHomebrew(b);
    return b;
  }

  // ---------------------------------------------------------------- dados
  RollResult roll(String expr, {String label = ''}) {
    final r = dice.roll(expr, label: label);
    rollLog.insert(0, r);
    if (rollLog.length > 200) rollLog.removeLast();
    notifyListeners();
    return r;
  }
}

/// Controla uma ficha aberta: recalcula a cada alteração e salva sozinho.
class CharacterController extends ChangeNotifier {
  final AppState app;
  final Character ch;
  late Sheet sheet;
  Timer? _saveTimer;
  bool dirty = false;
  bool _disposed = false;
  final bool autosave;

  CharacterController(this.app, this.ch, {this.autosave = true}) {
    sheet = app.calc.compute(ch);
  }

  void update(void Function(Character c) fn, {bool save = true}) {
    fn(ch);
    recompute();
    if (save && autosave) _scheduleSave();
  }

  void recompute() {
    sheet = app.calc.compute(ch);
    notifyListeners();
  }

  void _scheduleSave() {
    dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), saveNow);
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    await app.saveCharacter(ch);
    dirty = false;
    if (!_disposed) notifyListeners();
  }

  RollResult roll(String expr, String label) => app.roll(expr, label: '${ch.name}: $label');

  @override
  void dispose() {
    _disposed = true;
    if (dirty && autosave) {
      saveNow();
    }
    _saveTimer?.cancel();
    super.dispose();
  }
}
