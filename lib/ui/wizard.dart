import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../engine/bonus.dart';
import '../engine/defs.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'books_selector.dart';
import 'effect_editor.dart';
import 'homebrew_inline.dart';
import 'portrait.dart';
import 'tab_feats.dart';
import 'tab_inventory.dart';
import 'tab_levels.dart';
import 'tab_notes.dart';
import 'tab_spells.dart';
import 'tab_summary.dart';
import 'help.dart';
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
      (tr('Fontes', 'Sources'), Icons.library_books_outlined, tr('Nome e livros que a ficha pode usar.', 'Name and books the character may use.')),
      (tr('Raça', 'Race'), Icons.face_outlined, tr('Escolha a raça (ou crie uma homebrew).', 'Choose the race (or create a homebrew one).')),
      (tr('Atributos', 'Abilities'), Icons.fitness_center, tr('Valores de Força, Destreza, Constituição, Inteligência, Sabedoria e Carisma.', 'Ability scores.')),
      (tr('Classes e níveis', 'Classes & levels'), Icons.stairs_outlined, tr('Adicione níveis de classe; o XP acompanha o nível.', 'Add class levels; XP follows the level.')),
      (tr('Talentos', 'Feats'), Icons.star_outline, tr('Talentos de cada nível.', 'Feats per level.')),
      (tr('Magias', 'Spells'), Icons.auto_awesome_outlined, tr('Magias conhecidas e preparadas das classes conjuradoras.', 'Known and prepared spells.')),
      (tr('Equipamento', 'Equipment'), Icons.backpack_outlined, tr('Armas, armaduras, itens e dinheiro.', 'Weapons, armor, items and money.')),
      (tr('Detalhes', 'Details'), Icons.edit_note, tr('Retrato, tendência, divindade e aparência.', 'Portrait, alignment, deity and looks.')),
      (tr('Revisão', 'Review'), Icons.fact_check_outlined, tr('Ficha completa e avisos pendentes.', 'Full sheet and pending warnings.')),
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
                  Wrap(spacing: 16, runSpacing: 12, children: [
                    PortraitField(portrait: c.ch.portrait, onChanged: (v) => c.update((x) => x.portrait = v)),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: IdentityFields(ch: c.ch, update: (fn) => c.update(fn)),
                    ),
                  ]),
                ]));
        break;
      default:
        body = Consumer<CharacterController>(
          builder: (_, c, __) => Column(children: [
            if (c.sheet.warnings.isNotEmpty)
              Card(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                color: Theme.of(context).colorScheme.errorContainer,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.onErrorContainer),
                  title: Text('${c.sheet.warnings.length} ${tr('aviso(s) antes de concluir', 'warning(s) before finishing')}'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final w in c.sheet.warnings) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $w'))],
                ),
              ),
            const Expanded(child: SummaryTab()),
          ]),
        );
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
                      child: Tooltip(
                        message: steps[i].$3,
                        child: ChoiceChip(
                          avatar: Icon(steps[i].$2, size: 16),
                          label: Text('${i + 1}. ${steps[i].$1}'),
                          selected: step == i,
                          onSelected: (_) => setState(() => step = i),
                        ),
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
                if (step > 0) withHelp(tr('Voltar', 'Back'), OutlinedButton.icon(onPressed: () => setState(() => step--), icon: const Icon(Icons.arrow_back), label: Text(tr('Voltar', 'Back')))),
                const Spacer(),
                if (c.sheet.characterLevel > 0) Text('${tr('Nível', 'Level')} ${c.sheet.characterLevel} · '),
                Tooltip(
                  message: c.sheet.warnings.isEmpty ? tr('Nenhum aviso.', 'No warnings.') : c.sheet.warnings.map((w) => '• $w').join('\n'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: InkWell(
                    onTap: c.sheet.warnings.isEmpty ? null : () => showWarnings(context, c.sheet.warnings),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(c.sheet.warnings.isEmpty ? Icons.check_circle_outline : Icons.warning_amber,
                          size: 18, color: c.sheet.warnings.isEmpty ? null : Theme.of(context).colorScheme.error),
                      const SizedBox(width: 4),
                      Text('${c.sheet.warnings.length} ${tr('aviso(s)', 'warning(s)')}',
                          style: TextStyle(decoration: c.sheet.warnings.isEmpty ? null : TextDecoration.underline)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                if (step < steps.length - 1)
                  withHelp(tr('Próximo', 'Next'), FilledButton.icon(onPressed: () => setState(() => step++), icon: const Icon(Icons.arrow_forward), label: Text(tr('Próximo', 'Next'))))
                else
                  withHelp(tr('Concluir', 'Finish'), FilledButton.icon(
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
                  )),
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
      Tooltip(
        message: tr('Nome que aparece na lista de fichas e na impressão. Pode ser mudado depois.', 'Name shown in the list and print-out. Can be changed later.'),
        child: TextFormField(
          initialValue: c.ch.name,
          decoration: InputDecoration(labelText: tr('Nome do personagem', 'Character name')),
          onChanged: (v) => c.update((x) => x.name = v),
        ),
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
          Tooltip(
            message: raceTraitsText(app, r),
            waitDuration: const Duration(milliseconds: 300),
            child: ChoiceChip(
              label: Text('${r.displayName(Lang.isPt)} (${r.book})'),
              selected: c.ch.raceId == r.id && (c.ch.raceBook ?? r.book) == r.book,
              onSelected: (_) => c.update((x) {
                x.raceId = r.id;
                x.raceBook = r.book;
              }),
            ),
          ),
      ]),
      SectionTitle(tr('Outras raças da biblioteca', 'Other races from the library')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Tooltip(
          message: tr('Procura raças citadas nos livros escolhidos. Se a raça não tiver regras completas na base, você escolhe em qual raça ela se baseia e ajusta as diferenças.',
              'Searches races mentioned in the chosen books. If the race has no full rules, pick which race it is based on and adjust the differences.'),
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
        HomebrewCreateButton(
          label: tr('Criar raça homebrew…', 'Create homebrew race…'),
          onPressed: () async {
            final e = await createHomebrewInline(context, c, 'race', data: race == null ? null : (race.toJson()..remove('id')..remove('book')..remove('page')..remove('name')..remove('name_pt')));
            if (e == null) return;
            c.update((x) {
              x.raceId = slugify(e.name);
              x.raceBook = e.book;
            });
          },
        ),
      ]),
    ]);
  }
}

