import 'package:flutter/material.dart';

import '../i18n.dart';

/// Descrições dos campos da ficha, mostradas ao passar o mouse.
/// A chave é o rótulo (em português ou inglês) normalizado por [_norm].
final Map<String, (String, String)> _help = {
  // atributos
  'for': ('Força: ataque e dano corpo a corpo, carga, Escalar, Saltar, Natação.', 'Strength: melee attack and damage, load, Climb, Jump, Swim.'),
  'str': ('Força: ataque e dano corpo a corpo, carga, Escalar, Saltar, Natação.', 'Strength: melee attack and damage, load, Climb, Jump, Swim.'),
  'des': ('Destreza: CA, ataque à distância, Reflexos, iniciativa e perícias de agilidade.', 'Dexterity: AC, ranged attack, Reflex, initiative, agility skills.'),
  'dex': ('Destreza: CA, ataque à distância, Reflexos, iniciativa e perícias de agilidade.', 'Dexterity: AC, ranged attack, Reflex, initiative, agility skills.'),
  'con': ('Constituição: pontos de vida por nível e Fortitude.', 'Constitution: hit points per level and Fortitude.'),
  'int': ('Inteligência: pontos de perícia, idiomas e magias de mago.', 'Intelligence: skill points, languages, wizard spells.'),
  'sab': ('Sabedoria: Vontade, Observar, Ouvir e magias divinas.', 'Wisdom: Will, Spot, Listen, divine spells.'),
  'wis': ('Sabedoria: Vontade, Observar, Ouvir e magias divinas.', 'Wisdom: Will, Spot, Listen, divine spells.'),
  'car': ('Carisma: perícias sociais, expulsar mortos-vivos e magias de feiticeiro/bardo.', 'Charisma: social skills, turning, sorcerer/bard spells.'),
  'cha': ('Carisma: perícias sociais, expulsar mortos-vivos e magias de feiticeiro/bardo.', 'Charisma: social skills, turning, sorcerer/bard spells.'),
  // combate
  'ca': ('Classe de Armadura: 10 + armadura + escudo + Destreza + tamanho + natural + deflexão + outros. Toque ignora armadura, escudo e natural; surpreso ignora Destreza e esquiva. Clique para ver o detalhamento.',
      'Armor Class: 10 + armor + shield + Dex + size + natural + deflection + misc. Click for the breakdown.'),
  'ac': ('Classe de Armadura: 10 + armadura + escudo + Destreza + tamanho + natural + deflexão + outros. Toque ignora armadura, escudo e natural; surpreso ignora Destreza e esquiva. Clique para ver o detalhamento.',
      'Armor Class: 10 + armor + shield + Dex + size + natural + deflection + misc. Click for the breakdown.'),
  'iniciativa': ('Iniciativa: Destreza + bônus (Iniciativa Aprimorada etc.). Clique para rolar.', 'Initiative: Dex + bonuses. Click to roll.'),
  'initiative': ('Iniciativa: Destreza + bônus (Iniciativa Aprimorada etc.). Clique para rolar.', 'Initiative: Dex + bonuses. Click to roll.'),
  'bba': ('Bônus base de ataque: soma das classes; define ataques extras (+6, +11, +16).', 'Base attack bonus: sum of classes; grants extra attacks at +6/+11/+16.'),
  'bab': ('Bônus base de ataque: soma das classes; define ataques extras (+6, +11, +16).', 'Base attack bonus: sum of classes; grants extra attacks at +6/+11/+16.'),
  'agarrar': ('Agarrar: BBA + Força + modificador especial de tamanho. Clique para rolar.', 'Grapple: BAB + Str + special size modifier. Click to roll.'),
  'grapple': ('Agarrar: BBA + Força + modificador especial de tamanho. Clique para rolar.', 'Grapple: BAB + Str + special size modifier. Click to roll.'),
  'desloc': ('Deslocamento terrestre em pés (e metros), já com armadura e carga.', 'Land speed in feet (and meters), after armor and load.'),
  'speed': ('Deslocamento terrestre em pés (e metros), já com armadura e carga.', 'Land speed in feet (and meters), after armor and load.'),
  'rm sr': ('Resistência à magia: o conjurador precisa de 1d20 + nível de conjurador igual ou maior para afetar.', 'Spell resistance.'),
  'falha arc': ('Chance de falha de magia arcana pela armadura e escudo.', 'Arcane spell failure chance from armor and shield.'),
  'arc fail': ('Chance de falha de magia arcana pela armadura e escudo.', 'Arcane spell failure chance from armor and shield.'),
  'fortitude': ('Fortitude: resistência base + Constituição + bônus. Contra veneno, doença e morte. Clique para rolar, segure para detalhes.', 'Fortitude save. Click to roll, hold for details.'),
  'reflexos': ('Reflexos: resistência base + Destreza + bônus. Contra explosões e armadilhas. Clique para rolar, segure para detalhes.', 'Reflex save. Click to roll, hold for details.'),
  'reflex': ('Reflexos: resistência base + Destreza + bônus. Contra explosões e armadilhas. Clique para rolar, segure para detalhes.', 'Reflex save. Click to roll, hold for details.'),
  'vontade': ('Vontade: resistência base + Sabedoria + bônus. Contra encantamentos e ilusões. Clique para rolar, segure para detalhes.', 'Will save. Click to roll, hold for details.'),
  'will': ('Vontade: resistência base + Sabedoria + bônus. Contra encantamentos e ilusões. Clique para rolar, segure para detalhes.', 'Will save. Click to roll, hold for details.'),
  // seções
  'atributos': ('Valores de atributo atuais (clique para rolar um teste, segure para ver de onde vem cada ponto).', 'Current ability scores (click to roll, hold for breakdown).'),
  'abilities': ('Valores de atributo atuais (clique para rolar um teste, segure para ver de onde vem cada ponto).', 'Current ability scores (click to roll, hold for breakdown).'),
  'ataques': ('Ataques calculados com as armas marcadas como equipadas.', 'Attacks computed from equipped weapons.'),
  'attacks': ('Ataques calculados com as armas marcadas como equipadas.', 'Attacks computed from equipped weapons.'),
  'avisos': ('Regras que a ficha não cumpre (pré-requisitos, pontos, XP...). Não impedem salvar.', 'Rules the sheet breaks. They do not block saving.'),
  'warnings': ('Regras que a ficha não cumpre (pré-requisitos, pontos, XP...). Não impedem salvar.', 'Rules the sheet breaks. They do not block saving.'),
  'talentos': ('Talentos escolhidos em cada nível e espaços disponíveis (gerais, raciais e bônus de classe).', 'Feats per level and available slots.'),
  'feats': ('Talentos escolhidos em cada nível e espaços disponíveis (gerais, raciais e bônus de classe).', 'Feats per level and available slots.'),
  // itens
  'nome': ('Nome que aparece na ficha.', 'Name shown on the sheet.'),
  'name': ('Nome que aparece na ficha.', 'Name shown on the sheet.'),
  'qtd': ('Quantidade carregada (multiplica o peso).', 'Quantity carried (multiplies weight).'),
  'qty': ('Quantidade carregada (multiplica o peso).', 'Quantity carried (multiplies weight).'),
  'peso lb': ('Peso de uma unidade em libras (1 lb ≈ 0,45 kg); entra na carga.', 'Weight of one unit in pounds; counts toward load.'),
  'weight lb': ('Peso de uma unidade em libras (1 lb ≈ 0,45 kg); entra na carga.', 'Weight of one unit in pounds; counts toward load.'),
  'custo po': ('Preço em peças de ouro.', 'Price in gold pieces.'),
  'cost gp': ('Preço em peças de ouro.', 'Price in gold pieces.'),
  'melhoria': ('Bônus de melhoria mágico (+1 a +5): soma no ataque e dano da arma, ou na CA da armadura.', 'Magic enhancement bonus (+1 to +5).'),
  'enhancement': ('Bônus de melhoria mágico (+1 a +5): soma no ataque e dano da arma, ou na CA da armadura.', 'Magic enhancement bonus (+1 to +5).'),
  'cargas': ('Usos restantes (varinhas, cajados...). Vazio = sem cargas.', 'Remaining charges. Empty = none.'),
  'charges': ('Usos restantes (varinhas, cajados...). Vazio = sem cargas.', 'Remaining charges. Empty = none.'),
  'arma base': ('Arma da tabela de onde vêm dano, decisivo e categoria (ex.: Longsword).', 'Weapon from the table providing damage, critical and category.'),
  'base weapon': ('Arma da tabela de onde vêm dano, decisivo e categoria (ex.: Longsword).', 'Weapon from the table providing damage, critical and category.'),
  'dano sobrescreve': ('Dano personalizado (ex.: 2d6). Vazio = usa o da arma base ajustado ao tamanho.', 'Custom damage. Empty = base weapon by size.'),
  'damage override': ('Dano personalizado (ex.: 2d6). Vazio = usa o da arma base ajustado ao tamanho.', 'Custom damage. Empty = base weapon by size.'),
  'ameaca ex 19': ('Menor resultado natural do d20 que ameaça decisivo (19 = 19–20).', 'Lowest natural d20 roll that threatens a critical.'),
  'threat eg 19': ('Menor resultado natural do d20 que ameaça decisivo (19 = 19–20).', 'Lowest natural d20 roll that threatens a critical.'),
  'mult ex 3': ('Multiplicador do dano no decisivo.', 'Critical damage multiplier.'),
  'mult eg 3': ('Multiplicador do dano no decisivo.', 'Critical damage multiplier.'),
  'incremento pes': ('Incremento de distância: −2 no ataque a cada incremento além do primeiro.', 'Range increment: −2 per increment beyond the first.'),
  'range ft': ('Incremento de distância: −2 no ataque a cada incremento além do primeiro.', 'Range increment: −2 per increment beyond the first.'),
  'for composto': ('Arco composto: bônus máximo de Força aplicado ao dano.', 'Composite bow: maximum Strength bonus to damage.'),
  'composite str': ('Arco composto: bônus máximo de Força aplicado ao dano.', 'Composite bow: maximum Strength bonus to damage.'),
  'armadura base': ('Armadura da tabela de onde vêm bônus, Des máxima, penalidade e falha arcana.', 'Armor from the table providing bonus, max Dex, penalty and spell failure.'),
  'base armor': ('Armadura da tabela de onde vêm bônus, Des máxima, penalidade e falha arcana.', 'Armor from the table providing bonus, max Dex, penalty and spell failure.'),
  'bonus sobrescreve': ('Bônus de armadura personalizado. Vazio = o da armadura base.', 'Custom armor bonus. Empty = base armor.'),
  'bonus override': ('Bônus de armadura personalizado. Vazio = o da armadura base.', 'Custom armor bonus. Empty = base armor.'),
  'des max': ('Bônus máximo de Destreza na CA permitido pela armadura.', 'Maximum Dex bonus to AC allowed by the armor.'),
  'max dex': ('Bônus máximo de Destreza na CA permitido pela armadura.', 'Maximum Dex bonus to AC allowed by the armor.'),
  'penalidade': ('Penalidade de armadura em perícias de Força e Destreza (número negativo ou positivo, o app aplica como penalidade).', 'Armor check penalty on Str/Dex skills.'),
  'check penalty': ('Penalidade de armadura em perícias de Força e Destreza.', 'Armor check penalty on Str/Dex skills.'),
  'falha arcana': ('Chance de falha de magia arcana (%) ao conjurar com componente gestual.', 'Arcane spell failure (%) for somatic spells.'),
  'spell failure': ('Chance de falha de magia arcana (%) ao conjurar com componente gestual.', 'Arcane spell failure (%).'),
  'propriedades separadas por virgula keen flaming': ('Propriedades especiais da arma ou armadura (afiada, flamejante...). Algumas entram no cálculo.', 'Special properties; some are calculated.'),
  'properties comma separated keen flaming': ('Propriedades especiais da arma ou armadura (afiada, flamejante...). Algumas entram no cálculo.', 'Special properties; some are calculated.'),
  'notas': ('Anotações livres.', 'Free notes.'),
  'notes': ('Anotações livres.', 'Free notes.'),
  // identidade
  'sexo': ('Sexo ou gênero do personagem.', 'Character gender.'),
  'gender': ('Sexo ou gênero do personagem.', 'Character gender.'),
  'idade': ('Idade em anos (faixas de idade alteram atributos — Livro do Jogador, cap. 6).', 'Age in years (age categories change abilities).'),
  'age': ('Idade em anos (faixas de idade alteram atributos — Livro do Jogador, cap. 6).', 'Age in years (age categories change abilities).'),
  'altura': ('Altura do personagem.', 'Character height.'),
  'height': ('Altura do personagem.', 'Character height.'),
  'peso': ('Peso do personagem (não entra na carga).', 'Character weight (not counted in load).'),
  'weight': ('Peso do personagem (não entra na carga).', 'Character weight (not counted in load).'),
  'olhos': ('Cor dos olhos.', 'Eye color.'),
  'eyes': ('Cor dos olhos.', 'Eye color.'),
  'cabelos': ('Cor e estilo do cabelo.', 'Hair color and style.'),
  'hair': ('Cor e estilo do cabelo.', 'Hair color and style.'),
  'pele': ('Cor da pele.', 'Skin color.'),
  'skin': ('Cor da pele.', 'Skin color.'),
  'aparencia': ('Descrição física, roupas e trejeitos.', 'Physical description.'),
  'appearance': ('Descrição física, roupas e trejeitos.', 'Physical description.'),
  'historico': ('História do personagem antes da campanha.', 'Character background.'),
  'background': ('História do personagem antes da campanha.', 'Character background.'),
  'anotacoes de jogo': ('Anotações das sessões: missões, NPCs, pistas.', 'Session notes.'),
  'session notes': ('Anotações das sessões: missões, NPCs, pistas.', 'Session notes.'),
  'pontos de vida': ('PV atuais / máximos, PV temporários e dano não letal. Os máximos vêm dos dados de vida + Constituição.', 'Current/max HP, temporary HP and nonlethal damage.'),
  'hit points': ('PV atuais / máximos, PV temporários e dano não letal. Os máximos vêm dos dados de vida + Constituição.', 'Current/max HP, temporary HP and nonlethal damage.'),
};

String _norm(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Descrição de um campo pelo rótulo, ou null.
String? fieldHelp(String label) {
  final h = _help[_norm(label)];
  return h == null ? null : tr(h.$1, h.$2);
}

/// Envolve [child] numa dica com a descrição do campo [label], se existir
/// (ou com [help], quando informado).
Widget withHelp(String label, Widget child, {String? help}) {
  final m = help ?? fieldHelp(label);
  if (m == null || m.isEmpty) return child;
  return Tooltip(message: m, waitDuration: const Duration(milliseconds: 400), child: child);
}
