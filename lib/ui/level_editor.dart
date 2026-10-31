import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../engine/calc.dart';
import '../engine/defs.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'feat_picker.dart';
import 'help.dart';
import 'widgets.dart';

/// Catálogo de classes: núcleo + estruturadas + entradas de texto da base.
List<LibEntry> classCatalog(AppState app, Set<String>? books) {
  final out = <String, LibEntry>{};
  for (final l in app.rules.classes.values) {
    for (final c in l) {
      if (books != null && !books.contains(c.book)) continue;
      out['${c.id}@${c.book}'] = LibEntry(
          kind: c.prestige ? 'prestige' : 'class',
          name: c.name,
          book: c.book,
          page: c.page,
          summary: '${c.namePt.isNotEmpty ? '${c.namePt} · ' : ''}d${c.hitDie} · ${c.skillPoints}+Int · BBA ${c.bab}'
              '${c.spellcasting != null ? ' · ${tr('conjurador', 'caster')}' : ''}',
          data: {'_structured': true});
    }
  }
  for (final k in ['class', 'prestige']) {
    for (final e in app.library.byKind(k, books: books)) {
      out.putIfAbsent('${slugify(e.name)}@${e.book}', () => e);
    }
  }
  return out.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// Escolhe classe (com versão) e devolve o id usado na ficha; configura a classe
/// manualmente quando o livro não tem dados mecânicos estruturados.
Future<(String, String?)?> pickClass(BuildContext context, Character ch) async {
  final app = context.read<AppState>();
  final cat = classCatalog(app, ch.allowedBooks);
  final e = await pickEntry(context, title: tr('Escolher classe', 'Choose class'), fixed: cat);
  if (e == null || !context.mounted) return null;
  var pick = e;
  final versions = cat.where((x) => slugify(x.name) == slugify(e.name)).toList()
    ..sort((a, b) => (app.rules.bookDates[b.book] ?? 0).compareTo(app.rules.bookDates[a.book] ?? 0));
  if (versions.length > 1) {
    final key = 'class:${slugify(e.name)}';
    final saved = ch.versionChoices[key];
    if (saved != null && versions.any((v) => v.book == saved)) {
      pick = versions.firstWhere((v) => v.book == saved);
    } else {
      final v = await chooseVersion(context, versions, policy: ch.versionPolicy);
      if (v == null) return null;
      pick = v;
      ch.versionChoices[key] = v.book;
    }
  }
  final id = slugify(pick.name);
  final def = app.rules.pick(app.rules.classes, id, book: pick.book);
  if (def != null && def.book == pick.book) return (id, pick.book);
  if (ch.embeddedDefs.containsKey('class:$id')) return (id, pick.book);
  if (!context.mounted) return null;
  // classe sem dados mecânicos: configurar
  final cfg = await configureClass(context, pick);
  if (cfg == null) return null;
  ch.embeddedDefs['class:$id'] = jsonEncode(cfg.toJson());
  return (id, pick.book);
}

Future<ClassDef?> configureClass(BuildContext context, LibEntry e, {ClassDef? initial}) =>
    showDialog<ClassDef>(context: context, builder: (_) => _ClassConfigDialog(entry: e, initial: initial));

class _ClassConfigDialog extends StatefulWidget {
  final LibEntry entry;
  final ClassDef? initial;
  const _ClassConfigDialog({required this.entry, this.initial});
  @override
  State<_ClassConfigDialog> createState() => _ClassConfigDialogState();
}

class _ClassConfigDialogState extends State<_ClassConfigDialog> {
  int hd = 8, sp = 2, maxLevel = 10;
  String bab = '3/4';
  Set<String> good = {};
  Set<String> skills = {};
  bool prestige = true;
  String casting = 'none'; // none | advance | copy:<classId>
  @override
  void initState() {
    super.initState();
    prestige = widget.entry.kind == 'prestige';
    maxLevel = prestige ? 10 : 20;
    final i = widget.initial;
    if (i != null) {
      hd = i.hitDie;
      sp = i.skillPoints;
      bab = i.bab;
      good = Set.of(i.goodSaves);
      skills = Set.of(i.classSkills);
      prestige = i.prestige;
      maxLevel = i.maxLevel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final casters = app.rules.classes.values.map((l) => l.first).where((c) => c.spellcasting != null).toList();
    return AlertDialog(
      title: Text('${tr('Configurar', 'Configure')} ${widget.entry.name} (${widget.entry.sourceLabel})'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Este livro não tem a tabela da classe estruturada na base. Informe os dados da tabela (consulte a página indicada). Eles ficam salvos dentro da ficha.',
                'This book has no structured class table in the database. Enter the table data (see the page shown). It is stored inside the character file.')),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(tr('Dado de vida', 'Hit die')),
              SegmentedButton<int>(
                segments: [for (final d in [4, 6, 8, 10, 12]) ButtonSegment(value: d, label: Text('d$d'))],
                selected: {hd},
                onSelectionChanged: (s) => setState(() => hd = s.first),
              ),
              Text(tr('Perícias/nível', 'Skills/level')),
              SegmentedButton<int>(
                segments: [for (final d in [2, 4, 6, 8]) ButtonSegment(value: d, label: Text('$d'))],
                selected: {sp},
                onSelectionChanged: (s) => setState(() => sp = s.first),
              ),
              Text(tr('BBA', 'BAB')),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'full', label: Text('1')),
                  ButtonSegment(value: '3/4', label: Text('3/4')),
                  ButtonSegment(value: '1/2', label: Text('1/2')),
                ],
                selected: {bab},
                onSelectionChanged: (s) => setState(() => bab = s.first),
              ),
              Text(tr('Resistências boas', 'Good saves')),
              for (final k in ['fort', 'ref', 'will'])
                FilterChip(label: Text(saveName(k)), selected: good.contains(k), onSelected: (v) => setState(() => v ? good.add(k) : good.remove(k))),
              withHelp(tr('Classe de prestígio', 'Prestige class'), FilterChip(label: Text(tr('Classe de prestígio', 'Prestige class')), selected: prestige, onSelected: (v) => setState(() => prestige = v))),
              Text(tr('Nível máximo', 'Max level')),
              NumStepper(value: maxLevel, min: 1, max: 40, onChanged: (v) => setState(() => maxLevel = v.toInt())),
            ]),
            const SizedBox(height: 10),
            Text(tr('Conjuração', 'Spellcasting'), style: const TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: casting,
              isExpanded: true,
              items: [
                DropdownMenuItem(value: 'none', child: Text(tr('Nenhuma', 'None'))),
                DropdownMenuItem(value: 'advance', child: Text(tr('+1 nível de conjurador de uma classe existente (escolhido por nível)', '+1 caster level of an existing class (chosen per level)'))),
                for (final c in casters)
                  DropdownMenuItem(value: 'copy:${c.id}', child: Text('${tr('Tabela própria igual a', 'Own table like')} ${c.displayName(Lang.isPt)}')),
              ],
              onChanged: (v) => setState(() => casting = v ?? 'none'),
            ),
            const SizedBox(height: 10),
            Text(tr('Perícias de classe', 'Class skills'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final s in app.rules.skills.values)
                FilterChip(
                  label: Text(s.displayName(Lang.isPt), style: const TextStyle(fontSize: 12)),
                  selected: skills.contains(s.id),
                  onSelected: (v) => setState(() => v ? skills.add(s.id) : skills.remove(s.id)),
                ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar', 'Cancel'))),
        FilledButton(
          onPressed: () {
            SpellcastingDef? sc;
            if (casting.startsWith('copy:')) {
              sc = app.rules.classById(casting.substring(5))?.spellcasting;
            }
            Navigator.pop(
                context,
                ClassDef(
                  id: slugify(widget.entry.name),
                  name: widget.entry.name,
                  book: widget.entry.book,
                  page: widget.entry.page,
                  hitDie: hd,
                  skillPoints: sp,
                  bab: bab,
                  goodSaves: good,
                  classSkills: skills.toList(),
                  prestige: prestige,
                  maxLevel: maxLevel,
                  spellcasting: sc,
                  advancesCasting: casting == 'advance' ? [for (var i = 1; i <= maxLevel; i++) i] : const [],
                ));
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Rola/define os PV de um novo nível conforme o método escolhido.
int hpForNewLevel(AppState app, Character ch, ClassDef def) {
  switch (ch.hpMethod) {
    case 'max':
      return def.hitDie;
    case 'roll':
      return app.dice.d(def.hitDie);
    default:
      return def.hitDie ~/ 2 + 1;
  }
}

/// Edita um nível: PV, aumento de atributo, avanço de conjuração, perícias, talentos.
class LevelEditor extends StatelessWidget {
  final int index;
  const LevelEditor({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    final ch = c.ch;
    final l = ch.levels[index];
    final def = s.classDefs[l.classId];
    final charLevel = index + 1;
    final classLevel = ch.levels.take(index + 1).where((x) => x.classId == l.classId).length;
    final intMod = s.abilities['int']!.mod;
    var pts = (def == null ? 2 : def.skillPoints) + intMod;
    if (pts < 1) pts = 1;
    pts += s.race?.bonusSkillPoints ?? 0;
    if (index == 0) pts *= 4;
    var spent = 0.0;
    l.skillRanks.forEach((k, r) => spent += s.isClassSkillFor(l.classId, k) ? r : r * 2);
    final maxRanks = (charLevel + 3).toDouble();
    final casterClasses = s.classDefs.values.where((d) => d.spellcasting != null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${tr('Nível', 'Level')} $charLevel — ${def?.displayName(Lang.isPt) ?? l.classId} $classLevel',
            style: Theme.of(context).textTheme.titleMedium),
        if (index > 0 && def != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${tr('PV', 'HP')} (d${def.hitDie}) '),
            NumStepper(value: l.hpRoll <= 0 ? def.hitDie ~/ 2 + 1 : l.hpRoll, min: 1, max: def.hitDie, onChanged: (v) => c.update((x) => x.levels[index].hpRoll = v.toInt())),
            IconButton(
              tooltip: tr('Rolar', 'Roll'),
              icon: const Icon(Icons.casino_outlined, size: 18),
              onPressed: () => c.update((x) => x.levels[index].hpRoll = c.app.dice.d(def.hitDie)),
            ),
          ]),
        if (index == 0 && def != null) Text('${tr('PV', 'HP')}: ${def.hitDie} (${tr('máximo no 1º nível', 'max at 1st level')})'),
        if (charLevel % 4 == 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${tr('Aumento de atributo', 'Ability increase')}: '),
            DropdownButton<String>(
              value: l.abilityIncrease ?? '',
              items: [
                DropdownMenuItem(value: '', child: Text(tr('—', '—'))),
                for (final a in abilityIds) DropdownMenuItem(value: a, child: Text(abilityName(a))),
              ],
              onChanged: (v) => c.update((x) => x.levels[index].abilityIncrease = (v == null || v.isEmpty) ? null : v),
            ),
          ]),
        if (def != null && (def.prestige || def.advancesCasting.isNotEmpty) && casterClasses.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${tr('Avança conjuração de', 'Advances casting of')}: '),
            DropdownButton<String>(
              value: l.castingAdvances ?? '',
              items: [
                DropdownMenuItem(value: '', child: Text(tr('nenhuma', 'none'))),
                for (final cc in casterClasses.where((cc) => cc.id != l.classId))
                  DropdownMenuItem(value: cc.id, child: Text(cc.displayName(Lang.isPt))),
              ],
              onChanged: (v) => c.update((x) => x.levels[index].castingAdvances = (v == null || v.isEmpty) ? null : v),
            ),
          ]),
      ]),
      const SizedBox(height: 6),
      Text('${tr('Pontos de perícia', 'Skill points')}: ${spent == spent.roundToDouble() ? spent.toInt() : spent} / $pts'
          '  ·  ${tr('máx. graduações', 'max ranks')} ${maxRanks.toInt()} (${tr('classe', 'class')}) / ${maxRanks / 2} (${tr('outras', 'cross')})',
          style: TextStyle(color: spent > pts ? Theme.of(context).colorScheme.error : null)),
      const SizedBox(height: 4),
      Text(tr('Destaque: perícias da classe deste nível (custam 1 ponto) vêm primeiro e em negrito; o ícone de rosto marca bônus racial.',
              'Highlight: class skills of this level (1 point each) come first in bold; the face icon marks a racial bonus.'),
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (final k in [
          ...s.skills.where((k) => s.isClassSkillFor(l.classId, k.key)),
          ...s.skills.where((k) => !s.isClassSkillFor(l.classId, k.key)),
        ])
          _SkillRankChip(index: index, line: k, classSkill: s.isClassSkillFor(l.classId, k.key), racial: racialSkillBonus(s, k.key)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${tr('Talentos neste nível', 'Feats at this level')}:'),
        for (final f in l.feats) InputChip(label: Text(f.name), onDeleted: () => c.update((x) => x.levels[index].feats.remove(f))),
        withHelp(tr('talento', 'feat'), ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: Text(tr('talento', 'feat')),
          onPressed: () async {
            final slot = _defaultSlot(s, ch, index);
            final fp = await pickFeat(context, ch, s, slot: slot);
            if (fp != null) c.update((x) => x.levels[index].feats.add(fp));
          },
        )),
        Text(_slotHint(s, ch, index), style: Theme.of(context).textTheme.bodySmall),
      ]),
    ]);
  }

  static String _defaultSlot(Sheet s, Character ch, int index) {
    final lvl = index + 1;
    final l = ch.levels[index];
    final used = l.feats.map((f) => f.slot).toList();
    if ((lvl == 1 || lvl % 3 == 0) && !used.contains('general')) return 'general';
    if (lvl == 1 && (s.race?.bonusFeats ?? 0) > 0 && !used.contains('race')) return 'race';
    return 'class:${l.classId}';
  }

  static String _slotHint(Sheet s, Character ch, int index) {
    final lvl = index + 1;
    final l = ch.levels[index];
    final classLevel = ch.levels.take(index + 1).where((x) => x.classId == l.classId).length;
    final parts = <String>[];
    if (lvl == 1 || lvl % 3 == 0) parts.add(tr('1 geral', '1 general'));
    if (lvl == 1 && (s.race?.bonusFeats ?? 0) > 0) parts.add(tr('${s.race!.bonusFeats} racial', '${s.race!.bonusFeats} racial'));
    final def = s.classDefs[l.classId];
    if (def != null && def.bonusFeatLevels.contains(classLevel)) parts.add(tr('1 bônus de classe', '1 class bonus'));
    if (lvl > 20 && lvl % 3 == 0) parts.add(tr('(pode ser épico)', '(may be epic)'));
    return parts.isEmpty ? tr('(nenhum espaço novo)', '(no new slot)') : '(${parts.join(', ')})';
  }
}

