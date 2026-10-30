// Formato próprio de ficha: XML (.d35x), legível e versionado.
import 'package:xml/xml.dart';

import '../engine/bonus.dart';
import 'character.dart';

const characterRoot = 'grimorio35-character';
const characterExt = 'd35x';

String _b(bool v) => v ? '1' : '0';
bool _pb(String? v) => v == '1' || v == 'true';
int _pi(String? v, [int d = 0]) => int.tryParse(v ?? '') ?? d;
double _pd(String? v, [double d = 0]) => double.tryParse(v ?? '') ?? d;
String? _ne(String? v) => (v == null || v.isEmpty) ? null : v;

void writeEffect(XmlBuilder b, Effect e) {
  b.element('effect', attributes: {
    'target': e.target,
    'value': e.value,
    if (e.type != BonusType.untyped) 'type': e.type,
    if (e.situational) 'condition': e.condition!,
    if (e.source.isNotEmpty) 'source': e.source,
  });
}

Effect readEffect(XmlElement x) => Effect(
      target: x.getAttribute('target') ?? '',
      value: x.getAttribute('value') ?? '0',
      type: x.getAttribute('type') ?? BonusType.untyped,
      condition: x.getAttribute('condition'),
      source: x.getAttribute('source') ?? '',
    );

List<Effect> readEffects(XmlElement? parent) =>
    parent == null ? [] : parent.findElements('effect').map(readEffect).toList();

