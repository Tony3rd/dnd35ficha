// Ficha imprimível no formato do "Character Record Sheet" do Livro do Jogador 3.5:
// página 1 = atributos, defesa, resistências, ataques e perícias;
// página 2 = equipamento, posses, carga, dinheiro, talentos, habilidades,
// idiomas e magias; páginas extras = lista de magias e anotações.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show BuildContext, showDialog, SimpleDialog, SimpleDialogOption, Navigator, Text, ScaffoldMessenger, SnackBar;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../engine/calc.dart';
import '../i18n.dart';
import '../model/character.dart';

String _s(int v) => v >= 0 ? '+$v' : '$v';

class _Fonts {
  final pw.Font reg, bold, title;
  _Fonts(this.reg, this.bold, this.title);
  static Future<_Fonts> load() async {
    Future<pw.Font> f(String p) async => pw.Font.ttf(await rootBundle.load(p));
    return _Fonts(
      await f('assets/fonts/DejaVuSansCondensed.ttf'),
      await f('assets/fonts/DejaVuSansCondensed-Bold.ttf'),
      await f('assets/fonts/DejaVuSerifCondensed-Bold.ttf'),
    );
  }
}

const _ink = PdfColors.black;
const _grey = PdfColor.fromInt(0xFFBDBDBD);

pw.Widget _black(String text, {String? sub, double w = 60, double h = 20, double size = 10}) => pw.Container(
      width: w,
      height: h,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      decoration: const pw.BoxDecoration(color: _ink, borderRadius: pw.BorderRadius.all(pw.Radius.circular(3))),
      alignment: pw.Alignment.center,
      child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontSize: size, fontWeight: pw.FontWeight.bold)),
        if (sub != null) pw.Text(sub, style: const pw.TextStyle(color: PdfColors.white, fontSize: 4.5)),
      ]),
    );

pw.Widget _box(String v, {double w = 26, double h = 20, double size = 10, bool grey = false, bool bold = true}) => pw.Container(
      width: w,
      height: h,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 0.8), color: grey ? _grey : null),
      child: pw.Text(v, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

pw.Widget _cap(String t, {double w = 26}) =>
    pw.SizedBox(width: w, child: pw.Text(t.toUpperCase(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 4.5)));

pw.Widget _field(String value, String label, {double? w, double size = 9}) => pw.Container(
      width: w,
      padding: const pw.EdgeInsets.only(right: 6),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          height: 13,
          width: double.infinity,
          alignment: pw.Alignment.bottomLeft,
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.7))),
          child: pw.Text(value, maxLines: 1, style: pw.TextStyle(fontSize: size)),
        ),
        pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 5)),
      ]),
    );

