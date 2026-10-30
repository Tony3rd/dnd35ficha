import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../engine/defs.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'books_selector.dart';
import 'tab_feats.dart';
import 'tab_inventory.dart';
import 'tab_levels.dart';
import 'tab_notes.dart';
import 'tab_spells.dart';
import 'tab_summary.dart';
import 'widgets.dart';

/// Assistente de criação: guia passo a passo, reaproveitando as abas da ficha.
/// Funciona para qualquer nível (inclusive épico: níveis 21+ usam bônus épicos
/// de ataque/resistência, talentos a cada 3 níveis e riqueza estendida).
class CreationWizard extends StatefulWidget {
  const CreationWizard({super.key});
  @override
  State<CreationWizard> createState() => _CreationWizardState();
}

class _CreationWizardState extends State<CreationWizard> {
  late CharacterController ctl;
  int step = 0;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final c = Character(
      allowedBooks: app.settings.defaultBooks == null ? null : {...app.settings.defaultBooks!},
      versionPolicy: app.settings.defaultVersionPolicy,
      hpMethod: app.settings.hpMethod,
      pointBuyBudget: app.settings.pointBuy,
      baseAbilities: {for (final a in abilityIds) a: 8},
    );
    ctl = CharacterController(app, c, autosave: false);
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      (tr('Fontes', 'Sources'), Icons.library_books_outlined),
      (tr('Raça', 'Race'), Icons.face_outlined),
      (tr('Atributos', 'Abilities'), Icons.fitness_center),
      (tr('Classes e níveis', 'Classes & levels'), Icons.stairs_outlined),
      (tr('Talentos', 'Feats'), Icons.star_outline),
      (tr('Magias', 'Spells'), Icons.auto_awesome_outlined),
      (tr('Equipamento', 'Equipment'), Icons.backpack_outlined),
      (tr('Detalhes', 'Details'), Icons.edit_note),
      (tr('Revisão', 'Review'), Icons.fact_check_outlined),
    ];
    Widget body;
    switch (step) {
      case 0:
        body = const _SourcesStep();
        break;
      case 1:
        body = const _RaceStep();
        break;
      case 2:
        body = const _AbilitiesStep();
        break;
      case 3:
        body = const LevelsTab();
        break;
      case 4:
        body = const FeatsTab();
        break;
      case 5:
        body = const SpellsTab();
        break;
      case 6:
        body = const _EquipmentStep();
        break;
      case 7:
        body = Consumer<CharacterController>(
            builder: (_, c, __) => ListView(padding: const EdgeInsets.all(12), children: [
                  IdentityFields(ch: c.ch, update: (fn) => c.update(fn)),
                ]));
        break;
      default:
        body = const SummaryTab();
    }
    return ChangeNotifierProvider.value(
      value: ctl,
      child: Consumer<CharacterController>(builder: (context, c, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('Assistente de criação', 'Creation wizard')),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  for (var i = 0; i < steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 6),
                      child: ChoiceChip(
                        avatar: Icon(steps[i].$2, size: 16),
                        label: Text('${i + 1}. ${steps[i].$1}'),
                        selected: step == i,
                        onSelected: (_) => setState(() => step = i),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          body: body,
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                if (step > 0) OutlinedButton.icon(onPressed: () => setState(() => step--), icon: const Icon(Icons.arrow_back), label: Text(tr('Voltar', 'Back'))),
                const Spacer(),
                Text('${c.sheet.characterLevel > 0 ? '${tr('Nível', 'Level')} ${c.sheet.characterLevel} · ' : ''}'
                    '${c.sheet.warnings.length} ${tr('aviso(s)', 'warning(s)')}'),
                const SizedBox(width: 12),
                if (step < steps.length - 1)
                  FilledButton.icon(onPressed: () => setState(() => step++), icon: const Icon(Icons.arrow_forward), label: Text(tr('Próximo', 'Next')))
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(tr('Concluir', 'Finish')),
                    onPressed: () async {
                      if (c.ch.name.trim().isEmpty) {
                        final n = await promptText(context, tr('Nome do personagem', 'Character name'));
                        if (n == null || n.trim().isEmpty) return;
                        c.ch.name = n.trim();
                      }
                      if (c.sheet.warnings.isNotEmpty && context.mounted) {
                        final ok = await confirm(context, tr('Há ${c.sheet.warnings.length} aviso(s). Concluir mesmo assim?',
                            'There are ${c.sheet.warnings.length} warning(s). Finish anyway?'));
                        if (!ok) return;
                      }
                      if (context.mounted) Navigator.pop(context, c.ch);
                    },
                  ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

class _SourcesStep extends StatelessWidget {
  const _SourcesStep();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    return ListView(padding: const EdgeInsets.all(12), children: [
      TextFormField(
        initialValue: c.ch.name,
        decoration: InputDecoration(labelText: tr('Nome do personagem', 'Character name')),
        onChanged: (v) => c.update((x) => x.name = v),
      ),
      const SizedBox(height: 16),
      Text(tr('Quais livros esta ficha pode usar?', 'Which books may this character use?'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      BooksSelector(
        selected: c.ch.allowedBooks,
        policy: c.ch.versionPolicy,
        onChanged: (b, p) => c.update((x) {
          x.allowedBooks = b;
          x.versionPolicy = p;
        }),
      ),
      const SizedBox(height: 16),
      Text(
          tr('Quando um item existir em mais de um livro permitido, o app vai perguntar qual versão usar — ou escolher sozinho a mais recente, se você preferir.',
              'When an item exists in more than one allowed book, the app asks which version to use — or picks the most recent automatically.'),
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _RaceStep extends StatelessWidget {
  const _RaceStep();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final app = c.app;
    final books = c.ch.allowedBooks;
    final structured = <RaceDef>[
      for (final l in app.rules.races.values)
        for (final r in l)
          if (books == null || books.contains(r.book)) r,
    ]..sort((a, b) => a.displayName(Lang.isPt).compareTo(b.displayName(Lang.isPt)));
    final race = c.sheet.race;
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (race != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle),
            title: Text('${race.displayName(Lang.isPt)} (${race.sourceLabel})'),
            subtitle: Text([
              Lang.isPt ? (app.rules.size(race.size).namePt) : race.size,
              '${race.speed}′',
              if (race.abilityAdj.isNotEmpty) race.abilityAdj.entries.map((e) => '${abilityAbbr(e.key)} ${sgn(e.value)}').join(' '),
              if (race.la > 0) 'LA +${race.la}',
              if (race.favoredClass != 'any') '${tr('favorecida', 'favored')}: ${race.favoredClass}',
              ...race.features,
            ].join(' · ')),
          ),
        ),
      SectionTitle(tr('Raças com regras completas', 'Races with full rules')),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final r in structured)
          ChoiceChip(
            label: Text('${r.displayName(Lang.isPt)} (${r.book})'),
            selected: c.ch.raceId == r.id && (c.ch.raceBook ?? r.book) == r.book,
            onSelected: (_) => c.update((x) {
              x.raceId = r.id;
              x.raceBook = r.book;
            }),
          ),
      ]),
      SectionTitle(tr('Outras raças da biblioteca', 'Other races from the library')),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.search),
          label: Text(tr('Procurar raça nos livros…', 'Search race in books…')),
          onPressed: () async {
            final e = await pickEntry(context, title: tr('Raça', 'Race'), kinds: {'race'}, books: books);
            if (e == null || !context.mounted) return;
            var pick = e;
            final versions = app.library.versionsOf('race', e.name, books: books);
            if (versions.length > 1) {
              final v = await chooseVersion(context, versions, policy: c.ch.versionPolicy);
              if (v == null) return;
              pick = v;
              c.ch.versionChoices[pick.key] = pick.book;
            }
            final id = slugify(pick.name);
            final existing = app.rules.pick(app.rules.races, id, book: pick.book);
            if (existing != null && existing.book == pick.book) {
              c.update((x) {
                x.raceId = id;
                x.raceBook = pick.book;
              });
              return;
            }
            if (!context.mounted) return;
            final def = await showDialog<RaceDef>(context: context, builder: (_) => _RaceConfigDialog(entry: pick));
            if (def == null) return;
            c.update((x) {
              x.raceId = def.id;
              x.raceBook = null;
              x.embeddedDefs['race:${def.id}'] = jsonEncode(def.toJson());
            });
          },
        ),
      ),
    ]);
  }
}

