import 'dart:convert';
import 'dart:io';

class Settings {
  String language; // pt | en
  String defaultVersionPolicy; // ask | newest
  Set<String>? defaultBooks; // null = todos
  bool darkMode;
  String hpMethod; // max | average | roll
  int pointBuy;

  Settings({
    this.language = 'pt',
    this.defaultVersionPolicy = 'ask',
    this.defaultBooks,
    this.darkMode = true,
    this.hpMethod = 'average',
    this.pointBuy = 28,
  });

  static Future<Settings> load(File f) async {
    try {
      if (!await f.exists()) return Settings();
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return Settings(
        language: (j['language'] as String?) ?? 'pt',
        defaultVersionPolicy: (j['versionPolicy'] as String?) ?? 'ask',
        defaultBooks: (j['books'] as List?)?.map((e) => '$e').toSet(),
        darkMode: j['dark'] != false,
        hpMethod: (j['hpMethod'] as String?) ?? 'average',
        pointBuy: (j['pointBuy'] as num?)?.toInt() ?? 28,
      );
    } catch (_) {
      return Settings();
    }
  }

  Future<void> save(File f) async {
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'language': language,
      'versionPolicy': defaultVersionPolicy,
      if (defaultBooks != null) 'books': defaultBooks!.toList(),
      'dark': darkMode,
      'hpMethod': hpMethod,
      'pointBuy': pointBuy,
    }));
  }
}
