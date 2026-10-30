import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../engine/calc.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'level_editor.dart';
import 'widgets.dart';

/// Distribui pontos de perícia em todos os níveis, na ordem de prioridade dada,
/// respeitando máximo de graduações e custo (classe/outras).
void autoDistributeSkills(AppState app, Character ch, List<String> priority, {bool onlyEmptyLevels = true}) {
  for (var i = 0; i < ch.levels.length; i++) {
    final l = ch.levels[i];
    if (onlyEmptyLevels && l.skillRanks.isNotEmpty) continue;
    final s = app.calc.compute(ch);
    final def = s.classDefs[l.classId];
    if (def == null) continue;
    final intScore = s.abilities['int']!.permanent;
    var pts = math.max(1, def.skillPoints + abilityMod(intScore)) + (s.race?.bonusSkillPoints ?? 0);
    if (i == 0) pts *= 4;
    double budget = pts.toDouble();
    final maxR = (i + 1 + 3).toDouble();
    // passa várias vezes pela lista enquanto houver pontos
    var progress = true;
    while (budget > 0 && progress) {
      progress = false;
      for (final k in priority) {
        if (budget <= 0) break;
        final cls = s.isClassSkillFor(l.classId, k);
        final cap = cls ? maxR : maxR / 2;
        var have = 0.0;
        for (var j = 0; j <= i; j++) {
          have += ch.levels[j].skillRanks[k] ?? 0;
        }
        final step = cls ? 1.0 : 0.5;
        if (have + step <= cap + 0.001 && budget >= 1) {
          l.skillRanks[k] = (l.skillRanks[k] ?? 0) + step;
          budget -= 1;
          progress = true;
        }
      }
    }
  }
}

class LevelsTab extends StatelessWidget {
  const LevelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final ch = c.ch;
    final s = c.sheet;
    return ListView(padding: const EdgeInsets.all(8), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${tr('Nível', 'Level')} ${s.characterLevel}${s.ecl != s.characterLevel ? ' (NEP/ECL ${s.ecl})' : ''}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('XP ${ch.xp} / ${s.xpNeeded} · ${tr('próximo', 'next')} ${(s.ecl + 1) * s.ecl ~/ 2 * 1000}'),
            OutlinedButton(
              onPressed: () async {
                final v = await promptText(context, tr('XP (use +N para somar)', 'XP (use +N to add)'), initial: '${ch.xp}');
                if (v == null) return;
                final t = v.trim();
                final nv = t.startsWith('+') ? ch.xp + (int.tryParse(t.substring(1)) ?? 0) : int.tryParse(t);
                if (nv != null) c.update((x) => x.xp = nv);
              },
              child: Text(tr('Editar XP', 'Edit XP')),
            ),
            DropdownButton<String>(
              value: ch.hpMethod,
              items: [
                DropdownMenuItem(value: 'average', child: Text(tr('PV: média', 'HP: average'))),
                DropdownMenuItem(value: 'max', child: Text(tr('PV: máximo', 'HP: max'))),
                DropdownMenuItem(value: 'roll', child: Text(tr('PV: rolar', 'HP: roll'))),
              ],
              onChanged: (v) => c.update((x) => x.hpMethod = v ?? 'average'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(tr('Subir de nível', 'Level up')),
              onPressed: () => addLevels(context, c, 1),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.fast_forward),
              label: Text(tr('Vários níveis…', 'Several levels…')),
              onPressed: () async {
                final n = await promptInt(context, tr('Quantos níveis adicionar?', 'How many levels?'), initial: 5);
                if (n != null && n > 0 && context.mounted) await addLevels(context, c, n);
              },
            ),
            if (ch.levels.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.remove),
                label: Text(tr('Remover último', 'Remove last')),
                onPressed: () async {
                  if (await confirm(context, tr('Remover o nível ${ch.levels.length}?', 'Remove level ${ch.levels.length}?'))) {
                    c.update((x) => x.levels.removeLast());
                  }
                },
              ),
            if (ch.levels.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high),
                label: Text(tr('Distribuir perícias…', 'Distribute skills…')),
                onPressed: () => _autoSkills(context, c),
              ),
          ]),
        ),
      ),
      for (var i = ch.levels.length - 1; i >= 0; i--)
        Card(
          child: ExpansionTile(
            initiallyExpanded: i == ch.levels.length - 1,
            title: Text('${i + 1}. ${s.classDefs[ch.levels[i].classId]?.displayName(Lang.isPt) ?? ch.levels[i].classId}'
                ' ${ch.levels.take(i + 1).where((x) => x.classId == ch.levels[i].classId).length}'),
            subtitle: Text([
              if (ch.levels[i].feats.isNotEmpty) ch.levels[i].feats.map((f) => f.name).join(', '),
              if (ch.levels[i].abilityIncrease != null) '+1 ${abilityAbbr(ch.levels[i].abilityIncrease!)}',
            ].join(' · ')),
            childrenPadding: const EdgeInsets.all(10),
            children: [LevelEditor(index: i)],
          ),
        ),
    ]);
  }

  Future<void> _autoSkills(BuildContext context, CharacterController c) async {
    final s = c.sheet;
    final sel = <String>[];
    await showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: Text(tr('Prioridade das perícias', 'Skill priority')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Toque nas perícias na ordem de prioridade. Os pontos dos níveis sem perícias serão distribuídos maximizando as primeiras.',
                    'Tap skills in priority order. Points of levels without skills are spent maxing the first ones.')),
                const SizedBox(height: 8),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final k in s.skills)
                    FilterChip(
                      label: Text('${sel.contains(k.key) ? '${sel.indexOf(k.key) + 1}. ' : ''}${k.label}'),
                      selected: sel.contains(k.key),
                      onSelected: (v) => setS(() => v ? sel.add(k.key) : sel.remove(k.key)),
                    ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('Cancelar', 'Cancel'))),
            FilledButton(
                onPressed: () {
                  Navigator.pop(d);
                  c.update((x) => autoDistributeSkills(c.app, x, sel));
                },
                child: Text(tr('Distribuir', 'Distribute'))),
          ],
        ),
      ),
    );
  }
}

