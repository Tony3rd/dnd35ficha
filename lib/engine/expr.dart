import 'dart:math' as math;

/// Avaliador de fórmulas usadas em efeitos, recursos e homebrew.
/// Exemplos: "3", "@abil.cha.mod", "floor(@class.barbarian/4)+1",
///           "min(@cl, 10)", "max(1, @abil.wis.mod)", "@level >= 5 ? 2 : 1" (não)
/// Variáveis começam com '@' e podem conter letras, números, '.', '_' e '-'.
typedef VarResolver = num Function(String name);

class ExprException implements Exception {
  final String message;
  ExprException(this.message);
  @override
  String toString() => 'Fórmula inválida: $message';
}

class Expr {
  final String src;
  int _p = 0;
  final VarResolver _vars;
  Expr._(this.src, this._vars);

  static num eval(String src, VarResolver vars) {
    final s = src.trim();
    if (s.isEmpty) return 0;
    final direct = num.tryParse(s);
    if (direct != null) return direct;
    final e = Expr._(s, vars);
    final v = e._expr();
    e._ws();
    if (e._p != s.length) throw ExprException('caractere inesperado em "${s.substring(e._p)}"');
    return v;
  }

  static int evalInt(String src, VarResolver vars) {
    try {
      return eval(src, vars).floor();
    } on ExprException {
      return 0;
    }
  }

  /// Lista as variáveis referenciadas (útil para validar homebrew).
  static Set<String> variables(String src) =>
      RegExp(r'@([A-Za-z0-9_.\-]+)').allMatches(src).map((m) => m.group(1)!).toSet();

  void _ws() {
    while (_p < src.length && (src[_p] == ' ' || src[_p] == '\t')) {
      _p++;
    }
  }

  bool _eat(String c) {
    _ws();
    if (_p < src.length && src.startsWith(c, _p)) {
      _p += c.length;
      return true;
    }
    return false;
  }

  num _expr() {
    var v = _term();
    while (true) {
      if (_eat('+')) {
        v = v + _term();
      } else if (_eat('-')) {
        v = v - _term();
      } else {
        return v;
      }
    }
  }

  num _term() {
    var v = _unary();
    while (true) {
      if (_eat('*')) {
        v = v * _unary();
      } else if (_eat('/')) {
        final d = _unary();
        v = d == 0 ? 0 : v / d;
      } else {
        return v;
      }
    }
  }

  num _unary() {
    if (_eat('-')) return -_unary();
    if (_eat('+')) return _unary();
    return _primary();
  }

  num _primary() {
    _ws();
    if (_eat('(')) {
      final v = _expr();
      if (!_eat(')')) throw ExprException('falta ")"');
      return v;
    }
    if (_p >= src.length) throw ExprException('fim inesperado');
    final c = src[_p];
    if (c == '@') {
      _p++;
      final start = _p;
      while (_p < src.length && RegExp(r'[A-Za-z0-9_.\-]').hasMatch(src[_p])) {
        // '-' só faz parte do nome se seguido de letra (ex.: @skill.move-silently)
        if (src[_p] == '-' && (_p + 1 >= src.length || !RegExp(r'[A-Za-z]').hasMatch(src[_p + 1]))) {
          break;
        }
        _p++;
      }
      final name = src.substring(start, _p);
      if (name.endsWith('.')) throw ExprException('variável incompleta "$name"');
      return _vars(name);
    }
    if (RegExp(r'[0-9.]').hasMatch(c)) {
      final start = _p;
      while (_p < src.length && RegExp(r'[0-9.]').hasMatch(src[_p])) {
        _p++;
      }
      return num.parse(src.substring(start, _p));
    }
    if (RegExp(r'[A-Za-z]').hasMatch(c)) {
      final start = _p;
      while (_p < src.length && RegExp(r'[A-Za-z]').hasMatch(src[_p])) {
        _p++;
      }
      final fn = src.substring(start, _p).toLowerCase();
      if (!_eat('(')) throw ExprException('esperado "(" após $fn');
      final args = <num>[];
      if (!_eat(')')) {
        do {
          args.add(_expr());
        } while (_eat(','));
        if (!_eat(')')) throw ExprException('falta ")" em $fn');
      }
      return _call(fn, args);
    }
    throw ExprException('símbolo inesperado "$c"');
  }

  num _call(String fn, List<num> a) {
    num arg(int i) => i < a.length ? a[i] : 0;
    switch (fn) {
      case 'min':
        return a.isEmpty ? 0 : a.reduce(math.min);
      case 'max':
        return a.isEmpty ? 0 : a.reduce(math.max);
      case 'floor':
        return arg(0).floor();
      case 'ceil':
        return arg(0).ceil();
      case 'round':
        return arg(0).round();
      case 'abs':
        return arg(0).abs();
      case 'if': // if(cond, a, b) — cond > 0 é verdadeiro
        return arg(0) > 0 ? arg(1) : arg(2);
      case 'gte':
        return arg(0) >= arg(1) ? 1 : 0;
      default:
        throw ExprException('função desconhecida "$fn"');
    }
  }
}
