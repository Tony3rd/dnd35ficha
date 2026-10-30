import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../engine/defs.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'effect_editor.dart';
import 'widgets.dart';

class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    final ch = c.ch;
    final enc = s.encumbrance;
    final loadName = switch (enc.load) {
      'light' => tr('leve', 'light'),
      'medium' => tr('média', 'medium'),
      'heavy' => tr('pesada', 'heavy'),
      _ => tr('SOBRECARREGADO', 'OVERLOADED'),
    };
    final kinds = ['weapon', 'armor', 'shield', 'magic', 'gear', 'consumable', 'ammo'];
    final total = ch.items.fold<double>(0, (a, i) => a + i.cost * i.qty);
    return ListView(padding: const EdgeInsets.all(8), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(spacing: 18, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${tr('Carga', 'Load')}: ${enc.carried.toStringAsFixed(1)} lb ($loadName)', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${tr('leve', 'light')} ≤${enc.light} · ${tr('média', 'medium')} ≤${enc.medium} · ${tr('pesada', 'heavy')} ≤${enc.heavy}'),
            Text('${tr('Valor do equipamento', 'Gear value')}: ${total.toStringAsFixed(0)} po'),
            if (s.characterLevel > 0)
              Text('${tr('Riqueza esperada (DMG)', 'Expected wealth (DMG)')}: ${c.app.rules.wealthFor(s.characterLevel)} po'),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 12, children: [
            for (final k in ['pp', 'gp', 'sp', 'cp'])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(switch (k) { 'pp' => 'PL', 'gp' => 'PO', 'sp' => 'PP', _ => 'PC' }),
                TextButton(
                  child: Text('${ch.money[k] ?? 0}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final v = await promptText(context, tr('Moedas ($k) — use +N/−N para somar', 'Coins ($k) — use +N/-N to add'),
                        initial: '${ch.money[k] ?? 0}');
                    if (v == null) return;
                    final t = v.trim();
                    final cur = ch.money[k] ?? 0;
                    int? nv;
                    if (t.startsWith('+')) {
                      nv = cur + (int.tryParse(t.substring(1)) ?? 0);
                    } else if (t.startsWith('-') || t.startsWith('−')) {
                      nv = cur - (int.tryParse(t.substring(1)) ?? 0);
                    } else {
                      nv = int.tryParse(t);
                    }
                    if (nv != null) c.update((x) => x.money[k] = nv!);
                  },
                ),
              ]),
          ]),
        ),
      ),
      Wrap(spacing: 8, runSpacing: 6, children: [
        FilledButton.tonalIcon(icon: const Icon(Icons.hardware), label: Text(tr('Arma', 'Weapon')), onPressed: () => _addWeapon(context, c)),
        FilledButton.tonalIcon(icon: const Icon(Icons.shield_outlined), label: Text(tr('Armadura/escudo', 'Armor/shield')), onPressed: () => _addArmor(context, c)),
        FilledButton.tonalIcon(icon: const Icon(Icons.auto_awesome), label: Text(tr('Item da biblioteca', 'Library item')), onPressed: () => _addFromLibrary(context, c)),
        OutlinedButton.icon(icon: const Icon(Icons.add), label: Text(tr('Item livre', 'Custom item')), onPressed: () async {
          final it = await editItem(context, Item(name: tr('Novo item', 'New item')));
          if (it != null) c.update((x) => x.items.add(it));
        }),
      ]),
      for (final k in kinds)
        if (ch.items.any((i) => i.kind == k)) ...[
          SectionTitle(_kindLabel(k)),
          for (final it in ch.items.where((i) => i.kind == k))
            Card(
              child: ListTile(
                dense: true,
                leading: Checkbox(value: it.equipped, onChanged: (v) => c.update((x) => it.equipped = v ?? false)),
                title: Text('${it.qty > 1 ? '${it.qty}× ' : ''}${it.name}${it.enhancement > 0 ? ' +${it.enhancement}' : ''}'
                    '${it.masterwork && it.enhancement == 0 ? ' (${tr('obra-prima', 'masterwork')})' : ''}'),
                subtitle: Text([
                  '${it.totalWeight.toStringAsFixed(1)} lb',
                  if (it.cost > 0) '${it.cost} po',
                  if (it.location != 'body') it.location,
                  if (it.charges != null) '${tr('cargas', 'charges')} ${it.charges}',
                  ...it.properties,
                  ...it.effects.map(describeEffect),
                ].join(' · ')),
                onTap: () async {
                  final ed = await editItem(context, it);
                  if (ed != null) c.update((x) => x.items[x.items.indexOf(it)] = ed);
                },
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (it.charges != null)
                    IconButton(
                        tooltip: tr('Usar carga', 'Use charge'),
                        icon: const Icon(Icons.bolt),
                        onPressed: it.charges! > 0 ? () => c.update((x) => it.charges = it.charges! - 1) : null),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => c.update((x) => x.items.remove(it))),
                ]),
              ),
            ),
        ],
      const SizedBox(height: 60),
    ]);
  }

  String _kindLabel(String k) => switch (k) {
        'weapon' => tr('Armas', 'Weapons'),
        'armor' => tr('Armaduras', 'Armor'),
        'shield' => tr('Escudos', 'Shields'),
        'magic' => tr('Itens mágicos', 'Magic items'),
        'consumable' => tr('Consumíveis', 'Consumables'),
        'ammo' => tr('Munição', 'Ammunition'),
        _ => tr('Equipamento', 'Gear'),
      };

  Future<void> _addWeapon(BuildContext context, CharacterController c) async {
    final app = c.app;
    final list = <LibEntry>[
      for (final l in app.rules.weapons.values)
        for (final w in l)
          if (c.ch.allowedBooks == null || c.ch.allowedBooks!.contains(w.book))
            LibEntry(kind: 'weapon', name: w.name, book: w.book, page: w.page,
                summary: '${w.namePt} · ${w.dmgM} · ${w.critText} · ${w.category}'),
    ];
    final e = await pickEntry(context, title: tr('Escolher arma', 'Choose weapon'), fixed: list);
    if (e == null) return;
    final w = app.rules.pick(app.rules.weapons, slugify(e.name), book: e.book)!;
    final size = c.sheet.size;
    final mult = size == 'small' ? 0.5 : (size == 'large' ? 2.0 : 1.0);
    c.update((x) => x.items.add(Item(
          name: Lang.isPt && w.namePt.isNotEmpty ? w.namePt : w.name,
          kind: 'weapon',
          baseRef: w.name,
          baseBook: w.book,
          weight: w.weight * mult,
          cost: w.cost,
          size: size,
          equipped: true,
          twoHanded: w.handed == 'two',
        )));
  }

  Future<void> _addArmor(BuildContext context, CharacterController c) async {
    final app = c.app;
    final list = <LibEntry>[
      for (final l in app.rules.armors.values)
        for (final a in l)
          if (c.ch.allowedBooks == null || c.ch.allowedBooks!.contains(a.book))
            LibEntry(kind: 'armor', name: a.name, book: a.book, page: a.page,
                summary: '${a.namePt} · +${a.bonus} · ${tr('Des máx', 'max Dex')} ${a.maxDex ?? '—'} · ${a.acp} · ${a.asf}%'),
    ];
    final e = await pickEntry(context, title: tr('Escolher armadura/escudo', 'Choose armor/shield'), fixed: list);
    if (e == null) return;
    final a = app.rules.pick(app.rules.armors, slugify(e.name), book: e.book)!;
    final small = c.sheet.size == 'small';
    c.update((x) => x.items.add(Item(
          name: Lang.isPt && a.namePt.isNotEmpty ? a.namePt : a.name,
          kind: a.isShield ? 'shield' : 'armor',
          baseRef: a.name,
          baseBook: a.book,
          weight: small ? a.weight / 2 : a.weight,
          cost: a.cost,
          equipped: true,
        )));
  }

  Future<void> _addFromLibrary(BuildContext context, CharacterController c) async {
    final e = await pickEntry(context,
        title: tr('Item da biblioteca', 'Library item'), kinds: {'magic-item', 'equipment', 'weapon', 'armor'}, books: c.ch.allowedBooks);
    if (e == null || !context.mounted) return;
    final it = await editItem(
        context,
        Item(
          name: e.name,
          kind: e.kind == 'magic-item' ? 'magic' : 'gear',
          notes: '${e.sourceLabel}${e.summary.isNotEmpty ? ' — ${e.summary}' : ''}',
          cost: (e.data['cost'] as num?)?.toDouble() ?? 0,
          weight: (e.data['weight'] as num?)?.toDouble() ?? 0,
        ));
    if (it != null) c.update((x) => x.items.add(it));
  }
}

