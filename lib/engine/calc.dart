// Calcula todos os valores derivados de uma ficha a partir das escolhas do
// jogador (model/character.dart) e das regras ativas (ruleset.dart).
import 'dart:convert';
import 'dart:math' as math;

import '../model/character.dart';
import 'bonus.dart';
import 'defs.dart';
import 'expr.dart';
import 'ruleset.dart';

int abilityMod(int score) => ((score - 10) / 2).floor();

String signed(int v) => v >= 0 ? '+$v' : '$v';

class AbilityLine {
  final String id;
  final int base, racial, levelUps, drain, damage;
  final BonusTotal bonuses;
  final int total;
  AbilityLine(this.id, this.base, this.racial, this.levelUps, this.drain, this.damage, this.bonuses, this.total);
  int get mod => abilityMod(total);
  /// Valor "permanente" (sem bônus temporários): usado para pontos de perícia etc.
  int get permanent => base + racial + levelUps - drain;
}

class SaveLine {
  final String id, ability;
  final int base, abilMod;
  final BonusTotal misc;
  SaveLine(this.id, this.ability, this.base, this.abilMod, this.misc);
  int get total => base + abilMod + misc.total;
}

class SkillLine {
  final String key; // "hide" ou "craft:Alquimia"
  final SkillDef def;
  final String label;
  final double ranks;
  final int abilMod, acp, synergy, sizeMod;
  final BonusTotal misc;
  final bool classSkill, usable;
  final double maxRanks;
  final List<String> situational;
  SkillLine({
    required this.key,
    required this.def,
    required this.label,
    required this.ranks,
    required this.abilMod,
    required this.acp,
    required this.synergy,
    required this.sizeMod,
    required this.misc,
    required this.classSkill,
    required this.usable,
    required this.maxRanks,
    required this.situational,
  });
  int get total => ranks.floor() + abilMod + acp + synergy + sizeMod + misc.total;
}

class AttackLine {
  final String name;
  final Item? item;
  final List<int> bonuses; // ataques totais (iterativos)
  final String damage;
  final String crit;
  final int range;
  final String type;
  final List<String> notes;
  final bool isRanged;
  AttackLine(this.name, this.item, this.bonuses, this.damage, this.crit, this.range, this.type, this.notes, this.isRanged);
  String get bonusText => bonuses.map(signed).join('/');
}

class SpellLevelInfo {
  final int level;
  final int base, bonus, domain, specialist;
  final int known;
  final int dc;
  final bool castable;
  SpellLevelInfo(this.level, this.base, this.bonus, this.domain, this.specialist, this.known, this.dc, this.castable);
  int get perDay => base < 0 ? 0 : base + bonus;
}

class CasterInfo {
  final ClassDef cls;
  final int effectiveLevel;
  final int casterLevel;
  final String ability;
  final int abilityScore;
  final List<SpellLevelInfo> levels;
  CasterInfo(this.cls, this.effectiveLevel, this.casterLevel, this.ability, this.abilityScore, this.levels);
}

class ResourceLine {
  final String id, name;
  final int max, used;
  final String per;
  ResourceLine(this.id, this.name, this.max, this.used, this.per);
}

class Encumbrance {
  final double carried;
  final int light, medium, heavy;
  final String load; // light | medium | heavy | over
  Encumbrance(this.carried, this.light, this.medium, this.heavy, this.load);
}

class AcLine {
  final int total, touch, flatFooted;
  final int dexApplied;
  final BonusTotal bonuses;
  final List<String> situational;
  AcLine(this.total, this.touch, this.flatFooted, this.dexApplied, this.bonuses, this.situational);
}

class FeatSlots {
  final int general, race, epicOrGeneral;
  final Map<String, int> classBonus;
  FeatSlots(this.general, this.race, this.epicOrGeneral, this.classBonus);
  int get total => general + race + classBonus.values.fold(0, (a, b) => a + b);
}

class Sheet {
  final Character ch;
  final Ruleset rules;
  RaceDef? race;
  final Map<String, ClassDef> classDefs = {};
  final Map<String, int> classLevels = {};
  final Map<String, int> classLevelsPre20 = {};
  int characterLevel = 0;
  int ecl = 0;
  String size = 'medium';
  final Map<String, AbilityLine> abilities = {};
  int bab = 0;
  int epicAttack = 0;
  int epicSave = 0;
  final Map<String, SaveLine> saves = {};
  int hpMax = 0;
  int initiative = 0;
  BonusTotal? initBonus;
  late AcLine ac;
  int grapple = 0;
  int speed = 30;
  int spellFailure = 0;
  int armorCheck = 0;
  int sr = 0;
  final List<SkillLine> skills = [];
  final List<AttackLine> attacks = [];
  final List<CasterInfo> casters = [];
  final List<ResourceLine> resources = [];
  final List<BuffDef> availableBuffs = [];
  final List<String> features = [];
  final List<String> warnings = [];
  late Encumbrance encumbrance;
  late FeatSlots featSlots;
  final pool = BonusPool();
  final Set<String> featNames = {};
  Item? armor;
  Item? shield;
  ArmorDef? armorDef;
  ArmorDef? shieldDef;
  int xpNeeded = 0;
  int skillPointsTotal = 0;
  double skillPointsSpent = 0;

  Sheet(this.ch, this.rules);

  int get hpCurrent => hpMax + ch.tempHp - ch.damage;
  String get hpState {
    final cur = hpMax - ch.damage;
    if (cur <= -10) return 'dead';
    if (cur < 0) return 'dying';
    if (cur == 0) return 'disabled';
    if (ch.nonlethal >= cur && ch.nonlethal > 0) return ch.nonlethal == cur ? 'staggered' : 'unconscious';
    return 'ok';
  }

