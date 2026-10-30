// Definições de regras (o "conteúdo" estruturado) usadas pelo motor.
// Vêm de três lugares: assets/srd/core.json (núcleo SRD), da base de dados
// extraída dos livros (campo data_json) e dos livros homebrew do usuário.
import 'bonus.dart';

String slugify(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r"[’']"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

List<Effect> _effects(dynamic j, String source) => j == null
    ? <Effect>[]
    : (j as List).map((e) => Effect.fromJson(Map<String, dynamic>.from(e as Map)).copyWith(source: source)).toList();

List<String> _strs(dynamic j) => j == null ? <String>[] : (j as List).map((e) => '$e').toList();

/// Campos comuns a todo item de regra: nome, livro, página.
abstract class RuleDef {
  String get id;
  String get name;
  String get namePt;
  String get book;
  int? get page;
  String displayName(bool pt) => pt && namePt.isNotEmpty ? namePt : name;
  String get sourceLabel => page == null ? book : '$book p.$page';
}

class SkillDef extends RuleDef {
  @override
  final String id, name, namePt, book;
  @override
  final int? page;
  final String ability;
  final bool trainedOnly, subtypes;
  final int acp; // 0 nenhuma, 1 normal, 2 dobrada (Natação)
  SkillDef(this.id, this.name, this.namePt, this.ability, this.trainedOnly, this.acp, this.subtypes,
      {this.book = 'PH', this.page});
  factory SkillDef.fromJson(Map<String, dynamic> j) => SkillDef(
        j['id'] as String,
        j['name'] as String,
        (j['name_pt'] as String?) ?? '',
        j['ability'] as String,
        j['trained_only'] == true,
        (j['acp'] as num?)?.toInt() ?? 0,
        j['subtypes'] == true,
        book: (j['book'] as String?) ?? 'PH',
        page: (j['page'] as num?)?.toInt(),
      );
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'name_pt': namePt, 'ability': ability, 'trained_only': trainedOnly,
        'acp': acp, 'subtypes': subtypes, 'book': book, 'page': page,
      };
}

class SynergyDef {
  final String from, to;
  final String? cond;
  SynergyDef(this.from, this.to, this.cond);
}

class FeatureDef {
  final int level;
  final String name, namePt, text;
  final List<Effect> effects;
  FeatureDef(this.level, this.name, this.namePt, this.text, this.effects);
  factory FeatureDef.fromJson(Map<String, dynamic> j, String src) => FeatureDef(
        (j['level'] as num).toInt(),
        j['name'] as String,
        (j['name_pt'] as String?) ?? '',
        (j['text'] as String?) ?? '',
        _effects(j['effects'], src),
      );
  Map<String, dynamic> toJson() => {
        'level': level, 'name': name, 'name_pt': namePt, 'text': text,
        'effects': effects.map((e) => e.toJson()).toList(),
      };
}

class SpellcastingDef {
  final String type; // arcane | divine | psionic | other
  final String style; // prepared | spontaneous
  final String ability;
  final String list; // chave da lista de magias (ex.: 'Sor/Wiz', 'Clr')
  final int start; // primeiro nível de magia da tabela (0 ou 1)
  final List<List<int>> perDay; // índice = nível de classe - 1
  final List<List<int>>? known;
  final double clFactor;
  final bool domainSlots, spellbook;
  SpellcastingDef({
    required this.type,
    required this.style,
    required this.ability,
    required this.list,
    this.start = 0,
    required this.perDay,
    this.known,
    this.clFactor = 1,
    this.domainSlots = false,
    this.spellbook = false,
  });
  static List<List<int>> _table(dynamic j) =>
      (j as List).map((r) => (r as List).map((x) => (x as num).toInt()).toList()).toList();
  factory SpellcastingDef.fromJson(Map<String, dynamic> j) => SpellcastingDef(
        type: (j['type'] as String?) ?? 'arcane',
        style: (j['style'] as String?) ?? 'prepared',
        ability: (j['ability'] as String?) ?? 'int',
        list: (j['list'] as String?) ?? '',
        start: (j['start'] as num?)?.toInt() ?? 0,
        perDay: _table(j['per_day'] ?? []),
        known: j['known'] == null ? null : _table(j['known']),
        clFactor: (j['cl_factor'] as num?)?.toDouble() ?? 1,
        domainSlots: j['domain_slots'] == true,
        spellbook: j['spellbook'] == true,
      );
  Map<String, dynamic> toJson() => {
        'type': type, 'style': style, 'ability': ability, 'list': list, 'start': start,
        'per_day': perDay, if (known != null) 'known': known, 'cl_factor': clFactor,
        'domain_slots': domainSlots, 'spellbook': spellbook,
      };

