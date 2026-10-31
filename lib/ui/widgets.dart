import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/homebrew.dart';
import '../engine/dice.dart';
import '../i18n.dart';
import 'help.dart';

String sgn(int v) => v >= 0 ? '+$v' : '$v';

Future<String?> promptText(BuildContext context, String title,
    {String initial = '', String? hint, bool multiline = false}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: ctl,
          autofocus: true,
          maxLines: multiline ? 8 : 1,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: multiline ? null : (v) => Navigator.pop(c, v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Cancelar', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('OK')),
      ],
    ),
  );
}

Future<int?> promptInt(BuildContext context, String title, {int initial = 0}) async {
  final s = await promptText(context, title, initial: '$initial');
  if (s == null) return null;
  return int.tryParse(s.trim());
}

Future<bool> confirm(BuildContext context, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Não', 'No'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Sim', 'Yes'))),
      ],
    ),
  );
  return r == true;
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));

/// Mostra o resultado de uma rolagem com destaque para 20/1 naturais.
void showRoll(BuildContext context, RollResult r) {
  final nat = r.natural20;
  final scheme = Theme.of(context).colorScheme;
  String extra = '';
  if (nat == 20) extra = tr('  ★ 20 natural!', '  ★ natural 20!');
  if (nat == 1) extra = tr('  ✖ 1 natural', '  ✖ natural 1');
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    duration: const Duration(seconds: 5),
    backgroundColor: nat == 20 ? scheme.tertiary : (nat == 1 ? scheme.error : null),
    content: Text('${r.label.isEmpty ? r.expression : r.label}: ${r.total}   (${r.breakdown})$extra',
        style: const TextStyle(fontSize: 16)),
  ));
}

class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final Color? color;
  final String? help;
  const StatBox(this.label, this.value,
      {super.key, this.sub, this.onTap, this.onLongPress, this.width = 92, this.color, this.help});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return withHelp(label, help: help, SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: t.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, color: t.colorScheme.secondary)),
              const SizedBox(height: 2),
              Text(value, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
              if (sub != null)
                Text(sub!, textAlign: TextAlign.center, style: t.textTheme.labelSmall, maxLines: 2),
            ]),
          ),
        ),
      ),
    ));
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
      child: Row(children: [
        withHelp(
            text,
            Text(text.toUpperCase(),
                style: t.textTheme.titleSmall?.copyWith(letterSpacing: 1.4, color: t.colorScheme.secondary, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class NumStepper extends StatelessWidget {
  final num value;
  final ValueChanged<num> onChanged;
  final num min, max, step;
  final String Function(num)? format;
  const NumStepper(
      {super.key, required this.value, required this.onChanged, this.min = -999, this.max = 9999, this.step = 1, this.format});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.remove, size: 18),
        onPressed: value - step >= min ? () => onChanged(value - step) : null,
      ),
      SizedBox(
        width: 40,
        child: Text(format?.call(value) ?? (value == value.roundToDouble() ? '${value.toInt()}' : value.toStringAsFixed(1)),
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.add, size: 18),
        onPressed: value + step <= max ? () => onChanged(value + step) : null,
      ),
    ]);
  }
}

/// Quando um item existe em vários livros, pergunta qual versão usar.
Future<LibEntry?> chooseVersion(BuildContext context, List<LibEntry> versions, {String policy = 'ask'}) async {
  if (versions.isEmpty) return null;
  if (versions.length == 1 || policy == 'newest') return versions.first; // já ordenado do mais recente
  final app = context.read<AppState>();
  return showDialog<LibEntry>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('Versões diferentes encontradas', 'Different versions found')),
      content: SizedBox(
        width: 560,
        child: ListView(shrinkWrap: true, children: [
          Text(tr('"${versions.first.label}" aparece em ${versions.length} livros. Qual versão usar?',
              '"${versions.first.name}" appears in ${versions.length} books. Which version?')),
          const SizedBox(height: 8),
          for (final v in versions)
            Card(
              child: ListTile(
                title: Text('${app.library.book(v.book)?.title ?? v.book}  (${v.sourceLabel})'),
                subtitle: Text(
                    [
                      if (app.library.book(v.book)?.released != null && app.library.book(v.book)!.released > 0)
                        '${app.library.book(v.book)!.released ~/ 100}',
                      if (v.shownSummary.isNotEmpty) v.shownSummary,
                      if (v.body.isNotEmpty) v.body.length > 220 ? '${v.body.substring(0, 220)}…' : v.body,
                    ].join(' — '),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(c, v),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Cancelar', 'Cancel'))),
        FilledButton.tonal(
            onPressed: () => Navigator.pop(c, versions.first),
            child: Text(tr('Usar a mais recente', 'Use most recent'))),
      ],
    ),
  );
}

/// Detalhe de uma entrada da biblioteca, com todos os livros em que aparece.
Future<void> showEntry(BuildContext context, LibEntry e) {
  final app = context.read<AppState>();
  final full = app.library.full(e) ?? e;
  final others = app.library.appearances(full.kind, full.name);
  return showDialog(context: context, builder: (c) => _EntryDialog(full: full, others: others));
}

class _EntryDialog extends StatefulWidget {
  final LibEntry full;
  final List<LibEntry> others;
  const _EntryDialog({required this.full, required this.others});
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late bool pt = Lang.isPt && (widget.full.bodyPt.isNotEmpty || widget.full.summaryPt.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final full = widget.full;
    final hasPt = full.bodyPt.isNotEmpty || full.summaryPt.isNotEmpty;
    final summary = pt && full.summaryPt.isNotEmpty ? full.summaryPt : full.summary;
    final body = pt && full.bodyPt.isNotEmpty ? full.bodyPt : full.body;
    final pageText = body.isEmpty && full.page != null ? app.library.pageText(full.book, full.page!) : '';
    return AlertDialog(
      title: Text(full.label),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Chip(label: Text(kindName(full.kind))),
              Chip(label: Text('${app.library.book(full.book)?.title ?? full.book}${full.page != null ? ' · p. ${full.page}' : ''}')),
              if (full.homebrew) const Chip(label: Text('homebrew')),
              if (hasPt)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Português')),
                    ButtonSegment(value: false, label: Text('Original')),
                  ],
                  selected: {pt},
                  onSelectionChanged: (v) => setState(() => pt = v.first),
                ),
            ]),
            if (pt && full.summaryPt.isNotEmpty && full.bodyPt.isEmpty && full.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tr('Texto completo ainda não traduzido — veja o original.', 'Full text not translated yet.'),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            if (summary.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(summary, style: const TextStyle(fontStyle: FontStyle.italic))),
            if (body.isNotEmpty && !(pt && full.bodyPt.isEmpty))
              Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(body)),
            if (pageText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tr('Texto da página:', 'Page text:'), style: const TextStyle(fontWeight: FontWeight.bold)),
              SelectableText(pageText),
            ],
            if (widget.others.length > 1) ...[
              const SizedBox(height: 12),
              Text(tr('Também aparece em:', 'Also appears in:'), style: const TextStyle(fontWeight: FontWeight.bold)),
              for (final o in widget.others.where((o) => o.book != full.book || o.page != full.page))
                Text('• ${app.library.book(o.book)?.title ?? o.book} (${o.sourceLabel})'),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: '${full.label} (${full.sourceLabel})\n$summary\n$body')),
            child: Text(tr('Copiar', 'Copy'))),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Fechar', 'Close'))),
      ],
    );
  }
}