  bool isClassSkill(String key) {
    final base = key.split(':').first;
    if (ch.extraClassSkills.contains(base) || ch.extraClassSkills.contains(key)) return true;
    for (final c in classDefs.values) {
      if (c.classSkills.contains(base)) return true;
    }
    return false;
  }

  bool isClassSkillFor(String classId, String key) {
    final base = key.split(':').first;
    if (ch.extraClassSkills.contains(base)) return true;
    final c = classDefs[classId];
    return c != null && c.classSkills.contains(base);
  }

  num resolveVar(String name, {bool finalAbilities = true}) {
    final p = name.split('.');
    switch (p.first) {
      case 'abil':
        if (p.length < 2) return 0;
        final a = abilities[p[1]];
        int score;
        if (a != null && finalAbilities) {
          score = a.total;
        } else {
          score = (ch.baseAbilities[p[1]] ?? 10) + (race?.abilityAdj[p[1]] ?? 0);
        }
        return p.length > 2 && p[2] == 'mod' ? abilityMod(score) : score;
      case 'class':
        return p.length > 1 ? (classLevels[p[1]] ?? 0) : 0;
      case 'level':
      case 'hd':
        return characterLevel;
      case 'ecl':
        return ecl;
      case 'bab':
        return bab;
      case 'skill':
        if (p.length < 2) return 0;
        return ranksOf(p.sublist(1).join('.'));
      case 'size':
        return rules.size(size).mod;
      case 'cl':
        return casters.isEmpty ? 0 : casters.map((c) => c.casterLevel).reduce(math.max);
      case 'negativelevels':
        return ch.negativeLevels;
      default:
        return 0;
    }
  }

  double ranksOf(String key) {
    var r = 0.0;
    for (final l in ch.levels) {
      r += l.skillRanks[key] ?? 0;
    }
    return r;
  }

  /// Graduações somadas de todas as instâncias de uma perícia com subtipos.
  double ranksOfBase(String base) {
    var best = 0.0;
    final keys = <String>{};
    for (final l in ch.levels) {
      for (final k in l.skillRanks.keys) {
        if (k == base || k.startsWith('$base:')) keys.add(k);
      }
    }
    for (final k in keys) {
      best = math.max(best, ranksOf(k));
    }
    return best;
  }
}

class Calculator {
  final Ruleset rules;
  Calculator(this.rules);

  Sheet compute(Character ch) {
    final s = Sheet(ch, rules);
    _identity(s);
    final effects = _collectEffects(s);
    _abilities(s, effects);
    _resolveEffects(s, effects);
    _babAndSaves(s);
    _equipment(s);
    _encumbrance(s);
    _armorClass(s);
    _hp(s);
    _misc(s);
    _skills(s);
    _attacks(s);
    _casting(s);
    _resources(s);
    _validate(s);
    return s;
  }

  // ------------------------------------------------------------ identidade
  void _identity(Sheet s) {
    final ch = s.ch;
    s.race = rules.raceById(ch.raceId, book: ch.raceBook) ?? _embeddedRace(ch);
    s.size = ch.sizeOverride ?? s.race?.size ?? 'medium';
    var n = 0;
    for (final l in ch.levels) {
      n++;
      final def = s.classDefs[l.classId] ??
          rules.classById(l.classId, book: l.classBook) ??
          _embeddedClass(ch, l.classId) ??
          ClassDef(id: l.classId, name: l.classId, hitDie: 8, skillPoints: 2, bab: '3/4', goodSaves: {}, classSkills: []);
      s.classDefs[l.classId] = def;
      s.classLevels[l.classId] = (s.classLevels[l.classId] ?? 0) + 1;
      if (n <= 20) s.classLevelsPre20[l.classId] = (s.classLevelsPre20[l.classId] ?? 0) + 1;
      for (final f in l.feats) {
        s.featNames.add(f.name);
      }
    }
    s.characterLevel = ch.levels.length;
    s.ecl = s.characterLevel + (s.race?.la ?? 0);
    final e = s.ecl;
    s.xpNeeded = e <= 1 ? 0 : (e * (e - 1) ~/ 2) * 1000;
  }

  RaceDef? _embeddedRace(Character ch) {
    final j = ch.embeddedDefs['race:${ch.raceId}'];
    if (j == null) return null;
    try {
      return RaceDef.fromJson(Map<String, dynamic>.from(jsonDecode(j) as Map));
    } catch (_) {
      return null;
    }
  }