class _SkillRankChip extends StatelessWidget {
  final int index;
  final SkillLine line;
  final bool classSkill;
  final String? racial;
  const _SkillRankChip({required this.index, required this.line, required this.classSkill, this.racial});
  @override
  Widget build(BuildContext context) {
    final c = context.read<CharacterController>();
    final v = c.ch.levels[index].skillRanks[line.key] ?? 0;
    final step = classSkill ? 1.0 : 0.5;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: [
        if (skillHelp(line.key) != null) skillHelp(line.key)!,
        classSkill ? tr('Perícia de classe: 1 ponto por graduação.', 'Class skill: 1 point per rank.') : tr('Perícia de outra classe: 2 pontos por graduação.', 'Cross-class: 2 points per rank.'),
        if (racial != null) '${tr('Bônus racial', 'Racial bonus')}: $racial',
      ].join('\n'),
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: classSkill ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
        border: Border.all(color: v > 0 ? scheme.secondary : Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (racial != null) Padding(padding: const EdgeInsets.only(right: 3), child: Icon(Icons.face, size: 13, color: scheme.tertiary)),
        Text(line.label, style: TextStyle(fontSize: 12, fontWeight: classSkill ? FontWeight.bold : FontWeight.normal)),
        InkWell(
          onTap: v > 0
              ? () => c.update((x) {
                    final nv = v - step;
                    if (nv <= 0) {
                      x.levels[index].skillRanks.remove(line.key);
                    } else {
                      x.levels[index].skillRanks[line.key] = nv;
                    }
                  })
              : null,
          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, size: 14)),
        ),
        Text(v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
        InkWell(
          onTap: () => c.update((x) => x.levels[index].skillRanks[line.key] = v + step),
          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, size: 14)),
        ),
      ]),
      ),
    );
  }
}

/// Bônus raciais da raça da ficha para uma perícia (texto), ou null.
String? racialSkillBonus(Sheet s, String key) {
  final base = key.split(':').first;
  final out = [
    for (final e in s.race?.effects ?? const [])
      if (e.target == 'skill.$key' || e.target == 'skill.$base')
        '${e.value.startsWith('-') ? e.value : '+${e.value}'}${e.situational ? ' (${e.condition})' : ''}',
  ];
  return out.isEmpty ? null : out.join(', ');
}
