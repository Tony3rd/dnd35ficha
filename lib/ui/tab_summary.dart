import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../engine/bonus.dart';
import '../engine/calc.dart';
import '../engine/expr.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'help.dart';
import 'widgets.dart';

class SummaryTab extends StatelessWidget {
  const SummaryTab({super.key});

  void _breakdown(BuildContext context, String title, List<String> lines) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Text(lines.join('\n')))),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Fechar', 'Close')))],
      ),
    );
  }

  List<String> _bonusLines(BonusTotal t) => [
        for (final b in t.applied) '${sgn(b.value)} ${BonusType.labelsPt[b.type] ?? b.type} — ${b.source}',
        for (final b in t.suppressed) '(${sgn(b.value)} ${BonusType.labelsPt[b.type] ?? b.type} — ${b.source}: ${tr('não acumula', 'does not stack')})',
        for (final b in t.situational) '${sgn(b.value)} ${b.condition} — ${b.source}',
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    final ch = c.ch;
    final scheme = Theme.of(context).colorScheme;
    void roll(String label, int bonus) => showRoll(context, c.roll('1d20${sgn(bonus)}', label));

    return ListView(padding: const EdgeInsets.all(8), children: [
      _HpCard(),
      SectionTitle(tr('Atributos', 'Abilities')),
      Wrap(children: [
        for (final a in abilityIds)
          StatBox(
            abilityAbbr(a),
            '${s.abilities[a]!.total}',
            sub: sgn(s.abilities[a]!.mod) +
                ((ch.abilityDamage[a] ?? 0) > 0 ? ' (−${ch.abilityDamage[a]} ${tr('dano', 'dmg')})' : ''),
            color: s.abilities[a]!.total != s.abilities[a]!.permanent ? scheme.tertiary : null,
            onTap: () => roll(abilityName(a), s.abilities[a]!.mod),
            onLongPress: () => _breakdown(context, abilityName(a), [
              '${tr('Base', 'Base')}: ${s.abilities[a]!.base}',
              '${tr('Racial', 'Racial')}: ${sgn(s.abilities[a]!.racial)}',
              '${tr('Aumentos de nível', 'Level increases')}: ${sgn(s.abilities[a]!.levelUps)}',
              if (s.abilities[a]!.drain > 0) '${tr('Dreno', 'Drain')}: −${s.abilities[a]!.drain}',
              if (s.abilities[a]!.damage > 0) '${tr('Dano', 'Damage')}: −${s.abilities[a]!.damage}',
              ..._bonusLines(s.abilities[a]!.bonuses),
            ]),
          ),
      ]),
      SectionTitle(tr('Defesa e combate', 'Defense & combat')),
      Wrap(children: [
        StatBox(tr('CA', 'AC'), '${s.ac.total}',
            sub: '${tr('toque', 'touch')} ${s.ac.touch} · ${tr('surpr.', 'flat')} ${s.ac.flatFooted}',
            width: 130,
            onTap: () => _breakdown(context, tr('Classe de Armadura', 'Armor Class'), [
                  '10 ${tr('base', 'base')}',
                  '${sgn(s.ac.dexApplied)} ${tr('Destreza', 'Dexterity')}',
                  ..._bonusLines(s.ac.bonuses),
                  if (s.ac.situational.isNotEmpty) '',
                  ...s.ac.situational,
                ])),
        StatBox(tr('Iniciativa', 'Initiative'), sgn(s.initiative),
            width: 100, onTap: () => roll(tr('Iniciativa', 'Initiative'), s.initiative)),
        StatBox(tr('BBA', 'BAB'), sgn(s.bab),
            sub: s.epicAttack > 0 ? '${tr('épico', 'epic')} ${sgn(s.epicAttack)}' : null, width: 90),
        StatBox(tr('Agarrar', 'Grapple'), sgn(s.grapple), width: 90, onTap: () => roll(tr('Agarrar', 'Grapple'), s.grapple)),
        StatBox(tr('Desloc.', 'Speed'), '${s.speed}′', sub: '${(s.speed * 0.3).toStringAsFixed(1)} m', width: 90),
        if (s.sr > 0) StatBox('RM / SR', '${s.sr}', width: 80),
        if (s.spellFailure > 0) StatBox(tr('Falha arc.', 'Arc. fail'), '${s.spellFailure}%', width: 90),
        for (final k in ['fort', 'ref', 'will'])
          StatBox(saveName(k), sgn(s.saves[k]!.total),
              sub: '${tr('base', 'base')} ${s.saves[k]!.base}',
              onTap: () => roll(saveName(k), s.saves[k]!.total),
              onLongPress: () => _breakdown(context, saveName(k), [
                    '${tr('Base', 'Base')}: ${s.saves[k]!.base}',
                    '${abilityAbbr(s.saves[k]!.ability)}: ${sgn(s.saves[k]!.abilMod)}',
                    ..._bonusLines(s.saves[k]!.misc),
                  ])),
      ]),
      SectionTitle(tr('Ataques', 'Attacks')),
      for (final a in s.attacks) _AttackTile(a),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (s.featNames.contains('Power Attack'))
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('Ataque Poderoso', 'Power Attack')),
                NumStepper(value: ch.powerAttack, min: 0, max: math.max(0, s.bab), onChanged: (v) => c.update((x) => x.powerAttack = v.toInt())),
              ]),
            if (s.featNames.contains('Combat Expertise'))
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('Especialização', 'Expertise')),
                NumStepper(
                    value: ch.combatExpertise, min: 0, max: math.min(5, math.max(0, s.bab)),
                    onChanged: (v) => c.update((x) {
                          x.combatExpertise = v.toInt();
                          x.customEffects.removeWhere((e) => e.source == '#expertise');
                          if (x.combatExpertise > 0) {
                            x.customEffects.add(Effect(target: 'ac', value: '${x.combatExpertise}', type: BonusType.dodge, source: '#expertise'));
                          }
                        })),
              ]),
            withHelp(tr('Duas armas', 'Two weapons'), FilterChip(
              label: Text(tr('Duas armas', 'Two weapons')),
              selected: ch.twoWeaponFighting,
              onSelected: (v) => c.update((x) => x.twoWeaponFighting = v),
            )),
            withHelp(tr('Lutar na defensiva (+2 CA)', 'Fight defensively (+2 AC)'), FilterChip(
              label: Text(tr('Lutar na defensiva (+2 CA)', 'Fight defensively (+2 AC)')),
              selected: ch.fightingDefensively,
              onSelected: (v) => c.update((x) {
                x.fightingDefensively = v;
                x.customEffects.removeWhere((e) => e.source == '#defensive');
                if (v) x.customEffects.add(Effect(target: 'ac', value: '2', type: BonusType.dodge, source: '#defensive'));
              }),
            )),
          ]),
        ),
      ),
      if (s.availableBuffs.isNotEmpty || s.resources.isNotEmpty) SectionTitle(tr('Recursos e habilidades ativáveis', 'Resources & toggles')),
      if (s.availableBuffs.isNotEmpty)
        Wrap(spacing: 8, children: [
          for (final b in s.availableBuffs)
            FilterChip(
              avatar: const Icon(Icons.local_fire_department, size: 16),
              label: Text(b.namePt.isNotEmpty && Lang.isPt ? b.namePt : b.name),
              selected: ch.buffs.any((x) => x.source == 'class:${b.id}' && x.active),
              onSelected: (on) => c.update((x) {
                x.buffs.removeWhere((y) => y.source == 'class:${b.id}');
                if (on) {
                  int? rounds;
                  if (b.duration.isNotEmpty) {
                    rounds = _evalRounds(b.duration, (n) => s.resolveVar(n));
                  }
                  x.buffs.add(ActiveBuff(name: b.namePt.isNotEmpty ? b.namePt : b.name, effects: b.effects, source: 'class:${b.id}', roundsLeft: rounds));
                  final res = s.resources.where((rr) => rr.id == b.id);
                  if (res.isNotEmpty) x.resourcesUsed[b.id] = (x.resourcesUsed[b.id] ?? 0) + 1;
                } else if (b.id == 'rage' && (s.classLevels['barbarian'] ?? 0) < 17) {
                  x.conditions.add('raging-fatigue');
                }
              }),
            ),
        ]),
      for (final r in s.resources)
        Card(
          child: ListTile(
            dense: true,
            title: Text(r.name),
            subtitle: Text('${r.max - r.used} / ${r.max} ${r.per == 'day' ? tr('por dia', 'per day') : r.per}'),
            trailing: NumStepper(
              value: r.used,
              min: 0,
              max: r.max,
              format: (v) => '$v',
              onChanged: (v) => c.update((x) => x.resourcesUsed[r.id] = v.toInt()),
            ),
          ),
        ),
      if (s.warnings.isNotEmpty) ...[
        SectionTitle(tr('Avisos', 'Warnings')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final w in s.warnings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.warning_amber, size: 16, color: scheme.error),
                    const SizedBox(width: 6),
                    Expanded(child: Text(w)),
                  ]),
                ),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 60),
    ]);
  }

  static int? _evalRounds(String formula, num Function(String) vars) {
    final v = Expr.evalInt(formula, vars);
    return v > 0 ? v : null;
  }
}

