// Modelo persistente de um personagem. Tudo que é *escolha* do jogador fica
// aqui; tudo que é *derivado* (totais, CA, ataques...) é calculado pelo motor
// em engine/calc.dart. Serialização: model/xml_io.dart (formato .d35x).
import 'dart:math';

import '../engine/bonus.dart';

String newId() {
  final r = Random();
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '$t${r.nextInt(1 << 30).toRadixString(36)}';
}

const abilityIds = ['str', 'dex', 'con', 'int', 'wis', 'cha'];

class FeatPick {
  String name; // nome completo, com escolha: "Weapon Focus (Longsword)"
  String? book;
  /// Origem do espaço: general | race | class:<id> | bonus | epic | free
  String slot;
  FeatPick(this.name, {this.book, this.slot = 'general'});
}

class ClassLevel {
  String classId;
  String? classBook;
  int hpRoll; // resultado do dado de vida neste nível (sem Con)
  /// Graduações compradas NESTE nível, por perícia ("craft:Alquimia" para subtipos).
  Map<String, double> skillRanks;
  List<FeatPick> feats;
  String? abilityIncrease; // str..cha, nos níveis 4, 8, 12...
  /// Para classes de prestígio: qual classe conjuradora este nível avança.
  String? castingAdvances;
  /// Escolhas livres de características (estilo de combate, inimigo predileto...).
  Map<String, String> choices;
  ClassLevel({
    required this.classId,
    this.classBook,
    this.hpRoll = 0,
    Map<String, double>? skillRanks,
    List<FeatPick>? feats,
    this.abilityIncrease,
    this.castingAdvances,
    Map<String, String>? choices,
  })  : skillRanks = skillRanks ?? {},
        feats = feats ?? [],
        choices = choices ?? {};
}

class Item {
  String id;
  String name;
  /// weapon | armor | shield | gear | magic | ammo | consumable | money
  String kind;
  String? baseRef; // nome da arma/armadura base (ex.: "Longsword")
  String? baseBook;
  int qty;
  double weight; // por unidade (lb)
  double cost; // por unidade (po)
  bool equipped;
  String location; // corpo, mochila, montaria, guardado...
  int enhancement;
  bool masterwork;
  String material;
  String size; // tamanho do item (armas)
  List<String> properties; // keen, flaming, etc. (texto/IDs)
  List<Effect> effects; // bônus concedidos quando equipado
  String notes;
  int? charges;
  // Sobrescritas para armas/armaduras fora do núcleo
  String? dmg, critText;
  int? critRange, critMult, range, armorBonus, maxDex, acp, asf;
  String? handed, category;
  /// Arma: empunhar com duas mãos / mão inábil / bônus de For composto
  bool twoHanded, offHand;
  int compositeStr;
  bool showInAttacks;

  Item({
    String? id,
    required this.name,
    this.kind = 'gear',
    this.baseRef,
    this.baseBook,
    this.qty = 1,
    this.weight = 0,
    this.cost = 0,
    this.equipped = false,
    this.location = 'body',
    this.enhancement = 0,
    this.masterwork = false,
    this.material = '',
    this.size = 'medium',
    List<String>? properties,
    List<Effect>? effects,
    this.notes = '',
    this.charges,
    this.dmg,
    this.critText,
    this.critRange,
    this.critMult,
    this.range,
    this.armorBonus,
    this.maxDex,
    this.acp,
    this.asf,
    this.handed,
    this.category,
    this.twoHanded = false,
    this.offHand = false,
    this.compositeStr = 0,
    this.showInAttacks = true,
  })  : id = id ?? newId(),
        properties = properties ?? [],
        effects = effects ?? [];

  double get totalWeight => weight * qty;
}

/// Efeito temporário ligado/desligado na ficha: magia, fúria, poção...
class ActiveBuff {
  String id;
  String name;
  List<Effect> effects;
  bool active;
  int? roundsLeft;
  String source;
  String notes;
  ActiveBuff({
    String? id,
    required this.name,
    List<Effect>? effects,
    this.active = true,
    this.roundsLeft,
    this.source = '',
    this.notes = '',
  })  : id = id ?? newId(),
        effects = effects ?? [];
}

class KnownSpell {
  String name;
  String? book;
  int level;
  String classId;
  bool domain;
  KnownSpell({required this.name, this.book, required this.level, required this.classId, this.domain = false});
}

class PreparedSpell {
  String name;
  int level; // nível do espaço usado
  bool used;
  bool domain;
  String metamagic;
  PreparedSpell({required this.name, required this.level, this.used = false, this.domain = false, this.metamagic = ''});
}

class CasterState {
  String classId;
  List<KnownSpell> known; // grimório / magias conhecidas
  List<PreparedSpell> prepared;
  Map<int, int> usedSpontaneous; // nível -> usados hoje
  List<String> domains;
  String? specialistSchool;
  List<String> prohibitedSchools;
  CasterState({
    required this.classId,
    List<KnownSpell>? known,
    List<PreparedSpell>? prepared,
    Map<int, int>? usedSpontaneous,
    List<String>? domains,
    this.specialistSchool,
    List<String>? prohibitedSchools,
  })  : known = known ?? [],
        prepared = prepared ?? [],
        usedSpontaneous = usedSpontaneous ?? {},
        domains = domains ?? [],
        prohibitedSchools = prohibitedSchools ?? [];
}

class CustomResource {
  String id;
  String name;
  String max; // fórmula
  String per; // day | encounter | week | charges
  CustomResource({String? id, required this.name, this.max = '1', this.per = 'day'}) : id = id ?? newId();
}

