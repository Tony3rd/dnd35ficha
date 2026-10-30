import 'dart:math';

/// Rolador de dados com notação padrão:
///   1d20+5, 2d6+1d4-1, 4d6kh3 (mantém os 3 maiores), 2d20kl1, d%, 3d6x2? (não)
class DiceTerm {
  final int sign; // +1 ou -1
  final int count;
  final int sides; // 0 = constante
  final int value; // usado quando sides == 0
  final int keepHigh; // 0 = todos
  final int keepLow;
  DiceTerm({
    required this.sign,
    this.count = 0,
    this.sides = 0,
    this.value = 0,
    this.keepHigh = 0,
    this.keepLow = 0,
  });
  bool get isConstant => sides == 0;
}

class TermResult {
  final DiceTerm term;
  final List<int> rolls;
  final List<bool> kept;
  final int subtotal;
  TermResult(this.term, this.rolls, this.kept, this.subtotal);
}

class RollResult {
  final String expression;
  final String label;
  final List<TermResult> terms;
  final int total;
  final DateTime time;
  RollResult(this.expression, this.label, this.terms, this.total) : time = DateTime.now();

  /// Valor natural do d20 quando a rolagem tem exatamente um d20.
  int? get natural20 {
    final d20s = terms.where((t) => t.term.sides == 20 && t.term.count == 1).toList();
    if (d20s.length != 1) return null;
    return d20s.first.rolls.first;
  }

  String get breakdown {
    final b = StringBuffer();
    for (var i = 0; i < terms.length; i++) {
      final t = terms[i];
      final s = t.term.sign < 0 ? ' - ' : (i == 0 ? '' : ' + ');
      b.write(s);
      if (t.term.isConstant) {
        b.write(t.term.value);
      } else {
        final parts = <String>[];
        for (var j = 0; j < t.rolls.length; j++) {
          parts.add(t.kept[j] ? '${t.rolls[j]}' : '(${t.rolls[j]})');
        }
        b.write('${t.term.count}d${t.term.sides}[${parts.join(',')}]');
      }
    }
    return b.toString();
  }
}

class DiceParseException implements Exception {
  final String message;
  DiceParseException(this.message);
  @override
  String toString() => message;
}

class Dice {
  final Random _rng;
  Dice([Random? rng]) : _rng = rng ?? Random();

  static final _termRe = RegExp(r'^(\d*)d(\d+|%)(?:(kh|kl)(\d+))?$');

  static List<DiceTerm> parse(String expr) {
    final cleaned = expr.replaceAll(' ', '').toLowerCase().replaceAll('–', '-');
    if (cleaned.isEmpty) throw DiceParseException('Expressão vazia');
    final terms = <DiceTerm>[];
    var i = 0;
    var sign = 1;
    final buf = StringBuffer();
    void flush() {
      final s = buf.toString();
      buf.clear();
      if (s.isEmpty) throw DiceParseException('Termo vazio em "$expr"');
      final n = int.tryParse(s);
      if (n != null) {
        terms.add(DiceTerm(sign: sign, value: n));
        return;
      }
      final m = _termRe.firstMatch(s);
      if (m == null) throw DiceParseException('Termo inválido: "$s"');
      final count = m.group(1)!.isEmpty ? 1 : int.parse(m.group(1)!);
      final sides = m.group(2) == '%' ? 100 : int.parse(m.group(2)!);
      if (count > 1000 || sides > 10000 || sides < 1) {
        throw DiceParseException('Dados demais: "$s"');
      }
      var kh = 0, kl = 0;
      if (m.group(3) == 'kh') kh = int.parse(m.group(4)!);
      if (m.group(3) == 'kl') kl = int.parse(m.group(4)!);
      terms.add(DiceTerm(sign: sign, count: count, sides: sides, keepHigh: kh, keepLow: kl));
    }

    while (i < cleaned.length) {
      final c = cleaned[i];
      if (c == '+' || c == '-') {
        if (buf.isNotEmpty) flush();
        sign = c == '-' ? -1 : 1;
      } else {
        buf.write(c);
      }
      i++;
    }
    flush();
    return terms;
  }

  RollResult roll(String expr, {String label = ''}) {
    final terms = parse(expr);
    final results = <TermResult>[];
    var total = 0;
    for (final t in terms) {
      if (t.isConstant) {
        results.add(TermResult(t, const [], const [], t.sign * t.value));
        total += t.sign * t.value;
        continue;
      }
      final rolls = List<int>.generate(t.count, (_) => _rng.nextInt(t.sides) + 1);
      final kept = List<bool>.filled(rolls.length, true);
      if (t.keepHigh > 0 || t.keepLow > 0) {
        final idx = List<int>.generate(rolls.length, (k) => k);
        idx.sort((a, b) => rolls[a].compareTo(rolls[b]));
        final keepN = min(t.keepHigh > 0 ? t.keepHigh : t.keepLow, rolls.length);
        for (var k = 0; k < kept.length; k++) {
          kept[k] = false;
        }
        final chosen = t.keepHigh > 0 ? idx.reversed.take(keepN) : idx.take(keepN);
        for (final k in chosen) {
          kept[k] = true;
        }
      }
      var sub = 0;
      for (var k = 0; k < rolls.length; k++) {
        if (kept[k]) sub += rolls[k];
      }
      sub *= t.sign;
      total += sub;
      results.add(TermResult(t, rolls, kept, sub));
    }
    return RollResult(expr, label, results, total);
  }

  /// Rolagem de atributos clássica 4d6, descarta o menor.
  List<int> rollAbilityArray({int count = 6}) =>
      List<int>.generate(count, (_) => roll('4d6kh3').total);

  int d(int sides) => _rng.nextInt(sides) + 1;
}
