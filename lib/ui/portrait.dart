import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../i18n.dart';
import 'widgets.dart';

/// Decodifica o retrato salvo na ficha (PNG em base64).
Uint8List? portraitBytes(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

/// Reduz a imagem (lado maior até [maxSide] px) e converte para PNG,
/// para a ficha XML não ficar enorme.
Future<String?> encodePortrait(Uint8List raw, {int maxSide = 700}) async {
  final probe = await ui.instantiateImageCodec(raw);
  final first = (await probe.getNextFrame()).image;
  final w = first.width, h = first.height;
  first.dispose();
  int? tw, th;
  if (w >= h && w > maxSide) tw = maxSide;
  if (h > w && h > maxSide) th = maxSide;
  final codec = await ui.instantiateImageCodec(raw, targetWidth: tw, targetHeight: th);
  final img = (await codec.getNextFrame()).image;
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  if (data == null) return null;
  return base64Encode(data.buffer.asUint8List());
}

/// Avatar circular pequeno (listas e barra de título).
class PortraitAvatar extends StatelessWidget {
  final String? portrait;
  final String name;
  final double radius;
  const PortraitAvatar({super.key, required this.portrait, required this.name, this.radius = 20});
  @override
  Widget build(BuildContext context) {
    final b = portraitBytes(portrait);
    if (b == null) {
      return CircleAvatar(radius: radius, child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()));
    }
    return CircleAvatar(radius: radius, backgroundImage: MemoryImage(b));
  }
}

/// Campo de retrato/desenho com escolher, trocar e remover.
class PortraitField extends StatelessWidget {
  final String? portrait;
  final ValueChanged<String?> onChanged;
  final double size;
  const PortraitField({super.key, required this.portrait, required this.onChanged, this.size = 180});

  Future<void> _pick(BuildContext context) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = r?.files.single.bytes;
    if (bytes == null) return;
    try {
      final enc = await encodePortrait(bytes);
      if (enc != null) onChanged(enc);
    } catch (e) {
      if (context.mounted) toast(context, tr('Não foi possível ler a imagem: $e', 'Could not read image: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = portraitBytes(portrait);
    final scheme = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size * 1.25,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.secondary.withValues(alpha: 0.6), width: 1.5),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          clipBehavior: Clip.antiAlias,
          child: b == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: scheme.secondary),
                  const SizedBox(height: 6),
                  Text(tr('Foto ou desenho', 'Photo or drawing'), textAlign: TextAlign.center),
                ])
              : Image.memory(b, fit: BoxFit.cover),
        ),
      ),
      if (b != null)
        Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(onPressed: () => _pick(context), child: Text(tr('Trocar', 'Change'))),
          TextButton(onPressed: () => onChanged(null), child: Text(tr('Remover', 'Remove'))),
        ]),
    ]);
  }
}
