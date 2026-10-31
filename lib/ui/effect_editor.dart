import 'package:flutter/material.dart';

import '../engine/bonus.dart';
import '../engine/expr.dart';
import '../i18n.dart';
import 'help.dart';

/// Lista editável de modificadores (usada em itens, buffs, ajustes manuais e homebrew).
class EffectListEditor extends StatelessWidget {
  final List<Effect> effects;
  final ValueChanged<List<Effect>> onChanged;
  final List<String> skillIds;
  const EffectListEditor({super.key, required this.effects, required this.onChanged, this.skillIds = const []});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < effects.length; i++)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune, size: 18),
          title: Text(describeEffect(effects[i])),
          onTap: () async {
            final e = await editEffect(context, effects[i], skillIds: skillIds);
            if (e != null) onChanged([...effects]..[i] = e);
          },
          trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged([...effects]..removeAt(i))),
        ),
      withHelp(tr('Adicionar modificador', 'Add modifier'), TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: Text(tr('Adicionar modificador', 'Add modifier')),
        onPressed: () async {
          final e = await editEffect(context, null, skillIds: skillIds);
          if (e != null) onChanged([...effects, e]);
        },
      )),
    ]);
  }
}

String targetLabel(String t) {
  final g = Targets.general[t];
  if (g != null) return Lang.isPt ? g : t;
  if (t.startsWith('skill.')) return '${tr('Perícia', 'Skill')}: ${t.substring(6)}';
  if (t.startsWith('attack.weapon:')) return '${tr('Ataque com', 'Attack with')} ${t.substring(14)}';
  if (t.startsWith('damage.weapon:')) return '${tr('Dano com', 'Damage with')} ${t.substring(14)}';
  if (t.startsWith('spelldc.school:')) return '${tr('CD de', 'DC of')} ${t.substring(15)}';
  return t;
}

String describeEffect(Effect e) {
  final v = e.value.startsWith('-') ? e.value : '+${e.value}';
  final ty = e.type == BonusType.untyped ? '' : ' (${Lang.isPt ? (BonusType.labelsPt[e.type] ?? e.type) : e.type})';
  final cond = e.situational ? ' — ${e.condition}' : '';
  return '${targetLabel(e.target)} $v$ty$cond';
}

Future<Effect?> editEffect(BuildContext context, Effect? initial, {List<String> skillIds = const []}) {
  return showDialog<Effect>(context: context, builder: (_) => _EffectDialog(initial: initial, skillIds: skillIds));
}

class _EffectDialog extends StatefulWidget {
  final Effect? initial;
  final List<String> skillIds;
  const _EffectDialog({this.initial, required this.skillIds});
  @override
  State<_EffectDialog> createState() => _EffectDialogState();
}

class _EffectDialogState extends State<_EffectDialog> {
  late TextEditingController target, value, cond;
  late String type;
  String? err;

  @override
  void initState() {
    super.initState();
    target = TextEditingController(text: widget.initial?.target ?? 'ac');
    value = TextEditingController(text: widget.initial?.value ?? '1');
    cond = TextEditingController(text: widget.initial?.condition ?? '');
    type = widget.initial?.type ?? BonusType.untyped;
  }

  @override
  Widget build(BuildContext context) {
    final targets = [...Targets.general.keys, for (final s in widget.skillIds) 'skill.$s'];
    return AlertDialog(
      title: Text(tr('Modificador', 'Modifier')),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Autocomplete<String>(
            initialValue: TextEditingValue(text: target.text),
            optionsBuilder: (v) => targets.where((t) => t.contains(v.text.toLowerCase()) || targetLabel(t).toLowerCase().contains(v.text.toLowerCase())),
            displayStringForOption: (t) => t,
            onSelected: (t) => target.text = t,
            fieldViewBuilder: (c, ctl, focus, onSubmit) {
              ctl.addListener(() => target.text = ctl.text);
              return withHelp(tr('Alvo (ex.: ac, save.will, skill.hide, attack.weapon:longsword)', 'Target'), TextField(
                controller: ctl,
                focusNode: focus,
                decoration: InputDecoration(labelText: tr('Alvo (ex.: ac, save.will, skill.hide, attack.weapon:longsword)', 'Target')),
              ));
            },
          ),
          const SizedBox(height: 10),
          withHelp(tr('Valor ou fórmula', 'Value or formula'), TextField(
            controller: value,
            decoration: InputDecoration(
              labelText: tr('Valor ou fórmula', 'Value or formula'),
              helperText: tr('Ex.: 2, -1, floor(@class.bard/4)+1, @abil.cha.mod', 'e.g. 2, -1, floor(@class.bard/4)+1, @abil.cha.mod'),
              errorText: err,
            ),
          )),
          const SizedBox(height: 10),
          DropdownButton<String>(
            isExpanded: true,
            value: BonusType.all.contains(type) ? type : BonusType.untyped,
            items: [
              for (final t in BonusType.all)
                DropdownMenuItem(value: t, child: Text(Lang.isPt ? (BonusType.labelsPt[t] ?? t) : t)),
            ],
            onChanged: (v) => setState(() => type = v ?? BonusType.untyped),
          ),
          const SizedBox(height: 10),
          withHelp(tr('Condição (opcional — vira nota situacional)', 'Condition (optional — situational note)'), TextField(
            controller: cond,
            decoration: InputDecoration(
                labelText: tr('Condição (opcional — vira nota situacional)', 'Condition (optional — situational note)')),
          )),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar', 'Cancel'))),
        FilledButton(
          onPressed: () {
            try {
              Expr.eval(value.text, (_) => 1);
            } catch (e) {
              setState(() => err = '$e');
              return;
            }
            Navigator.pop(
                context,
                Effect(
                  target: target.text.trim(),
                  value: value.text.trim(),
                  type: type,
                  condition: cond.text.trim().isEmpty ? null : cond.text.trim(),
                  source: widget.initial?.source ?? '',
                ));
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