  ClassDef? _embeddedClass(Character ch, String id) {
    final j = ch.embeddedDefs['class:$id'];
    if (j == null) return null;
    try {
      return ClassDef.fromJson(Map<String, dynamic>.from(jsonDecode(j) as Map));
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ efeitos
  List<Effect> _collectEffects(Sheet s) {
    final ch = s.ch;
    final out = <Effect>[];
    final race = s.race;
    if (race != null) out.addAll(race.effects.map((e) => e.copyWith(source: race.displayName(true))));
    for (final entry in s.classDefs.entries) {
      final lvl = s.classLevels[entry.key] ?? 0;
      final c = entry.value;
      out.addAll(c.effects);
      for (final f in c.features) {
        if (f.level <= lvl) {
          out.addAll(f.effects);
        }
      }
    }
    // talentos
    for (final l in ch.levels) {
      for (final fp in l.feats) {
        final def = rules.featByName(fp.name, book: fp.book);
        if (def == null) continue;
        final choice = Ruleset.featChoice(fp.name) ?? '';
        for (final e in def.effects) {
          out.add(Effect(
            target: e.target.replaceAll('{choice}', _choiceKey(def.choice, choice)),
            value: e.value,
            type: e.type,
            condition: e.condition,
            source: fp.name,
          ));
        }
      }
    }
    // condições
    for (final cid in ch.conditions) {
      final c = rules.conditions[cid];
      if (c != null) out.addAll(c.effects);
    }
    // buffs ativos
    for (final b in ch.buffs.where((b) => b.active)) {
      out.addAll(b.effects.map((e) => e.copyWith(source: b.name)));
    }
    // itens equipados
    for (final it in ch.items.where((i) => i.equipped)) {
      out.addAll(it.effects.map((e) => e.copyWith(source: it.name)));
    }
    out.addAll(ch.customEffects);
    // níveis negativos
    if (ch.negativeLevels > 0) {
      final v = '-${ch.negativeLevels}';
      for (final t in ['attack.all', 'save.all', 'skill.all', 'abilitycheck', 'cl.all']) {
        out.add(Effect(target: t, value: v, source: 'Níveis negativos'));
      }
      out.add(Effect(target: 'hp.max', value: '-${ch.negativeLevels * 5}', source: 'Níveis negativos'));
    }
    return out;
  }

  String _choiceKey(String? kind, String choice) {
    if (kind == 'skill') return slugify(choice).isEmpty ? choice : _skillKeyFromName(choice);
    if (kind == 'weapon') return slugify(choice);
    if (kind == 'school') return slugify(choice);
    return choice;
  }

  String _skillKeyFromName(String n) {
    final sl = slugify(n);
    for (final d in rules.skills.values) {
      if (d.id == sl || slugify(d.name) == sl || slugify(d.namePt) == sl) return d.id;
    }
    return sl;
  }

  void _abilities(Sheet s, List<Effect> effects) {
    final ch = s.ch;
    final pre = BonusPool();
    for (final e in effects.where((e) => e.target.startsWith('abil.'))) {
      final v = Expr.evalInt(e.value, (n) => s.resolveVar(n, finalAbilities: false));
      pre.add(ResolvedBonus(e.target, v, e.type, e.source, e.situational ? e.condition : null));
    }
    bool flag(String f) => effects.any((e) => e.target == 'flag.$f' && !e.situational && e.value != '0');
    final ups = <String, int>{};
    for (final l in ch.levels) {
      final a = l.abilityIncrease;
      if (a != null) ups[a] = (ups[a] ?? 0) + 1;
    }
    for (final a in abilityIds) {
      final base = ch.baseAbilities[a] ?? 10;
      final racial = s.race?.abilityAdj[a] ?? 0;
      final drain = ch.abilityDrain[a] ?? 0;
      final dmg = ch.abilityDamage[a] ?? 0;
      final bt = pre.total(['abil.$a']);
      var total = base + racial + (ups[a] ?? 0) - drain + bt.total - dmg;
      if (a == 'dex' && flag('dex_zero')) total = 0;
      if (a == 'str' && flag('str_zero')) total = 0;
      if (total < 0) total = 0;
      s.abilities[a] = AbilityLine(a, base, racial, ups[a] ?? 0, drain, dmg, bt, total);
    }
  }

  void _resolveEffects(Sheet s, List<Effect> effects) {
    for (final e in effects.where((e) => !e.target.startsWith('abil.'))) {
      final v = Expr.evalInt(e.value, (n) => s.resolveVar(n));
      s.pool.add(ResolvedBonus(e.target, v, e.type, e.source, e.situational ? e.condition : null));
    }
  }

  // ------------------------------------------------------------ BBA e resistências
  void _babAndSaves(Sheet s) {
    var bab = 0;
    final base = {'fort': 0, 'ref': 0, 'will': 0};
    s.classLevelsPre20.forEach((id, lvl) {
      final c = s.classDefs[id]!;
      bab += c.babAt(lvl);
      for (final k in base.keys.toList()) {
        base[k] = base[k]! + c.saveAt(k, lvl);
      }
    });
    final epicLevels = math.max(0, s.characterLevel - 20);
    s.epicAttack = (epicLevels + 1) ~/ 2;
    s.epicSave = epicLevels ~/ 2;
    s.bab = bab + s.epicAttack + s.pool.total(['bab']).total;
    const ab = {'fort': 'con', 'ref': 'dex', 'will': 'wis'};
    for (final k in base.keys) {
      s.saves[k] = SaveLine(k, ab[k]!, base[k]! + s.epicSave, s.abilities[ab[k]]!.mod, s.pool.total(['save.$k', 'save.all']));
    }
  }

  // ------------------------------------------------------------ equipamento
  void _equipment(Sheet s) {
    for (final it in s.ch.items.where((i) => i.equipped)) {
      if (it.kind == 'armor' && s.armor == null) {
        s.armor = it;
        s.armorDef = it.baseRef == null ? null : rules.armorByName(it.baseRef!);
      } else if (it.kind == 'shield' && s.shield == null) {
        s.shield = it;
        s.shieldDef = it.baseRef == null ? null : rules.armorByName(it.baseRef!);
      }
    }
  }

  bool _proficientArmor(Sheet s, String category) {
    for (final c in s.classDefs.values) {
      if (c.armorProf.contains(category)) return true;
    }
    final featFor = {
      'light': 'Armor Proficiency (Light)',
      'medium': 'Armor Proficiency (Medium)',
      'heavy': 'Armor Proficiency (Heavy)',
      'shield': 'Shield Proficiency',
      'tower': 'Tower Shield Proficiency',
    };
    return s.featNames.contains(featFor[category]);
  }

  bool proficientWeapon(Sheet s, WeaponDef? w, String name) {
    if (w == null) return true;
    if (w.name == 'Unarmed strike' || w.name == 'Gauntlet') return true;
    for (final c in s.classDefs.values) {
      if (c.weaponProf.contains(w.category) || c.weaponProf.contains(w.name)) return true;
    }
    for (final f in s.featNames) {
      if (f == 'Simple Weapon Proficiency' && w.category == 'simple') return true;
      final ch = Ruleset.featChoice(f);
      if (ch != null && slugify(ch) == w.id &&
          (f.startsWith('Martial Weapon Proficiency') || f.startsWith('Exotic Weapon Proficiency'))) {
        return true;
      }
    }
    // familiaridade racial (anões, gnomos) — tratada como proficiência marcial
    final race = s.race?.id;
    if (race == 'dwarf' && (w.id == 'waraxe-dwarven' || w.id == 'urgrosh-dwarven')) {
      return s.classDefs.values.any((c) => c.weaponProf.contains('martial'));
    }
    if (race == 'gnome' && w.id == 'hammer-gnome-hooked') {
      return s.classDefs.values.any((c) => c.weaponProf.contains('martial'));
    }
    if (race == 'elf' && ['longsword', 'rapier', 'longbow', 'longbow-composite', 'shortbow', 'shortbow-composite'].contains(w.id)) {
      return true;
    }
    return false;
  }

  void _encumbrance(Sheet s) {
    var w = 0.0;
    for (final it in s.ch.items) {
      if (it.location == 'stored' || it.location == 'mount') continue;
      w += it.totalWeight;
    }
    final coins = s.ch.money.values.fold<int>(0, (a, b) => a + b);
    w += coins / 50.0;
    final str = s.abilities['str']!.total;
    final mult = s.rules.size(s.size).carry;
    final heavy = (s.rules.heavyLoadFor(str) * mult).floor();
    final light = heavy ~/ 3;
    final medium = (heavy * 2) ~/ 3;
    String load;
    if (w <= light) {
      load = 'light';
    } else if (w <= medium) {
      load = 'medium';
    } else if (w <= heavy) {
      load = 'heavy';
    } else {
      load = 'over';
    }
    s.encumbrance = Encumbrance(w, light, medium, heavy, load);
  }

  void _armorClass(Sheet s) {
    final p = s.pool;
    final sz = s.rules.size(s.size);
    if (sz.mod != 0) p.add(ResolvedBonus('ac', sz.mod, BonusType.size, 'Tamanho'));
    var maxDex = 99;
    var acp = 0;
    var asf = 0;
    final a = s.armor;
    if (a != null) {
      final d = s.armorDef;
      final bonus = (a.armorBonus ?? d?.bonus ?? 0) + a.enhancement;
      p.add(ResolvedBonus('ac', bonus, BonusType.armor, a.name));
      final md = a.maxDex ?? d?.maxDex;
      if (md != null) maxDex = math.min(maxDex, md);
      var ac = a.acp ?? d?.acp ?? 0;
      if (a.masterwork || a.enhancement > 0) ac = math.min(0, ac + 1);
      acp += ac;
      asf += a.asf ?? d?.asf ?? 0;
      final cat = a.category ?? d?.category ?? 'light';
      if (!_proficientArmor(s, cat)) {
        s.warnings.add('Sem proficiência com ${a.name}: penalidade de armadura aplica-se aos ataques.');
        p.add(ResolvedBonus('attack.all', ac, BonusType.untyped, 'Armadura sem proficiência'));
      }
    }
    final sh = s.shield;
    if (sh != null) {
      final d = s.shieldDef;
      final bonus = (sh.armorBonus ?? d?.bonus ?? 0) + sh.enhancement;
      p.add(ResolvedBonus('ac', bonus, BonusType.shield, sh.name));
      final md = sh.maxDex ?? d?.maxDex;
      if (md != null) maxDex = math.min(maxDex, md);
      var ac = sh.acp ?? d?.acp ?? 0;
      if (sh.masterwork || sh.enhancement > 0) ac = math.min(0, ac + 1);
      acp += ac;
      asf += sh.asf ?? d?.asf ?? 0;
      final cat = (d?.id == 'shield-tower') ? 'tower' : 'shield';
      if (!_proficientArmor(s, cat)) {
        s.warnings.add('Sem proficiência com ${sh.name}: penalidade aplica-se aos ataques.');
        p.add(ResolvedBonus('attack.all', ac, BonusType.untyped, 'Escudo sem proficiência'));
      }
    }
    // carga
    final load = s.encumbrance.load;
    if (load == 'medium') {
      maxDex = math.min(maxDex, 3);
      acp = math.min(acp, -3);
    } else if (load == 'heavy' || load == 'over') {
      maxDex = math.min(maxDex, 1);
      acp = math.min(acp, -6);
    }
    s.armorCheck = acp;
    s.spellFailure = asf;

    // bônus condicionais de classe (monge, movimento rápido)
    final unarmored = s.armor == null && s.shield == null && load == 'light';
    final notHeavy = (s.armorDef?.category ?? s.armor?.category ?? 'light') != 'heavy' && load != 'heavy' && load != 'over';
    final fixed = <ResolvedBonus>[];
    final remove = <ResolvedBonus>[];
    for (final b in p.all) {
      if (b.type == 'monk_unarmored') {
        remove.add(b);
        if (unarmored) fixed.add(ResolvedBonus(b.target, b.value, BonusType.untyped, b.source, b.condition));
      } else if (b.type == 'not_heavy') {
        remove.add(b);
        if (notHeavy) fixed.add(ResolvedBonus(b.target, b.value, BonusType.untyped, b.source, b.condition));
      }
    }
    if (remove.isNotEmpty) {
      p.removeWhere((b) => remove.contains(b));
      p.addAll(fixed);
    }

    final dexMod = s.abilities['dex']!.mod;
    final loseDex = s.pool.hasFlag('lose_dex_ac') || s.pool.hasFlag('dex_zero');
    var dexAc = math.min(dexMod, maxDex);
    final all = s.pool.total(['ac']);
    final touch = s.pool.total(['ac'], excludeTypes: {BonusType.armor, BonusType.shield, BonusType.natural, BonusType.naturalEnh});
    final ffBonus = s.pool.total(['ac'], excludeTypes: {BonusType.dodge});
    final ffTouchless = math.min(0, dexAc);
    if (loseDex) {
      dexAc = ffTouchless;
      s.ac = AcLine(10 + ffBonus.total + dexAc, 10 + touch.total - touch.byType(BonusType.dodge) + dexAc,
          10 + ffBonus.total + dexAc, dexAc, ffBonus, all.situational.map(_situ).toList());
    } else {
      s.ac = AcLine(10 + all.total + dexAc, 10 + touch.total + dexAc, 10 + ffBonus.total + ffTouchless, dexAc, all,
          all.situational.map(_situ).toList());
    }
  }

  String _situ(ResolvedBonus b) => '${signed(b.value)} ${b.condition} (${b.source})';

  // ------------------------------------------------------------ PV
  void _hp(Sheet s) {
    final con = s.abilities['con']!.mod;
    var hp = 0;
    var i = 0;
    for (final l in s.ch.levels) {
      final hd = s.classDefs[l.classId]!.hitDie;
      final roll = i == 0 ? hd : (l.hpRoll <= 0 ? (hd ~/ 2 + 1) : math.min(l.hpRoll, hd));
      hp += math.max(1, roll + con);
      i++;
    }
    hp += s.pool.total(['hp.max']).total;
    s.hpMax = math.max(hp, s.characterLevel > 0 ? 1 : 0);
  }

  // ------------------------------------------------------------ iniciativa, agarrar, deslocamento
  void _misc(Sheet s) {
    s.initBonus = s.pool.total(['init']);
    s.initiative = s.abilities['dex']!.mod + s.initBonus!.total;
    final sz = s.rules.size(s.size);
    s.grapple = s.bab + s.abilities['str']!.mod + sz.grapple + s.pool.total(['grapple']).total;
    var base = s.race?.speed ?? 30;
    final noSlow = s.pool.hasFlag('armor_no_slow');
    final cat = s.armorDef?.category ?? s.armor?.category;
    final slowed = (cat == 'medium' || cat == 'heavy' || s.encumbrance.load == 'medium' || s.encumbrance.load == 'heavy') && !noSlow;
    if (slowed) {
      base = base - (base ~/ 15) * 5; // 20→15, 30→20, 40→30, 50→35, 60→40 (PH tabela 7-6)
    }
    var sp = base + s.pool.total(['speed.land']).total;
    if (s.pool.hasFlag('half_speed')) sp = sp ~/ 2;
    if (s.encumbrance.load == 'over') sp = 5;
    s.speed = sp;
    final srs = s.pool.all.where((b) => b.target == 'sr' && b.condition == null).map((b) => b.value);
    s.sr = srs.isEmpty ? 0 : srs.reduce(math.max);
    // características de classe para exibição
    for (final e in s.classDefs.entries) {
      final lvl = s.classLevels[e.key] ?? 0;
      final seen = <String>{};
      for (final f in e.value.features.where((f) => f.level <= lvl)) {
        final n = f.displayName(true);
        if (seen.add(n)) s.features.add('$n (${e.value.displayName(true)})');
      }
      s.availableBuffs.addAll(e.value.buffs);
    }
    if (s.race != null) s.features.addAll(s.race!.features);
  }

  // ------------------------------------------------------------ perícias
  void _skills(Sheet s) {
    final ch = s.ch;
    final keys = <String>{};
    for (final d in rules.skills.values) {
      if (!d.subtypes) keys.add(d.id);
    }
    for (final l in ch.levels) {
      keys.addAll(l.skillRanks.keys);
    }
    for (final d in rules.skills.values.where((d) => d.subtypes)) {
      if (!keys.any((k) => k.startsWith('${d.id}:'))) keys.add(d.id);
    }
    final sizeHide = s.rules.size(s.size).hide;
    final lvl = s.characterLevel;
    for (final key in keys) {
      final baseId = key.split(':').first;
      final def = rules.skills[baseId];
      if (def == null) continue;
      final ranks = s.ranksOf(key);
      final abilMod = def.ability == 'none' ? 0 : s.abilities[def.ability]!.mod;
      final acp = def.acp == 0 ? 0 : s.armorCheck * def.acp;
      var syn = 0;
      final situ = <String>[];
      for (final sy in rules.synergies.where((x) => x.to == baseId)) {
        final fromRanks = rules.skills[sy.from]?.subtypes == true ? s.ranksOfBase(sy.from) : s.ranksOf(sy.from);
        if (fromRanks >= 5) {
          final fromName = rules.skills[sy.from]?.displayName(true) ?? sy.from;
          if (sy.cond == null) {
            syn += 2;
          } else {
            situ.add('+2 ${sy.cond} (sinergia: $fromName)');
          }
        }
      }
      final misc = s.pool.total(['skill.$key', if (key != baseId) 'skill.$baseId', 'skill.all', 'skillabil.${def.ability}']);
      situ.addAll(misc.situational.map(_situ));
      final cs = s.isClassSkill(key);
      final maxR = cs ? (lvl + 3).toDouble() : (lvl + 3) / 2;
      final usable = !def.trainedOnly || ranks > 0;
      final sub = key.contains(':') ? ' (${key.substring(key.indexOf(':') + 1)})' : '';
      s.skills.add(SkillLine(
        key: key,
        def: def,
        label: def.displayName(true) + sub,
        ranks: ranks,
        abilMod: abilMod,
        acp: acp,
        synergy: syn,
        sizeMod: baseId == 'hide' ? sizeHide : 0,
        misc: misc,
        classSkill: cs,
        usable: usable,
        maxRanks: maxR,
        situational: situ,
      ));
      if (ranks > maxR + 0.001) {
        s.warnings.add('${def.displayName(true)}$sub: ${_fmt(ranks)} graduações excede o máximo de ${_fmt(maxR)}.');
      }
    }
    s.skills.sort((a, b) => a.label.compareTo(b.label));
    // pontos de perícia
    var total = 0;
    var spent = 0.0;
    var i = 0;
    final intUps = <int>[];
    var ups = 0;
    for (final l in ch.levels) {
      if (l.abilityIncrease == 'int') ups++;
      intUps.add(ups);
    }
    for (final l in ch.levels) {
      final c = s.classDefs[l.classId]!;
      final intScore = (ch.baseAbilities['int'] ?? 10) + (s.race?.abilityAdj['int'] ?? 0) + intUps[i] - (ch.abilityDrain['int'] ?? 0);
      var pts = math.max(1, c.skillPoints + abilityMod(intScore)) + (s.race?.bonusSkillPoints ?? 0);
      if (i == 0) pts *= 4;
      total += pts;
      var spentHere = 0.0;
      l.skillRanks.forEach((k, r) {
        spentHere += s.isClassSkillFor(l.classId, k) ? r : r * 2;
      });
      spent += spentHere;
      if (spentHere > pts + 0.001) {
        s.warnings.add('Nível ${i + 1}: ${_fmt(spentHere)} pontos de perícia gastos de $pts disponíveis.');
      }
      i++;
    }
    s.skillPointsTotal = total;
    s.skillPointsSpent = spent;
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  // ------------------------------------------------------------ ataques
  void _attacks(Sheet s) {
    final str = s.abilities['str']!.mod;
    final dex = s.abilities['dex']!.mod;
    final sizeMod = s.rules.size(s.size).mod;
    final finesse = s.featNames.contains('Weapon Finesse');
    final ch = s.ch;
    final weapons = ch.items.where((i) => i.kind == 'weapon' && i.showInAttacks && (i.equipped || ch.items.where((x) => x.kind == 'weapon' && x.equipped).isEmpty)).toList();

    List<int> iteratives(int bonus, int bab) {
      final n = math.max(1, math.min(4, ((bab - 1) ~/ 5) + 1));
      return [for (var k = 0; k < n; k++) bonus - 5 * k];
    }

    // desarmado (monge escala o dano)
    final monk = s.classLevels['monk'] ?? 0;
    if (!weapons.any((w) => (w.baseRef ?? w.name) == 'Unarmed strike')) {
      String dmg;
      if (monk > 0) {
        const med = ['1d6', '1d8', '1d10', '2d6', '2d8', '2d10'];
        const sml = ['1d4', '1d6', '1d8', '1d10', '2d6', '2d8'];
        const lrg = ['1d8', '2d6', '2d8', '3d6', '3d8', '4d8'];
        final idx = monk >= 20 ? 5 : (monk >= 16 ? 4 : (monk >= 12 ? 3 : (monk >= 8 ? 2 : (monk >= 4 ? 1 : 0))));
        dmg = s.size == 'small' ? sml[idx] : (s.size == 'large' ? lrg[idx] : med[idx]);
      } else {
        dmg = s.size == 'small' ? '1d2' : '1d3';
      }
      final atk = s.bab + str + sizeMod + s.pool.total(['attack.all', 'attack.melee', 'attack.weapon:unarmed-strike']).total;
      final dmgBonus = str + s.pool.total(['damage.all', 'damage.melee', 'damage.weapon:unarmed-strike']).total;
      final notes = <String>[];
      if (monk == 0 && !s.featNames.contains('Improved Unarmed Strike')) notes.add('dano não letal; provoca ataque de oportunidade');
      s.attacks.add(AttackLine('Ataque desarmado', null, iteratives(atk, s.bab), '$dmg${dmgBonus == 0 ? '' : signed(dmgBonus)}',
          '20/x2', 0, 'B', notes, false));
      if (monk > 0) {
        final pen = monk >= 9 ? 0 : (monk >= 5 ? -1 : -2);
        final it = iteratives(atk + pen, s.bab);
        final flurry = [it.first, ...it];
        if (monk >= 11) flurry.insert(0, it.first);
        s.attacks.add(AttackLine('Rajada de golpes', null, flurry, '$dmg${dmgBonus == 0 ? '' : signed(dmgBonus)}', '20/x2', 0, 'B',
            ['sem armadura e carga leve'], false));
      }
    }

    for (final it in weapons) {
      final w = it.baseRef == null ? rules.weaponByName(it.name) : rules.weaponByName(it.baseRef!);
      final handed = it.handed ?? w?.handed ?? 'one';
      final ranged = handed == 'ranged' || handed == 'thrown';
      final thrown = handed == 'thrown';
      final wid = w?.id ?? slugify(it.baseRef ?? it.name);
      final notes = <String>[];
      final canFinesse = finesse && (w?.finesse == true) && !ranged;
      final abil = ranged ? dex : (canFinesse ? math.max(str, dex) : str);
      var atk = s.bab + abil + sizeMod;
      final enh = it.enhancement > 0 ? it.enhancement : (it.masterwork ? 1 : 0);
      atk += enh;
      if (!proficientWeapon(s, w, it.name)) {
        atk -= 4;
        notes.add('sem proficiência (-4)');
      }
      final atkPool = s.pool.total(['attack.all', ranged ? 'attack.ranged' : 'attack.melee', 'attack.weapon:$wid']);
      atk += atkPool.total;
      notes.addAll(atkPool.situational.map(_situ));
      // combate com duas armas
      if (ch.twoWeaponFighting) {
        final offLight = ch.items.any((x) => x.equipped && x.offHand && x.kind == 'weapon' &&
            ((x.baseRef == null ? rules.weaponByName(x.name) : rules.weaponByName(x.baseRef!))?.handed == 'light'));
        final twf = s.featNames.contains('Two-Weapon Fighting');
        int pen;
        if (it.offHand) {
          pen = twf ? (offLight ? -2 : -4) : (offLight ? -8 : -10);
        } else {
          pen = twf ? (offLight ? -2 : -4) : (offLight ? -4 : -6);
        }
        atk += pen;
      }
      // ataque poderoso / especialização em combate
      var paDmg = 0;
      if (!ranged && ch.powerAttack > 0) {
        final pa = math.min(ch.powerAttack, s.bab);
        atk -= pa;
        paDmg = (it.twoHanded || handed == 'two') ? pa * 2 : (handed == 'light' ? 0 : pa);
      }
      if (!ranged && ch.combatExpertise > 0) atk -= math.min(ch.combatExpertise, math.min(5, s.bab));
      if (ch.fightingDefensively) atk -= 4;

      // dano
      final baseDmg = it.dmg ?? (w == null ? '1d6' : rules.scaleDamage(w.dmgM, w.dmgS, it.size));
      var dmgBonus = 0;
      if (!ranged || thrown) {
        if (it.offHand) {
          dmgBonus += str > 0 ? str ~/ 2 : str;
        } else if (it.twoHanded || handed == 'two') {
          dmgBonus += str > 0 ? (str * 3) ~/ 2 : str;
        } else {
          dmgBonus += str;
        }
      } else {
        final isBow = (w?.name ?? it.name).toLowerCase().contains('bow') && !(w?.name ?? it.name).toLowerCase().contains('crossbow');
        if (isBow) {
          if ((w?.name ?? it.name).toLowerCase().contains('composite')) {
            dmgBonus += math.min(str, it.compositeStr);
          } else if (str < 0) {
            dmgBonus += str;
          }
        } else if ((w?.name ?? '').toLowerCase().contains('sling') && str < 0) {
          dmgBonus += str;
        }
      }
      dmgBonus += it.enhancement + paDmg;
      final dPool = s.pool.total(['damage.all', ranged ? 'damage.ranged' : 'damage.melee', 'damage.weapon:$wid']);
      dmgBonus += dPool.total;
      notes.addAll(dPool.situational.map(_situ));
      // decisivo
      var cr = it.critRange ?? w?.critRange ?? 20;
      final cm = it.critMult ?? w?.critMult ?? 2;
      final keen = it.properties.any((p) => p.toLowerCase() == 'keen' || p.toLowerCase() == 'afiada');
      final ic = s.pool.total(['critrange.weapon:$wid']).total > 0;
      if (keen || ic) cr = 21 - (21 - cr) * 2;
      final critText = cr >= 20 ? '20/x$cm' : '$cr-20/x$cm';
      final range = it.range ?? w?.range ?? 0;
      final props = it.properties.isEmpty ? '' : ' [${it.properties.join(', ')}]';
      final label = '${it.enhancement > 0 ? '${it.name} +${it.enhancement}' : it.name}$props';
      s.attacks.add(AttackLine(label, it, iteratives(atk, s.bab), '$baseDmg${dmgBonus == 0 ? '' : signed(dmgBonus)}',
          critText, range, w?.dtype ?? '', notes, ranged));
    }
  }

  // ------------------------------------------------------------ magias
  void _casting(Sheet s) {
    // níveis de prestígio que avançam conjuração
    final adv = <String, int>{};
    for (final l in s.ch.levels) {
      final a = l.castingAdvances;
      if (a != null && a.isNotEmpty) adv[a] = (adv[a] ?? 0) + 1;
    }
    for (final e in s.classDefs.entries) {
      final sc = e.value.spellcasting;
      if (sc == null) continue;
      final lvl = (s.classLevels[e.key] ?? 0) + (adv[e.key] ?? 0);
      if (lvl <= 0) continue;
      final abil = s.abilities[sc.ability]!;
      final mod = abil.mod;
      final cl = math.max(0, (lvl * sc.clFactor).floor() + s.pool.total(['cl.all', 'cl.${e.key}']).total);
      final slots = sc.slotsAt(math.min(lvl, 20));
      final known = sc.knownAt(math.min(lvl, 20));
      final state = s.ch.casters[e.key];
      final lines = <SpellLevelInfo>[];
      final dcPool = s.pool.total(['spelldc.all', 'spelldc.${e.key}']).total;
      for (final entry in slots.entries) {
        final L = entry.key;
        final base = entry.value;
        var bonus = 0;
        if (L >= 1 && base >= 0 && mod >= L) bonus = 1 + (mod - L) ~/ 4;
        final castable = abil.total >= 10 + L;
        final dom = (sc.domainSlots && L >= 1) ? 1 : 0;
        final spec = (state?.specialistSchool != null && state!.specialistSchool!.isNotEmpty && sc.spellbook) ? 1 : 0;
        lines.add(SpellLevelInfo(L, castable ? base : -1, castable ? bonus : 0, castable ? dom : 0, castable ? spec : 0,
            known[L] ?? 0, 10 + L + mod + dcPool, castable));
      }
      s.casters.add(CasterInfo(e.value, lvl, cl, sc.ability, abil.total, lines));
    }
  }

  void _resources(Sheet s) {
    for (final c in s.classDefs.values) {
      for (final r in c.resources) {
        var max = Expr.evalInt(r.max, (n) => s.resolveVar(n));
        if (r.id == 'turn-undead') {
          max += 4 * s.featNames.where((f) => f == 'Extra Turning').length;
        }
        if (max <= 0) continue;
        s.resources.add(ResourceLine(r.id, r.displayName, max, s.ch.resourcesUsed[r.id] ?? 0, r.per));
      }
    }
    for (final r in s.ch.customResources) {
      final max = Expr.evalInt(r.max, (n) => s.resolveVar(n));
      s.resources.add(ResourceLine(r.id, r.name, max, s.ch.resourcesUsed[r.id] ?? 0, r.per));
    }
  }

  // ------------------------------------------------------------ validações
  void _validate(Sheet s) {
    final ch = s.ch;
    final lvl = s.characterLevel;
    // espaços de talento
    final general = lvl == 0 ? 0 : 1 + lvl ~/ 3;
    final raceBonus = s.race?.bonusFeats ?? 0;
    final classBonus = <String, int>{};
    final counts = <String, int>{};
    for (final l in ch.levels) {
      counts[l.classId] = (counts[l.classId] ?? 0) + 1;
      final c = s.classDefs[l.classId]!;
      if (c.bonusFeatLevels.contains(counts[l.classId])) {
        classBonus[l.classId] = (classBonus[l.classId] ?? 0) + 1;
      }
    }
    s.featSlots = FeatSlots(general, raceBonus, 0, classBonus);
    final chosen = ch.levels.fold<int>(0, (a, l) => a + l.feats.where((f) => f.slot != 'free').length);
    if (chosen < s.featSlots.total) {
      s.warnings.add('Talentos: ${s.featSlots.total - chosen} espaço(s) não preenchido(s).');
    } else if (chosen > s.featSlots.total) {
      s.warnings.add('Talentos: $chosen escolhidos para ${s.featSlots.total} espaços.');
    }
    // pré-requisitos
    for (final l in ch.levels) {
      for (final f in l.feats) {
        final miss = missingPrereqs(s, f.name, book: f.book);
        if (miss.isNotEmpty) s.warnings.add('${f.name}: requer ${miss.join(', ')}.');
      }
    }
    // aumentos de atributo
    final ups = ch.levels.where((l) => l.abilityIncrease != null).length;
    if (ups < lvl ~/ 4) s.warnings.add('Aumentos de atributo: ${lvl ~/ 4 - ups} pendente(s).');
    // XP e multiclasse
    if (ch.xp < s.xpNeeded) s.warnings.add('XP ${ch.xp} abaixo do necessário (${s.xpNeeded}) para o NEP ${s.ecl}.');
    final xpPen = multiclassPenalty(s);
    if (xpPen > 0) s.warnings.add('Penalidade de XP por multiclasse: -$xpPen%.');
    if (s.skillPointsSpent > s.skillPointsTotal + 0.001) {
      s.warnings.add('Pontos de perícia: ${_fmt(s.skillPointsSpent)} gastos de ${s.skillPointsTotal}.');
    }
  }

  int multiclassPenalty(Sheet s) {
    final favored = s.race?.favoredClass ?? 'any';
    final base = <int>[];
    String? highest;
    var hi = 0;
    s.classLevels.forEach((id, n) {
      if (n > hi) {
        hi = n;
        highest = id;
      }
    });
    s.classLevels.forEach((id, n) {
      final c = s.classDefs[id]!;
      if (c.prestige) return;
      if (favored == id) return;
      if (favored == 'any' && id == highest) return;
      base.add(n);
    });
    if (base.length <= 1) return 0;
    base.sort();
    final top = base.last;
    final uneven = base.where((n) => top - n > 1).length;
    return uneven * 20;
  }

  /// Lista os pré-requisitos não atendidos de um talento.
  List<String> missingPrereqs(Sheet s, String featName, {String? book}) {
    final def = rules.featByName(featName, book: book);
    if (def == null) return const [];
    final choice = Ruleset.featChoice(featName) ?? '';
    final out = <String>[];
    for (final p in def.prereqs) {
      switch (p.kind) {
        case 'abil':
          if ((s.abilities[p.key]?.permanent ?? 0) < (p.value ?? 0)) out.add(p.describe(true));
          break;
        case 'bab':
          if (s.bab < (p.value ?? 0)) out.add(p.describe(true));
          break;
        case 'feat':
          final need = p.key!.replaceAll('{choice}', choice);
          if (!s.featNames.contains(need)) out.add(need);
          break;
        case 'skill':
          if (s.ranksOf(p.key!) < (p.value ?? 0)) out.add(p.describe(true));
          break;
        case 'class':
          if ((s.classLevels[p.key] ?? 0) < (p.value ?? 0)) out.add(p.describe(true));
          break;
        case 'cl':
          final cl = s.casters.isEmpty ? 0 : s.casters.map((c) => c.casterLevel).reduce(math.max);
          if (cl < (p.value ?? 0)) out.add(p.describe(true));
          break;
        case 'level':
          if (s.characterLevel < (p.value ?? 0)) out.add(p.describe(true));
          break;
        default:
          break;
      }
    }
    return out;
  }
}

extension on ResourceDef {
  String get displayName => namePt.isNotEmpty ? namePt : name;
}