/// Campo de busca + lista para escolher uma entrada da biblioteca.
Future<LibEntry?> pickEntry(BuildContext context,
    {required String title, Set<String>? kinds, Set<String>? books, List<LibEntry>? fixed}) {
  return showDialog<LibEntry>(
      context: context, builder: (c) => _PickEntryDialog(title: title, kinds: kinds, books: books, fixed: fixed));
}

class _PickEntryDialog extends StatefulWidget {
  final String title;
  final Set<String>? kinds, books;
  final List<LibEntry>? fixed;
  const _PickEntryDialog({required this.title, this.kinds, this.books, this.fixed});
  @override
  State<_PickEntryDialog> createState() => _PickEntryDialogState();
}

class _PickEntryDialogState extends State<_PickEntryDialog> {
  String q = '';
  Timer? _debounce;
  List<LibEntry> _unique = const [];
  Map<String, int> _versions = const {};
  /// Texto de busca já em minúsculas, calculado uma vez para listas fixas.
  late final List<String>? _hay = widget.fixed
      ?.map((e) => '${e.name}\u0001${e.namePt}\u0001${e.summary}\u0001${e.summaryPt}'.toLowerCase())
      .toList();

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    q = v;
    _debounce?.cancel();
    // espera o usuário parar de digitar antes de consultar a base
    _debounce = Timer(Duration(milliseconds: widget.fixed != null ? 90 : 220), () {
      if (mounted) setState(_run);
    });
  }

  void _run() {
    final app = context.read<AppState>();
    List<LibEntry> items;
    if (widget.fixed != null) {
      final ql = q.trim().toLowerCase();
      final f = widget.fixed!;
      items = ql.isEmpty ? f : [for (var i = 0; i < f.length; i++) if (_hay![i].contains(ql)) f[i]];
    } else {
      items = app.library.search(q, kinds: widget.kinds, books: widget.books, limit: 200, fullText: false);
    }
    // agrupa versões pelo nome
    final counts = <String, int>{};
    final unique = <LibEntry>[];
    for (final e in items) {
      final n = counts[e.key];
      if (n == null) unique.add(e);
      counts[e.key] = (n ?? 0) + 1;
    }
    _unique = unique;
    _versions = counts;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final unique = _unique;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 620,
        height: 520,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Buscar…', 'Search…')),
            onChanged: _onChanged,
            onSubmitted: (_) {
              _debounce?.cancel();
              setState(_run);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: unique.isEmpty
                ? Center(child: Text(app.library.hasDb || widget.fixed != null
                    ? tr('Nada encontrado.', 'Nothing found.')
                    : tr('Base de dados não encontrada (data/rules.sqlite).', 'Database not found (data/rules.sqlite).')))
                : ListView.builder(
                    itemCount: unique.length,
                    itemExtent: 56,
                    itemBuilder: (c, i) {
                      final e = unique[i];
                      final n = _versions[e.key] ?? 1;
                      final summary = e.shownSummary;
                      final tile = ListTile(
                        dense: true,
                        title: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${e.sourceLabel}${n > 1 ? tr(' · +${n - 1} versão(ões)', ' · +${n - 1} version(s)') : ''}'
                            '${summary.isNotEmpty ? ' — $summary' : ''}',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                            tooltip: tr('Ver o texto completo', 'Show full text'),
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => showEntry(context, e)),
                        onTap: () => Navigator.pop(context, e),
                      );
                      return summary.length > 60
                          ? Tooltip(message: summary, waitDuration: const Duration(milliseconds: 600), child: tile)
                          : tile;
                    }),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar', 'Cancel')))],
    );
  }
}