  /// Magias por dia (sem bônus) para um nível de classe; mapa nível de magia -> qtd.
  Map<int, int> slotsAt(int classLevel) {
    if (classLevel < 1 || perDay.isEmpty) return {};
    final row = perDay[(classLevel > perDay.length ? perDay.length : classLevel) - 1];
    return {for (var i = 0; i < row.length; i++) start + i: row[i]};
  }

  Map<int, int> knownAt(int classLevel) {
    if (known == null || classLevel < 1 || known!.isEmpty) return {};
    final row = known![(classLevel > known!.length ? known!.length : classLevel) - 1];
    return {for (var i = 0; i < row.length; i++) start + i: row[i]};
  }
}

class ResourceDef {
  final String id, name, namePt, per, max;
  ResourceDef(this.id, this.name, this.namePt, this.per, this.max);
  factory ResourceDef.fromJson(Map<String, dynamic> j) => ResourceDef(
      j['id'] as String, j['name'] as String, (j['name_pt'] as String?) ?? '',
      (j['per'] as String?) ?? 'day', '${j['max'] ?? 1}');
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'name_pt': namePt, 'per': per, 'max': max};
}

/// Um "buff" pronto que pode ser ligado/desligado na ficha (Fúria, Inspirar Coragem,
/// magias comuns como Força do Touro...).
class BuffDef {
  final String id, name, namePt, duration;
  final List<Effect> effects;
  BuffDef(this.id, this.name, this.namePt, this.duration, this.effects);
  factory BuffDef.fromJson(Map<String, dynamic> j, String src) => BuffDef(
      j['id'] as String, j['name'] as String, (j['name_pt'] as String?) ?? '',
      (j['duration'] as String?) ?? '', _effects(j['effects'], src));
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'name_pt': namePt, 'duration': duration,
        'effects': effects.map((e) => e.toJson()).toList(),
      };
}

class ClassDef extends RuleDef {
  @override
  final String id, name, namePt, book;
  @override
  final int? page;
  final int hitDie, skillPoints;
  final String bab; // full | 3/4 | 1/2
  final Set<String> goodSaves;
  final List<String> classSkills;
  final List<FeatureDef> features;
  final SpellcastingDef? spellcasting;
  final List<int> bonusFeatLevels;
  final List<ResourceDef> resources;
  final List<BuffDef> buffs;
  final List<Effect> effects;
  final bool prestige;
  final int maxLevel;
  final String? startingGold;
  /// Classe de prestígio que avança a conjuração de outra classe: níveis que somam +1.
  final List<int> advancesCasting;
  final String requirements; // texto livre (pré-requisitos de prestígio)
  /// 'simple', 'martial' ou nomes de armas; 'light','medium','heavy','shield','tower'
  final List<String> weaponProf, armorProf;
  ClassDef({
    required this.id,
    required this.name,
    this.namePt = '',
    this.book = 'PH',
    this.page,
    required this.hitDie,
    required this.skillPoints,
    required this.bab,
    required this.goodSaves,
    required this.classSkills,
    this.features = const [],
    this.spellcasting,
    this.bonusFeatLevels = const [],
    this.resources = const [],
    this.buffs = const [],
    this.effects = const [],
    this.prestige = false,
    this.maxLevel = 20,
    this.startingGold,
    this.advancesCasting = const [],
    this.requirements = '',
    this.weaponProf = const [],
    this.armorProf = const [],
  });

