import 'dart:convert';
import 'dart:math' as math;

import 'defs.dart';

/// Conjunto de regras ativo: núcleo SRD + entradas estruturadas da base de dados
/// + homebrew. Cada tipo guarda *todas* as versões (uma por livro); a ficha
/// escolhe qual usar através de [pick].
class Ruleset {
  final Map<String, SkillDef> skills = {};
  final List<SynergyDef> synergies = [];
  final Map<String, List<ClassDef>> classes = {};
  final Map<String, List<RaceDef>> races = {};
  final Map<String, List<FeatDef>> feats = {};
  final Map<String, List<WeaponDef>> weapons = {};
  final Map<String, List<ArmorDef>> armors = {};
  final Map<String, List<SpellDef>> spells = {};
  final Map<String, ConditionDef> conditions = {};
  final Map<String, SizeDef> sizes = {};
  List<String> sizeOrder = [];
  List<int> heavyLoad = [];
  List<int> wealthByLevel = [];
  Map<int, int> pointBuy = {};
  List<int> eliteArray = [15, 14, 13, 12, 10, 8];
  List<String> schools = [];
  List<String> schoolsPt = [];
  List<String> damageSteps = [];

  /// Data de lançamento (yyyymm) por livro, para escolher "a versão mais recente".
  final Map<String, int> bookDates = {'PH': 200307, 'DMG': 200307, 'MM': 200307};

  static Ruleset fromCoreJson(String src) {
    final r = Ruleset();
    r.loadCore(jsonDecode(src) as Map<String, dynamic>);
    return r;
  }

  void loadCore(Map<String, dynamic> j) {
    for (final s in (j['skills'] as List)) {
      final d = SkillDef.fromJson(Map<String, dynamic>.from(s as Map));
      skills[d.id] = d;
    }
    for (final s in (j['synergies'] as List)) {
      final m = s as Map;
      synergies.add(SynergyDef(m['from'] as String, m['to'] as String, m['cond'] as String?));
    }
    for (final c in (j['classes'] as List)) {
      addClass(ClassDef.fromJson(Map<String, dynamic>.from(c as Map)));
    }
    for (final c in (j['races'] as List)) {
      addRace(RaceDef.fromJson(Map<String, dynamic>.from(c as Map)));
    }
    for (final c in (j['feats'] as List)) {
      addFeat(FeatDef.fromJson(Map<String, dynamic>.from(c as Map)));
    }
    for (final c in (j['weapons'] as List)) {
      addWeapon(WeaponDef.fromJson(Map<String, dynamic>.from(c as Map)));
    }
    for (final c in (j['armors'] as List)) {
      addArmor(ArmorDef.fromJson(Map<String, dynamic>.from(c as Map)));
    }
    for (final c in (j['conditions'] as List)) {
      final d = ConditionDef.fromJson(Map<String, dynamic>.from(c as Map));
      conditions[d.id] = d;
    }
    final t = j['tables'] as Map<String, dynamic>;
    (t['sizes'] as Map).forEach((k, v) {
      final m = v as Map;
      sizes['$k'] = SizeDef('$k', m['pt'] as String, (m['mod'] as num).toInt(), (m['grapple'] as num).toInt(),
          (m['hide'] as num).toInt(), (m['carry'] as num).toDouble(), (m['reach'] as num).toInt());
    });
    sizeOrder = (t['size_order'] as List).cast<String>();
    heavyLoad = (t['heavy_load'] as List).map((e) => (e as num).toInt()).toList();
    wealthByLevel = (t['wealth_by_level'] as List).map((e) => (e as num).toInt()).toList();
    pointBuy = (t['point_buy'] as Map).map((k, v) => MapEntry(int.parse('$k'), (v as num).toInt()));
    eliteArray = (t['elite_array'] as List).map((e) => (e as num).toInt()).toList();
    schools = (t['schools'] as List).cast<String>();
    schoolsPt = (t['schools_pt'] as List).cast<String>();
    damageSteps = (t['damage_steps'] as List).cast<String>();
  }

  /// [replace]=false mantém a versão já existente do mesmo livro (o núcleo
  /// estruturado tem prioridade sobre dados extraídos automaticamente).
  static void _add<T extends RuleDef>(Map<String, List<T>> m, T d, bool replace) {
    final list = m.putIfAbsent(d.id, () => <T>[]);
    if (list.any((x) => x.book == d.book)) {
      if (!replace) return;
      list.removeWhere((x) => x.book == d.book);
    }
    list.add(d);
  }