class _HpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    final ch = c.ch;
    final cur = s.hpMax - ch.damage;
    final frac = s.hpMax <= 0 ? 0.0 : (cur / s.hpMax).clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final state = s.hpState;
    final stateLabel = switch (state) {
      'dead' => tr('MORTO', 'DEAD'),
      'dying' => tr('MORRENDO', 'DYING'),
      'disabled' => tr('INCAPACITADO', 'DISABLED'),
      'staggered' => tr('ZONZO (não letal)', 'STAGGERED (nonlethal)'),
      'unconscious' => tr('INCONSCIENTE (não letal)', 'UNCONSCIOUS (nonlethal)'),
      _ => '',
    };
    Future<void> apply(String kind) async {
      final v = await promptInt(context, switch (kind) {
        'dmg' => tr('Dano sofrido', 'Damage taken'),
        'heal' => tr('Cura', 'Healing'),
        'temp' => tr('PV temporários', 'Temporary HP'),
        _ => tr('Dano não letal', 'Nonlethal damage'),
      });
      if (v == null || v == 0) return;
      c.update((x) {
        switch (kind) {
          case 'dmg':
            var d = v;
            final absorbed = math.min(x.tempHp, d);
            x.tempHp -= absorbed;
            d -= absorbed;
            x.damage += d;
            break;
          case 'heal':
            x.damage = math.max(0, x.damage - v);
            x.nonlethal = math.max(0, x.nonlethal - v);
            break;
          case 'temp':
            x.tempHp = math.max(x.tempHp, v);
            break;
          default:
            x.nonlethal += v;
        }
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            withHelp(tr('Pontos de vida', 'Hit points'), Text(tr('Pontos de vida', 'Hit points'), style: Theme.of(context).textTheme.titleMedium)),
            const Spacer(),
            if (stateLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(6)),
                child: Text(stateLabel, style: TextStyle(color: scheme.onError, fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$cur', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(' / ${s.hpMax}', style: Theme.of(context).textTheme.titleLarge),
            if (ch.tempHp > 0) Text('  +${ch.tempHp} ${tr('temp', 'temp')}', style: TextStyle(color: scheme.tertiary)),
            if (ch.nonlethal > 0) Text('  ${ch.nonlethal} ${tr('não letal', 'nonlethal')}', style: TextStyle(color: scheme.secondary)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 10,
              color: frac > 0.5 ? scheme.tertiary : (frac > 0.25 ? scheme.secondary : scheme.error),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            withHelp(tr('Dano', 'Damage'), FilledButton.icon(onPressed: () => apply('dmg'), icon: const Icon(Icons.heart_broken_outlined), label: Text(tr('Dano', 'Damage')))),
            withHelp(tr('Curar', 'Heal'), FilledButton.tonalIcon(onPressed: () => apply('heal'), icon: const Icon(Icons.healing), label: Text(tr('Curar', 'Heal')))),
            OutlinedButton(onPressed: () => apply('temp'), child: Text(tr('PV temp.', 'Temp HP'))),
            OutlinedButton(onPressed: () => apply('nl'), child: Text(tr('Não letal', 'Nonlethal'))),
            if (ch.damage > 0 || ch.tempHp > 0 || ch.nonlethal > 0)
              TextButton(
                  onPressed: () => c.update((x) {
                        x.damage = 0;
                        x.tempHp = 0;
                        x.nonlethal = 0;
                      }),
                  child: Text(tr('Zerar', 'Reset'))),
          ]),
        ]),
      ),
    );
  }
}