String characterToXml(Character c) {
  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(characterRoot, nest: () {
    b.attribute('version', '${Character.schemaVersion}');
    b.attribute('id', c.id);
    b.attribute('created', c.created.toIso8601String());
    b.attribute('modified', DateTime.now().toIso8601String());
    b.element('identity', attributes: {
      'name': c.name, 'player': c.player, 'campaign': c.campaign, 'alignment': c.alignment,
      'deity': c.deity, 'gender': c.gender, 'age': c.age, 'height': c.height, 'weight': c.weight,
      'eyes': c.eyes, 'hair': c.hair, 'skin': c.skin, 'languages': c.languages,
    });
    b.element('sources', nest: () {
      b.attribute('policy', c.versionPolicy);
      b.attribute('all', _b(c.allowedBooks == null));
      for (final bk in (c.allowedBooks ?? <String>{}).toList()..sort()) {
        b.element('book', nest: bk);
      }
      c.versionChoices.forEach((k, v) => b.element('choice', attributes: {'key': k, 'book': v}));
    });
    b.element('race', attributes: {
      'id': c.raceId,
      if (c.raceBook != null) 'book': c.raceBook!,
      if (c.sizeOverride != null) 'size': c.sizeOverride!,
    });
    b.element('abilities', nest: () {
      b.attribute('method', c.abilityMethod);
      b.attribute('budget', '${c.pointBuyBudget}');
      for (final a in abilityIds) {
        b.element('ability', attributes: {'id': a, 'base': '${c.baseAbilities[a] ?? 10}'});
      }
    });
    b.element('levels', nest: () {
      b.attribute('hpMethod', c.hpMethod);
      for (final x in c.extraClassSkills) {
        b.element('classSkill', nest: x);
      }
      for (final l in c.levels) {
        b.element('level', nest: () {
          b.attribute('class', l.classId);
          if (l.classBook != null) b.attribute('book', l.classBook!);
          b.attribute('hp', '${l.hpRoll}');
          if (l.abilityIncrease != null) b.attribute('increase', l.abilityIncrease!);
          if (l.castingAdvances != null) b.attribute('advances', l.castingAdvances!);
          l.skillRanks.forEach((k, v) {
            if (v != 0) b.element('skill', attributes: {'key': k, 'ranks': v.toString()});
          });
          for (final f in l.feats) {
            b.element('feat', attributes: {'name': f.name, 'slot': f.slot, if (f.book != null) 'book': f.book!});
          }
          l.choices.forEach((k, v) => b.element('choice', attributes: {'key': k, 'value': v}));
        });
      }
    });
    b.element('xp', nest: '${c.xp}');
    b.element('state', nest: () {
      b.attribute('damage', '${c.damage}');
      b.attribute('nonlethal', '${c.nonlethal}');
      b.attribute('temp', '${c.tempHp}');
      b.attribute('negativeLevels', '${c.negativeLevels}');
      c.abilityDamage.forEach((k, v) => b.element('abilityDamage', attributes: {'id': k, 'value': '$v'}));
      c.abilityDrain.forEach((k, v) => b.element('abilityDrain', attributes: {'id': k, 'value': '$v'}));
      for (final x in c.conditions) {
        b.element('condition', attributes: {'id': x});
      }
      for (final bf in c.buffs) {
        b.element('buff', nest: () {
          b.attribute('id', bf.id);
          b.attribute('name', bf.name);
          b.attribute('active', _b(bf.active));
          if (bf.roundsLeft != null) b.attribute('rounds', '${bf.roundsLeft}');
          if (bf.source.isNotEmpty) b.attribute('source', bf.source);
          if (bf.notes.isNotEmpty) b.attribute('notes', bf.notes);
          for (final e in bf.effects) {
            writeEffect(b, e);
          }
        });
      }
      c.resourcesUsed.forEach((k, v) => b.element('resource', attributes: {'id': k, 'used': '$v'}));
    });
    b.element('customEffects', nest: () {
      for (final e in c.customEffects) {
        writeEffect(b, e);
      }
    });
    b.element('customResources', nest: () {
      for (final r in c.customResources) {
        b.element('resource', attributes: {'id': r.id, 'name': r.name, 'max': r.max, 'per': r.per});
      }
    });
    b.element('inventory', nest: () {
      b.element('money', attributes: c.money.map((k, v) => MapEntry(k, '$v')));
      for (final it in c.items) {
        b.element('item', nest: () {
          final a = <String, String?>{
            'id': it.id, 'name': it.name, 'kind': it.kind, 'base': it.baseRef, 'baseBook': it.baseBook,
            'qty': '${it.qty}', 'weight': '${it.weight}', 'cost': '${it.cost}', 'equipped': _b(it.equipped),
            'location': it.location, 'enhancement': '${it.enhancement}', 'masterwork': _b(it.masterwork),
            'material': it.material, 'size': it.size, 'charges': it.charges?.toString(),
            'dmg': it.dmg, 'crit': it.critText, 'critRange': it.critRange?.toString(),
            'critMult': it.critMult?.toString(), 'range': it.range?.toString(),
            'armorBonus': it.armorBonus?.toString(), 'maxDex': it.maxDex?.toString(),
            'acp': it.acp?.toString(), 'asf': it.asf?.toString(), 'handed': it.handed,
            'category': it.category, 'twoHanded': _b(it.twoHanded), 'offHand': _b(it.offHand),
            'compositeStr': '${it.compositeStr}', 'showInAttacks': _b(it.showInAttacks),
          };
          a.forEach((k, v) {
            if (v != null && v.isNotEmpty) b.attribute(k, v);
          });
          for (final p in it.properties) {
            b.element('property', nest: p);
          }
          for (final e in it.effects) {
            writeEffect(b, e);
          }
          if (it.notes.isNotEmpty) b.element('notes', nest: it.notes);
        });
      }
    });
    b.element('spellcasting', nest: () {
      for (final cs in c.casters.values) {
        b.element('caster', nest: () {
          b.attribute('class', cs.classId);
          if (cs.specialistSchool != null) b.attribute('specialist', cs.specialistSchool!);
          for (final d in cs.domains) {
            b.element('domain', nest: d);
          }
          for (final d in cs.prohibitedSchools) {
            b.element('prohibited', nest: d);
          }
          for (final k in cs.known) {
            b.element('known', attributes: {
              'name': k.name, 'level': '${k.level}', if (k.book != null) 'book': k.book!,
              if (k.domain) 'domain': '1',
            });
          }
          for (final p in cs.prepared) {
            b.element('prepared', attributes: {
              'name': p.name, 'level': '${p.level}', 'used': _b(p.used),
              if (p.domain) 'domain': '1', if (p.metamagic.isNotEmpty) 'metamagic': p.metamagic,
            });
          }
          cs.usedSpontaneous.forEach((l, n) => b.element('used', attributes: {'level': '$l', 'count': '$n'}));
        });
      }
    });
    b.element('embedded', nest: () {
      c.embeddedDefs.forEach((k, v) => b.element('def', attributes: {'key': k}, nest: () => b.cdata(v)));
    });
    b.element('combat', attributes: {
      'twf': _b(c.twoWeaponFighting), 'powerAttack': '${c.powerAttack}',
      'combatExpertise': '${c.combatExpertise}', 'defensive': _b(c.fightingDefensively),
    });
    b.element('appearance', nest: c.appearance);
    b.element('background', nest: c.background);
    b.element('notes', nest: c.notes);
  });
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

Character characterFromXml(String src) {
  final doc = XmlDocument.parse(src);
  final r = doc.rootElement;
  if (r.name.local != characterRoot) {
    throw FormatException('Arquivo não é uma ficha do Grimório 3.5 (raiz <${r.name.local}>).');
  }
  XmlElement? one(XmlElement p, String n) {
    final it = p.findElements(n);
    return it.isEmpty ? null : it.first;
  }

  final c = Character(
    id: r.getAttribute('id'),
    created: DateTime.tryParse(r.getAttribute('created') ?? ''),
    modified: DateTime.tryParse(r.getAttribute('modified') ?? ''),
  );
  final idn = one(r, 'identity');
  if (idn != null) {
    String g(String k) => idn.getAttribute(k) ?? '';
    c
      ..name = g('name')
      ..player = g('player')
      ..campaign = g('campaign')
      ..alignment = g('alignment').isEmpty ? 'N' : g('alignment')
      ..deity = g('deity')
      ..gender = g('gender')
      ..age = g('age')
      ..height = g('height')
      ..weight = g('weight')
      ..eyes = g('eyes')
      ..hair = g('hair')
      ..skin = g('skin')
      ..languages = g('languages');
  }
  final src2 = one(r, 'sources');
  if (src2 != null) {
    c.versionPolicy = src2.getAttribute('policy') ?? 'ask';
    if (!_pb(src2.getAttribute('all'))) {
      c.allowedBooks = src2.findElements('book').map((e) => e.innerText).toSet();
    }
    for (final ch in src2.findElements('choice')) {
      c.versionChoices[ch.getAttribute('key') ?? ''] = ch.getAttribute('book') ?? '';
    }
  }
  final race = one(r, 'race');
  if (race != null) {
    c.raceId = race.getAttribute('id') ?? 'human';
    c.raceBook = race.getAttribute('book');
    c.sizeOverride = race.getAttribute('size');
  }
  final ab = one(r, 'abilities');
  if (ab != null) {
    c.abilityMethod = ab.getAttribute('method') ?? 'manual';
    c.pointBuyBudget = _pi(ab.getAttribute('budget'), 28);
    for (final a in ab.findElements('ability')) {
      c.baseAbilities[a.getAttribute('id') ?? ''] = _pi(a.getAttribute('base'), 10);
    }
  }
  final lv = one(r, 'levels');
  if (lv != null) {
    c.hpMethod = lv.getAttribute('hpMethod') ?? 'average';
    c.extraClassSkills = lv.findElements('classSkill').map((e) => e.innerText).toSet();
    for (final l in lv.findElements('level')) {
      c.levels.add(ClassLevel(
        classId: l.getAttribute('class') ?? 'fighter',
        classBook: l.getAttribute('book'),
        hpRoll: _pi(l.getAttribute('hp')),
        abilityIncrease: _ne(l.getAttribute('increase')),
        castingAdvances: _ne(l.getAttribute('advances')),
        skillRanks: {
          for (final s in l.findElements('skill')) s.getAttribute('key') ?? '': _pd(s.getAttribute('ranks')),
        },
        feats: [
          for (final f in l.findElements('feat'))
            FeatPick(f.getAttribute('name') ?? '', book: f.getAttribute('book'), slot: f.getAttribute('slot') ?? 'general'),
        ],
        choices: {
          for (final x in l.findElements('choice')) x.getAttribute('key') ?? '': x.getAttribute('value') ?? '',
        },
      ));
    }
  }
  c.xp = _pi(one(r, 'xp')?.innerText);
  final st = one(r, 'state');
  if (st != null) {
    c.damage = _pi(st.getAttribute('damage'));
    c.nonlethal = _pi(st.getAttribute('nonlethal'));
    c.tempHp = _pi(st.getAttribute('temp'));
    c.negativeLevels = _pi(st.getAttribute('negativeLevels'));
    for (final x in st.findElements('abilityDamage')) {
      c.abilityDamage[x.getAttribute('id') ?? ''] = _pi(x.getAttribute('value'));
    }
    for (final x in st.findElements('abilityDrain')) {
      c.abilityDrain[x.getAttribute('id') ?? ''] = _pi(x.getAttribute('value'));
    }
    c.conditions = st.findElements('condition').map((e) => e.getAttribute('id') ?? '').toSet();
    for (final x in st.findElements('buff')) {
      c.buffs.add(ActiveBuff(
        id: x.getAttribute('id'),
        name: x.getAttribute('name') ?? '',
        active: _pb(x.getAttribute('active')),
        roundsLeft: int.tryParse(x.getAttribute('rounds') ?? ''),
        source: x.getAttribute('source') ?? '',
        notes: x.getAttribute('notes') ?? '',
        effects: readEffects(x),
      ));
    }
    for (final x in st.findElements('resource')) {
      c.resourcesUsed[x.getAttribute('id') ?? ''] = _pi(x.getAttribute('used'));
    }
  }
  c.customEffects = readEffects(one(r, 'customEffects'));
  final cr = one(r, 'customResources');
  if (cr != null) {
    for (final x in cr.findElements('resource')) {
      c.customResources.add(CustomResource(
          id: x.getAttribute('id'), name: x.getAttribute('name') ?? '', max: x.getAttribute('max') ?? '1',
          per: x.getAttribute('per') ?? 'day'));
    }
  }
  final inv = one(r, 'inventory');
  if (inv != null) {
    final m = one(inv, 'money');
    if (m != null) {
      for (final k in ['pp', 'gp', 'sp', 'cp']) {
        c.money[k] = _pi(m.getAttribute(k));
      }
    }
    for (final x in inv.findElements('item')) {
      String? g(String k) => x.getAttribute(k);
      int? gi(String k) => int.tryParse(g(k) ?? '');
      final notes = one(x, 'notes');
      c.items.add(Item(
        id: g('id'),
        name: g('name') ?? '',
        kind: g('kind') ?? 'gear',
        baseRef: g('base'),
        baseBook: g('baseBook'),
        qty: _pi(g('qty'), 1),
        weight: _pd(g('weight')),
        cost: _pd(g('cost')),
        equipped: _pb(g('equipped')),
        location: g('location') ?? 'body',
        enhancement: _pi(g('enhancement')),
        masterwork: _pb(g('masterwork')),
        material: g('material') ?? '',
        size: g('size') ?? 'medium',
        charges: gi('charges'),
        dmg: g('dmg'),
        critText: g('crit'),
        critRange: gi('critRange'),
        critMult: gi('critMult'),
        range: gi('range'),
        armorBonus: gi('armorBonus'),
        maxDex: gi('maxDex'),
        acp: gi('acp'),
        asf: gi('asf'),
        handed: g('handed'),
        category: g('category'),
        twoHanded: _pb(g('twoHanded')),
        offHand: _pb(g('offHand')),
        compositeStr: _pi(g('compositeStr')),
        showInAttacks: g('showInAttacks') == null ? true : _pb(g('showInAttacks')),
        properties: x.findElements('property').map((e) => e.innerText).toList(),
        effects: readEffects(x),
        notes: notes?.innerText ?? '',
      ));
    }
  }
  final sc = one(r, 'spellcasting');
  if (sc != null) {
    for (final x in sc.findElements('caster')) {
      final cs = CasterState(
        classId: x.getAttribute('class') ?? '',
        specialistSchool: x.getAttribute('specialist'),
        domains: x.findElements('domain').map((e) => e.innerText).toList(),
        prohibitedSchools: x.findElements('prohibited').map((e) => e.innerText).toList(),
        known: [
          for (final k in x.findElements('known'))
            KnownSpell(
              name: k.getAttribute('name') ?? '',
              level: _pi(k.getAttribute('level')),
              book: k.getAttribute('book'),
              classId: x.getAttribute('class') ?? '',
              domain: _pb(k.getAttribute('domain')),
            ),
        ],
        prepared: [
          for (final p in x.findElements('prepared'))
            PreparedSpell(
              name: p.getAttribute('name') ?? '',
              level: _pi(p.getAttribute('level')),
              used: _pb(p.getAttribute('used')),
              domain: _pb(p.getAttribute('domain')),
              metamagic: p.getAttribute('metamagic') ?? '',
            ),
        ],
        usedSpontaneous: {
          for (final u in x.findElements('used')) _pi(u.getAttribute('level')): _pi(u.getAttribute('count')),
        },
      );
      c.casters[cs.classId] = cs;
    }
  }
  final emb = one(r, 'embedded');
  if (emb != null) {
    for (final d in emb.findElements('def')) {
      c.embeddedDefs[d.getAttribute('key') ?? ''] = d.innerText;
    }
  }
  final cb = one(r, 'combat');
  if (cb != null) {
    c.twoWeaponFighting = _pb(cb.getAttribute('twf'));
    c.powerAttack = _pi(cb.getAttribute('powerAttack'));
    c.combatExpertise = _pi(cb.getAttribute('combatExpertise'));
    c.fightingDefensively = _pb(cb.getAttribute('defensive'));
  }
  c.appearance = one(r, 'appearance')?.innerText ?? '';
  c.background = one(r, 'background')?.innerText ?? '';
  c.notes = one(r, 'notes')?.innerText ?? '';
  return c;
}
