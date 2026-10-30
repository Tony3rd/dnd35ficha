import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import 'widgets.dart';

class SkillsTab extends StatefulWidget {
  const SkillsTab({super.key});
  @override
  State<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends State<SkillsTab> {
  String filter = '';
  bool onlyRanked = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    final ch = c.ch;
    final lastLevel = ch.levels.isEmpty ? null : ch.levels.last;
    final rows = s.skills.where((k) {
      if (onlyRanked && k.ranks <= 0) return false;
      if (filter.isEmpty) return true;
      return k.label.toLowerCase().contains(filter.toLowerCase()) || k.def.name.toLowerCase().contains(filter.toLowerCase());
    }).toList();
    final spentFmt = s.skillPointsSpent == s.skillPointsSpent.roundToDouble()
        ? '${s.skillPointsSpent.toInt()}'
        : s.skillPointsSpent.toStringAsFixed(1);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 240,
            child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Filtrar perícias', 'Filter skills')),
              onChanged: (v) => setState(() => filter = v),
            ),
          ),
          FilterChip(label: Text(tr('Só com graduações', 'Ranked only')), selected: onlyRanked, onSelected: (v) => setState(() => onlyRanked = v)),
          Text('${tr('Pontos', 'Points')}: $spentFmt / ${s.skillPointsTotal}'),
          if (s.armorCheck != 0) Text('${tr('Penalidade de armadura', 'Armor check')}: ${s.armorCheck}'),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(tr('Ofício/Atuação/Profissão…', 'Craft/Perform/Profession…')),
            onPressed: lastLevel == null
                ? null
                : () async {
                    final base = await showDialog<String>(
                        context: context,
                        builder: (d) => SimpleDialog(title: Text(tr('Perícia com especialização', 'Skill with specialty')), children: [
                              for (final id in ['craft', 'perform', 'profession'])
                                SimpleDialogOption(
                                    onPressed: () => Navigator.pop(d, id),
                                    child: Text(c.app.rules.skills[id]!.displayName(Lang.isPt))),
                            ]));
                    if (base == null || !context.mounted) return;
                    final sub = await promptText(context, tr('Especialização (ex.: Alquimia)', 'Specialty (e.g. Alchemy)'));
                    if (sub == null || sub.trim().isEmpty) return;
                    c.update((x) => x.levels.last.skillRanks.putIfAbsent('$base:${sub.trim()}', () => 0));
                  },
          ),
        ]),
      ),
      if (lastLevel != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            tr('Os botões +/− compram graduações no nível ${ch.levels.length} (${s.classDefs[lastLevel.classId]?.displayName(true) ?? lastLevel.classId}). Para outros níveis use a aba Níveis.',
                '+/− buy ranks at level ${ch.levels.length} (${s.classDefs[lastLevel.classId]?.displayName(false) ?? lastLevel.classId}). Use the Levels tab for other levels.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final k = rows[i];
            final here = lastLevel?.skillRanks[k.key] ?? 0;
            final classHere = lastLevel != null && s.isClassSkillFor(lastLevel.classId, k.key);
            final step = classHere ? 1.0 : 0.5;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: ListTile(
                dense: true,
                leading: SizedBox(
                  width: 56,
                  child: InkWell(
                    onTap: k.usable ? () => showRoll(context, c.roll('1d20${sgn(k.total)}', k.label)) : null,
                    child: Center(
                      child: Text(k.usable ? sgn(k.total) : '—',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                title: Row(children: [
                  if (k.classSkill) Icon(Icons.circle, size: 8, color: Theme.of(context).colorScheme.secondary),
                  if (k.classSkill) const SizedBox(width: 6),
                  Flexible(child: Text(k.label)),
                  if (k.def.trainedOnly) const Text('  ✱', style: TextStyle(fontSize: 11)),
                ]),
                subtitle: Text([
                  '${k.def.ability == 'none' ? '—' : abilityAbbr(k.def.ability)} ${sgn(k.abilMod)}',
                  '${tr('grad.', 'ranks')} ${k.ranks == k.ranks.roundToDouble() ? k.ranks.toInt() : k.ranks}/${k.maxRanks == k.maxRanks.roundToDouble() ? k.maxRanks.toInt() : k.maxRanks}',
                  if (k.synergy != 0) '${tr('sinergia', 'synergy')} ${sgn(k.synergy)}',
                  if (k.acp != 0) '${tr('armadura', 'armor')} ${k.acp}',
                  if (k.sizeMod != 0) '${tr('tamanho', 'size')} ${sgn(k.sizeMod)}',
                  if (k.misc.total != 0) '${tr('outros', 'misc')} ${sgn(k.misc.total)}',
                  ...k.situational,
                ].join(' · ')),
                trailing: lastLevel == null
                    ? null
                    : NumStepper(
                        value: here,
                        min: 0,
                        max: 99,
                        step: step,
                        onChanged: (v) => c.update((x) {
                          if (v <= 0) {
                            x.levels.last.skillRanks.remove(k.key);
                          } else {
                            x.levels.last.skillRanks[k.key] = v.toDouble();
                          }
                        }),
                      ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
