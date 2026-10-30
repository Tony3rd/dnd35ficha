import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../model/character.dart';
import '../print/sheet_pdf.dart';
import 'portrait.dart';
import 'tab_effects.dart';
import 'tab_feats.dart';
import 'tab_inventory.dart';
import 'tab_levels.dart';
import 'tab_notes.dart';
import 'tab_skills.dart';
import 'tab_spells.dart';
import 'tab_summary.dart';
import 'widgets.dart';

class CharacterScreen extends StatefulWidget {
  final Character character;
  const CharacterScreen({super.key, required this.character});
  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  late CharacterController ctl;

  @override
  void initState() {
    super.initState();
    ctl = CharacterController(context.read<AppState>(), widget.character);
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (tr('Resumo', 'Summary'), Icons.dashboard_outlined, const SummaryTab()),
      (tr('Perícias', 'Skills'), Icons.psychology_outlined, const SkillsTab()),
      (tr('Talentos', 'Feats'), Icons.star_outline, const FeatsTab()),
      (tr('Magias', 'Spells'), Icons.auto_awesome_outlined, const SpellsTab()),
      (tr('Inventário', 'Inventory'), Icons.backpack_outlined, const InventoryTab()),
      (tr('Efeitos', 'Effects'), Icons.bolt_outlined, const EffectsTab()),
      (tr('Níveis', 'Levels'), Icons.stairs_outlined, const LevelsTab()),
      (tr('Notas', 'Notes'), Icons.edit_note, const NotesTab()),
    ];
    return ChangeNotifierProvider.value(
      value: ctl,
      child: DefaultTabController(
        length: tabs.length,
        child: Consumer<CharacterController>(builder: (context, c, _) {
          final s = c.sheet;
          return Scaffold(
            appBar: AppBar(
              title: Row(children: [
                PortraitAvatar(portrait: c.ch.portrait, name: c.ch.name, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.ch.name.isEmpty ? tr('(sem nome)', '(unnamed)') : c.ch.name, overflow: TextOverflow.ellipsis),
                    Text(context.read<AppState>().summaryOf(c.ch),
                        style: Theme.of(context).textTheme.labelSmall, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
              actions: [
                IconButton(
                  tooltip: tr('Próxima rodada (durações)', 'Next round (durations)'),
                  icon: const Icon(Icons.skip_next),
                  onPressed: () {
                    late List<String> exp;
                    c.update((ch) => exp = ch.nextRound());
                    if (exp.isNotEmpty) toast(context, '${tr('Terminou', 'Expired')}: ${exp.join(', ')}');
                  },
                ),
                IconButton(
                  tooltip: tr('Descansar (8 horas)', 'Rest (8 hours)'),
                  icon: const Icon(Icons.bedtime_outlined),
                  onPressed: () async {
                    if (await confirm(context, tr('Descansar 8 horas? Recupera PV pelo nível, magias e usos diários.',
                        'Rest 8 hours? Recovers HP by level, spells and daily uses.'))) {
                      c.update((ch) => ch.restOvernight());
                    }
                  },
                ),
                IconButton(
                  tooltip: tr('Ficha para impressão (PDF)', 'Printable sheet (PDF)'),
                  icon: const Icon(Icons.print_outlined),
                  onPressed: () => printSheet(context, s),
                ),
                IconButton(
                  tooltip: tr('Salvar', 'Save'),
                  icon: Icon(c.dirty ? Icons.save : Icons.save_outlined),
                  onPressed: () async {
                    await c.saveNow();
                    if (context.mounted) toast(context, tr('Ficha salva.', 'Saved.'));
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final t in tabs) Tab(icon: Icon(t.$2, size: 18), text: t.$1, height: 52)],
              ),
            ),
            body: TabBarView(children: [for (final t in tabs) t.$3]),
          );
        }),
      ),
    );
  }
}