Future<void> showWarnings(BuildContext context, List<String> warnings) => showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Avisos', 'Warnings')),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.warning_amber, size: 16, color: Theme.of(d).colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(child: Text(w)),
                  ]),
                ),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
      ),
    );

/// O que cada atributo afeta (dica ao passar o mouse).
String abilityHelp(String a) => switch (a) {
      'str' => tr('Força: ataque e dano corpo a corpo, carga, Escalar, Saltar, Natação.', 'Strength: melee attack and damage, load, Climb, Jump, Swim.'),
      'dex' => tr('Destreza: CA, ataque à distância, Reflexos, iniciativa, perícias de agilidade.', 'Dexterity: AC, ranged attack, Reflex, initiative, agility skills.'),
      'con' => tr('Constituição: pontos de vida por nível e Fortitude.', 'Constitution: hit points per level and Fortitude.'),
      'int' => tr('Inteligência: pontos de perícia por nível, idiomas e magias de mago.', 'Intelligence: skill points, languages and wizard spells.'),
      'wis' => tr('Sabedoria: Vontade, Observar, Ouvir e magias divinas (clérigo, druida…).', 'Wisdom: Will, Spot, Listen and divine spells.'),
      _ => tr('Carisma: perícias sociais, expulsar mortos-vivos e magias de feiticeiro/bardo.', 'Charisma: social skills, turning and sorcerer/bard spells.'),
    };

/// Texto com os traços de uma raça (dica ao passar o mouse).
String raceTraitsText(AppState app, RaceDef r) => [
      Lang.isPt ? app.rules.size(r.size).namePt : r.size,
      '${tr('Deslocamento', 'Speed')} ${r.speed}′',
      if (r.abilityAdj.isNotEmpty) r.abilityAdj.entries.map((e) => '${abilityAbbr(e.key)} ${sgn(e.value)}').join(', '),
      if (r.la > 0) 'LA +${r.la}',
      if (r.favoredClass != 'any') '${tr('Classe favorecida', 'Favored class')}: ${app.rules.classById(r.favoredClass)?.displayName(Lang.isPt) ?? r.favoredClass}',
      if (r.vision.isNotEmpty) r.vision,
      for (final e in r.effects) describeEffect(e),
      ...r.features,
    ].join('\n');