/// Adiciona [n] níveis de uma classe escolhida (com aumentos de atributo).
Future<void> addLevels(BuildContext context, CharacterController c, int n) async {
  final picked = await pickClass(context, c.ch);
  if (picked == null || !context.mounted) return;
  final (id, book) = picked;
  String? inc;
  final start = c.ch.levels.length;
  final needsInc = [for (var k = 1; k <= n; k++) start + k].any((l) => l % 4 == 0);
  if (needsInc) {
    inc = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(title: Text(tr('Aumentos de atributo vão para…', 'Ability increases go to…')), children: [
        for (final a in abilityIds) SimpleDialogOption(onPressed: () => Navigator.pop(d, a), child: Text(abilityName(a))),
        SimpleDialogOption(onPressed: () => Navigator.pop(d, ''), child: Text(tr('Decidir depois', 'Decide later'))),
      ]),
    );
  }
  final incF = inc;
  c.update((x) {
    for (var k = 0; k < n; k++) {
      final lvl = x.levels.length + 1;
      final probe = ClassLevel(classId: id, classBook: book);
      x.levels.add(probe);
      final def = c.app.calc.compute(x).classDefs[id];
      probe.hpRoll = lvl == 1 || def == null ? (def?.hitDie ?? 8) : hpForNewLevel(c.app, x, def);
      if (lvl % 4 == 0 && incF != null && incF.isNotEmpty) probe.abilityIncrease = incF;
      // conjurador de prestígio: por padrão avança a primeira classe conjuradora
      if (def != null && def.advancesCasting.contains(x.levels.where((y) => y.classId == id).length)) {
        final casters = x.levels.map((y) => y.classId).toSet().where((cid) => c.app.rules.classById(cid)?.spellcasting != null);
        if (casters.isNotEmpty) probe.castingAdvances = casters.first;
      }
    }
  });
}
