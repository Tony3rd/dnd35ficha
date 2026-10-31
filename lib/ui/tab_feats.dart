import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'feat_picker.dart';
import 'homebrew_inline.dart';
import 'help.dart';
import 'widgets.dart';

class FeatsTab extends StatelessWidget {
  const FeatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    final ch = c.ch;
    final app = c.app;
    final chosen = ch.levels.fold<int>(0, (a, l) => a + l.feats.where((f) => f.slot != 'free').length);
    return ListView(padding: const EdgeInsets.all(8), children: [
      SectionTitle(tr('Talentos', 'Feats'),
          trailing: Text('$chosen / ${s.featSlots.total} ${tr('espaços', 'slots')}')),
      Text(
          [
            '${tr('Gerais', 'General')}: ${s.featSlots.general}',
            if (s.featSlots.race > 0) '${tr('Raça', 'Race')}: ${s.featSlots.race}',
            for (final e in s.featSlots.classBonus.entries) '${s.classDefs[e.key]?.displayName(Lang.isPt) ?? e.key}: ${e.value}',
            if (s.characterLevel > 20) tr('Talentos após o 20º podem ser épicos', 'Feats after 20th may be epic'),
          ].join(' · '),
          style: Theme.of(context).textTheme.bodySmall),
      for (var i = 0; i < ch.levels.length; i++)
        for (final f in ch.levels[i].feats)
          Card(
            child: ListTile(
              dense: true,
              leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              title: Text(_label(app, f.name, f.book)),
              subtitle: Builder(builder: (_) {
                final miss = app.calc.missingPrereqs(s, f.name, book: f.book);
                final def = app.rules.featByName(f.name, book: f.book);
                return Text([
                  '${f.book ?? def?.book ?? ''}${def?.page != null ? ' p.${def!.page}' : ''}',
                  _slotName(f.slot, s),
                  if (miss.isNotEmpty) '⚠ ${tr('requer', 'requires')} ${miss.join(', ')}',
                ].where((x) => x.isNotEmpty).join(' · '));
              }),
              onTap: () {
                final vs = app.library.versionsOf('feat', f.name.split(' (').first);
                if (vs.isNotEmpty) showEntry(context, vs.firstWhere((v) => v.book == f.book, orElse: () => vs.first));
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => c.update((x) => x.levels[i].feats.remove(f)),
              ),
            ),
          ),
      if (ch.levels.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: withHelp(tr('Adicionar talento', 'Add feat'), FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: Text(tr('Adicionar talento', 'Add feat')),
              onPressed: () async {
                final lvl = await _askLevel(context, ch.levels.length);
                if (lvl == null || !context.mounted) return;
                final slot = await _askSlot(context, s, ch.levels[lvl - 1].classId);
                if (slot == null || !context.mounted) return;
                final fp = await pickFeat(context, ch, s, slot: slot);
                if (fp != null) c.update((x) => x.levels[lvl - 1].feats.add(fp));
              },
            )),
          ),
        ),
      if (ch.levels.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: HomebrewCreateButton(
              label: tr('Criar talento homebrew…', 'Create homebrew feat…'),
              onPressed: () async {
                final e = await createHomebrewInline(context, c, 'feat', data: {'types': ['general']});
                if (e == null || !context.mounted) return;
                final lvl = await _askLevel(context, c.ch.levels.length);
                if (lvl == null || !context.mounted) return;
                final slot = await _askSlot(context, c.sheet, c.ch.levels[lvl - 1].classId);
                if (slot == null) return;
                c.update((x) => x.levels[lvl - 1].feats.add(FeatPick(e.name, book: e.book, slot: slot)));
              },
            ),
          ),
        ),
      SectionTitle(tr('Habilidades de classe e raça', 'Class & racial features')),
      for (final f in s.features)
        ListTile(
          dense: true,
          leading: const Icon(Icons.chevron_right),
          title: Text(f),
          onTap: () {
            final name = f.split(' (').first;
            final hits = app.library.search(name, limit: 10);
            if (hits.isNotEmpty) showEntry(context, hits.first);
          },
        ),
      if (s.race?.vision.isNotEmpty == true) ListTile(dense: true, leading: const Icon(Icons.visibility), title: Text(s.race!.vision)),
      ListTile(
        dense: true,
        leading: const Icon(Icons.translate),
        title: Text('${tr('Idiomas', 'Languages')}: ${ch.languages.isEmpty ? (s.race?.languages ?? '') : ch.languages}'),
        onTap: () async {
          final v = await promptText(context, tr('Idiomas', 'Languages'), initial: ch.languages.isEmpty ? (s.race?.languages ?? '') : ch.languages);
          if (v != null) c.update((x) => x.languages = v);
        },
      ),
    ]);
  }

  String _label(AppState app, String name, String? book) {
    final def = app.rules.featByName(name, book: book);
    if (def == null || !Lang.isPt || def.namePt.isEmpty) return name;
    final choice = name.contains('(') ? ' ${name.substring(name.indexOf('('))}' : '';
    return '${def.namePt}$choice — ${def.name}';
  }

  String _slotName(String slot, dynamic s) {
    if (slot == 'general') return tr('geral', 'general');
    if (slot == 'race') return tr('racial', 'racial');
    if (slot == 'free') return tr('livre (não conta)', 'free (not counted)');
    if (slot.startsWith('class:')) return '${tr('bônus de', 'bonus from')} ${slot.substring(6)}';
    return slot;
  }

  Future<int?> _askLevel(BuildContext context, int max) async {
    if (max == 1) return 1;
    return showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(title: Text(tr('Em qual nível?', 'At which level?')), children: [
        SizedBox(
          width: 300,
          height: 360,
          child: ListView(children: [
            for (var i = max; i >= 1; i--)
              SimpleDialogOption(onPressed: () => Navigator.pop(c, i), child: Text('${tr('Nível', 'Level')} $i')),
          ]),
        ),
      ]),
    );
  }

  Future<String?> _askSlot(BuildContext context, dynamic s, String classId) {
    return showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: Text(tr('Tipo de espaço', 'Slot type')), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'general'), child: Text(tr('Geral (a cada 3 níveis)', 'General (every 3 levels)'))),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'race'), child: Text(tr('Racial (ex.: humano)', 'Racial (e.g. human)'))),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'class:$classId'), child: Text(tr('Bônus de classe', 'Class bonus'))),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'free'), child: Text(tr('Livre (não conta nos espaços)', 'Free (not counted)'))),
      ]),
    );
  }
}