/// Raça do Livro do Jogador em que uma raça sem regras provavelmente se baseia.
RaceDef? guessBaseRace(AppState app, String name) {
  final n = name.toLowerCase();
  String? id;
  const map = [
    (['half-elf', 'half elf', 'meio-elf', 'meio elf'], 'half-elf'),
    (['half-orc', 'half orc', 'meio-orc', 'meio orc'], 'half-orc'),
    (['halfling', 'hin', 'kender'], 'halfling'),
    (['gnome', 'gnomo', 'svirfneblin'], 'gnome'),
    (['dwarf', 'dwarves', 'anão', 'anões', 'anao', 'duergar'], 'dwarf'),
    (['elf', 'elves', 'elfo', 'elfa', 'drow', 'eladrin'], 'elf'),
    (['human', 'humano', 'humana'], 'human'),
  ];
  for (final m in map) {
    if (m.$1.any(n.contains)) {
      id = m.$2;
      break;
    }
  }
  if (id == null) return null;
  return app.rules.pick(app.rules.races, id, book: 'PH');
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
  String favored = 'any', vision = '', languages = '', type = 'humanoid';
  List<Effect> effects = const [];
  int bonusFeats = 0, bonusSkill = 0;
  RaceDef? base;
  final adj = <String, int>{for (final a in abilityIds) a: 0};
  final feats = TextEditingController();

  @override
  void initState() {
    super.initState();
    final g = guessBaseRace(context.read<AppState>(), widget.entry.name);
    if (g != null) _apply(g);
  }

  void _apply(RaceDef? r) {
    base = r;
    if (r == null) return;
    size = r.size;
    speed = r.speed;
    la = r.la;
    favored = r.favoredClass;
    vision = r.vision;
    languages = r.languages;
    type = r.type;
    effects = List.of(r.effects);
    bonusFeats = r.bonusFeats;
    bonusSkill = r.bonusSkillPoints;
    for (final a in abilityIds) {
      adj[a] = r.abilityAdj[a] ?? 0;
    }
    feats.text = r.features.join('; ');
  }

  Widget _tip(String msg, Widget child) => Tooltip(message: msg, waitDuration: const Duration(milliseconds: 400), child: child);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final all = [for (final l in app.rules.races.values) ...l]..sort((a, b) => a.displayName(Lang.isPt).compareTo(b.displayName(Lang.isPt)));
    return AlertDialog(
      title: Text('${widget.entry.label} (${widget.entry.sourceLabel})'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.entry.shownSummary.isNotEmpty) Text(widget.entry.shownSummary),
            Text(
                tr('Esta raça não tem regras completas na base. Escolha em qual raça ela se baseia: as regras são copiadas e você ajusta só o que o livro altera (veja a página indicada).',
                    'This race has no full rules in the database. Pick the race it is based on: its rules are copied and you adjust only what the book changes (see the page shown).'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _tip(
              tr('Raça de origem cujas regras são copiadas (tamanho, deslocamento, ajustes, bônus raciais e traços).',
                  'Source race whose rules are copied (size, speed, adjustments, racial bonuses and traits).'),
              DropdownButton<RaceDef?>(
                value: base,
                hint: Text(tr('Baseada em…', 'Based on…')),
                items: [
                  DropdownMenuItem(value: null, child: Text(tr('(nenhuma — preencher do zero)', '(none — fill from scratch)'))),
                  for (final r in all) DropdownMenuItem(value: r, child: Text('${tr('Baseada em', 'Based on')} ${r.displayName(Lang.isPt)} (${r.book})')),
                ],
                onChanged: (v) => setState(() {
                  if (v == null) {
                    base = null;
                    effects = const [];
                  } else {
                    _apply(v);
                  }
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text(tr('Tamanho, deslocamento e ajuste de nível', 'Size, speed and level adjustment'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _tip(
                tr('Categoria de tamanho: altera CA, ataque, Esconder-se e carga.', 'Size category: changes AC, attack, Hide and load.'),
                DropdownButton<String>(
                  value: size,
                  items: [for (final s in app.rules.sizeOrder) DropdownMenuItem(value: s, child: Text(Lang.isPt ? app.rules.size(s).namePt : s))],
                  onChanged: (v) => setState(() => size = v ?? 'medium'),
                ),
              ),
              _tip(tr('Deslocamento terrestre básico em pés (30 pés = 9 m).', 'Base land speed in feet.'), Text(tr('Deslocamento (pés)', 'Speed (ft)'))),
              NumStepper(value: speed, min: 0, max: 120, step: 5, onChanged: (v) => setState(() => speed = v.toInt())),
              _tip(
                  tr('Ajuste de nível (LA/NEP): somado ao nível de personagem para calcular XP, riqueza e o nível efetivo. Raças comuns têm 0; drow +2, nagah de Tormenta +1...',
                      'Level adjustment (LA/ECL): added to character level for XP, wealth and effective level.'),
                  Text(tr('Ajuste de nível (LA)', 'Level adjustment (LA)'))),
              NumStepper(value: la, min: 0, max: 20, onChanged: (v) => setState(() => la = v.toInt())),
            ]),
            const SizedBox(height: 8),
            _tip(
              tr('Ajustes raciais de atributo (ex.: elfo +2 Des, −2 Con). Use + ou − em cada atributo.', 'Racial ability adjustments.'),
              Text(tr('Ajustes de atributo (bônus de habilidade)', 'Ability adjustments'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Wrap(spacing: 16, runSpacing: 4, children: [
              for (final a in abilityIds)
                SizedBox(
                  width: 250,
                  child: Row(children: [
                    SizedBox(width: 110, child: _tip(tr('Ajuste racial de ${abilityName(a)}.', 'Racial ${abilityName(a)} adjustment.'), Text(abilityName(a)))),
                    NumStepper(value: adj[a]!, min: -10, max: 20, format: (v) => sgn(v.toInt()), onChanged: (v) => setState(() => adj[a] = v.toInt())),
                  ]),
                ),
            ]),
            const SizedBox(height: 8),
            Text(tr('Outros traços numéricos', 'Other numeric traits'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _tip(tr('Talentos adicionais no 1º nível (humano: 1).', 'Extra feats at 1st level (human: 1).'), Text(tr('Talentos extras no 1º', 'Bonus feats at 1st'))),
              NumStepper(value: bonusFeats, min: 0, max: 5, onChanged: (v) => setState(() => bonusFeats = v.toInt())),
              _tip(tr('Pontos de perícia extras por nível (×4 no 1º). Humano: 1.', 'Extra skill points per level (×4 at 1st).'), Text(tr('Perícias extras/nível', 'Bonus skill pts/level'))),
              NumStepper(value: bonusSkill, min: 0, max: 10, onChanged: (v) => setState(() => bonusSkill = v.toInt())),
              _tip(
                tr('Classe ignorada na penalidade de XP por multiclasse ("qualquer" = a classe mais alta).', 'Class ignored for multiclass XP penalty.'),
                DropdownButton<String>(
                  value: favored == 'any' || app.rules.classById(favored) != null ? favored : 'any',
                  items: [
                    DropdownMenuItem(value: 'any', child: Text(tr('Classe favorecida: qualquer', 'Favored class: any'))),
                    for (final cl in {for (final l in app.rules.classes.values) l.first.id: l.first}.values.where((x) => !x.prestige))
                      DropdownMenuItem(value: cl.id, child: Text('${tr('Classe favorecida', 'Favored class')}: ${cl.displayName(Lang.isPt)}')),
                  ],
                  onChanged: (v) => setState(() => favored = v ?? 'any'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            _tip(
              tr('Bônus raciais calculados na ficha: perícias (ex.: +2 em Ouvir), resistências (ex.: +2 contra veneno), CA natural, ataque... Remova os que o livro tirou e adicione os novos.',
                  'Racial bonuses applied to the sheet: skills, saves, natural AC, attack... Remove the ones the book removed and add new ones.'),
              Text(tr('Bônus raciais (perícias, resistências, CA...)', 'Racial bonuses (skills, saves, AC...)'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            EffectListEditor(
              effects: effects,
              skillIds: app.rules.skills.keys.toList(),
              onChanged: (l) => setState(() => effects = l),
            ),
            const SizedBox(height: 8),
            _tip(
              tr('Traços sem cálculo automático (visão, imunidades, armas naturais...). Separe por ponto e vírgula.',
                  'Traits without automatic calculation. Separate with semicolons.'),
              withHelp(tr('Traços (texto, separados por ;)', 'Traits (text, separated by ;)'), TextField(controller: feats, maxLines: 3, decoration: InputDecoration(labelText: tr('Traços (texto, separados por ;)', 'Traits (text, separated by ;)')))),
            ),
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
                namePt: widget.entry.namePt,
                book: widget.entry.book,
                page: widget.entry.page,
                size: size,
                speed: speed,
                la: la,
                favoredClass: favored,
                vision: vision,
                languages: languages,
                type: type,
                bonusFeats: bonusFeats,
                bonusSkillPoints: bonusSkill,
                effects: effects,
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

  /// Valores do conjunto (padrão ou rolados) em ordem decrescente.
  static List<int> _pool(Character ch) =>
      [for (final a in abilityIds) ch.baseAbilities[a] ?? 8]..sort((a, b) => b.compareTo(a));

  /// Ordem atual dos atributos: do maior valor para o menor (estável pela ordem padrão).
  static List<String> _order(Character ch) {
    final ids = List.of(abilityIds);
    ids.sort((a, b) {
      final c = (ch.baseAbilities[b] ?? 8).compareTo(ch.baseAbilities[a] ?? 8);
      return c != 0 ? c : abilityIds.indexOf(a).compareTo(abilityIds.indexOf(b));
    });
    return ids;
  }

  /// Reatribui os valores: o atributo no topo recebe o maior valor, o do fundo o menor.
  static void _assign(Character x, List<String> order, List<int> pool) {
    for (var i = 0; i < order.length; i++) {
      x.baseAbilities[order[i]] = pool[i];
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final ch = c.ch;
    final rules = c.app.rules;
    final s = c.sheet;
    int cost(int v) => rules.pointBuy[v] ?? (v < 8 ? -(8 - v) : 99);
    final spent = abilityIds.fold<int>(0, (a, k) => a + cost(ch.baseAbilities[k] ?? 8));
    final ordered = ch.abilityMethod == 'array' || ch.abilityMethod == 'roll';

    Widget subtitle(String a) => Text([
          if ((s.race?.abilityAdj[a] ?? 0) != 0) '${tr('racial', 'racial')} ${sgn(s.race!.abilityAdj[a]!)}',
          '${tr('total', 'total')} ${s.abilities[a]!.total} (${sgn(s.abilities[a]!.mod)})',
          if (ch.abilityMethod == 'pointbuy') '${tr('custo', 'cost')} ${cost(ch.baseAbilities[a] ?? 8)}',
        ].join(' · '));

    final header = <Widget>[
      SegmentedButton<String>(
        segments: [
          ButtonSegment(
              value: 'pointbuy',
              label: Text(tr('Compra de pontos', 'Point buy')),
              tooltip: tr('Todos começam em 8; cada aumento custa pontos do orçamento (DMG p. 169).', 'All start at 8; raises cost budget points.')),
          ButtonSegment(
              value: 'array',
              label: Text(tr('Valores padrão', 'Standard array')),
              tooltip: tr('Conjunto fixo 15, 14, 13, 12, 10, 8: ordene os atributos arrastando.', 'Fixed set 15, 14, 13, 12, 10, 8: drag to order.')),
          ButtonSegment(
              value: 'roll',
              label: Text(tr('Rolar 4d6', 'Roll 4d6')),
              tooltip: tr('Rola 4d6 seis vezes descartando o menor dado; depois ordene os atributos.', 'Roll 4d6 six times dropping the lowest; then order.')),
          ButtonSegment(
              value: 'manual',
              label: Text(tr('Manual', 'Manual')),
              tooltip: tr('Digite qualquer valor (para fichas já existentes).', 'Type any value (for existing characters).')),
        ],
        selected: {ch.abilityMethod},
        onSelectionChanged: (v) => c.update((x) {
          final order = _order(x);
          x.abilityMethod = v.first;
          if (v.first == 'pointbuy') {
            for (final a in abilityIds) {
              x.baseAbilities[a] = 8;
            }
          } else if (v.first == 'array') {
            final pool = List.of(rules.eliteArray)..sort((a, b) => b.compareTo(a));
            _assign(x, order, pool);
          }
        }),
      ),
      const SizedBox(height: 12),
      if (ch.abilityMethod == 'pointbuy')
        Row(children: [
          Tooltip(
              message: tr('Pontos gastos / orçamento. Custos: 9=1, 10=2, 11=3, 12=4, 13=5, 14=6, 15=8, 16=10, 17=13, 18=16.', 'Spent / budget.'),
              child: Text('${tr('Pontos', 'Points')}: $spent / ')),
          NumStepper(value: ch.pointBuyBudget, min: 0, max: 100, onChanged: (v) => c.update((x) => x.pointBuyBudget = v.toInt())),
          Text(tr('  (25 baixo · 28 padrão · 32 heroico)', '  (25 low · 28 standard · 32 heroic)'), style: Theme.of(context).textTheme.bodySmall),
        ]),
      if (ch.abilityMethod == 'roll')
        Align(
          alignment: Alignment.centerLeft,
          child: withHelp(tr('Rolar 6× 4d6 (descarta o menor)', 'Roll 6× 4d6 drop lowest'), FilledButton.tonalIcon(
            icon: const Icon(Icons.casino),
            label: Text(tr('Rolar 6× 4d6 (descarta o menor)', 'Roll 6× 4d6 drop lowest')),
            onPressed: () {
              final vals = c.app.dice.rollAbilityArray()..sort((a, b) => b.compareTo(a));
              c.update((x) => _assign(x, _order(x), vals));
              toast(context, '${tr('Resultados', 'Results')}: ${vals.join(', ')}');
            },
          )),
        ),
      if (ordered)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
              tr('Arraste os atributos para ordená-los. O do topo recebe o maior valor (${_pool(ch).first}) e o do fundo o menor (${_pool(ch).last}).',
                  'Drag abilities to order them. The top one gets the highest value (${_pool(ch).first}), the bottom one the lowest (${_pool(ch).last}).'),
              style: Theme.of(context).textTheme.bodyMedium),
        ),
    ];

    final footer = <Widget>[
      if (ch.abilityMethod == 'pointbuy' && spent > ch.pointBuyBudget)
        Text(tr('Pontos acima do orçamento!', 'Over budget!'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 8),
      Text(
          tr('Aumentos de atributo dos níveis 4, 8, 12… são escolhidos na etapa de níveis. Itens e magias que aumentam atributos entram depois, como efeitos.',
              'Ability increases at levels 4, 8, 12… are chosen in the levels step. Items and spells that raise abilities are added later as effects.'),
          style: Theme.of(context).textTheme.bodySmall),
    ];

    if (ordered) {
      final order = _order(ch);
      final pool = _pool(ch);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...header,
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // valores fixos por posição
              Column(children: [
                for (final v in pool)
                  Container(
                    height: 64,
                    width: 56,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    alignment: Alignment.center,
                    child: Text('$v', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ),
              ]),
              Expanded(
                child: ReorderableListView(
                  buildDefaultDragHandles: false,
                  onReorder: (from, to) => c.update((x) {
                    final o = _order(x);
                    final item = o.removeAt(from);
                    o.insert(to > from ? to - 1 : to, item);
                    _assign(x, o, _pool(x));
                  }),
                  children: [
                    for (var i = 0; i < order.length; i++)
                      SizedBox(
                        key: ValueKey(order[i]),
                        height: 68,
                        child: Card(
                          child: ReorderableDragStartListener(
                            index: i,
                            child: ListTile(
                              leading: const Icon(Icons.drag_indicator),
                              title: Tooltip(
                                  message: abilityHelp(order[i]),
                                  child: Text(abilityName(order[i]), style: const TextStyle(fontWeight: FontWeight.w600))),
                              subtitle: subtitle(order[i]),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
          ...footer,
        ]),
      );
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      ...header,
      const SizedBox(height: 8),
      for (final a in abilityIds)
        Card(
          child: ListTile(
            title: Tooltip(message: abilityHelp(a), child: Text(abilityName(a))),
            subtitle: subtitle(a),
            trailing: NumStepper(
              value: ch.baseAbilities[a] ?? 8,
              min: ch.abilityMethod == 'pointbuy' ? 8 : 1,
              max: ch.abilityMethod == 'pointbuy' ? 18 : 60,
              onChanged: (v) => c.update((x) => x.baseAbilities[a] = v.toInt()),
            ),
          ),
        ),
      ...footer,
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
