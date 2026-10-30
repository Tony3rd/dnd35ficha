import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../engine/bonus.dart';
import '../engine/defs.dart';
import '../i18n.dart';
import 'effect_editor.dart';
import 'widgets.dart';

class HomebrewScreen extends StatelessWidget {
  const HomebrewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homebrew'),
        actions: [
          IconButton(
            tooltip: tr('Importar livro (.d35book)', 'Import book (.d35book)'),
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              final r = await FilePicker.platform.pickFiles(type: FileType.any);
              final p = r?.files.single.path;
              if (p == null) return;
              try {
                final b = await app.importHomebrew(p);
                if (context.mounted) toast(context, '${tr('Importado', 'Imported')}: ${b.title}');
              } catch (e) {
                if (context.mounted) toast(context, '$e');
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(tr('Novo livro', 'New book')),
        onPressed: () async {
          final b = await _editBookInfo(context, null);
          if (b == null) return;
          if (app.library.book(b.id) != null) {
            if (context.mounted) toast(context, tr('Já existe um livro com a abreviação ${b.id}.', 'A book with abbreviation ${b.id} already exists.'));
            return;
          }
          await app.saveHomebrew(b);
          if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => HomebrewBookScreen(bookId: b.id)));
        },
      ),
      body: app.library.homebrew.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                    tr('Crie livros com suas próprias raças, classes, talentos, magias, itens e regras. Eles funcionam como qualquer livro da base — e são os únicos que podem ser exportados para outros usuários.',
                        'Create books with your own races, classes, feats, spells, items and rules. They work like any other book — and are the only ones that can be exported to other users.'),
                    textAlign: TextAlign.center),
              ),
            )
          : ListView(padding: const EdgeInsets.all(8), children: [
              for (final b in app.library.homebrew)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_fix_high),
                    title: Text('${b.title} (${b.id})'),
                    subtitle: Text('${b.entries.length} ${tr('entradas', 'entries')}${b.author.isNotEmpty ? ' · ${b.author}' : ''} · v${b.version}'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HomebrewBookScreen(bookId: b.id))),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'export') {
                          final out = await FilePicker.platform.saveFile(
                              dialogTitle: tr('Exportar livro', 'Export book'), fileName: '${slugify(b.id)}.$bookExt');
                          if (out != null) {
                            await File(out).writeAsString(b.toXml());
                            if (context.mounted) toast(context, tr('Exportado para $out', 'Exported to $out'));
                          }
                        } else if (v == 'delete') {
                          if (await confirm(context, tr('Apagar o livro "${b.title}" e todo o seu conteúdo?', 'Delete "${b.title}" and all its content?'))) {
                            await app.deleteHomebrew(b);
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'export', child: Text(tr('Exportar (.d35book)', 'Export (.d35book)'))),
                        PopupMenuItem(value: 'delete', child: Text(tr('Apagar', 'Delete'))),
                      ],
                    ),
                  ),
                ),
            ]),
    );
  }
}