Future<Item?> editItem(BuildContext context, Item item) =>
    showDialog<Item>(context: context, builder: (_) => _ItemDialog(item: item));

class _ItemDialog extends StatefulWidget {
  final Item item;
  const _ItemDialog({required this.item});
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late Item it;
  final ctl = <String, TextEditingController>{};

  TextEditingController f(String k, String v) => ctl.putIfAbsent(k, () => TextEditingController(text: v));

  @override
  void initState() {
    super.initState();
    final o = widget.item;
    it = Item(
      id: o.id, name: o.name, kind: o.kind, baseRef: o.baseRef, baseBook: o.baseBook, qty: o.qty, weight: o.weight,
      cost: o.cost, equipped: o.equipped, location: o.location, enhancement: o.enhancement, masterwork: o.masterwork,
      material: o.material, size: o.size, properties: List.of(o.properties), effects: List.of(o.effects), notes: o.notes,
      charges: o.charges, dmg: o.dmg, critText: o.critText, critRange: o.critRange, critMult: o.critMult, range: o.range,
      armorBonus: o.armorBonus, maxDex: o.maxDex, acp: o.acp, asf: o.asf, handed: o.handed, category: o.category,
      twoHanded: o.twoHanded, offHand: o.offHand, compositeStr: o.compositeStr, showInAttacks: o.showInAttacks,
    );
  }

