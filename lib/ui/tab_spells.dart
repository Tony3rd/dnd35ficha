import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../engine/calc.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'widgets.dart';

class SpellsTab extends StatelessWidget {
  const SpellsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    if (s.casters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
              tr('Este personagem não tem classes conjuradoras. Magias de itens e habilidades similares podem ser registradas como recursos ou notas.',
                  'This character has no spellcasting classes. Item spells and spell-like abilities can be tracked as resources or notes.'),
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.all(8), children: [for (final ci in s.casters) _CasterCard(ci)]);
  }
}

class _CasterCard extends StatelessWidget {
  final CasterInfo ci;
  const _CasterCard(this.ci);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final ch = c.ch;
    final sc = ci.cls.spellcasting!;
    final st = ch.casters[ci.cls.id] ?? CasterState(classId: ci.cls.id);
    final spontaneous = sc.style == 'spontaneous';

    void edit(void Function(CasterState cs) fn) => c.update((x) {
          final cs = x.casters.putIfAbsent(ci.cls.id, () => CasterState(classId: ci.cls.id));
          fn(cs);
        });

    Future<void> addKnown(int level) async {
      final app = c.app;
      final options = app.library.spellsFor(sc.list, level, books: ch.allowedBooks);
      for (final d in st.domains) {
        options.addAll(app.library.spellsFor(d, level, books: ch.allowedBooks));
      }
      LibEntry? e;
      if (options.isNotEmpty) {
        e = await pickEntry(context, title: '${tr('Magias de nível', 'Level')} $level (${sc.list})', fixed: options);
      } else {
        final name = await promptText(context, tr('Nome da magia', 'Spell name'),
            hint: app.library.hasDb ? null : tr('Sem base de dados: digite o nome', 'No database: type the name'));
        if (name != null && name.trim().isNotEmpty) e = LibEntry(kind: 'spell', name: name.trim(), book: '');
      }
      if (e == null || !context.mounted) return;
      var pick = e;
      final versions = app.library.versionsOf('spell', e.name, books: ch.allowedBooks);
      if (versions.length > 1) {
        final saved = ch.versionChoices[e.key];
        if (saved != null && versions.any((v) => v.book == saved)) {
          pick = versions.firstWhere((v) => v.book == saved);
        } else {
          final v = await chooseVersion(context, versions, policy: ch.versionPolicy);
          if (v == null) return;
          pick = v;
          ch.versionChoices[e.key] = v.book;
        }
      }
      edit((cs) => cs.known.add(KnownSpell(name: pick.name, book: pick.book.isEmpty ? null : pick.book, level: level, classId: ci.cls.id)));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(ci.cls.displayName(Lang.isPt), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 12),
            Chip(label: Text('${tr('NC', 'CL')} ${ci.casterLevel}')),
            const SizedBox(width: 6),
            Chip(label: Text('${abilityAbbr(ci.ability)} ${ci.abilityScore}')),
            const SizedBox(width: 6),
            Chip(label: Text(spontaneous ? tr('espontâneo', 'spontaneous') : tr('preparado', 'prepared'))),
            const Spacer(),
            IconButton(
              tooltip: tr('Rolar nível de conjurador (RM)', 'Roll caster level check (SR)'),
              icon: const Icon(Icons.casino_outlined),
              onPressed: () => showRoll(context, c.roll('1d20+${ci.casterLevel}', tr('Teste de NC', 'CL check'))),
            ),
          ]),
          if (sc.domainSlots)
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${tr('Domínios', 'Domains')}:'),
              for (final d in st.domains) InputChip(label: Text(d), onDeleted: () => edit((cs) => cs.domains.remove(d))),
              ActionChip(
                label: Text(tr('+ domínio', '+ domain')),
                onPressed: () async {
                  final d = await promptText(context, tr('Domínio (como na lista de magias, ex.: Fire, Good)', 'Domain (as in spell lists, e.g. Fire, Good)'));
                  if (d != null && d.trim().isNotEmpty) edit((cs) => cs.domains.add(d.trim()));
                },
              ),
            ]),
          if (sc.spellbook)
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${tr('Escola de especialização', 'Specialist school')}:'),
              DropdownButton<String>(
                value: st.specialistSchool ?? '',
                items: [
                  DropdownMenuItem(value: '', child: Text(tr('nenhuma (generalista)', 'none (generalist)'))),
                  for (var i = 0; i < c.app.rules.schools.length - 1; i++)
                    DropdownMenuItem(value: c.app.rules.schools[i], child: Text(Lang.isPt ? c.app.rules.schoolsPt[i] : c.app.rules.schools[i])),
                ],
                onChanged: (v) => edit((cs) => cs.specialistSchool = (v == null || v.isEmpty) ? null : v),
              ),
            ]),
          const SizedBox(height: 6),
          for (final lv in ci.levels.where((l) => l.base >= 0 || l.known > 0))
            _LevelBlock(ci: ci, lv: lv, st: st, spontaneous: spontaneous, edit: edit, addKnown: addKnown),
        ]),
      ),
    );
  }
}

