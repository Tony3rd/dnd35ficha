import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../engine/bonus.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'effect_editor.dart';
import 'widgets.dart';

/// Magias e efeitos comuns prontos para ligar.
List<ActiveBuff> buffTemplates() {
  Effect e(String t, String v, [String ty = BonusType.untyped, String? c]) => Effect(target: t, value: v, type: ty, condition: c);
  ActiveBuff b(String pt, String en, List<Effect> fx) => ActiveBuff(name: tr(pt, en), effects: fx, source: 'template');
  return [
    b('Força do Touro', "Bull's Strength", [e('abil.str', '4', BonusType.enhancement)]),
    b('Agilidade do Gato', "Cat's Grace", [e('abil.dex', '4', BonusType.enhancement)]),
    b('Vigor do Urso', "Bear's Endurance", [e('abil.con', '4', BonusType.enhancement)]),
    b('Astúcia da Raposa', "Fox's Cunning", [e('abil.int', '4', BonusType.enhancement)]),
    b('Sabedoria da Coruja', "Owl's Wisdom", [e('abil.wis', '4', BonusType.enhancement)]),
    b('Esplendor da Águia', "Eagle's Splendor", [e('abil.cha', '4', BonusType.enhancement)]),
    b('Armadura Arcana', 'Mage Armor', [e('ac', '4', BonusType.armor)]),
    b('Escudo Arcano', 'Shield', [e('ac', '4', BonusType.shield)]),
    b('Escudo da Fé', 'Shield of Faith', [e('ac', '2', BonusType.deflection)]),
    b('Pele de Árvore (+2)', 'Barkskin (+2)', [e('ac', '2', BonusType.naturalEnh)]),
    b('Velocidade', 'Haste', [e('attack.all', '1'), e('ac', '1', BonusType.dodge), e('save.ref', '1', BonusType.dodge), e('speed.land', '30', BonusType.enhancement)]),
    b('Bênção', 'Bless', [e('attack.all', '1', BonusType.morale), e('save.all', '1', BonusType.morale, 'contra medo')]),
    b('Oração (aliados)', 'Prayer (allies)', [
      e('attack.all', '1', BonusType.luck), e('damage.all', '1', BonusType.luck), e('save.all', '1', BonusType.luck), e('skill.all', '1', BonusType.luck)
    ]),
    b('Heroísmo', 'Heroism', [e('attack.all', '2', BonusType.morale), e('save.all', '2', BonusType.morale), e('skill.all', '2', BonusType.morale)]),
    b('Heroísmo Maior', 'Greater Heroism', [e('attack.all', '4', BonusType.morale), e('save.all', '4', BonusType.morale), e('skill.all', '4', BonusType.morale)]),
    b('Fúria (magia)', 'Rage (spell)', [e('abil.str', '2', BonusType.morale), e('abil.con', '2', BonusType.morale), e('save.will', '1', BonusType.morale), e('ac', '-2')]),
    b('Aumentar Pessoa', 'Enlarge Person', [e('abil.str', '2', BonusType.size), e('abil.dex', '-2', BonusType.size), e('ac', '-1', BonusType.size), e('attack.all', '-1', BonusType.size)]),
    b('Reduzir Pessoa', 'Reduce Person', [e('abil.str', '-2', BonusType.size), e('abil.dex', '2', BonusType.size), e('ac', '1', BonusType.size), e('attack.all', '1', BonusType.size)]),
    b('Favor Divino', 'Divine Favor', [e('attack.all', 'max(1,min(3,floor(@level/3)))', BonusType.luck), e('damage.all', 'max(1,min(3,floor(@level/3)))', BonusType.luck)]),
    b('Proteção contra o Mal', 'Protection from Evil', [e('ac', '2', BonusType.deflection, 'contra criaturas más'), e('save.all', '2', BonusType.resistance, 'contra criaturas más')]),
    b('Resistência', 'Resistance', [e('save.all', '1', BonusType.resistance)]),
    b('Orientação', 'Guidance', [e('skill.all', '1', BonusType.competence)]),
    b('Investida (carga)', 'Charging', [e('attack.melee', '2'), e('ac', '-2')]),
    b('Flanqueando', 'Flanking', [e('attack.melee', '2')]),
  ];
}