Future<HomebrewBook?> _editBookInfo(BuildContext context, HomebrewBook? b) {
  final id = TextEditingController(text: b?.id ?? 'HB');
  final title = TextEditingController(text: b?.title ?? '');
  final author = TextEditingController(text: b?.author ?? '');
  final ver = TextEditingController(text: b?.version ?? '1.0');
  final desc = TextEditingController(text: b?.description ?? '');
  return showDialog<HomebrewBook>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(b == null ? tr('Novo livro homebrew', 'New homebrew book') : tr('Dados do livro', 'Book info')),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: InputDecoration(labelText: tr('Título', 'Title'))),
          TextField(
              controller: id,
              enabled: b == null,
              decoration: InputDecoration(labelText: tr('Abreviação (usada como fonte, ex.: HB-Ana)', 'Abbreviation (used as source, e.g. HB-Ana)'))),
          TextField(controller: author, decoration: InputDecoration(labelText: tr('Autor', 'Author'))),
          TextField(controller: ver, decoration: InputDecoration(labelText: tr('Versão', 'Version'))),
          TextField(controller: desc, maxLines: 3, decoration: InputDecoration(labelText: tr('Descrição', 'Description'))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Cancelar', 'Cancel'))),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isEmpty || id.text.trim().isEmpty) return;
            if (b != null) {
              b
                ..title = title.text.trim()
                ..author = author.text.trim()
                ..version = ver.text.trim()
                ..description = desc.text;
              Navigator.pop(c, b);
            } else {
              Navigator.pop(
                  c,
                  HomebrewBook(
                      id: id.text.trim().replaceAll(' ', '-'),
                      title: title.text.trim(),
                      author: author.text.trim(),
                      version: ver.text.trim(),
                      description: desc.text));
            }
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class HomebrewBookScreen extends StatelessWidget {
  final String bookId;
  const HomebrewBookScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final found = app.library.homebrew.where((b) => b.id == bookId);
    if (found.isEmpty) return Scaffold(appBar: AppBar(), body: const SizedBox());
    final book = found.first;
    final byKind = <String, List<LibEntry>>{};
    for (final e in book.entries) {
      byKind.putIfAbsent(e.kind, () => []).add(e);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              final b = await _editBookInfo(context, book);
              if (b != null) await app.saveHomebrew(b);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(tr('Nova entrada', 'New entry')),
        onPressed: () async {
          final e = await Navigator.of(context).push<LibEntry>(
              MaterialPageRoute<LibEntry>(builder: (_) => EntryEditor(entry: LibEntry(kind: 'feat', name: '', book: book.id, homebrew: true))));
          if (e == null) return;
          book.entries.add(e);
          await app.saveHomebrew(book);
        },
      ),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        if (book.description.isNotEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(book.description)),
        for (final k in byKind.entries) ...[
          SectionTitle('${kindName(k.key)} (${k.value.length})'),
          for (final e in k.value..sort((a, b) => a.name.compareTo(b.name)))
            Card(
              child: ListTile(
                dense: true,
                title: Text(e.name),
                subtitle: Text([if (e.page != null) 'p. ${e.page}', if (e.summary.isNotEmpty) e.summary, if (e.data.isNotEmpty) tr('com regras', 'with rules')].join(' · ')),
                onTap: () async {
                  final ed = await Navigator.of(context).push<LibEntry>(MaterialPageRoute<LibEntry>(builder: (_) => EntryEditor(entry: e)));
                  if (ed == null) return;
                  book.entries[book.entries.indexOf(e)] = ed;
                  await app.saveHomebrew(book);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, tr('Apagar "${e.name}"?', 'Delete "${e.name}"?'))) {
                      book.entries.remove(e);
                      await app.saveHomebrew(book);
                    }
                  },
                ),
              ),
            ),
        ],
      ]),
    );
  }
}