  void addClass(ClassDef d, {bool replace = true}) => _add(classes, d, replace);
  void addRace(RaceDef d, {bool replace = true}) => _add(races, d, replace);
  void addFeat(FeatDef d, {bool replace = true}) => _add(feats, d, replace);
  void addWeapon(WeaponDef d, {bool replace = true}) => _add(weapons, d, replace);
  void addArmor(ArmorDef d, {bool replace = true}) => _add(armors, d, replace);
  void addSpell(SpellDef d, {bool replace = true}) => _add(spells, d, replace);

  /// Escolhe a versão de um item considerando: escolha explícita da ficha,
  /// livros permitidos e (se nada for escolhido) o livro mais recente.
  T? pick<T extends RuleDef>(Map<String, List<T>> m, String id,
      {String? book, Set<String>? allowedBooks}) {
    final all = m[id];
    if (all == null || all.isEmpty) return null;
    var cands = all;
    if (allowedBooks != null) {
      final f = all.where((d) => allowedBooks.contains(d.book)).toList();
      if (f.isNotEmpty) cands = f;
    }
    if (book != null) {
      for (final d in cands) {
        if (d.book == book) return d;
      }
    }
    return newest(cands);
  }

  T newest<T extends RuleDef>(List<T> cands) {
    var best = cands.first;
    for (final d in cands.skip(1)) {
      if ((bookDates[d.book] ?? 0) > (bookDates[best.book] ?? 0)) best = d;
    }
    return best;
  }

  ClassDef? classById(String id, {String? book}) => pick(classes, id, book: book);
  RaceDef? raceById(String id, {String? book}) => pick(races, id, book: book);
  FeatDef? featByName(String name, {String? book}) => pick(feats, slugify(_baseFeatName(name)), book: book);
  WeaponDef? weaponByName(String name) => pick(weapons, slugify(name));
  ArmorDef? armorByName(String name) => pick(armors, slugify(name));

  /// "Weapon Focus (Longsword)" -> "Weapon Focus"
  static String _baseFeatName(String n) {
    final i = n.indexOf('(');
    if (i <= 0) return n.trim();
    // talentos cujo nome oficial contém parênteses
    const keep = ['Armor Proficiency'];
    final base = n.substring(0, i).trim();
    if (keep.contains(base)) return n.trim();
    return base;
  }

  static String? featChoice(String n) {
    final m = RegExp(r'\(([^)]*)\)\s*$').firstMatch(n);
    if (m == null || n.startsWith('Armor Proficiency')) return null;
    return m.group(1);
  }

  SizeDef size(String id) => sizes[id] ?? sizes['medium']!;

  int heavyLoadFor(int str) {
    if (str <= 0) return 0;
    if (str <= 29) return heavyLoad[str - 1];
    // acima de 29: cada +10 multiplica por 4
    final over = str - 20;
    final steps = over ~/ 10;
    final base = heavyLoad[(20 + over % 10) - 1];
    return base * math.pow(4, steps).toInt();
  }

  int wealthFor(int level) {
    if (level <= 0) return 0;
    if (level <= wealthByLevel.length) return wealthByLevel[level - 1];
    var w = wealthByLevel.last.toDouble();
    for (var l = wealthByLevel.length + 1; l <= level; l++) {
      w *= 1.3;
    }
    return (w / 1000).round() * 1000;
  }

  /// Escala um dado de dano de arma Média para outro tamanho.
  String scaleDamage(String medium, String small, String size) {
    if (size == 'small') return small;
    if (size == 'medium' || medium.isEmpty || medium == '—') return medium;
    final idx = sizeOrder.indexOf(size) - sizeOrder.indexOf('medium');
    if (idx < 0) {
      // Miúdo e menores: um passo abaixo do Pequeno por categoria
      var i = damageSteps.indexOf(small);
      if (i < 0) return small;
      i = math.max(0, i + idx + 1);
      return damageSteps[i];
    }
    var d = medium;
    for (var k = 0; k < idx; k++) {
      d = _stepUp(d);
    }
    return d;
  }

  String _stepUp(String d) {
    const special = {'1d10': '2d8', '1d12': '3d6', '2d4': '2d6', '2d8': '3d8', '2d10': '4d8', '3d8': '4d8'};
    if (special.containsKey(d)) return special[d]!;
    final i = damageSteps.indexOf(d);
    if (i < 0 || i + 1 >= damageSteps.length) return d;
    return damageSteps[i + 1];
  }
}
