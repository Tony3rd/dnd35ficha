import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../engine/calc.dart';
import '../engine/defs.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'widgets.dart';

/// Lista unificada de talentos: núcleo estruturado + base de dados + homebrew.
List<LibEntry> featCatalog(AppState app, Set<String>? books) {
  final out = <String, LibEntry>{};
  for (final list in app.rules.feats.values) {
    for (final f in list) {
      if (books != null && !books.contains(f.book)) continue;
      final e = LibEntry(
        kind: 'feat',
        name: f.name,
        book: f.book,
        page: f.page,
        summary: [
          if (Lang.isPt && f.namePt.isNotEmpty) f.namePt,
          f.types.join(', '),
          if (f.prereqs.isNotEmpty) '${tr('Pré', 'Prereq')}: ${f.prereqs.map((p) => p.describe(Lang.isPt)).join(', ')}',
          if (f.prereqText.isNotEmpty) f.prereqText,
        ].join(' · '),
      );
      out['${e.key}@${e.book}'] = e;
    }
  }
  for (final e in app.library.byKind('feat', books: books)) {
    out.putIfAbsent('${e.key}@${e.book}', () => e);
  }
  final l = out.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  return l;
}

/// Pergunta a escolha de um talento com parâmetro (arma, perícia, escola).
Future<String?> askFeatChoice(BuildContext context, AppState app, FeatDef def) async {
  if (def.choice == null) return def.name;
  List<String> options;
  switch (def.choice) {
    case 'weapon':
      options = app.rules.weapons.values.map((l) => l.first.name).toList()..sort();
      break;
    case 'skill':
      options = app.rules.skills.values.map((s) => s.name).toList()..sort();
      break;
    case 'school':
      options = List.of(app.rules.schools);
      break;
    default:
      final t = await promptText(context, '${def.name}: ${tr('escolha', 'choice')}');
      return t == null || t.isEmpty ? null : '${def.name} ($t)';
  }
  final picked = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text('${def.name}: ${tr('escolha', 'choose')}'),
      children: [
        SizedBox(
          width: 360,
          height: 420,
          child: ListView(children: [
            for (final o in options) SimpleDialogOption(onPressed: () => Navigator.pop(c, o), child: Text(o)),
          ]),
        ),
      ],
    ),
  );
  return picked == null ? null : '${def.name} ($picked)';
}

/// Fluxo completo: escolher talento, versão (se houver várias) e parâmetro.
Future<FeatPick?> pickFeat(BuildContext context, Character ch, Sheet sheet, {String slot = 'general'}) async {
  final app = context.read<AppState>();
  final catalog = featCatalog(app, ch.allowedBooks);
  final chosen = await pickEntry(context, title: tr('Escolher talento', 'Choose feat'), fixed: catalog);
  if (chosen == null || !context.mounted) return null;
  var entry = chosen;
  final versions = catalog.where((e) => e.key == chosen.key).toList()
    ..sort((a, b) => (app.rules.bookDates[b.book] ?? 0).compareTo(app.rules.bookDates[a.book] ?? 0));
  if (versions.length > 1) {
    final saved = ch.versionChoices[chosen.key];
    if (saved != null && versions.any((v) => v.book == saved)) {
      entry = versions.firstWhere((v) => v.book == saved);
    } else {
      final v = await chooseVersion(context, versions, policy: ch.versionPolicy);
      if (v == null || !context.mounted) return null;
      entry = v;
      ch.versionChoices[chosen.key] = v.book;
    }
  }
  final def = app.rules.featByName(entry.name, book: entry.book);
  var name = entry.name;
  if (def != null && def.choice != null) {
    final n = await askFeatChoice(context, app, def);
    if (n == null) return null;
    name = n;
  }
  if (def != null && context.mounted) {
    final miss = app.calc.missingPrereqs(sheet, name, book: entry.book);
    if (miss.isNotEmpty) {
      final ok = await confirm(context,
          tr('Pré-requisitos não atendidos: ${miss.join(', ')}. Adicionar mesmo assim?', 'Unmet prerequisites: ${miss.join(', ')}. Add anyway?'));
      if (!ok) return null;
    }
  }
  return FeatPick(name, book: entry.book, slot: slot);
}
