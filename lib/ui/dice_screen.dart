import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../engine/dice.dart';
import '../i18n.dart';
import 'widgets.dart';

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});
  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen> {
  final ctl = TextEditingController(text: '1d20');
  String? err;
  int count = 1;
  int mod = 0;

  void _roll(AppState app, String expr, {String label = ''}) {
    try {
      final r = app.roll(expr, label: label);
      setState(() => err = null);
      showRoll(context, r);
    } on DiceParseException catch (e) {
      setState(() => err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Rolador de dados', 'Dice roller'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: ctl,
              decoration: InputDecoration(
                labelText: tr('Expressão', 'Expression'),
                helperText: tr('Ex.: 1d20+7, 2d6+1d4+3, 4d6kh3 (mantém os 3 maiores), d%', 'e.g. 1d20+7, 2d6+1d4+3, 4d6kh3 (keep 3 highest), d%'),
                errorText: err,
              ),
              onSubmitted: (v) => _roll(app, v),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: () => _roll(app, ctl.text), icon: const Icon(Icons.casino), label: Text(tr('Rolar', 'Roll'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text(tr('Quantidade', 'Count')),
          NumStepper(value: count, min: 1, max: 100, onChanged: (v) => setState(() => count = v.toInt())),
          const SizedBox(width: 16),
          Text(tr('Modificador', 'Modifier')),
          NumStepper(value: mod, min: -100, max: 100, format: (v) => sgn(v.toInt()), onChanged: (v) => setState(() => mod = v.toInt())),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in [2, 3, 4, 6, 8, 10, 12, 20, 100])
            SizedBox(
              width: 76,
              height: 56,
              child: FilledButton.tonal(
                onPressed: () => _roll(app, '${count}d$d${mod == 0 ? '' : sgn(mod)}'),
                child: Text('d$d', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: () => _roll(app, '4d6kh3', label: tr('Atributo', 'Ability')), child: Text(tr('Atributo (4d6)', 'Ability (4d6)'))),
          OutlinedButton(
              onPressed: () {
                final vals = app.dice.rollAbilityArray();
                showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                          title: Text(tr('Seis atributos', 'Six abilities')),
                          content: Text('${vals.join('  ·  ')}\n${tr('Total de modificadores', 'Total modifiers')}: ${vals.fold<int>(0, (a, v) => a + ((v - 10) / 2).floor())}'),
                          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
                        ));
              },
              child: Text(tr('6 atributos', '6 abilities'))),
          OutlinedButton(onPressed: () => _roll(app, '1d100', label: tr('Chance de falha', 'Miss chance')), child: Text(tr('Chance (d%)', 'Percentile'))),
        ]),
        SectionTitle(tr('Histórico', 'History'),
            trailing: TextButton(onPressed: () => setState(() => app.rollLog.clear()), child: Text(tr('Limpar', 'Clear')))),
        for (final r in app.rollLog)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: r.natural20 == 20 ? scheme.tertiary : (r.natural20 == 1 ? scheme.error : null),
              child: Text('${r.total}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(r.label.isEmpty ? r.expression : r.label),
            subtitle: Text('${r.breakdown}   ${TimeOfDay.fromDateTime(r.time).format(context)}'),
            onTap: () => _roll(app, r.expression, label: r.label),
          ),
      ]),
    );
  }
}