class EffectsTab extends StatelessWidget {
  const EffectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final ch = c.ch;
    final rules = c.app.rules;
    return ListView(padding: const EdgeInsets.all(8), children: [
      SectionTitle(tr('Condições', 'Conditions')),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final cd in rules.conditions.values)
          Tooltip(
            message: cd.text,
            child: FilterChip(
              label: Text(cd.displayName(Lang.isPt)),
              selected: ch.conditions.contains(cd.id),
              onSelected: (v) => c.update((x) => v ? x.conditions.add(cd.id) : x.conditions.remove(cd.id)),
            ),
          ),
      ]),
      SectionTitle(tr('Efeitos ativos (magias, poções, habilidades)', 'Active effects (spells, potions, abilities)'),
          trailing: PopupMenuButton<ActiveBuff>(
            tooltip: tr('Adicionar efeito pronto', 'Add preset effect'),
            icon: const Icon(Icons.playlist_add),
            itemBuilder: (_) => [for (final t in buffTemplates()) PopupMenuItem(value: t, child: Text(t.name))],
            onSelected: (t) async {
              final r = await promptInt(context, tr('Duração em rodadas (0 = sem contagem)', 'Duration in rounds (0 = untracked)'), initial: 0);
              c.update((x) => x.buffs.add(ActiveBuff(name: t.name, effects: t.effects, roundsLeft: (r ?? 0) > 0 ? r : null, source: 'template')));
            },
          )),
      for (final b in ch.buffs)
        Card(
          child: ListTile(
            dense: true,
            leading: Switch(value: b.active, onChanged: (v) => c.update((x) => b.active = v)),
            title: Text(b.name),
            subtitle: Text([
              if (b.roundsLeft != null) '${b.roundsLeft} ${tr('rodadas', 'rounds')}',
              ...b.effects.map(describeEffect),
            ].join(' · ')),
            onTap: () => _editBuff(context, c, b),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => c.update((x) => x.buffs.remove(b))),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(tr('Efeito personalizado', 'Custom effect')),
          onPressed: () => _editBuff(context, c, null),
        ),
      ),
      SectionTitle(tr('Dano e dreno de atributo, níveis negativos', 'Ability damage/drain, negative levels')),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            for (final a in abilityIds)
              Row(children: [
                SizedBox(width: 130, child: Text(abilityName(a))),
                Text(tr('dano', 'damage')),
                NumStepper(value: ch.abilityDamage[a] ?? 0, min: 0, max: 99, onChanged: (v) => c.update((x) => x.abilityDamage[a] = v.toInt())),
                const SizedBox(width: 16),
                Text(tr('dreno', 'drain')),
                NumStepper(value: ch.abilityDrain[a] ?? 0, min: 0, max: 99, onChanged: (v) => c.update((x) => x.abilityDrain[a] = v.toInt())),
              ]),
            Row(children: [
              SizedBox(width: 130, child: Text(tr('Níveis negativos', 'Negative levels'))),
              NumStepper(value: ch.negativeLevels, min: 0, max: 99, onChanged: (v) => c.update((x) => x.negativeLevels = v.toInt())),
            ]),
          ]),
        ),
      ),
      SectionTitle(tr('Ajustes manuais permanentes', 'Permanent manual adjustments')),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: EffectListEditor(
            effects: ch.customEffects.where((e) => !e.source.startsWith('#')).toList(),
            skillIds: rules.skills.keys.toList(),
            onChanged: (l) => c.update((x) {
              x.customEffects.removeWhere((e) => !e.source.startsWith('#'));
              x.customEffects.addAll(l.map((e) => e.copyWith(source: e.source.isEmpty ? tr('Ajuste', 'Adjustment') : e.source)));
            }),
          ),
        ),
      ),
      SectionTitle(tr('Recursos personalizados', 'Custom resources')),
      for (final r in ch.customResources)
        ListTile(
          dense: true,
          title: Text(r.name),
          subtitle: Text('max = ${r.max} · ${r.per}'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => c.update((x) => x.customResources.remove(r))),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(tr('Recurso (usos por dia, cargas…)', 'Resource (uses/day, charges…)')),
          onPressed: () async {
            final n = await promptText(context, tr('Nome', 'Name'));
            if (n == null || n.isEmpty || !context.mounted) return;
            final m = await promptText(context, tr('Máximo (número ou fórmula, ex.: 3+@abil.cha.mod)', 'Maximum (number or formula)'), initial: '1');
            if (m == null) return;
            c.update((x) => x.customResources.add(CustomResource(name: n, max: m)));
          },
        ),
      ),
      const SizedBox(height: 60),
    ]);
  }

  Future<void> _editBuff(BuildContext context, CharacterController c, ActiveBuff? b) async {
    final res = await showDialog<ActiveBuff>(context: context, builder: (_) => _BuffDialog(buff: b, skillIds: c.app.rules.skills.keys.toList()));
    if (res == null) return;
    c.update((x) {
      if (b == null) {
        x.buffs.add(res);
      } else {
        x.buffs[x.buffs.indexOf(b)] = res;
      }
    });
  }
}

class _BuffDialog extends StatefulWidget {
  final ActiveBuff? buff;
  final List<String> skillIds;
  const _BuffDialog({this.buff, required this.skillIds});
  @override
  State<_BuffDialog> createState() => _BuffDialogState();
}

class _BuffDialogState extends State<_BuffDialog> {
  late TextEditingController name, rounds;
  late List<Effect> effects;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.buff?.name ?? '');
    rounds = TextEditingController(text: widget.buff?.roundsLeft?.toString() ?? '');
    effects = List.of(widget.buff?.effects ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Efeito', 'Effect')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: tr('Nome', 'Name'))),
            TextField(controller: rounds, decoration: InputDecoration(labelText: tr('Rodadas restantes (vazio = indefinido)', 'Rounds left (empty = untracked)'))),
            const SizedBox(height: 8),
            EffectListEditor(effects: effects, skillIds: widget.skillIds, onChanged: (l) => setState(() => effects = l)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar', 'Cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              ActiveBuff(
                id: widget.buff?.id,
                name: name.text.trim().isEmpty ? tr('Efeito', 'Effect') : name.text.trim(),
                effects: effects,
                roundsLeft: int.tryParse(rounds.text.trim()),
                active: widget.buff?.active ?? true,
                source: widget.buff?.source ?? 'custom',
              )),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
