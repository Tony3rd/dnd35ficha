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
  bool onlyClass = false;
  bool onlyRacial = false;

  Widget _badge(BuildContext context, String text, Color bg, Color fg, String tip) => Tooltip(
        message: tip,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    final ch = c.ch;
    final lastLevel = ch.levels.isEmpty ? null : ch.levels.last;
    // perícias com bônus raciais (efeitos da raça que apontam para skill.*)
    final racial = <String, List<String>>{};
    for (final e in s.race?.effects ?? const []) {
      if (!e.target.startsWith('skill.') || e.target == 'skill.all') continue;
      final id = e.target.substring(6);
      racial.putIfAbsent(id, () => []).add('${e.value.startsWith('-') ? e.value : '+${e.value}'}${e.situational ? ' (${e.condition})' : ''}');
    }
    List<String>? racialOf(String key) => racial[key] ?? racial[key.split(':').first];
    final scheme = Theme.of(context).colorScheme;
    final rows = s.skills.where((k) {
      if (onlyRanked && k.ranks <= 0) return false;
      if (onlyClass && !k.classSkill) return false;
      if (onlyRacial && racialOf(k.key) == null) return false;
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
          Tooltip(
            message: tr('Perícias de classe de qualquer uma das suas classes: custam 1 ponto por graduação e o máximo é nível + 3.',
                'Class skills of any of your classes: 1 point per rank, max level + 3.'),
            child: FilterChip(
              avatar: Icon(Icons.school, size: 16, color: scheme.primary),
              label: Text(tr('De classe', 'Class skills')),
              selected: onlyClass,
              onSelected: (v) => setState(() => onlyClass = v),
            ),
          ),
          if (racial.isNotEmpty)
            Tooltip(
              message: tr('Perícias com bônus racial da raça ${s.race?.displayName(true) ?? ''}.', 'Skills with a racial bonus from ${s.race?.displayName(false) ?? ''}.'),
              child: FilterChip(
                avatar: Icon(Icons.face, size: 16, color: scheme.tertiary),
                label: Text(tr('Raciais', 'Racial')),
                selected: onlyRacial,
                onSelected: (v) => setState(() => onlyRacial = v),
              ),
            ),
          Tooltip(
            message: tr('Pontos gastos / disponíveis em todos os níveis. Perícia de classe custa 1 ponto por graduação; as outras custam 2 (meia graduação por ponto).',
                'Points spent / available across all levels. Class skills cost 1 per rank; others cost 2.'),
            child: Text('${tr('Pontos', 'Points')}: $spentFmt / ${s.skillPointsTotal}'),
          ),
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
            final rac = racialOf(k.key);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: k.classSkill ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
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
                  Flexible(child: Text(k.label, style: TextStyle(fontWeight: k.classSkill ? FontWeight.w600 : null))),
                  if (k.def.trainedOnly)
                    Tooltip(message: tr('Só pode ser usada com graduações (treinada).', 'Trained only.'), child: const Text('  ✱', style: TextStyle(fontSize: 11))),
                  if (k.classSkill)
                    _badge(context, tr('classe', 'class'), scheme.primary, scheme.onPrimary,
                        classHere || lastLevel == null
                            ? tr('Perícia de classe: 1 ponto por graduação.', 'Class skill: 1 point per rank.')
                            : tr('Perícia de classe de outra classe sua; no nível atual custa 2 pontos por graduação.', 'Class skill of another of your classes; costs 2 per rank at the current level.')),
                  if (rac != null)
                    _badge(context, '${tr('raça', 'race')} ${rac.first.split(' ').first}', scheme.tertiary, scheme.onTertiary,
                        '${tr('Bônus racial', 'Racial bonus')}: ${rac.join(', ')}'),
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
