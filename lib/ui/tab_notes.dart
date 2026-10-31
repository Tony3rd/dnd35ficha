import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../model/character.dart';
import 'books_selector.dart';
import 'portrait.dart';
import 'widgets.dart';

const alignmentCodes = ['LG', 'NG', 'CG', 'LN', 'N', 'CN', 'LE', 'NE', 'CE'];
String alignmentName(String c) {
  const pt = {'LG': 'Leal e Bom', 'NG': 'Neutro e Bom', 'CG': 'Caótico e Bom', 'LN': 'Leal e Neutro', 'N': 'Neutro',
    'CN': 'Caótico e Neutro', 'LE': 'Leal e Mau', 'NE': 'Neutro e Mau', 'CE': 'Caótico e Mau'};
  const en = {'LG': 'Lawful Good', 'NG': 'Neutral Good', 'CG': 'Chaotic Good', 'LN': 'Lawful Neutral', 'N': 'Neutral',
    'CN': 'Chaotic Neutral', 'LE': 'Lawful Evil', 'NE': 'Neutral Evil', 'CE': 'Chaotic Evil'};
  return (Lang.isPt ? pt : en)[c] ?? c;
}

class IdentityFields extends StatelessWidget {
  final Character ch;
  final void Function(void Function(Character)) update;
  const IdentityFields({super.key, required this.ch, required this.update});

  @override
  Widget build(BuildContext context) {
    Widget f(String label, String v, void Function(Character, String) set, {double w = 200, String help = ''}) {
      final w0 = SizedBox(
        width: w,
        child: TextFormField(
          initialValue: v,
          decoration: InputDecoration(labelText: label),
          onChanged: (t) => update((x) => set(x, t)),
        ),
      );
      return help.isEmpty ? w0 : Tooltip(message: help, waitDuration: const Duration(milliseconds: 400), child: w0);
    }
    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      f(tr('Nome do personagem', 'Character name'), ch.name, (x, t) => x.name = t, w: 300),
      f(tr('Jogador', 'Player'), ch.player, (x, t) => x.player = t, help: tr('Nome da pessoa que joga com este personagem.', 'Who plays this character.')),
      f(tr('Campanha', 'Campaign'), ch.campaign, (x, t) => x.campaign = t, help: tr('Campanha ou mesa de jogo (ajuda a organizar as fichas).', 'Campaign or table.')),
      Tooltip(
        message: tr('Tendência: alguns requisitos de classe (paladino, monge, bárbaro…) e magias dependem dela.', 'Alignment: some class requirements and spells depend on it.'),
        child: DropdownButton<String>(
        value: alignmentCodes.contains(ch.alignment) ? ch.alignment : 'N',
        items: [for (final a in alignmentCodes) DropdownMenuItem(value: a, child: Text(alignmentName(a)))],
        onChanged: (v) => update((x) => x.alignment = v ?? 'N'),
      ),
      ),
      f(tr('Divindade', 'Deity'), ch.deity, (x, t) => x.deity = t,
          help: tr('Deus patrono. Clérigos, paladinos e alguns talentos (ex.: talentos de divindade de Tormenta) exigem um.', 'Patron deity; clerics, paladins and some feats require one.')),
      f(tr('Sexo', 'Gender'), ch.gender, (x, t) => x.gender = t, w: 110),
      f(tr('Idade', 'Age'), ch.age, (x, t) => x.age = t, w: 90),
      f(tr('Altura', 'Height'), ch.height, (x, t) => x.height = t, w: 100),
      f(tr('Peso', 'Weight'), ch.weight, (x, t) => x.weight = t, w: 100),
      f(tr('Olhos', 'Eyes'), ch.eyes, (x, t) => x.eyes = t, w: 110),
      f(tr('Cabelos', 'Hair'), ch.hair, (x, t) => x.hair = t, w: 110),
      f(tr('Pele', 'Skin'), ch.skin, (x, t) => x.skin = t, w: 110),
    ]);
  }
}

class NotesTab extends StatelessWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CharacterController>();
    final ch = c.ch;
    Widget area(String label, String v, void Function(Character, String) set) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextFormField(
            initialValue: v,
            minLines: 4,
            maxLines: 14,
            decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
            onChanged: (t) => c.update((x) => set(x, t)),
          ),
        );
    return ListView(padding: const EdgeInsets.all(12), children: [
      SectionTitle(tr('Identidade', 'Identity')),
      Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.start, children: [
        PortraitField(portrait: ch.portrait, onChanged: (v) => c.update((x) => x.portrait = v)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: IdentityFields(ch: ch, update: (fn) => c.update(fn)),
        ),
      ]),
      SectionTitle(tr('Livros usados nesta ficha', 'Books used by this character')),
      ChosenBooks(
        selected: ch.allowedBooks,
        policy: ch.versionPolicy,
        onChanged: (b, p) => c.update((x) {
          x.allowedBooks = b;
          x.versionPolicy = p;
        }),
      ),
      if (ch.versionChoices.isNotEmpty) ...[
        SectionTitle(tr('Versões escolhidas', 'Chosen versions'),
            trailing: TextButton(onPressed: () => c.update((x) => x.versionChoices.clear()), child: Text(tr('Limpar', 'Clear')))),
        Wrap(spacing: 6, children: [
          for (final e in ch.versionChoices.entries)
            InputChip(label: Text('${e.key.split(':').last} → ${e.value}'), onDeleted: () => c.update((x) => x.versionChoices.remove(e.key))),
        ]),
      ],
      SectionTitle(tr('Descrição', 'Description')),
      area(tr('Aparência', 'Appearance'), ch.appearance, (x, t) => x.appearance = t),
      area(tr('Histórico', 'Background'), ch.background, (x, t) => x.background = t),
      area(tr('Anotações de jogo', 'Session notes'), ch.notes, (x, t) => x.notes = t),
      const SizedBox(height: 40),
    ]);
  }
}