  factory ClassDef.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String;
    final src = name;
    return ClassDef(
      id: (j['id'] as String?) ?? slugify(name),
      name: name,
      namePt: (j['name_pt'] as String?) ?? '',
      book: (j['book'] as String?) ?? '',
      page: (j['page'] as num?)?.toInt(),
      hitDie: (j['hit_die'] as num?)?.toInt() ?? 8,
      skillPoints: (j['skill_points'] as num?)?.toInt() ?? 2,
      bab: (j['bab'] as String?) ?? '3/4',
      goodSaves: _strs(j['good_saves']).toSet(),
      classSkills: _strs(j['class_skills']),
      features: ((j['features'] as List?) ?? [])
          .map((f) => FeatureDef.fromJson(Map<String, dynamic>.from(f as Map), src))
          .toList(),
      spellcasting: j['spellcasting'] == null
          ? null
          : SpellcastingDef.fromJson(Map<String, dynamic>.from(j['spellcasting'] as Map)),
      bonusFeatLevels: ((j['bonus_feat_levels'] as List?) ?? []).map((e) => (e as num).toInt()).toList(),
      resources: ((j['resources'] as List?) ?? [])
          .map((r) => ResourceDef.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      buffs: ((j['buffs'] as List?) ?? [])
          .map((b) => BuffDef.fromJson(Map<String, dynamic>.from(b as Map), src))
          .toList(),
      effects: _effects(j['effects'], src),
      prestige: j['prestige'] == true,
      maxLevel: (j['max_level'] as num?)?.toInt() ?? 20,
      startingGold: j['starting_gold'] as String?,
      advancesCasting: ((j['advances_casting'] as List?) ?? []).map((e) => (e as num).toInt()).toList(),
      requirements: (j['requirements'] as String?) ?? '',
      weaponProf: _strs(j['weapon_prof']),
      armorProf: _strs(j['armor_prof']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'name_pt': namePt, 'book': book, 'page': page,
        'weapon_prof': weaponProf, 'armor_prof': armorProf,
        'hit_die': hitDie, 'skill_points': skillPoints, 'bab': bab,
        'good_saves': goodSaves.toList(), 'class_skills': classSkills,
        'features': features.map((f) => f.toJson()).toList(),
        if (spellcasting != null) 'spellcasting': spellcasting!.toJson(),
        'bonus_feat_levels': bonusFeatLevels,
        'resources': resources.map((r) => r.toJson()).toList(),
        'buffs': buffs.map((b) => b.toJson()).toList(),
        'effects': effects.map((e) => e.toJson()).toList(),
        'prestige': prestige, 'max_level': maxLevel, 'starting_gold': startingGold,
        'advances_casting': advancesCasting, 'requirements': requirements,
      };

  int babAt(int lvl) {
    switch (bab) {
      case 'full':
        return lvl;
      case '1/2':
        return lvl ~/ 2;
      default:
        return (lvl * 3) ~/ 4;
    }
  }

  int saveAt(String save, int lvl) {
    if (lvl <= 0) return 0;
    return goodSaves.contains(save) ? 2 + lvl ~/ 2 : lvl ~/ 3;
  }
}

class RaceDef extends RuleDef {
  @override
  final String id, name, namePt, book;
  @override
  final int? page;
  final String size, favoredClass, languages, vision, type;
  final int speed, la, bonusFeats, bonusSkillPoints;
  final Map<String, int> abilityAdj;
  final List<Effect> effects;
  final List<String> features;
  /// Dados de vida raciais (monstros jogáveis): quantidade, dado, BBA, perícias...
  final int racialHd;
  final int racialHdDie;
  RaceDef({
    required this.id,
    required this.name,
    this.namePt = '',
    this.book = 'PH',
    this.page,
    this.size = 'medium',
    this.speed = 30,
    this.la = 0,
    this.favoredClass = 'any',
    this.abilityAdj = const {},
    this.effects = const [],
    this.features = const [],
    this.bonusFeats = 0,
    this.bonusSkillPoints = 0,
    this.languages = 'Common',
    this.vision = '',
    this.type = 'humanoid',
    this.racialHd = 0,
    this.racialHdDie = 8,
  });
  factory RaceDef.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String;
    return RaceDef(
      id: (j['id'] as String?) ?? slugify(name),
      name: name,
      namePt: (j['name_pt'] as String?) ?? '',
      book: (j['book'] as String?) ?? '',
      page: (j['page'] as num?)?.toInt(),
      size: (j['size'] as String?) ?? 'medium',
      speed: (j['speed'] as num?)?.toInt() ?? 30,
      la: (j['la'] as num?)?.toInt() ?? 0,
      favoredClass: (j['favored_class'] as String?) ?? 'any',
      abilityAdj: ((j['ability_adj'] as Map?) ?? {}).map((k, v) => MapEntry('$k', (v as num).toInt())),
      effects: _effects(j['effects'], name),
      features: _strs(j['features']),
      bonusFeats: (j['bonus_feats'] as num?)?.toInt() ?? 0,
      bonusSkillPoints: (j['bonus_skill_points'] as num?)?.toInt() ?? 0,
      languages: (j['languages'] as String?) ?? '',
      vision: (j['vision'] as String?) ?? '',
      type: (j['type'] as String?) ?? 'humanoid',
      racialHd: (j['racial_hd'] as num?)?.toInt() ?? 0,
      racialHdDie: (j['racial_hd_die'] as num?)?.toInt() ?? 8,
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'name_pt': namePt, 'book': book, 'page': page, 'size': size,
        'speed': speed, 'la': la, 'favored_class': favoredClass, 'ability_adj': abilityAdj,
        'effects': effects.map((e) => e.toJson()).toList(), 'features': features,
        'bonus_feats': bonusFeats, 'bonus_skill_points': bonusSkillPoints,
        'languages': languages, 'vision': vision, 'type': type,
        'racial_hd': racialHd, 'racial_hd_die': racialHdDie,
      };
}

class Prereq {
  final String kind; // abil | bab | feat | skill | class | cl | level | ability | text
  final String? key;
  final num? value;
  Prereq(this.kind, this.key, this.value);
  factory Prereq.fromJson(Map<String, dynamic> j) =>
      Prereq(j['k'] as String, j['key'] as String?, j['v'] as num?);
  Map<String, dynamic> toJson() => {'k': kind, if (key != null) 'key': key, if (value != null) 'v': value};

  String describe(bool pt) {
    switch (kind) {
      case 'abil':
        return '${key!.toUpperCase()} $value';
      case 'bab':
        return (pt ? 'BBA +' : 'BAB +') + '$value';
      case 'feat':
        return key!;
      case 'skill':
        return '$key $value ${pt ? 'graduações' : 'ranks'}';
      case 'class':
        return '$key ${pt ? 'nível' : 'level'} $value';
      case 'cl':
        return (pt ? 'Nível de conjurador ' : 'Caster level ') + '$value';
      case 'level':
        return (pt ? 'Nível de personagem ' : 'Character level ') + '$value';
      default:
        return key ?? '';
    }
  }
}

class FeatDef extends RuleDef {
  @override
  final String id, name, namePt, book;
  @override
  final int? page;
  final List<String> types;
  final List<Prereq> prereqs;
  final String prereqText;
  final List<Effect> effects;
  final String? choice; // weapon | skill | school | text
  final bool multiple;
  final String text;
  FeatDef({
    required this.id,
    required this.name,
    this.namePt = '',
    this.book = 'PH',
    this.page,
    this.types = const ['general'],
    this.prereqs = const [],
    this.prereqText = '',
    this.effects = const [],
    this.choice,
    this.multiple = false,
    this.text = '',
  });
  factory FeatDef.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String;
    return FeatDef(
      id: (j['id'] as String?) ?? slugify(name),
      name: name,
      namePt: (j['name_pt'] as String?) ?? '',
      book: (j['book'] as String?) ?? '',
      page: (j['page'] as num?)?.toInt(),
      types: _strs(j['types']).isEmpty ? ['general'] : _strs(j['types']),
      prereqs: ((j['prereq'] as List?) ?? [])
          .map((p) => Prereq.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      prereqText: (j['prereq_text'] as String?) ?? '',
      effects: _effects(j['effects'], name),
      choice: j['choice'] as String?,
      multiple: j['multiple'] == true,
      text: (j['text'] as String?) ?? '',
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'name_pt': namePt, 'book': book, 'page': page, 'types': types,
        'prereq': prereqs.map((p) => p.toJson()).toList(), 'prereq_text': prereqText,
        'effects': effects.map((e) => e.toJson()).toList(), 'choice': choice,
        'multiple': multiple, 'text': text,
      };
  bool get isEpic => types.contains('epic');
  bool get isFighterBonus => types.contains('fighter');
}

class WeaponDef extends RuleDef {
  @override
  final String id, name, namePt, book;
  @override
  final int? page;
  final String category, handed, dmgS, dmgM, dtype, critText;
  final int critRange, critMult, range;
  final double weight, cost;
  final bool finesse;
  WeaponDef({
    required this.id,
    required this.name,
    this.namePt = '',
    this.book = 'PH',
    this.page,
    this.category = 'simple',
    this.handed = 'one',
    this.dmgS = '1d4',
    this.dmgM = '1d6',
    this.dtype = '',
    this.critText = 'x2',
    this.critRange = 20,
    this.critMult = 2,
    this.range = 0,
    this.weight = 0,
    this.cost = 0,
    this.finesse = false,
  });
  factory WeaponDef.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String;
    return WeaponDef(
      id: (j['id'] as String?) ?? slugify(name),
      name: name,
      namePt: (j['name_pt'] as String?) ?? '',
      book: (j['book'] as String?) ?? '',
      page: (j['page'] as num?)?.toInt(),
      category: (j['category'] as String?) ?? 'simple',
      handed: (j['handed'] as String?) ?? 'one',
      dmgS: (j['dmg_s'] as String?) ?? '',
      dmgM: (j['dmg_m'] as String?) ?? '',
      dtype: (j['dtype'] as String?) ?? '',
      critText: (j['crit_text'] as String?) ?? 'x2',
      critRange: (j['crit_range'] as num?)?.toInt() ?? 20,
      critMult: (j['crit_mult'] as num?)?.toInt() ?? 2,
      range: (j['range'] as num?)?.toInt() ?? 0,
      weight: (j['weight'] as num?)?.toDouble() ?? 0,
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      finesse: j['finesse'] == true,
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'name_pt': namePt, 'book': book, 'page': page,
        'category': category, 'handed': handed, 'dmg_s': dmgS, 'dmg_m': dmgM, 'dtype': dtype,
        'crit_text': critText, 'crit_range': critRange, 'crit_mult': critMult, 'range': range,
        'weight': weight, 'cost': cost, 'finesse': finesse,
      };
  bool get isRanged => handed == 'ranged' || handed == 'thrown';
}

class ArmorDef extends RuleDef {
  @override
  final String id, name, namePt, book;
  @override
  final int? page;
  final String category; // light | medium | heavy | shield
  final int bonus, acp, asf, speed30, speed20;
  final int? maxDex;
  final double weight, cost;
  ArmorDef({
    required this.id,
    required this.name,
    this.namePt = '',
    this.book = 'PH',
    this.page,
    this.category = 'light',
    this.bonus = 0,
    this.maxDex,
    this.acp = 0,
    this.asf = 0,
    this.speed30 = 30,
    this.speed20 = 20,
    this.weight = 0,
    this.cost = 0,
  });
  factory ArmorDef.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String;
    return ArmorDef(
      id: (j['id'] as String?) ?? slugify(name),
      name: name,
      namePt: (j['name_pt'] as String?) ?? '',
      book: (j['book'] as String?) ?? '',
      page: (j['page'] as num?)?.toInt(),
      category: (j['category'] as String?) ?? 'light',
      bonus: (j['bonus'] as num?)?.toInt() ?? 0,
      maxDex: (j['max_dex'] as num?)?.toInt(),
      acp: (j['acp'] as num?)?.toInt() ?? 0,
      asf: (j['asf'] as num?)?.toInt() ?? 0,
      speed30: (j['speed30'] as num?)?.toInt() ?? 30,
      speed20: (j['speed20'] as num?)?.toInt() ?? 20,
      weight: (j['weight'] as num?)?.toDouble() ?? 0,
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'name_pt': namePt, 'book': book, 'page': page,
        'category': category, 'bonus': bonus, 'max_dex': maxDex, 'acp': acp, 'asf': asf,
        'speed30': speed30, 'speed20': speed20, 'weight': weight, 'cost': cost,
      };
  bool get isShield => category == 'shield';
}

class ConditionDef extends RuleDef {
  @override
  final String id, name, namePt, book;
  @override
  final int? page;
  final String text;
  final List<Effect> effects;
  ConditionDef(this.id, this.name, this.namePt, this.text, this.effects, {this.book = 'DMG', this.page});
  factory ConditionDef.fromJson(Map<String, dynamic> j) => ConditionDef(
        j['id'] as String,
        j['name'] as String,
        (j['name_pt'] as String?) ?? '',
        (j['text'] as String?) ?? '',
        _effects(j['effects'], (j['name_pt'] as String?) ?? (j['name'] as String)),
        book: (j['book'] as String?) ?? 'DMG',
        page: (j['page'] as num?)?.toInt(),
      );
}

class SizeDef {
  final String id, namePt;
  final int mod, grapple, hide, reach;
  final double carry;
  SizeDef(this.id, this.namePt, this.mod, this.grapple, this.hide, this.carry, this.reach);
}

/// Definição genérica de magia (vinda da base de dados ou homebrew).
class SpellDef extends RuleDef {
  @override
  final String id, name, namePt, book;
  @override
  final int? page;
  final String school, subschool, descriptors, components, castingTime, range, target,
      duration, save, sr, summary, text;
  /// Ex.: {'Sor/Wiz': 3, 'Clr': 4, 'Fire': 3}
  final Map<String, int> levels;
  SpellDef({
    required this.id,
    required this.name,
    this.namePt = '',
    this.book = '',
    this.page,
    this.school = '',
    this.subschool = '',
    this.descriptors = '',
    this.components = '',
    this.castingTime = '',
    this.range = '',
    this.target = '',
    this.duration = '',
    this.save = '',
    this.sr = '',
    this.summary = '',
    this.text = '',
    this.levels = const {},
  });
  factory SpellDef.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String;
    return SpellDef(
      id: (j['id'] as String?) ?? slugify(name),
      name: name,
      namePt: (j['name_pt'] as String?) ?? '',
      book: (j['book'] as String?) ?? '',
      page: (j['page'] as num?)?.toInt(),
      school: (j['school'] as String?) ?? '',
      subschool: (j['subschool'] as String?) ?? '',
      descriptors: (j['descriptors'] as String?) ?? '',
      components: (j['components'] as String?) ?? '',
      castingTime: (j['casting_time'] as String?) ?? '',
      range: (j['range'] as String?) ?? '',
      target: (j['target'] as String?) ?? '',
      duration: (j['duration'] as String?) ?? '',
      save: (j['save'] as String?) ?? '',
      sr: (j['sr'] as String?) ?? '',
      summary: (j['summary'] as String?) ?? '',
      text: (j['text'] as String?) ?? '',
      levels: ((j['levels'] as Map?) ?? {}).map((k, v) => MapEntry('$k', (v as num).toInt())),
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'name_pt': namePt, 'book': book, 'page': page,
        'school': school, 'subschool': subschool, 'descriptors': descriptors,
        'components': components, 'casting_time': castingTime, 'range': range,
        'target': target, 'duration': duration, 'save': save, 'sr': sr,
        'summary': summary, 'text': text, 'levels': levels,
      };
}