class _AttackTile extends StatelessWidget {
  final AttackLine a;
  const _AttackTile(this.a);
  @override
  Widget build(BuildContext context) {
    final c = context.read<CharacterController>();
    final dmgExpr = a.damage.replaceAll('/', '+');
    void attack(int bonus) {
      final r = c.roll('1d20${sgn(bonus)}', '${a.name} (${tr('ataque', 'attack')})');
      showRoll(context, r);
    }

    return Card(
      child: ListTile(
        leading: Icon(a.isRanged ? Icons.gps_fixed : Icons.hardware),
        title: Text(a.name),
        subtitle: Text([
          '${tr('Ataque', 'Attack')} ${a.bonusText}',
          '${tr('Dano', 'Damage')} ${a.damage} ${a.type}',
          '${tr('Dec.', 'Crit')} ${a.crit}',
          if (a.range > 0) '${a.range}′',
          ...a.notes,
        ].join(' · ')),
        trailing: Wrap(spacing: 4, children: [
          IconButton(
            tooltip: tr('Rolar ataque', 'Roll attack'),
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => attack(a.bonuses.first),
          ),
          IconButton(
            tooltip: tr('Rolar dano', 'Roll damage'),
            icon: const Icon(Icons.water_drop_outlined),
            onPressed: () {
              try {
                showRoll(context, c.roll(dmgExpr.split(' ').first, '${a.name} (${tr('dano', 'damage')})'));
              } catch (_) {
                toast(context, tr('Dano não rolável: ${a.damage}', 'Damage not rollable: ${a.damage}'));
              }
            },
          ),
          if (a.bonuses.length > 1)
            IconButton(
              tooltip: tr('Ataque total', 'Full attack'),
              icon: const Icon(Icons.repeat),
              onPressed: () {
                final rs = [for (final b in a.bonuses) c.roll('1d20${sgn(b)}', a.name)];
                showDialog(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text('${tr('Ataque total', 'Full attack')}: ${a.name}'),
                    content: Text(rs.map((r) => '${r.total}  (${r.breakdown})${r.natural20 == 20 ? '  ★' : ''}').join('\n')),
                    actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }
}