pw.Widget _header(String t, {double? w}) => pw.Container(
      width: w,
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      color: _ink,
      alignment: pw.Alignment.center,
      child: pw.Text(t.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );

String _sizeName(Sheet s) => Lang.isPt ? s.rules.size(s.size).namePt : s.size;

Future<Uint8List> buildSheetPdf(Sheet s) async {
  final fonts = await _Fonts.load();
  final ch = s.ch;
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: fonts.reg, bold: fonts.bold),
    title: ch.name,
    author: 'Grimório 3.5',
  );
  final classes = s.classLevels.entries.map((e) => '${s.classDefs[e.key]?.displayName(Lang.isPt) ?? e.key} ${e.value}').join(' / ');
  final race = s.race?.displayName(Lang.isPt) ?? ch.raceId;

  // ------------------------------------------------------------------ página 1
  pw.Widget abilities() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.SizedBox(width: 52),
          _cap(tr('valor', 'score'), w: 28),
          _cap(tr('mod.', 'modifier'), w: 28),
          _cap(tr('valor temp.', 'temp score'), w: 28),
          _cap(tr('mod. temp.', 'temp mod'), w: 28),
        ]),
        for (final a in abilityIds)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(children: [
              _black(abilityAbbr(a), sub: abilityName(a).toUpperCase(), w: 50, h: 20, size: 11),
              pw.SizedBox(width: 2),
              _box('${s.abilities[a]!.permanent}', w: 28),
              _box(_s(abilityMod(s.abilities[a]!.permanent)), w: 28),
              _box(s.abilities[a]!.total != s.abilities[a]!.permanent ? '${s.abilities[a]!.total}' : '', w: 28, grey: true),
              _box(s.abilities[a]!.total != s.abilities[a]!.permanent ? _s(s.abilities[a]!.mod) : '', w: 28, grey: true),
            ]),
          ),
      ]);

  pw.Widget defense() {
    final acArmor = s.ac.bonuses.byType('armor');
    final acShield = s.ac.bonuses.byType('shield');
    final acNat = s.ac.bonuses.byType('natural') + s.ac.bonuses.byType('natural_enhancement');
    final acDefl = s.ac.bonuses.byType('deflection');
    final acSize = s.ac.bonuses.byType('size');
    final acMisc = s.ac.total - 10 - acArmor - acShield - acNat - acDefl - acSize - s.ac.dexApplied;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children: [
        _black(tr('PV', 'HP'), sub: tr('PONTOS DE VIDA', 'HIT POINTS'), w: 50),
        pw.SizedBox(width: 2),
        _box('${s.hpMax}', w: 30),
        pw.SizedBox(width: 4),
        _box(ch.damage > 0 || ch.tempHp > 0 ? '${s.hpMax - ch.damage}${ch.tempHp > 0 ? ' +${ch.tempHp}' : ''}' : '', w: 110, bold: false),
        pw.SizedBox(width: 4),
        _box(ch.nonlethal > 0 ? '${ch.nonlethal}' : '', w: 40, bold: false),
        pw.SizedBox(width: 6),
        _black(tr('DESLOC.', 'SPEED'), w: 46),
        pw.SizedBox(width: 2),
        _box("${s.speed}'", w: 34),
      ]),
      pw.Row(children: [
        pw.SizedBox(width: 84),
        _cap(tr('ferimentos / PV atuais', 'wounds / current hp'), w: 112),
        _cap(tr('não letal', 'nonlethal'), w: 44),
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        _black(tr('CA', 'AC'), sub: tr('CLASSE DE ARMADURA', 'ARMOR CLASS'), w: 50),
        pw.SizedBox(width: 2),
        _box('${s.ac.total}', w: 30),
        pw.Text(' = 10 + ', style: const pw.TextStyle(fontSize: 8)),
        for (final v in [acArmor, acShield, s.ac.dexApplied, acSize, acNat, acDefl, acMisc]) ...[
          _box('$v', w: 22, size: 9),
          pw.SizedBox(width: 3),
        ],
      ]),
      pw.Row(children: [
        pw.SizedBox(width: 115),
        for (final t in [
          tr('armad.', 'armor'),
          tr('escudo', 'shield'),
          tr('des', 'dex'),
          tr('tamanho', 'size'),
          tr('natural', 'natural'),
          tr('deflexão', 'deflect'),
          tr('outros', 'misc'),
        ]) ...[
          _cap(t, w: 22),
          pw.SizedBox(width: 3),
        ],
      ]),
      pw.SizedBox(height: 3),
      pw.Row(children: [
        _black(tr('TOQUE', 'TOUCH'), w: 50, h: 16, size: 9),
        _box('${s.ac.touch}', w: 30, h: 16),
        pw.SizedBox(width: 8),
        _black(tr('SURPRESO', 'FLAT-FOOTED'), w: 62, h: 16, size: 8),
        _box('${s.ac.flatFooted}', w: 30, h: 16),
        pw.SizedBox(width: 8),
        _black(tr('INICIATIVA', 'INITIATIVE'), w: 58, h: 16, size: 8),
        _box(_s(s.initiative), w: 30, h: 16),
        pw.Text(' = ', style: const pw.TextStyle(fontSize: 8)),
        _box(_s(s.abilities['dex']!.mod), w: 22, h: 16, size: 8),
        pw.Text(' + ', style: const pw.TextStyle(fontSize: 8)),
        _box(_s(s.initiative - s.abilities['dex']!.mod), w: 22, h: 16, size: 8),
      ]),
    ]);
  }

  pw.Widget saves() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.SizedBox(width: 74),
          _cap(tr('total', 'total'), w: 28),
          pw.SizedBox(width: 8),
          for (final t in [tr('base', 'base'), tr('atributo', 'ability'), tr('mágico', 'magic'), tr('outros', 'misc')]) ...[
            _cap(t, w: 24),
            pw.SizedBox(width: 8),
          ],
          pw.Expanded(child: pw.Text(tr('MODIFICADORES SITUACIONAIS', 'CONDITIONAL MODIFIERS'), style: const pw.TextStyle(fontSize: 5))),
        ]),
        for (final k in ['fort', 'ref', 'will'])
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(children: [
              _black(saveName(k).toUpperCase(), sub: '(${abilityName(s.saves[k]!.ability).toUpperCase()})', w: 72, h: 20, size: 9),
              pw.SizedBox(width: 2),
              _box(_s(s.saves[k]!.total), w: 28),
              pw.Text(' = ', style: const pw.TextStyle(fontSize: 8)),
              _box('${s.saves[k]!.base}', w: 24, size: 9),
              pw.Text(' + ', style: const pw.TextStyle(fontSize: 8)),
              _box(_s(s.saves[k]!.abilMod), w: 24, size: 9),
              pw.Text(' + ', style: const pw.TextStyle(fontSize: 8)),
              _box(_s(s.saves[k]!.misc.byType('resistance')), w: 24, size: 9),
              pw.Text(' + ', style: const pw.TextStyle(fontSize: 8)),
              _box(_s(s.saves[k]!.misc.total - s.saves[k]!.misc.byType('resistance')), w: 24, size: 9),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(s.saves[k]!.misc.situational.map((b) => '${_s(b.value)} ${b.condition}').join('; '),
                    style: const pw.TextStyle(fontSize: 5.5), maxLines: 3),
              ),
            ]),
          ),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          _black(tr('BÔNUS BASE DE ATAQUE', 'BASE ATTACK BONUS'), w: 128, h: 18, size: 8),
          pw.SizedBox(width: 2),
          _box(_attackSeq(s.bab), w: 70, h: 18, size: 9),
          pw.SizedBox(width: 8),
          _black(tr('RES. À MAGIA', 'SPELL RESIST.'), w: 70, h: 18, size: 8),
          _box(s.sr > 0 ? '${s.sr}' : '', w: 30, h: 18),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          _black(tr('AGARRAR', 'GRAPPLE'), sub: tr('MODIFICADOR', 'MODIFIER'), w: 72, h: 20),
          pw.SizedBox(width: 2),
          _box(_s(s.grapple), w: 28),
          pw.Text(' = ', style: const pw.TextStyle(fontSize: 8)),
          _box(_s(s.bab), w: 24, size: 9),
          pw.Text(' + ', style: const pw.TextStyle(fontSize: 8)),
          _box(_s(s.abilities['str']!.mod), w: 24, size: 9),
          pw.Text(' + ', style: const pw.TextStyle(fontSize: 8)),
          _box(_s(s.rules.size(s.size).grapple), w: 24, size: 9),
          pw.Text(' + ', style: const pw.TextStyle(fontSize: 8)),
          _box(_s(s.grapple - s.bab - s.abilities['str']!.mod - s.rules.size(s.size).grapple), w: 24, size: 9),
        ]),
      ]);

  pw.Widget attack(AttackLine? a) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 0.8)),
        child: pw.Column(children: [
          pw.Row(children: [
            pw.Expanded(flex: 5, child: _header(tr('ATAQUE', 'ATTACK'))),
            pw.Expanded(flex: 3, child: _header(tr('BÔNUS', 'ATTACK BONUS'))),
            pw.Expanded(flex: 2, child: _header(tr('DANO', 'DAMAGE'))),
            pw.Expanded(flex: 2, child: _header(tr('DECISIVO', 'CRITICAL'))),
          ]),
          pw.Container(
            height: 14,
            child: pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Padding(padding: const pw.EdgeInsets.only(left: 3), child: pw.Text(a?.name ?? '', maxLines: 1, style: const pw.TextStyle(fontSize: 8)))),
              pw.Expanded(flex: 3, child: pw.Center(child: pw.Text(a?.bonusText ?? '', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)))),
              pw.Expanded(flex: 2, child: pw.Center(child: pw.Text(a?.damage ?? '', style: const pw.TextStyle(fontSize: 8)))),
              pw.Expanded(flex: 2, child: pw.Center(child: pw.Text(a?.crit ?? '', style: const pw.TextStyle(fontSize: 8)))),
            ]),
          ),
          pw.Row(children: [
            pw.Expanded(flex: 2, child: _header(tr('ALCANCE', 'RANGE'))),
            pw.Expanded(flex: 1, child: _header(tr('TIPO', 'TYPE'))),
            pw.Expanded(flex: 9, child: _header(tr('NOTAS', 'NOTES'))),
          ]),
          pw.Container(
            height: 14,
            child: pw.Row(children: [
              pw.Expanded(flex: 2, child: pw.Center(child: pw.Text(a != null && a.range > 0 ? "${a.range}'" : '', style: const pw.TextStyle(fontSize: 8)))),
              pw.Expanded(flex: 1, child: pw.Center(child: pw.Text(a?.type ?? '', style: const pw.TextStyle(fontSize: 8)))),
              pw.Expanded(flex: 9, child: pw.Padding(padding: const pw.EdgeInsets.only(left: 3), child: pw.Text(a?.notes.join('; ') ?? '', maxLines: 2, style: const pw.TextStyle(fontSize: 6)))),
            ]),
          ),
        ]),
      );

  pw.Widget skills() {
    final rows = s.skills;
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 0.8)),
      child: pw.Column(children: [
        pw.Row(children: [
          pw.Expanded(child: _header(tr('PERÍCIAS', 'SKILLS'))),
          pw.Container(
            color: _ink,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: pw.Text('${tr('MÁX. GRAD.', 'MAX RANKS')} ${s.characterLevel + 3}/${((s.characterLevel + 3) / 2).toStringAsFixed(1)}',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 6)),
          ),
        ]),
        pw.Table(
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _grey, width: 0.4)),
          columnWidths: const {
            0: pw.FixedColumnWidth(9),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(22),
            3: pw.FixedColumnWidth(22),
            4: pw.FixedColumnWidth(20),
            5: pw.FixedColumnWidth(20),
            6: pw.FixedColumnWidth(20),
          },
          children: [
            pw.TableRow(children: [
              pw.SizedBox(),
              pw.Text(tr('PERÍCIA', 'SKILL NAME'), style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
              for (final t in [tr('ATRIB.', 'KEY'), tr('TOTAL', 'MOD'), tr('MOD', 'ABIL'), tr('GRAD', 'RANKS'), tr('OUTR', 'MISC')])
                pw.Text(t, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 5)),
            ]),
            for (final k in rows)
              pw.TableRow(children: [
                pw.Text(k.classSkill ? '■' : '□', style: const pw.TextStyle(fontSize: 6)),
                pw.Text('${k.label}${k.def.trainedOnly ? ' ✱' : ''}${k.def.acp > 0 ? (k.def.acp == 2 ? ' ²' : ' ¹') : ''}',
                    maxLines: 1, style: const pw.TextStyle(fontSize: 6.5)),
                pw.Text(k.def.ability == 'none' ? '—' : abilityAbbr(k.def.ability), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6)),
                pw.Text(k.usable ? _s(k.total) : '—', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.Text(_s(k.abilMod), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5)),
                pw.Text(k.ranks == 0 ? '' : (k.ranks == k.ranks.roundToDouble() ? '${k.ranks.toInt()}' : k.ranks.toStringAsFixed(1)),
                    textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5)),
                pw.Text(() {
                  final m = k.misc.total + k.synergy + k.acp + k.sizeMod;
                  return m == 0 ? '' : _s(m);
                }(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5)),
              ]),
          ],
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(
              tr('■ perícia de classe  ✱ só treinada  ¹ penalidade de armadura  ² penalidade dobrada',
                  '■ class skill  ✱ trained only  ¹ armor check penalty  ² double penalty'),
              style: const pw.TextStyle(fontSize: 5)),
        ),
      ]),
    );
  }

  final attacks = [...s.attacks];
  while (attacks.length < 4) {
    attacks.add(AttackLine('', null, const [], '', '', 0, '', const [], false));
  }

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.all(22),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(
          child: pw.Column(children: [
            pw.Row(children: [
              pw.Expanded(flex: 3, child: _field(ch.name, tr('Nome do personagem', 'Character name'), size: 11)),
              pw.Expanded(flex: 2, child: _field(ch.player, tr('Jogador', 'Player'))),
            ]),
            pw.Row(children: [
              pw.Expanded(flex: 3, child: _field(classes, tr('Classe e nível', 'Class and level'))),
              pw.Expanded(flex: 2, child: _field(race, tr('Raça', 'Race'))),
              pw.Expanded(flex: 1, child: _field(ch.alignment, tr('Tendência', 'Alignment'))),
              pw.Expanded(flex: 2, child: _field(ch.deity, tr('Divindade', 'Deity'))),
            ]),
            pw.Row(children: [
              pw.Expanded(child: _field(_sizeName(s), tr('Tamanho', 'Size'))),
              pw.Expanded(child: _field(ch.age, tr('Idade', 'Age'))),
              pw.Expanded(child: _field(ch.gender, tr('Sexo', 'Gender'))),
              pw.Expanded(child: _field(ch.height, tr('Altura', 'Height'))),
              pw.Expanded(child: _field(ch.weight, tr('Peso', 'Weight'))),
              pw.Expanded(child: _field(ch.eyes, tr('Olhos', 'Eyes'))),
              pw.Expanded(child: _field(ch.hair, tr('Cabelos', 'Hair'))),
              pw.Expanded(child: _field(ch.skin, tr('Pele', 'Skin'))),
            ]),
          ]),
        ),
        pw.SizedBox(width: 8),
        pw.Column(children: [
          pw.Text('DUNGEONS & DRAGONS 3.5', style: pw.TextStyle(font: fonts.title, fontSize: 11)),
          pw.Text(tr('FICHA DE PERSONAGEM', 'CHARACTER RECORD SHEET'), style: const pw.TextStyle(fontSize: 7, letterSpacing: 1.5)),
        ]),
      ]),
      pw.SizedBox(height: 6),
      pw.Expanded(
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
            width: 330,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [abilities()]),
              pw.SizedBox(height: 4),
              defense(),
              pw.SizedBox(height: 6),
              saves(),
              pw.SizedBox(height: 6),
              for (final a in attacks.take(5)) attack(a.name.isEmpty ? null : a),
            ]),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(child: skills()),
        ]),
      ),
      pw.Text('Grimório 3.5 · ${DateTime.now().toIso8601String().substring(0, 10)}', style: const pw.TextStyle(fontSize: 5)),
    ]),
  ));

  // ------------------------------------------------------------------ página 2
  final armor = s.armor;
  final shield = s.shield;
  final possessions = ch.items.where((i) => !identical(i, armor) && !identical(i, shield)).toList();
  final feats = <String>[for (final l in ch.levels) ...l.feats.map((f) => f.name)];
  final str = s.abilities['str']!.total;
  final heavy = s.encumbrance.heavy;

  pw.Widget gearBox(Item? it, String title, {required bool isShield}) {
    final d = isShield ? s.shieldDef : s.armorDef;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 0.8)),
      child: pw.Column(children: [
        pw.Row(children: [
          pw.Expanded(flex: 4, child: _header(title)),
          pw.Expanded(flex: 2, child: _header(tr('TIPO', 'TYPE'))),
          pw.Expanded(flex: 2, child: _header(tr('BÔNUS CA', 'AC BONUS'))),
          pw.Expanded(flex: 2, child: _header(tr('DES MÁX', 'MAX DEX'))),
        ]),
        pw.Container(
          height: 13,
          child: pw.Row(children: [
            pw.Expanded(flex: 4, child: pw.Padding(padding: const pw.EdgeInsets.only(left: 3), child: pw.Text(it == null ? '' : '${it.name}${it.enhancement > 0 ? ' +${it.enhancement}' : ''}', style: const pw.TextStyle(fontSize: 8)))),
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text(it == null ? '' : (it.category ?? d?.category ?? ''), style: const pw.TextStyle(fontSize: 7)))),
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text(it == null ? '' : '+${(it.armorBonus ?? d?.bonus ?? 0) + it.enhancement}', style: const pw.TextStyle(fontSize: 8)))),
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text(it == null ? '' : '${it.maxDex ?? d?.maxDex ?? '—'}', style: const pw.TextStyle(fontSize: 8)))),
          ]),
        ),
        pw.Row(children: [
          pw.Expanded(flex: 2, child: _header(tr('PENALIDADE', 'CHECK PENALTY'))),
          pw.Expanded(flex: 2, child: _header(tr('FALHA ARCANA', 'SPELL FAILURE'))),
          pw.Expanded(flex: 1, child: _header(tr('PESO', 'WEIGHT'))),
          pw.Expanded(flex: 5, child: _header(tr('PROPRIEDADES', 'SPECIAL PROPERTIES'))),
        ]),
        pw.Container(
          height: 13,
          child: pw.Row(children: [
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text(it == null ? '' : '${it.acp ?? d?.acp ?? 0}', style: const pw.TextStyle(fontSize: 8)))),
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text(it == null ? '' : '${it.asf ?? d?.asf ?? 0}%', style: const pw.TextStyle(fontSize: 8)))),
            pw.Expanded(flex: 1, child: pw.Center(child: pw.Text(it == null ? '' : it.weight.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 8)))),
            pw.Expanded(flex: 5, child: pw.Text(it == null ? '' : it.properties.join(', '), style: const pw.TextStyle(fontSize: 7))),
          ]),
        ),
      ]),
    );
  }

  pw.Widget listBox(String title, List<String> lines, {int minLines = 8, double size = 7}) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          _header(title),
          for (var i = 0; i < (lines.length > minLines ? lines.length : minLines); i++)
            pw.Container(
              height: 11,
              alignment: pw.Alignment.bottomLeft,
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _grey, width: 0.5))),
              child: pw.Text(i < lines.length ? lines[i] : '', maxLines: 1, style: pw.TextStyle(fontSize: size)),
            ),
        ]),
      );

  final casterBlocks = <pw.Widget>[];
  for (final ci in s.casters) {
    final st = ch.casters[ci.cls.id];
    casterBlocks.add(pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _header('${tr('MAGIAS', 'SPELLS')} — ${ci.cls.displayName(Lang.isPt)} (${tr('NC', 'CL')} ${ci.casterLevel})'),
        if (st != null && (st.domains.isNotEmpty || st.specialistSchool != null))
          pw.Text('${tr('Domínios/Escola', 'Domains/School')}: ${[...st.domains, if (st.specialistSchool != null) st.specialistSchool!].join(', ')}',
              style: const pw.TextStyle(fontSize: 6.5)),
        pw.Table(
          border: pw.TableBorder.all(color: _ink, width: 0.5),
          children: [
            pw.TableRow(children: [
              for (final t in [tr('NÍVEL', 'LEVEL'), tr('CONHEC.', 'KNOWN'), tr('CD', 'SAVE DC'), tr('POR DIA', 'PER DAY'), tr('BÔNUS', 'BONUS')])
                pw.Padding(padding: const pw.EdgeInsets.all(1), child: pw.Text(t, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold))),
            ]),
            for (final lv in ci.levels.where((l) => l.base >= 0))
              pw.TableRow(children: [
                for (final v in [
                  '${lv.level}',
                  lv.known > 0 ? '${lv.known}' : '',
                  '${lv.dc}',
                  '${lv.perDay + lv.domain + lv.specialist}',
                  lv.bonus > 0 ? '${lv.bonus}' : '',
                ])
                  pw.Text(v, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
              ]),
          ],
        ),
      ]),
    ));
  }

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.all(22),
    build: (ctx) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(
        width: 270,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          _field(ch.campaign, tr('Campanha', 'Campaign')),
          _field('${ch.xp} / ${s.xpNeeded}  (${tr('próximo', 'next')} ${(s.ecl + 1) * s.ecl ~/ 2 * 1000})', tr('Pontos de experiência', 'Experience points')),
          pw.SizedBox(height: 4),
          _header(tr('EQUIPAMENTO', 'GEAR')),
          pw.SizedBox(height: 2),
          gearBox(armor, tr('ARMADURA', 'ARMOR/PROTECTIVE ITEM'), isShield: false),
          gearBox(shield, tr('ESCUDO', 'SHIELD/PROTECTIVE ITEM'), isShield: true),
          _header(tr('OUTRAS POSSES', 'OTHER POSSESSIONS')),
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _grey, width: 0.4)),
            columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FixedColumnWidth(26)},
            children: [
              for (final it in possessions.take(24))
                pw.TableRow(children: [
                  pw.Text('${it.qty > 1 ? '${it.qty}× ' : ''}${it.name}${it.enhancement > 0 ? ' +${it.enhancement}' : ''}${it.equipped ? ' (E)' : ''}',
                      maxLines: 1, style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(it.totalWeight == 0 ? '' : it.totalWeight.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7)),
                ]),
            ],
          ),
          if (possessions.length > 24) pw.Text('+${possessions.length - 24} ${tr('itens (ver anotações)', 'items (see notes)')}', style: const pw.TextStyle(fontSize: 6)),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('${tr('PESO TOTAL CARREGADO', 'TOTAL WEIGHT CARRIED')}: ${s.encumbrance.carried.toStringAsFixed(1)} lb',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            for (final p in [
              ('${s.encumbrance.light}', tr('CARGA LEVE', 'LIGHT LOAD')),
              ('${s.encumbrance.medium}', tr('CARGA MÉDIA', 'MEDIUM LOAD')),
              ('$heavy', tr('CARGA PESADA', 'HEAVY LOAD')),
              ('$heavy', tr('ERGUER ACIMA DA CABEÇA', 'LIFT OVER HEAD')),
              ('${heavy * 2}', tr('ERGUER DO CHÃO', 'LIFT OFF GROUND')),
              ('${heavy * 5}', tr('EMPURRAR/ARRASTAR', 'PUSH OR DRAG')),
            ])
              pw.Column(children: [_box(p.$1, w: 38, h: 16, size: 8), _cap(p.$2, w: 40)]),
          ]),
          pw.Text('${tr('For', 'Str')} $str · ${tr('carga atual', 'current load')}: ${s.encumbrance.load}', style: const pw.TextStyle(fontSize: 6)),
          pw.SizedBox(height: 4),
          _header(tr('DINHEIRO', 'MONEY')),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Text('PL/PP ${ch.money['pp'] ?? 0}    PO/GP ${ch.money['gp'] ?? 0}    PP/SP ${ch.money['sp'] ?? 0}    PC/CP ${ch.money['cp'] ?? 0}',
                style: const pw.TextStyle(fontSize: 8)),
          ),
        ]),
      ),
      pw.SizedBox(width: 8),
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          listBox(tr('TALENTOS', 'FEATS'), feats, minLines: 12),
          listBox(tr('HABILIDADES ESPECIAIS', 'SPECIAL ABILITIES'), [
            ...s.features,
            if (s.race?.vision.isNotEmpty == true) s.race!.vision,
            for (final r in s.resources) '${r.name}: ${r.max}/${r.per == 'day' ? tr('dia', 'day') : r.per}',
          ], minLines: 12, size: 6.5),
          listBox(tr('IDIOMAS', 'LANGUAGES'), [ch.languages.isEmpty ? (s.race?.languages ?? '') : ch.languages], minLines: 2),
          ...casterBlocks,
          if (s.spellFailure > 0)
            pw.Text('${tr('Falha arcana', 'Arcane spell failure')}: ${s.spellFailure}%', style: const pw.TextStyle(fontSize: 7)),
        ]),
      ),
    ]),
  ));

  // ------------------------------------------------------------------ páginas extras
  final spellLines = <pw.Widget>[];
  for (final cs in ch.casters.values) {
    if (cs.known.isEmpty && cs.prepared.isEmpty) continue;
    final cls = s.classDefs[cs.classId];
    spellLines.add(_header('${tr('Lista de magias', 'Spell list')} — ${cls?.displayName(Lang.isPt) ?? cs.classId}'));
    final levels = <int>{...cs.known.map((k) => k.level), ...cs.prepared.map((p) => p.level)}.toList()..sort();
    for (final l in levels) {
      final known = cs.known.where((k) => k.level == l).map((k) => '${k.name}${k.book != null ? ' (${k.book})' : ''}').toList()..sort();
      final prep = cs.prepared.where((p) => p.level == l).map((p) => '${p.used ? '☒' : '☐'} ${p.name}').toList();
      spellLines.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('${tr('Nível', 'Level')} $l', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          if (known.isNotEmpty) pw.Text(known.join(' · '), style: const pw.TextStyle(fontSize: 8)),
          if (prep.isNotEmpty) pw.Text('${tr('Preparadas', 'Prepared')}: ${prep.join('  ')}', style: const pw.TextStyle(fontSize: 8)),
        ]),
      ));
    }
  }
  final notes = [
    if (ch.appearance.isNotEmpty) (tr('Aparência', 'Appearance'), ch.appearance),
    if (ch.background.isNotEmpty) (tr('Histórico', 'Background'), ch.background),
    if (ch.notes.isNotEmpty) (tr('Anotações', 'Notes'), ch.notes),
  ];
  if (spellLines.isNotEmpty || notes.isNotEmpty || ch.buffs.isNotEmpty || ch.conditions.isNotEmpty) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        ...spellLines,
        if (ch.buffs.isNotEmpty || ch.conditions.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _header(tr('Efeitos e condições ativos', 'Active effects and conditions')),
          for (final b in ch.buffs.where((b) => b.active))
            pw.Text('• ${b.name}${b.roundsLeft != null ? ' (${b.roundsLeft} ${tr('rodadas', 'rounds')})' : ''}', style: const pw.TextStyle(fontSize: 8)),
          for (final c in ch.conditions)
            pw.Text('• ${s.rules.conditions[c]?.displayName(Lang.isPt) ?? c}', style: const pw.TextStyle(fontSize: 8)),
        ],
        for (final n in notes) ...[
          pw.SizedBox(height: 8),
          _header(n.$1),
          pw.Paragraph(text: n.$2, style: const pw.TextStyle(fontSize: 9)),
        ],
      ],
    ));
  }
  return doc.save();
}

String _attackSeq(int bab) {
  var n = bab <= 0 ? 1 : (bab - 1) ~/ 5 + 1;
  if (n > 4) n = 4;
  return [for (var i = 0; i < n; i++) _s(bab - 5 * i)].join('/');
}

/// Pergunta se o usuário quer imprimir ou salvar o PDF.
Future<void> printSheet(BuildContext context, Sheet s) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(title: Text(tr('Ficha imprimível', 'Printable sheet')), children: [
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'print'), child: Text(tr('Visualizar / imprimir', 'Preview / print'))),
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'save'), child: Text(tr('Salvar PDF…', 'Save PDF…'))),
    ]),
  );
  if (choice == null) return;
  final bytes = await buildSheetPdf(s);
  final name = '${s.ch.name.isEmpty ? 'ficha' : s.ch.name}.pdf';
  if (choice == 'print') {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  } else {
    final out = await FilePicker.platform.saveFile(dialogTitle: tr('Salvar PDF', 'Save PDF'), fileName: name);
    if (out == null) return;
    await File(out).writeAsBytes(bytes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Salvo em', 'Saved to')} $out')));
    }
  }
}
