/// Interface bilíngue. Os textos ficam junto do código: `tr('Salvar', 'Save')`.
/// O idioma é trocado em Configurações e a árvore inteira é reconstruída.
class Lang {
  static String code = 'pt';
  static bool get isPt => code == 'pt';
}

String tr(String pt, String en) => Lang.isPt ? pt : en;

const abilityNamesPt = {
  'str': 'Força', 'dex': 'Destreza', 'con': 'Constituição',
  'int': 'Inteligência', 'wis': 'Sabedoria', 'cha': 'Carisma',
};
const abilityNamesEn = {
  'str': 'Strength', 'dex': 'Dexterity', 'con': 'Constitution',
  'int': 'Intelligence', 'wis': 'Wisdom', 'cha': 'Charisma',
};
const abilityAbbrPt = {'str': 'FOR', 'dex': 'DES', 'con': 'CON', 'int': 'INT', 'wis': 'SAB', 'cha': 'CAR'};
const abilityAbbrEn = {'str': 'STR', 'dex': 'DEX', 'con': 'CON', 'int': 'INT', 'wis': 'WIS', 'cha': 'CHA'};

String abilityName(String id) => (Lang.isPt ? abilityNamesPt : abilityNamesEn)[id] ?? id;
String abilityAbbr(String id) => (Lang.isPt ? abilityAbbrPt : abilityAbbrEn)[id] ?? id.toUpperCase();

String saveName(String id) => switch (id) {
      'fort' => tr('Fortitude', 'Fortitude'),
      'ref' => tr('Reflexos', 'Reflex'),
      'will' => tr('Vontade', 'Will'),
      _ => id,
    };

String kindName(String kind) => switch (kind) {
      'spell' => tr('Magia', 'Spell'),
      'feat' => tr('Talento', 'Feat'),
      'race' => tr('Raça', 'Race'),
      'class' => tr('Classe', 'Class'),
      'prestige' => tr('Classe de prestígio', 'Prestige class'),
      'skill' => tr('Perícia', 'Skill'),
      'weapon' => tr('Arma', 'Weapon'),
      'armor' => tr('Armadura', 'Armor'),
      'item' => tr('Item', 'Item'),
      'magic-item' => tr('Item mágico', 'Magic item'),
      'equipment' => tr('Equipamento', 'Equipment'),
      'monster' => tr('Criatura', 'Creature'),
      'deity' => tr('Divindade', 'Deity'),
      'domain' => tr('Domínio', 'Domain'),
      'power' => tr('Poder psiônico', 'Psionic power'),
      'maneuver' => tr('Manobra', 'Maneuver'),
      'invocation' => tr('Invocação', 'Invocation'),
      'infusion' => tr('Infusão', 'Infusion'),
      'condition' => tr('Condição', 'Condition'),
      'rule' => tr('Regra', 'Rule'),
      'template' => tr('Modelo', 'Template'),
      'page' => tr('Página', 'Page'),
      _ => kind,
    };

const allKinds = [
  'spell', 'feat', 'race', 'class', 'prestige', 'skill', 'weapon', 'armor', 'equipment', 'magic-item',
  'monster', 'deity', 'domain', 'power', 'maneuver', 'invocation', 'infusion', 'condition', 'template', 'rule',
];
