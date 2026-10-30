/// Sistema de modificadores do D&D 3.5.
///
/// Toda fonte (raça, classe, talento, item, magia ativa, condição, ajuste
/// manual, homebrew) contribui com [Effect]s. Um efeito aponta para um *alvo*
/// (ex.: `abil.str`, `ac`, `save.will`, `skill.hide`, `attack.melee`) e tem um
/// *tipo de bônus*. Bônus do mesmo tipo não se acumulam (vale o maior), exceto
/// esquiva, circunstância e sem tipo. Penalidades sempre se acumulam.
library;

class BonusType {
  static const untyped = 'untyped';
  static const alchemical = 'alchemical';
  static const armor = 'armor';
  static const circumstance = 'circumstance';
  static const competence = 'competence';
  static const deflection = 'deflection';
  static const dodge = 'dodge';
  static const enhancement = 'enhancement';
  static const insight = 'insight';
  static const luck = 'luck';
  static const morale = 'morale';
  static const natural = 'natural';
  static const naturalEnh = 'natural_enhancement';
  static const profane = 'profane';
  static const racial = 'racial';
  static const resistance = 'resistance';
  static const sacred = 'sacred';
  static const shield = 'shield';
  static const size = 'size';
  static const inherent = 'inherent';
  static const epic = 'epic';
  static const exalted = 'exalted';

  static const all = [
    untyped, alchemical, armor, circumstance, competence, deflection, dodge,
    enhancement, epic, exalted, inherent, insight, luck, morale, natural,
    naturalEnh, profane, racial, resistance, sacred, shield, size,
  ];

  /// Tipos que se acumulam consigo mesmos.
  static bool stacks(String t) => t == dodge || t == circumstance || t == untyped;

  static const labelsPt = {
    untyped: 'sem tipo', alchemical: 'alquímico', armor: 'armadura',
    circumstance: 'circunstância', competence: 'competência',
    deflection: 'deflexão', dodge: 'esquiva', enhancement: 'melhoria',
    epic: 'épico', exalted: 'exaltado', inherent: 'inerente',
    insight: 'intuição', luck: 'sorte', morale: 'moral',
    natural: 'armadura natural', naturalEnh: 'melhoria de arm. natural',
    profane: 'profano', racial: 'racial', resistance: 'resistência',
    sacred: 'sagrado', shield: 'escudo', size: 'tamanho',
  };
}

class Effect {
  String target;
  String value; // fórmula (ver expr.dart)
  String type;
  /// Se preenchido, o efeito é situacional: aparece na ficha como nota
  /// ("+2 contra veneno") mas não entra no total.
  String? condition;
  String source;

  Effect({
    required this.target,
    required this.value,
    this.type = BonusType.untyped,
    this.condition,
    this.source = '',
  });

  bool get situational => condition != null && condition!.trim().isNotEmpty;

  Effect copyWith({String? source}) => Effect(
        target: target,
        value: value,
        type: type,
        condition: condition,
        source: source ?? this.source,
      );

  Map<String, dynamic> toJson() => {
        't': target,
        'v': value,
        if (type != BonusType.untyped) 'ty': type,
        if (situational) 'c': condition,
        if (source.isNotEmpty) 's': source,
      };

  factory Effect.fromJson(Map<String, dynamic> j) => Effect(
        target: j['t'] as String,
        value: '${j['v']}',
        type: (j['ty'] as String?) ?? BonusType.untyped,
        condition: j['c'] as String?,
        source: (j['s'] as String?) ?? '',
      );

  @override
  String toString() => '$target ${value.startsWith('-') ? value : '+$value'} ($type)';
}

class ResolvedBonus {
  final String target;
  final int value;
  final String type;
  final String source;
  final String? condition;
  ResolvedBonus(this.target, this.value, this.type, this.source, [this.condition]);
}

/// Resultado de somar bônus com regras de empilhamento, com a lista do que
/// foi efetivamente aplicado (para o detalhamento na ficha).
class BonusTotal {
  final int total;
  final List<ResolvedBonus> applied;
  final List<ResolvedBonus> suppressed;
  final List<ResolvedBonus> situational;
  BonusTotal(this.total, this.applied, this.suppressed, this.situational);

  int byType(String type) =>
      applied.where((b) => b.type == type).fold(0, (s, b) => s + b.value);
}

class BonusPool {
  final List<ResolvedBonus> _all = [];

  void add(ResolvedBonus b) => _all.add(b);
  void addAll(Iterable<ResolvedBonus> bs) => _all.addAll(bs);
  void removeWhere(bool Function(ResolvedBonus b) test) => _all.removeWhere(test);
  Iterable<ResolvedBonus> get all => _all;

  bool hasFlag(String flag) =>
      _all.any((b) => b.target == 'flag.$flag' && b.value != 0 && b.condition == null);

  /// Soma os bônus de qualquer um dos [targets], respeitando o empilhamento.
  /// [excludeTypes] permite, p.ex., CA de toque (sem armadura/escudo/natural).
  BonusTotal total(List<String> targets, {Set<String> excludeTypes = const {}}) {
    final relevant = _all.where((b) => targets.contains(b.target)).toList();
    final situ = relevant.where((b) => b.condition != null).toList();
    final active = relevant.where((b) => b.condition == null && !excludeTypes.contains(b.type));

    final applied = <ResolvedBonus>[];
    final suppressed = <ResolvedBonus>[];
    final bestByType = <String, ResolvedBonus>{};

    for (final b in active) {
      if (b.value < 0 || BonusType.stacks(b.type)) {
        applied.add(b);
        continue;
      }
      final cur = bestByType[b.type];
      if (cur == null) {
        bestByType[b.type] = b;
      } else if (b.value > cur.value) {
        suppressed.add(cur);
        bestByType[b.type] = b;
      } else {
        suppressed.add(b);
      }
    }
    applied.addAll(bestByType.values);
    final sum = applied.fold<int>(0, (s, b) => s + b.value);
    return BonusTotal(sum, applied, suppressed, situ);
  }
}

/// Alvos conhecidos (usados no editor de efeitos e homebrew).
class Targets {
  static const abilities = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
  static const general = <String, String>{
    'abil.str': 'Força', 'abil.dex': 'Destreza', 'abil.con': 'Constituição',
    'abil.int': 'Inteligência', 'abil.wis': 'Sabedoria', 'abil.cha': 'Carisma',
    'ac': 'Classe de Armadura', 'init': 'Iniciativa',
    'save.all': 'Todos os testes de resistência', 'save.fort': 'Fortitude',
    'save.ref': 'Reflexos', 'save.will': 'Vontade',
    'attack.all': 'Ataque (todos)', 'attack.melee': 'Ataque corpo a corpo',
    'attack.ranged': 'Ataque à distância',
    'damage.all': 'Dano (todos)', 'damage.melee': 'Dano corpo a corpo',
    'damage.ranged': 'Dano à distância',
    'skill.all': 'Todas as perícias', 'abilitycheck': 'Testes de atributo',
    'hp.max': 'PV máximos', 'speed.land': 'Deslocamento (pés)',
    'grapple': 'Agarrar', 'cl.all': 'Nível de conjurador', 'spelldc.all': 'CD das magias',
    'sr': 'Resistência à magia', 'bab': 'Bônus base de ataque',
    'flag.lose_dex_ac': 'Perde Des na CA', 'flag.dex_zero': 'Destreza 0 (indefeso)',
    'flag.str_zero': 'Força 0', 'flag.no_run': 'Não pode correr/investir',
    'flag.half_speed': 'Metade do deslocamento',
  };
}