  int? _i(String k) => int.tryParse(ctl[k]?.text.trim() ?? '');

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    Widget tf(String k, String label, String v, {double w = 140}) =>
        SizedBox(width: w, child: TextField(controller: f(k, v), decoration: InputDecoration(labelText: label)));
    return AlertDialog(
      title: Text(tr('Item', 'Item')),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            tf('name', tr('Nome', 'Name'), it.name, w: 600),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              DropdownButton<String>(
                value: it.kind,
                items: [
                  for (final k in ['weapon', 'armor', 'shield', 'magic', 'gear', 'consumable', 'ammo'])
                    DropdownMenuItem(value: k, child: Text(k)),
                ],
                onChanged: (v) => setState(() => it.kind = v ?? 'gear'),
              ),
              tf('qty', tr('Qtd.', 'Qty'), '${it.qty}', w: 70),
              tf('weight', tr('Peso (lb)', 'Weight (lb)'), '${it.weight}', w: 90),
              tf('cost', tr('Custo (po)', 'Cost (gp)'), '${it.cost}', w: 100),
              tf('enh', tr('Melhoria +', 'Enhancement +'), '${it.enhancement}', w: 100),
              tf('charges', tr('Cargas', 'Charges'), it.charges?.toString() ?? '', w: 80),
              FilterChip(label: Text(tr('Obra-prima', 'Masterwork')), selected: it.masterwork, onSelected: (v) => setState(() => it.masterwork = v)),
              FilterChip(label: Text(tr('Equipado', 'Equipped')), selected: it.equipped, onSelected: (v) => setState(() => it.equipped = v)),
              DropdownButton<String>(
                value: ['body', 'pack', 'mount', 'stored'].contains(it.location) ? it.location : 'body',
                items: [
                  DropdownMenuItem(value: 'body', child: Text(tr('no corpo', 'worn'))),
                  DropdownMenuItem(value: 'pack', child: Text(tr('mochila', 'backpack'))),
                  DropdownMenuItem(value: 'mount', child: Text(tr('montaria (não pesa)', 'mount (no weight)'))),
                  DropdownMenuItem(value: 'stored', child: Text(tr('guardado (não pesa)', 'stored (no weight)'))),
                ],
                onChanged: (v) => setState(() => it.location = v ?? 'body'),
              ),
            ]),
            if (it.kind == 'weapon') ...[
              const SizedBox(height: 10),
              Text(tr('Arma', 'Weapon'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                tf('base', tr('Arma base', 'Base weapon'), it.baseRef ?? '', w: 200),
                DropdownButton<String>(
                  value: app.rules.sizeOrder.contains(it.size) ? it.size : 'medium',
                  items: [for (final s in app.rules.sizeOrder) DropdownMenuItem(value: s, child: Text(Lang.isPt ? app.rules.size(s).namePt : s))],
                  onChanged: (v) => setState(() => it.size = v ?? 'medium'),
                ),
                tf('dmg', tr('Dano (sobrescreve)', 'Damage (override)'), it.dmg ?? '', w: 130),
                tf('critRange', tr('Ameaça (ex. 19)', 'Threat (e.g. 19)'), it.critRange?.toString() ?? '', w: 110),
                tf('critMult', tr('Mult. (ex. 3)', 'Mult. (e.g. 3)'), it.critMult?.toString() ?? '', w: 100),
                tf('range', tr('Incremento (pés)', 'Range (ft)'), it.range?.toString() ?? '', w: 110),
                tf('comp', tr('For composto', 'Composite Str'), '${it.compositeStr}', w: 110),
                FilterChip(label: Text(tr('Duas mãos', 'Two-handed')), selected: it.twoHanded, onSelected: (v) => setState(() => it.twoHanded = v)),
                FilterChip(label: Text(tr('Mão inábil', 'Off-hand')), selected: it.offHand, onSelected: (v) => setState(() => it.offHand = v)),
                FilterChip(label: Text(tr('Mostrar em ataques', 'Show in attacks')), selected: it.showInAttacks, onSelected: (v) => setState(() => it.showInAttacks = v)),
              ]),
            ],
            if (it.kind == 'armor' || it.kind == 'shield') ...[
              const SizedBox(height: 10),
              Text(tr('Armadura', 'Armor'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 10, runSpacing: 10, children: [
                tf('base', tr('Armadura base', 'Base armor'), it.baseRef ?? '', w: 200),
                tf('armorBonus', tr('Bônus (sobrescreve)', 'Bonus (override)'), it.armorBonus?.toString() ?? '', w: 120),
                tf('maxDex', tr('Des máx.', 'Max Dex'), it.maxDex?.toString() ?? '', w: 90),
                tf('acp', tr('Penalidade', 'Check penalty'), it.acp?.toString() ?? '', w: 100),
                tf('asf', tr('Falha arcana %', 'Spell failure %'), it.asf?.toString() ?? '', w: 110),
              ]),
            ],
            const SizedBox(height: 10),
            tf('props', tr('Propriedades (separadas por vírgula: keen, flaming…)', 'Properties (comma separated: keen, flaming…)'),
                it.properties.join(', '), w: 600),
            const SizedBox(height: 10),
            Text(tr('Modificadores quando equipado', 'Modifiers when equipped'), style: const TextStyle(fontWeight: FontWeight.bold)),
            EffectListEditor(
              effects: it.effects,
              skillIds: app.rules.skills.keys.toList(),
              onChanged: (l) => setState(() => it.effects = l),
            ),
            tf('notes', tr('Notas', 'Notes'), it.notes, w: 600),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar', 'Cancel'))),
        FilledButton(
          onPressed: () {
            it.name = ctl['name']!.text.trim();
            it.qty = _i('qty') ?? 1;
            it.weight = double.tryParse(ctl['weight']!.text.replaceAll(',', '.')) ?? 0;
            it.cost = double.tryParse(ctl['cost']!.text.replaceAll(',', '.')) ?? 0;
            it.enhancement = _i('enh') ?? 0;
            it.charges = _i('charges');
            if (ctl.containsKey('base')) it.baseRef = ctl['base']!.text.trim().isEmpty ? null : ctl['base']!.text.trim();
            if (it.kind == 'weapon') {
              it.dmg = ctl['dmg']!.text.trim().isEmpty ? null : ctl['dmg']!.text.trim();
              it.critRange = _i('critRange');
              it.critMult = _i('critMult');
              it.range = _i('range');
              it.compositeStr = _i('comp') ?? 0;
            }
            if (it.kind == 'armor' || it.kind == 'shield') {
              it.armorBonus = _i('armorBonus');
              it.maxDex = _i('maxDex');
              it.acp = _i('acp');
              it.asf = _i('asf');
            }
            it.properties = ctl['props']!.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            it.notes = ctl['notes']!.text;
            Navigator.pop(context, it);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