class _RaceConfigDialog extends StatefulWidget {
  final LibEntry entry;
  const _RaceConfigDialog({required this.entry});
  @override
  State<_RaceConfigDialog> createState() => _RaceConfigDialogState();
}

class _RaceConfigDialogState extends State<_RaceConfigDialog> {
  String size = 'medium';
  int speed = 30, la = 0;
  final adj = <String, int>{for (final a in abilityIds) a: 0};
  final feats = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return AlertDialog(
      title: Text('${widget.entry.name} (${widget.entry.sourceLabel})'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.entry.summary.isNotEmpty) Text(widget.entry.summary),
            Text(tr('Informe os traços mecânicos da raça (veja a página indicada).', 'Enter the race mechanical traits (see the page shown).'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              DropdownButton<String>(
                value: size,
                items: [for (final s in app.rules.sizeOrder) DropdownMenuItem(value: s, child: Text(Lang.isPt ? app.rules.size(s).namePt : s))],
                onChanged: (v) => setState(() => size = v ?? 'medium'),
              ),
              Text(tr('Deslocamento', 'Speed')),
              NumStepper(value: speed, min: 0, max: 120, step: 5, onChanged: (v) => setState(() => speed = v.toInt())),
              const Text('LA'),
              NumStepper(value: la, min: 0, max: 20, onChanged: (v) => setState(() => la = v.toInt())),
            ]),
            for (final a in abilityIds)
              Row(children: [
                SizedBox(width: 130, child: Text(abilityName(a))),
                NumStepper(value: adj[a]!, min: -10, max: 20, onChanged: (v) => setState(() => adj[a] = v.toInt())),
              ]),
            TextField(controller: feats, decoration: InputDecoration(labelText: tr('Traços (texto, separados por ;)', 'Traits (text, separated by ;)'))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar', 'Cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              RaceDef(
                id: slugify(widget.entry.name),
                name: widget.entry.name,
                book: widget.entry.book,
                page: widget.entry.page,
                size: size,
                speed: speed,
                la: la,
                abilityAdj: {for (final e in adj.entries) if (e.value != 0) e.key: e.value},
                features: feats.text.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
              )),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _AbilitiesStep extends StatelessWidget {
  const _AbilitiesStep();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final ch = c.ch;
    final rules = c.app.rules;
    final s = c.sheet;
    int cost(int v) => rules.pointBuy[v] ?? (v < 8 ? -(8 - v) : 99);
    final spent = abilityIds.fold<int>(0, (a, k) => a + cost(ch.baseAbilities[k] ?? 8));
    return ListView(padding: const EdgeInsets.all(12), children: [
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'pointbuy', label: Text(tr('Compra de pontos', 'Point buy'))),
          ButtonSegment(value: 'array', label: Text(tr('Valores padrão', 'Standard array'))),
          ButtonSegment(value: 'roll', label: Text(tr('Rolar 4d6', 'Roll 4d6'))),
          ButtonSegment(value: 'manual', label: Text(tr('Manual', 'Manual'))),
        ],
        selected: {ch.abilityMethod},
        onSelectionChanged: (v) => c.update((x) {
          x.abilityMethod = v.first;
          if (v.first == 'pointbuy') {
            for (final a in abilityIds) {
              x.baseAbilities[a] = 8;
            }
          } else if (v.first == 'array') {
            for (var i = 0; i < 6; i++) {
              x.baseAbilities[abilityIds[i]] = rules.eliteArray[i];
            }
          }
        }),
      ),
      const SizedBox(height: 12),
      if (ch.abilityMethod == 'pointbuy')
        Row(children: [
          Text('${tr('Pontos', 'Points')}: $spent / '),
          NumStepper(value: ch.pointBuyBudget, min: 0, max: 100, onChanged: (v) => c.update((x) => x.pointBuyBudget = v.toInt())),
          Text(tr('  (25 baixo · 28 padrão · 32 heroico)', '  (25 low · 28 standard · 32 heroic)'), style: Theme.of(context).textTheme.bodySmall),
        ]),
      if (ch.abilityMethod == 'roll')
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.casino),
            label: Text(tr('Rolar 6× 4d6 (descarta o menor)', 'Roll 6× 4d6 drop lowest')),
            onPressed: () {
              final vals = c.app.dice.rollAbilityArray()..sort((a, b) => b.compareTo(a));
              c.update((x) {
                for (var i = 0; i < 6; i++) {
                  x.baseAbilities[abilityIds[i]] = vals[i];
                }
              });
              toast(context, '${tr('Resultados', 'Results')}: ${vals.join(', ')} — ${tr('use as setas para trocar', 'use arrows to swap')}');
            },
          ),
        ),
      const SizedBox(height: 8),
      for (var i = 0; i < 6; i++)
        Card(
          child: ListTile(
            title: Text(abilityName(abilityIds[i])),
            subtitle: Text([
              '${tr('base', 'base')} ${ch.baseAbilities[abilityIds[i]]}',
              if ((s.race?.abilityAdj[abilityIds[i]] ?? 0) != 0) '${tr('racial', 'racial')} ${sgn(s.race!.abilityAdj[abilityIds[i]]!)}',
              '= ${s.abilities[abilityIds[i]]!.total} (${sgn(s.abilities[abilityIds[i]]!.mod)})',
              if (ch.abilityMethod == 'pointbuy') '${tr('custo', 'cost')} ${cost(ch.baseAbilities[abilityIds[i]] ?? 8)}',
            ].join(' · ')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (ch.abilityMethod == 'array' || ch.abilityMethod == 'roll') ...[
                IconButton(
                  tooltip: tr('Trocar com o de cima', 'Swap with above'),
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0
                      ? null
                      : () => c.update((x) {
                            final a = abilityIds[i], b = abilityIds[i - 1];
                            final t = x.baseAbilities[a]!;
                            x.baseAbilities[a] = x.baseAbilities[b]!;
                            x.baseAbilities[b] = t;
                          }),
                ),
                IconButton(
                  tooltip: tr('Trocar com o de baixo', 'Swap with below'),
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == 5
                      ? null
                      : () => c.update((x) {
                            final a = abilityIds[i], b = abilityIds[i + 1];
                            final t = x.baseAbilities[a]!;
                            x.baseAbilities[a] = x.baseAbilities[b]!;
                            x.baseAbilities[b] = t;
                          }),
                ),
              ] else
                NumStepper(
                  value: ch.baseAbilities[abilityIds[i]] ?? 8,
                  min: ch.abilityMethod == 'pointbuy' ? 8 : 1,
                  max: ch.abilityMethod == 'pointbuy' ? 18 : 60,
                  onChanged: (v) => c.update((x) => x.baseAbilities[abilityIds[i]] = v.toInt()),
                ),
            ]),
          ),
        ),
      if (ch.abilityMethod == 'pointbuy' && spent > ch.pointBuyBudget)
        Text(tr('Pontos acima do orçamento!', 'Over budget!'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 8),
      Text(
          tr('Aumentos de atributo dos níveis 4, 8, 12… são escolhidos na etapa de níveis. Itens e magias que aumentam atributos entram depois, como efeitos.',
              'Ability increases at levels 4, 8, 12… are chosen in the levels step. Items and spells that raise abilities are added later as effects.'),
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _EquipmentStep extends StatelessWidget {
  const _EquipmentStep();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final s = c.sheet;
    final lvl = s.characterLevel;
    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (lvl <= 1) ...[
              Text(tr('Dinheiro inicial da classe', 'Class starting gold')),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.casino),
                label: Text(s.classDefs.values.isEmpty ? '—' : (s.classDefs.values.first.startingGold ?? '—')),
                onPressed: () {
                  final g = s.classDefs.values.isEmpty ? null : s.classDefs.values.first.startingGold;
                  if (g == null) return;
                  final parts = g.split('*');
                  var total = c.app.dice.roll(parts.first).total;
                  if (parts.length > 1) total *= int.tryParse(parts[1]) ?? 1;
                  c.update((x) => x.money['gp'] = total, save: false);
                  toast(context, '$total po');
                },
              ),
            ] else ...[
              Text('${tr('Riqueza por nível (DMG)', 'Wealth by level (DMG)')}: ${c.app.rules.wealthFor(lvl)} po'
                  '${lvl > 20 ? tr(' (épico: estimativa ×1,3/nível)', ' (epic: estimate ×1.3/level)') : ''}'),
              OutlinedButton(
                onPressed: () => c.update((x) => x.money['gp'] = c.app.rules.wealthFor(lvl), save: false),
                child: Text(tr('Usar como orçamento', 'Use as budget')),
              ),
            ],
          ]),
        ),
      ),
      const Expanded(child: InventoryTab()),
    ]);
  }
}
