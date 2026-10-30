import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolve onde ficam os dados. No Windows/Linux o app é *portátil*: tudo fica
/// em `data/` ao lado do executável (funciona em pendrive). Se essa pasta não
/// puder ser escrita, cai para a pasta de dados do usuário. No Android usa a
/// pasta de documentos do app.
class AppPaths {
  late final Directory root;
  late final bool portable;

  Directory get characters => Directory(p.join(root.path, 'characters'));
  Directory get homebrew => Directory(p.join(root.path, 'homebrew'));
  Directory get exports => Directory(p.join(root.path, 'exports'));
  File get rulesDb => File(p.join(root.path, 'rules.sqlite'));
  File get settings => File(p.join(root.path, 'settings.json'));

  static Future<AppPaths> init() async {
    final a = AppPaths();
    Directory? dir;
    var portable = false;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final candidate = Directory(p.join(exeDir.path, 'data'));
      if (await _writable(candidate)) {
        dir = candidate;
        portable = true;
      }
    }
    dir ??= Directory(p.join((await getApplicationDocumentsDirectory()).path, 'Grimorio35'));
    a.root = dir;
    a.portable = portable;
    for (final d in [a.root, a.characters, a.homebrew, a.exports]) {
      if (!await d.exists()) await d.create(recursive: true);
    }
    return a;
  }

  static Future<bool> _writable(Directory d) async {
    try {
      if (!await d.exists()) await d.create(recursive: true);
      final f = File(p.join(d.path, '.write_test'));
      await f.writeAsString('ok');
      await f.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