/// Editor de uma entrada homebrew. Os campos estruturados variam conforme o tipo
/// e alimentam o motor de regras (mesmo esquema do núcleo SRD).
class EntryEditor extends StatefulWidget {
  final LibEntry entry;
  const EntryEditor({super.key, required this.entry});
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late String kind;
  late Map<String, dynamic> data;
  final ctl = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    kind = widget.entry.kind;
    data = Map<String, dynamic>.from(widget.entry.data);
  }

  TextEditingController t(String k, [String init = '']) =>
      ctl.putIfAbsent(k, () => TextEditingController(text: '${data[k] ?? init}'));

  Widget field(String k, String label, {double w = 200, String init = '', int lines = 1}) => SizedBox(
        width: w,
        child: TextField(controller: t(k, init), maxLines: lines, decoration: InputDecoration(labelText: label)),
      );

  List<Effect> get effects =>
      ((data['effects'] as List?) ?? []).map((e) => Effect.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  set effects(List<Effect> l) => data['effects'] = l.map((e) => e.toJson()).toList();

  int? _int(String k) => int.tryParse(ctl[k]?.text.trim() ?? '');
  double? _dbl(String k) => double.tryParse((ctl[k]?.text.trim() ?? '').replaceAll(',', '.'));
  String _s(String k) => ctl[k]?.text.trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final e = widget.entry;
    final rules = app.rules;
    final kinds = ['feat', 'race', 'class', 'prestige', 'spell', 'weapon', 'armor', 'magic-item', 'equipment', 'deity', 'domain', 'monster', 'rule', 'template'];
    return Scaffold(
      appBar: AppBar(
        title: Text(e.name.isEmpty ? tr('Nova entrada', 'New entry') : e.name),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(tr('Salvar', 'Save')),
            onPressed: () {
              final name = _s('name');
              if (name.isEmpty) {
                toast(context, tr('Informe o nome.', 'Enter a name.'));
                return;
              }
              Navigator.pop(context, _build(name));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 320, child: TextField(controller: ctl.putIfAbsent('name', () => TextEditingController(text: e.name)), decoration: InputDecoration(labelText: tr('Nome', 'Name')))),
          DropdownButton<String>(
            value: kinds.contains(kind) ? kind : 'rule',
            items: [for (final k in kinds) DropdownMenuItem(value: k, child: Text(kindName(k)))],
            onChanged: (v) => setState(() => kind = v ?? 'rule'),
          ),
          SizedBox(width: 90, child: TextField(controller: ctl.putIfAbsent('page', () => TextEditingController(text: e.page?.toString() ?? '')), decoration: InputDecoration(labelText: tr('Página', 'Page')))),
          if (kind == 'feat' || kind == 'race' || kind == 'class' || kind == 'prestige' || kind == 'weapon' || kind == 'armor')
            field('name_pt', tr('Nome em português (opcional)', 'Portuguese name (optional)'), w: 260),
        ]),
        const SizedBox(height: 10),
        TextField(controller: ctl.putIfAbsent('summary', () => TextEditingController(text: e.summary)), decoration: InputDecoration(labelText: tr('Resumo (uma linha)', 'Summary (one line)'))),
        const SizedBox(height: 10),
        TextField(
            controller: ctl.putIfAbsent('body', () => TextEditingController(text: e.body)),
            minLines: 5,
            maxLines: 20,
            decoration: InputDecoration(labelText: tr('Texto completo', 'Full text'), alignLabelWithHint: true)),
        SectionTitle(tr('Regras (usadas nos cálculos)', 'Rules (used in calculations)')),
        ..._kindFields(),
        if (kind != 'spell' && kind != 'weapon' && kind != 'armor') ...[
          const SizedBox(height: 8),
          Text(tr('Modificadores concedidos', 'Modifiers granted'), style: const TextStyle(fontWeight: FontWeight.bold)),
          EffectListEditor(effects: effects, skillIds: rules.skills.keys.toList(), onChanged: (l) => setState(() => effects = l)),
        ],
      ]),
    );
  }

  List<Widget> _kindFields() {
    switch (kind) {
      case 'feat':
        return [
          Wrap(spacing: 12, runSpacing: 10, children: [
            field('types_text', tr('Tipos (general, fighter, metamagic, epic…)', 'Types (general, fighter, metamagic, epic…)'),
                w: 360, init: ((data['types'] as List?) ?? ['general']).join(', ')),
            field('prereq_text', tr('Pré-requisitos (texto)', 'Prerequisites (text)'), w: 420),
            DropdownButton<String>(
              value: (data['choice'] as String?) ?? '',
              items: [
                DropdownMenuItem(value: '', child: Text(tr('sem escolha', 'no choice'))),
                DropdownMenuItem(value: 'weapon', child: Text(tr('escolhe arma', 'choose weapon'))),
                DropdownMenuItem(value: 'skill', child: Text(tr('escolhe perícia', 'choose skill'))),
                DropdownMenuItem(value: 'school', child: Text(tr('escolhe escola', 'choose school'))),
                DropdownMenuItem(value: 'text', child: Text(tr('escolha livre', 'free choice'))),
              ],
              onChanged: (v) => setState(() => data['choice'] = (v == null || v.isEmpty) ? null : v),
            ),
            FilterChip(label: Text(tr('Pode repetir', 'Can repeat')), selected: data['multiple'] == true, onSelected: (v) => setState(() => data['multiple'] = v)),
          ]),
          Text(tr('Dica: use {choice} no alvo do modificador (ex.: attack.weapon:{choice}).', 'Tip: use {choice} in the modifier target (e.g. attack.weapon:{choice}).'),
              style: Theme.of(context).textTheme.bodySmall),
        ];
      case 'race':
        return [
          Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<String>(
              value: (data['size'] as String?) ?? 'medium',
              items: [for (final s in app().rules.sizeOrder) DropdownMenuItem(value: s, child: Text(Lang.isPt ? app().rules.size(s).namePt : s))],
              onChanged: (v) => setState(() => data['size'] = v),
            ),
            field('speed', tr('Deslocamento', 'Speed'), w: 110, init: '30'),
            field('la', 'LA', w: 70, init: '0'),
            field('favored_class', tr('Classe favorecida (id ou any)', 'Favored class (id or any)'), w: 200, init: 'any'),
            field('bonus_feats', tr('Talentos extras no 1º', 'Bonus feats at 1st'), w: 150, init: '0'),
            field('bonus_skill_points', tr('Perícias extras/nível', 'Bonus skill pts/level'), w: 160, init: '0'),
            field('adj_text', tr('Ajustes (ex.: str +2, cha -2)', 'Adjustments (e.g. str +2, cha -2)'), w: 260,
                init: ((data['ability_adj'] as Map?) ?? {}).entries.map((e) => '${e.key} ${e.value}').join(', ')),
            field('vision', tr('Visão', 'Vision'), w: 200),
            field('languages', tr('Idiomas', 'Languages'), w: 220),
            field('features_text', tr('Traços (separados por ;)', 'Traits (separated by ;)'), w: 600,
                init: ((data['features'] as List?) ?? []).join('; ')),
          ]),
        ];
      case 'class':
      case 'prestige':
        final good = Set<String>.from((data['good_saves'] as List?) ?? []);
        final skills = Set<String>.from((data['class_skills'] as List?) ?? []);
        return [
          Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            field('hit_die', tr('Dado de vida', 'Hit die'), w: 110, init: '8'),
            field('skill_points', tr('Perícias/nível', 'Skills/level'), w: 120, init: '2'),
            DropdownButton<String>(
              value: (data['bab'] as String?) ?? '3/4',
              items: const [
                DropdownMenuItem(value: 'full', child: Text('BBA 1')),
                DropdownMenuItem(value: '3/4', child: Text('BBA 3/4')),
                DropdownMenuItem(value: '1/2', child: Text('BBA 1/2')),
              ],
              onChanged: (v) => setState(() => data['bab'] = v),
            ),
            for (final k in ['fort', 'ref', 'will'])
              FilterChip(
                label: Text(saveName(k)),
                selected: good.contains(k),
                onSelected: (v) => setState(() {
                  v ? good.add(k) : good.remove(k);
                  data['good_saves'] = good.toList();
                }),
              ),
            field('max_level', tr('Nível máximo', 'Max level'), w: 110, init: kind == 'prestige' ? '10' : '20'),
            field('requirements', tr('Requisitos (texto)', 'Requirements (text)'), w: 420),
            field('bonus_feat_text', tr('Níveis com talento bônus (ex.: 1,2,4)', 'Bonus feat levels (e.g. 1,2,4)'), w: 280,
                init: ((data['bonus_feat_levels'] as List?) ?? []).join(',')),
            field('features_text', tr('Habilidades: "nível: nome" por linha', 'Features: "level: name" per line'), w: 600, lines: 5,
                init: ((data['features'] as List?) ?? []).map((f) => '${(f as Map)['level']}: ${f['name']}').join('\n')),
            DropdownButton<String>(
              value: (data['_casting'] as String?) ?? 'none',
              items: [
                DropdownMenuItem(value: 'none', child: Text(tr('Sem conjuração', 'No spellcasting'))),
                DropdownMenuItem(value: 'advance', child: Text(tr('+1 nível de conjurador existente', '+1 existing caster level'))),
                for (final c in app().rules.classes.values.map((l) => l.first).where((c) => c.spellcasting != null))
                  DropdownMenuItem(value: 'copy:${c.id}', child: Text('${tr('Tabela igual a', 'Table like')} ${c.displayName(Lang.isPt)}')),
              ],
              onChanged: (v) => setState(() => data['_casting'] = v),
            ),
          ]),
          const SizedBox(height: 8),
          Text(tr('Perícias de classe', 'Class skills'), style: const TextStyle(fontWeight: FontWeight.bold)),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final s in app().rules.skills.values)
              FilterChip(
                label: Text(s.displayName(Lang.isPt), style: const TextStyle(fontSize: 12)),
                selected: skills.contains(s.id),
                onSelected: (v) => setState(() {
                  v ? skills.add(s.id) : skills.remove(s.id);
                  data['class_skills'] = skills.toList();
                }),
              ),
          ]),
        ];
      case 'spell':
        return [
          Wrap(spacing: 12, runSpacing: 10, children: [
            field('school', tr('Escola', 'School'), w: 180),
            field('descriptors', tr('Descritores', 'Descriptors'), w: 180),
            field('levels_text', tr('Níveis (ex.: Sor/Wiz 3, Clr 4)', 'Levels (e.g. Sor/Wiz 3, Clr 4)'), w: 300,
                init: ((data['levels'] as Map?) ?? {}).entries.map((e) => '${e.key} ${e.value}').join(', ')),
            field('components', tr('Componentes', 'Components'), w: 160),
            field('casting_time', tr('Tempo de execução', 'Casting time'), w: 180),
            field('range', tr('Alcance', 'Range'), w: 180),
            field('target', tr('Alvo/Área/Efeito', 'Target/Area/Effect'), w: 240),
            field('duration', tr('Duração', 'Duration'), w: 180),
            field('save', tr('Teste de resistência', 'Saving throw'), w: 200),
            field('sr', tr('Resistência à magia', 'Spell resistance'), w: 160),
          ]),
        ];
      case 'weapon':
        return [
          Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<String>(
              value: (data['category'] as String?) ?? 'martial',
              items: const [
                DropdownMenuItem(value: 'simple', child: Text('simple')),
                DropdownMenuItem(value: 'martial', child: Text('martial')),
                DropdownMenuItem(value: 'exotic', child: Text('exotic')),
              ],
              onChanged: (v) => setState(() => data['category'] = v),
            ),
            DropdownButton<String>(
              value: (data['handed'] as String?) ?? 'one',
              items: const [
                DropdownMenuItem(value: 'light', child: Text('light')),
                DropdownMenuItem(value: 'one', child: Text('one-handed')),
                DropdownMenuItem(value: 'two', child: Text('two-handed')),
                DropdownMenuItem(value: 'ranged', child: Text('ranged')),
                DropdownMenuItem(value: 'thrown', child: Text('thrown')),
              ],
              onChanged: (v) => setState(() => data['handed'] = v),
            ),
            field('dmg_s', tr('Dano (P)', 'Damage (S)'), w: 100, init: '1d4'),
            field('dmg_m', tr('Dano (M)', 'Damage (M)'), w: 100, init: '1d6'),
            field('crit_range', tr('Ameaça mín.', 'Threat min'), w: 100, init: '20'),
            field('crit_mult', tr('Multiplicador', 'Multiplier'), w: 110, init: '2'),
            field('range', tr('Incremento (pés)', 'Range (ft)'), w: 120, init: '0'),
            field('weight', tr('Peso (lb)', 'Weight (lb)'), w: 100, init: '0'),
            field('cost', tr('Custo (po)', 'Cost (gp)'), w: 100, init: '0'),
            field('dtype', tr('Tipo (P/S/B)', 'Type (P/S/B)'), w: 100),
            FilterChip(label: Text(tr('Acuidade', 'Finesse')), selected: data['finesse'] == true, onSelected: (v) => setState(() => data['finesse'] = v)),
          ]),
        ];
      case 'armor':
        return [
          Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<String>(
              value: (data['category'] as String?) ?? 'light',
              items: const [
                DropdownMenuItem(value: 'light', child: Text('light')),
                DropdownMenuItem(value: 'medium', child: Text('medium')),
                DropdownMenuItem(value: 'heavy', child: Text('heavy')),
                DropdownMenuItem(value: 'shield', child: Text('shield')),
              ],
              onChanged: (v) => setState(() => data['category'] = v),
            ),
            field('bonus', tr('Bônus', 'Bonus'), w: 90, init: '1'),
            field('max_dex', tr('Des máx. (vazio = sem limite)', 'Max Dex (empty = none)'), w: 200),
            field('acp', tr('Penalidade', 'Check penalty'), w: 110, init: '0'),
            field('asf', tr('Falha arcana %', 'Spell failure %'), w: 130, init: '0'),
            field('weight', tr('Peso (lb)', 'Weight (lb)'), w: 100, init: '0'),
            field('cost', tr('Custo (po)', 'Cost (gp)'), w: 100, init: '0'),
          ]),
        ];
      default:
        return [
          Wrap(spacing: 12, runSpacing: 10, children: [
            field('cost', tr('Custo (po)', 'Cost (gp)'), w: 120),
            field('weight', tr('Peso (lb)', 'Weight (lb)'), w: 120),
          ]),
        ];
    }
  }

  AppState app() => context.read<AppState>();

  LibEntry _build(String name) {
    final d = Map<String, dynamic>.from(data);
    d['name'] = name;
    if (_s('name_pt').isNotEmpty) d['name_pt'] = _s('name_pt');
    switch (kind) {
      case 'feat':
        d['types'] = _s('types_text').split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
        d['prereq_text'] = _s('prereq_text');
        break;
      case 'race':
        d['speed'] = _int('speed') ?? 30;
        d['la'] = _int('la') ?? 0;
        d['favored_class'] = _s('favored_class').isEmpty ? 'any' : _s('favored_class');
        d['bonus_feats'] = _int('bonus_feats') ?? 0;
        d['bonus_skill_points'] = _int('bonus_skill_points') ?? 0;
        final adj = <String, int>{};
        for (final m in RegExp(r'(str|dex|con|int|wis|cha)\s*([+\-−]?\d+)').allMatches(_s('adj_text').toLowerCase())) {
          adj[m.group(1)!] = int.parse(m.group(2)!.replaceAll('−', '-').replaceAll('+', ''));
        }
        d['ability_adj'] = adj;
        d['vision'] = _s('vision');
        d['languages'] = _s('languages');
        d['features'] = _s('features_text').split(';').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
        break;
      case 'class':
      case 'prestige':
        d['hit_die'] = _int('hit_die') ?? 8;
        d['skill_points'] = _int('skill_points') ?? 2;
        d['bab'] = d['bab'] ?? '3/4';
        d['max_level'] = _int('max_level') ?? (kind == 'prestige' ? 10 : 20);
        d['prestige'] = kind == 'prestige';
        d['requirements'] = _s('requirements');
        d['bonus_feat_levels'] = _s('bonus_feat_text').split(',').map((x) => int.tryParse(x.trim())).whereType<int>().toList();
        d['features'] = [
          for (final line in _s('features_text').split('\n'))
            if (line.contains(':')) {'level': int.tryParse(line.split(':').first.trim()) ?? 1, 'name': line.substring(line.indexOf(':') + 1).trim()},
        ];
        final cast = (d['_casting'] as String?) ?? 'none';
        d.remove('spellcasting');
        d.remove('advances_casting');
        if (cast.startsWith('copy:')) {
          final sc = app().rules.classById(cast.substring(5))?.spellcasting;
          if (sc != null) d['spellcasting'] = sc.toJson();
        } else if (cast == 'advance') {
          d['advances_casting'] = [for (var i = 1; i <= (d['max_level'] as int); i++) i];
        }
        break;
      case 'spell':
        for (final k in ['school', 'descriptors', 'components', 'casting_time', 'range', 'target', 'duration', 'save', 'sr']) {
          d[k] = _s(k);
        }
        final lv = <String, int>{};
        for (final part in _s('levels_text').split(',')) {
          final m = RegExp(r'^(.+?)\s+(\d+)$').firstMatch(part.trim());
          if (m != null) lv[m.group(1)!.trim()] = int.parse(m.group(2)!);
        }
        d['levels'] = lv;
        break;
      case 'weapon':
        d['dmg_s'] = _s('dmg_s');
        d['dmg_m'] = _s('dmg_m');
        d['crit_range'] = _int('crit_range') ?? 20;
        d['crit_mult'] = _int('crit_mult') ?? 2;
        d['crit_text'] = '${(d['crit_range'] as int) < 20 ? '${d['crit_range']}-20/' : ''}x${d['crit_mult']}';
        d['range'] = _int('range') ?? 0;
        d['weight'] = _dbl('weight') ?? 0;
        d['cost'] = _dbl('cost') ?? 0;
        d['dtype'] = _s('dtype');
        d['category'] = d['category'] ?? 'martial';
        d['handed'] = d['handed'] ?? 'one';
        break;
      case 'armor':
        d['bonus'] = _int('bonus') ?? 1;
        d['max_dex'] = _int('max_dex');
        d['acp'] = _int('acp') ?? 0;
        d['asf'] = _int('asf') ?? 0;
        d['weight'] = _dbl('weight') ?? 0;
        d['cost'] = _dbl('cost') ?? 0;
        d['category'] = d['category'] ?? 'light';
        break;
      default:
        if (_dbl('cost') != null) d['cost'] = _dbl('cost');
        if (_dbl('weight') != null) d['weight'] = _dbl('weight');
    }
    // limpa campos auxiliares
    for (final k in ['types_text', 'adj_text', 'features_text', 'bonus_feat_text', 'levels_text']) {
      d.remove(k);
    }
    return LibEntry(
      uid: widget.entry.uid,
      kind: kind,
      name: name,
      book: widget.entry.book,
      page: int.tryParse(_s('page')),
      summary: _s('summary'),
      body: ctl['body']?.text ?? '',
      data: d,
      homebrew: true,
    );
  }
}