class Character {
  static const schemaVersion = 1;
  String id;
  String name;
  String player;
  String campaign;
  String alignment;
  String deity;
  String gender, age, height, weight, eyes, hair, skin;
  String appearance;
  String background;
  String notes;
  String languages;
  /// Retrato/desenho do personagem: PNG em base64 (null = sem imagem).
  String? portrait;

  // Fontes
  /// null = todos os livros; caso contrário, abreviações permitidas.
  Set<String>? allowedBooks;
  /// ask | newest
  String versionPolicy;
  /// "kind:id" -> livro escolhido (ex.: "spell:fireball" -> "PH")
  Map<String, String> versionChoices;

  // Raça e atributos
  String raceId;
  String? raceBook;
  String? sizeOverride;
  Map<String, int> baseAbilities;
  String abilityMethod; // pointbuy | roll | array | manual
  int pointBuyBudget;

  List<ClassLevel> levels;
  int xp;
  /// hpMax: max | average | roll — como os PV dos níveis novos são definidos.
  String hpMethod;
  Set<String> extraClassSkills;

  // Em jogo
  int damage;
  int nonlethal;
  int tempHp;
  Map<String, int> abilityDamage;
  Map<String, int> abilityDrain;
  int negativeLevels;
  Set<String> conditions;
  List<ActiveBuff> buffs;
  List<Effect> customEffects;
  Map<String, int> resourcesUsed;
  List<CustomResource> customResources;

  List<Item> items;
  Map<String, int> money; // pp, gp, sp, cp
  Map<String, CasterState> casters;
  /// Definições estruturadas embutidas na ficha (ex.: classe de um livro sem
  /// dados mecânicos na base, configurada pelo usuário). "class:<id>" -> JSON.
  Map<String, String> embeddedDefs;

  // Opções de combate
  bool twoWeaponFighting;
  int powerAttack;
  int combatExpertise;
  bool fightingDefensively;

  DateTime created;
  DateTime modified;

  Character({
    String? id,
    this.name = '',
    this.player = '',
    this.campaign = '',
    this.alignment = 'N',
    this.deity = '',
    this.gender = '',
    this.age = '',
    this.height = '',
    this.weight = '',
    this.eyes = '',
    this.hair = '',
    this.skin = '',
    this.appearance = '',
    this.background = '',
    this.notes = '',
    this.languages = '',
    this.portrait,
    this.allowedBooks,
    this.versionPolicy = 'ask',
    Map<String, String>? versionChoices,
    this.raceId = 'human',
    this.raceBook,
    this.sizeOverride,
    Map<String, int>? baseAbilities,
    this.abilityMethod = 'pointbuy',
    this.pointBuyBudget = 28,
    List<ClassLevel>? levels,
    this.xp = 0,
    this.hpMethod = 'average',
    Set<String>? extraClassSkills,
    this.damage = 0,
    this.nonlethal = 0,
    this.tempHp = 0,
    Map<String, int>? abilityDamage,
    Map<String, int>? abilityDrain,
    this.negativeLevels = 0,
    Set<String>? conditions,
    List<ActiveBuff>? buffs,
    List<Effect>? customEffects,
    Map<String, int>? resourcesUsed,
    List<CustomResource>? customResources,
    List<Item>? items,
    Map<String, int>? money,
    Map<String, CasterState>? casters,
    Map<String, String>? embeddedDefs,
    this.twoWeaponFighting = false,
    this.powerAttack = 0,
    this.combatExpertise = 0,
    this.fightingDefensively = false,
    DateTime? created,
    DateTime? modified,
  })  : id = id ?? newId(),
        versionChoices = versionChoices ?? {},
        baseAbilities = baseAbilities ?? {for (final a in abilityIds) a: 10},
        levels = levels ?? [],
        extraClassSkills = extraClassSkills ?? {},
        abilityDamage = abilityDamage ?? {},
        abilityDrain = abilityDrain ?? {},
        conditions = conditions ?? {},
        buffs = buffs ?? [],
        customEffects = customEffects ?? [],
        resourcesUsed = resourcesUsed ?? {},
        customResources = customResources ?? [],
        items = items ?? [],
        money = money ?? {'pp': 0, 'gp': 0, 'sp': 0, 'cp': 0},
        casters = casters ?? {},
        embeddedDefs = embeddedDefs ?? {},
        created = created ?? DateTime.now(),
        modified = modified ?? DateTime.now();

  int get characterLevel => levels.length;

  Map<String, int> get classLevelCounts {
    final m = <String, int>{};
    for (final l in levels) {
      m[l.classId] = (m[l.classId] ?? 0) + 1;
    }
    return m;
  }

  /// Descanso de 8 horas: recupera recursos diários, espaços de magia,
  /// PV pelo nível (e dano não letal), 1 ponto de dano de atributo.
  void restOvernight({int? healHp}) {
    resourcesUsed.clear();
    for (final c in casters.values) {
      c.usedSpontaneous.clear();
      for (final p in c.prepared) {
        p.used = false;
      }
    }
    final heal = healHp ?? characterLevel;
    damage = max(0, damage - heal);
    nonlethal = max(0, nonlethal - characterLevel * 8);
    abilityDamage.updateAll((k, v) => max(0, v - 1));
    abilityDamage.removeWhere((k, v) => v == 0);
    buffs.removeWhere((b) => b.roundsLeft != null);
    conditions.removeAll({'fatigued', 'raging-fatigue', 'exhausted'});
  }

  /// Avança uma rodada: decrementa durações e remove buffs vencidos.
  List<String> nextRound() {
    final expired = <String>[];
    for (final b in buffs) {
      if (b.active && b.roundsLeft != null) {
        b.roundsLeft = b.roundsLeft! - 1;
        if (b.roundsLeft! <= 0) {
          b.active = false;
          expired.add(b.name);
        }
      }
    }
    return expired;
  }
}