class _LevelBlock extends StatelessWidget {
  final CasterInfo ci;
  final SpellLevelInfo lv;
  final CasterState st;
  final bool spontaneous;
  final void Function(void Function(CasterState)) edit;
  final Future<void> Function(int) addKnown;
  const _LevelBlock({required this.ci, required this.lv, required this.st, required this.spontaneous, required this.edit, required this.addKnown});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final known = st.known.where((k) => k.level == lv.level).toList()..sort((a, b) => a.name.compareTo(b.name));
    final prepared = st.prepared.where((p) => p.level == lv.level).toList();
    final slots = lv.perDay + lv.domain + lv.specialist;
    final usedSpont = st.usedSpontaneous[lv.level] ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${tr('Nível', 'Level')} ${lv.level}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 10),
          Text('${tr('por dia', 'per day')}: ${lv.perDay}${lv.bonus > 0 ? ' (${lv.base}+${lv.bonus})' : ''}'
              '${lv.domain > 0 ? ' +${lv.domain} ${tr('domínio', 'domain')}' : ''}'
              '${lv.specialist > 0 ? ' +${lv.specialist} ${tr('escola', 'school')}' : ''}'
              '${lv.known > 0 ? ' · ${tr('conhecidas', 'known')} ${known.length}/${lv.known}' : ''}'
              ' · CD ${lv.dc}'),
          const Spacer(),
          if (spontaneous)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${tr('usadas', 'used')} '),
              NumStepper(value: usedSpont, min: 0, max: slots, onChanged: (v) => edit((cs) => cs.usedSpontaneous[lv.level] = v.toInt())),
            ]),
        ]),
        if (!lv.castable)
          Text(tr('Atributo insuficiente para este nível (precisa ${10 + lv.level}).', 'Ability too low for this level (needs ${10 + lv.level}).'),
              style: TextStyle(color: scheme.error)),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final k in known)
            InputChip(
              label: Text('${k.name}${k.book != null ? ' (${k.book})' : ''}'),
              onPressed: () {
                final vs = app.library.versionsOf('spell', k.name);
                if (vs.isNotEmpty) showEntry(context, vs.firstWhere((v) => v.book == k.book, orElse: () => vs.first));
              },
              onDeleted: () => edit((cs) => cs.known.removeWhere((x) => x.name == k.name && x.level == k.level)),
              avatar: spontaneous
                  ? null
                  : InkWell(
                      onTap: () => edit((cs) => cs.prepared.add(PreparedSpell(name: k.name, level: lv.level))),
                      child: const Icon(Icons.add_circle_outline, size: 18),
                    ),
            ),
          ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(ci.cls.spellcasting!.spellbook ? tr('grimório', 'spellbook') : tr('conhecer', 'learn')),
              onPressed: () => addKnown(lv.level)),
        ]),
        if (!spontaneous) ...[
          const SizedBox(height: 6),
          Text('${tr('Preparadas', 'Prepared')}: ${prepared.length}/$slots', style: Theme.of(context).textTheme.labelMedium),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final p in prepared)
              FilterChip(
                label: Text('${p.name}${p.domain ? ' (D)' : ''}${p.metamagic.isNotEmpty ? ' [${p.metamagic}]' : ''}',
                    style: TextStyle(decoration: p.used ? TextDecoration.lineThrough : null)),
                selected: p.used,
                tooltip: tr('Marcar como conjurada', 'Mark as cast'),
                onSelected: (v) => edit((cs) => cs.prepared.firstWhere((x) => identical(x, p) || (x.name == p.name && x.level == p.level && x.used == p.used)).used = v),
                onDeleted: () => edit((cs) => cs.prepared.remove(cs.prepared.firstWhere((x) => x.name == p.name && x.level == p.level))),
              ),
            if (known.isEmpty)
              ActionChip(
                label: Text(tr('preparar (texto livre)', 'prepare (free text)')),
                onPressed: () async {
                  final n = await promptText(context, tr('Magia', 'Spell'));
                  if (n != null && n.isNotEmpty) edit((cs) => cs.prepared.add(PreparedSpell(name: n, level: lv.level)));
                },
              ),
          ]),
        ],
      ]),
    );
  }
}
