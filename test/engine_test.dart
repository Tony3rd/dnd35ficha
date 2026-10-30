import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:grimorio35/engine/bonus.dart';
import 'package:grimorio35/engine/calc.dart';
import 'package:grimorio35/engine/dice.dart';
import 'package:grimorio35/engine/expr.dart';
import 'package:grimorio35/engine/ruleset.dart';
import 'package:grimorio35/model/character.dart';
import 'package:grimorio35/model/xml_io.dart';

Ruleset loadRules() => Ruleset.fromCoreJson(File('assets/srd/core.json').readAsStringSync());

Character fighter(int level, {String race = 'human'}) {
  final c = Character(name: 'Teste', raceId: race, baseAbilities: {
    'str': 16, 'dex': 14, 'con': 14, 'int': 10, 'wis': 12, 'cha': 8,
  });
  for (var i = 0; i < level; i++) {
    c.levels.add(ClassLevel(classId: 'fighter', hpRoll: 6, abilityIncrease: (i + 1) % 4 == 0 ? 'str' : null));
  }
  return c;
}

void main() {
  final rules = loadRules();
  final calc = Calculator(rules);

  group('Dados', () {
    test('parse e limites', () {
      final d = Dice(Random(1));
      for (var i = 0; i < 200; i++) {
        final r = d.roll('2d6+3');
        expect(r.total, inInclusiveRange(5, 15));
      }
      final k = d.roll('4d6kh3');
      expect(k.terms.first.kept.where((x) => x).length, 3);
      expect(() => Dice.parse('2x6'), throwsA(isA<DiceParseException>()));
      expect(d.roll('1d20+5').natural20, isNotNull);
      expect(d.roll('10').total, 10);
      expect(d.roll('1d4-10').total, lessThan(0));
    });
  });

  group('Fórmulas', () {
    test('aritmética e funções', () {
      num v(String n) => {'class.barbarian': 11, 'abil.con.mod': 3}[n] ?? 0;
      expect(Expr.eval('1+2*3', v), 7);
      expect(Expr.eval('floor(@class.barbarian/4)+1', v), 3);
      expect(Expr.eval('if(gte(@class.barbarian,11),6,4)', v), 6);
      expect(Expr.eval('3+@abil.con.mod', v), 6);
      expect(Expr.eval('min(10, max(1, -5))', v), 1);
    });
  });

  group('Empilhamento de bônus', () {
    test('mesmo tipo não acumula; esquiva acumula; penalidades acumulam', () {
      final p = BonusPool()
        ..add(ResolvedBonus('ac', 2, BonusType.deflection, 'anel'))
        ..add(ResolvedBonus('ac', 3, BonusType.deflection, 'magia'))
        ..add(ResolvedBonus('ac', 1, BonusType.dodge, 'Esquiva'))
        ..add(ResolvedBonus('ac', 1, BonusType.dodge, 'haste'))
        ..add(ResolvedBonus('ac', -2, BonusType.untyped, 'fúria'))
        ..add(ResolvedBonus('ac', -1, BonusType.untyped, 'outro'));
      final t = p.total(['ac']);
      expect(t.total, 3 + 2 - 3);
      expect(t.suppressed.length, 1);
    });
  });

  group('Ficha', () {
    test('guerreiro humano 1', () {
      final s = calc.compute(fighter(1));
      expect(s.bab, 1);
      expect(s.saves['fort']!.total, 2 + 2);
      expect(s.saves['ref']!.total, 0 + 2);
      expect(s.saves['will']!.total, 0 + 1);
      expect(s.hpMax, 10 + 2);
      expect(s.ac.total, 12);
      expect(s.initiative, 2);
      expect(s.skillPointsTotal, (2 + 0 + 1) * 4);
      // humano 1 talento + 1 geral + 1 guerreiro
      expect(s.featSlots.total, 3);
    });

    test('progressão épica (nível 25)', () {
      final s = calc.compute(fighter(25));
      // BBA 20 + épico ceil(5/2)=3
      expect(s.bab, 23);
      // Fort base 12 + épico floor(5/2)=2
      expect(s.saves['fort']!.base, 14);
      expect(s.attacks.first.bonuses.length, 4);
    });

    test('armadura limita Destreza e aplica penalidade', () {
      final c = fighter(1)..baseAbilities['dex'] = 18;
      c.items.add(Item(name: 'Cota', kind: 'armor', baseRef: 'Chainmail', equipped: true, weight: 40));
      final s = calc.compute(c);
      expect(s.ac.dexApplied, 2);
      expect(s.ac.total, 10 + 5 + 2);
      expect(s.armorCheck, -5);
      expect(s.speed, 20);
      final climb = s.skills.firstWhere((k) => k.key == 'climb');
      expect(climb.acp, -5);
    });

    test('anão não é desacelerado e halfling é pequeno', () {
      final d = calc.compute(fighter(1, race: 'dwarf'));
      expect(d.speed, 20);
      final h = calc.compute(fighter(1, race: 'halfling'));
      expect(h.ac.total, 10 + 3 + 1);
      expect(h.saves['will']!.total, 0 + 1 + 1);
    });

    test('condições e buffs', () {
      final c = fighter(4);
      c.conditions.add('shaken');
      c.buffs.add(ActiveBuff(name: 'Força do Touro', effects: [Effect(target: 'abil.str', value: '4', type: BonusType.enhancement)]));
      final s = calc.compute(c);
      expect(s.abilities['str']!.total, 16 + 1 + 4);
      expect(s.saves['will']!.total, 1 + 1 - 2);
    });

    test('fúria do bárbaro', () {
      final c = Character(raceId: 'human', baseAbilities: {'str': 16, 'dex': 12, 'con': 14, 'int': 8, 'wis': 10, 'cha': 10});
      c.levels.add(ClassLevel(classId: 'barbarian'));
      final base = calc.compute(c);
      final rage = base.availableBuffs.firstWhere((b) => b.id == 'rage');
      c.buffs.add(ActiveBuff(name: 'Fúria', effects: rage.effects));
      final s = calc.compute(c);
      expect(s.abilities['str']!.total, 20);
      expect(s.ac.total, base.ac.total - 2);
      expect(s.hpMax, base.hpMax + 2);
      expect(s.speed, 40);
    });

    test('magias por dia com bônus de atributo', () {
      final c = Character(raceId: 'human', baseAbilities: {'str': 8, 'dex': 14, 'con': 12, 'int': 18, 'wis': 10, 'cha': 10});
      for (var i = 0; i < 5; i++) {
        c.levels.add(ClassLevel(classId: 'wizard'));
      }
      final s = calc.compute(c);
      final w = s.casters.single;
      expect(w.casterLevel, 5);
      final l3 = w.levels.firstWhere((l) => l.level == 3);
      expect(l3.base, 1);
      expect(l3.bonus, 1);
      expect(l3.dc, 10 + 3 + 4);
    });

    test('talento Weapon Focus e Toughness', () {
      final c = fighter(1);
      c.items.add(Item(name: 'Espada longa', kind: 'weapon', baseRef: 'Longsword', equipped: true));
      c.levels.first.feats.addAll([
        FeatPick('Weapon Focus (Longsword)'),
        FeatPick('Toughness'),
      ]);
      final s = calc.compute(c);
      final atk = s.attacks.firstWhere((a) => a.item != null);
      expect(atk.bonuses.first, 1 + 3 + 1);
      expect(atk.damage, '1d8+3');
      expect(atk.crit, '19-20/x2');
      expect(s.hpMax, 12 + 3);
    });
  });

  test('XML ida e volta', () {
    final c = fighter(3)
      ..name = 'Ána "Lâmina" <Teste>'
      ..damage = 5
      ..conditions = {'prone'};
    c.items.add(Item(name: 'Arco', kind: 'weapon', baseRef: 'Longbow, composite', compositeStr: 2, properties: ['keen']));
    c.levels.first.skillRanks['craft:Alquimia'] = 2.5;
    final xml = characterToXml(c);
    final back = characterFromXml(xml);
    expect(back.name, c.name);
    expect(back.levels.length, 3);
    expect(back.damage, 5);
    expect(back.conditions, {'prone'});
    expect(back.items.single.compositeStr, 2);
    expect(back.levels.first.skillRanks['craft:Alquimia'], 2.5);
    expect(back.items.single.properties, ['keen']);
  });
}
