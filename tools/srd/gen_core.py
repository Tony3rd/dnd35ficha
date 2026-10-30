#!/usr/bin/env python3
"""Gera assets/srd/core.json — dados estruturados do núcleo de regras (SRD 3.5,
conteúdo OGL) que o motor usa para calcular a ficha. Referências de página são
do Player's Handbook / Dungeon Master's Guide 3.5 (abreviações PH / DMG).

Executar:  python3 tools/srd/gen_core.py
"""
import json, os

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'srd', 'core.json')

def E(target, value, type='untyped', cond=None):
    d = {'t': target, 'v': str(value)}
    if type != 'untyped': d['ty'] = type
    if cond: d['c'] = cond
    return d

# ---------------------------------------------------------------- perícias
# id, nome EN, nome PT, atributo, só treinada, penalidade de armadura (0/1/2), subtipos
SKILLS = [
 ('appraise','Appraise','Avaliação','int',0,0,0),
 ('balance','Balance','Equilíbrio','dex',0,1,0),
 ('bluff','Bluff','Blefar','cha',0,0,0),
 ('climb','Climb','Escalar','str',0,1,0),
 ('concentration','Concentration','Concentração','con',0,0,0),
 ('craft','Craft','Ofícios','int',0,0,1),
 ('decipher-script','Decipher Script','Decifrar Escrita','int',1,0,0),
 ('diplomacy','Diplomacy','Diplomacia','cha',0,0,0),
 ('disable-device','Disable Device','Operar Mecanismo','int',1,0,0),
 ('disguise','Disguise','Disfarces','cha',0,0,0),
 ('escape-artist','Escape Artist','Arte da Fuga','dex',0,1,0),
 ('forgery','Forgery','Falsificação','int',0,0,0),
 ('gather-information','Gather Information','Obter Informação','cha',0,0,0),
 ('handle-animal','Handle Animal','Adestrar Animais','cha',1,0,0),
 ('heal','Heal','Cura','wis',0,0,0),
 ('hide','Hide','Esconder-se','dex',0,1,0),
 ('intimidate','Intimidate','Intimidação','cha',0,0,0),
 ('jump','Jump','Saltar','str',0,1,0),
 ('knowledge-arcana','Knowledge (arcana)','Conhecimento (arcano)','int',1,0,0),
 ('knowledge-architecture','Knowledge (architecture and engineering)','Conhecimento (arquitetura e engenharia)','int',1,0,0),
 ('knowledge-dungeoneering','Knowledge (dungeoneering)','Conhecimento (masmorras)','int',1,0,0),
 ('knowledge-geography','Knowledge (geography)','Conhecimento (geografia)','int',1,0,0),
 ('knowledge-history','Knowledge (history)','Conhecimento (história)','int',1,0,0),
 ('knowledge-local','Knowledge (local)','Conhecimento (local)','int',1,0,0),
 ('knowledge-nature','Knowledge (nature)','Conhecimento (natureza)','int',1,0,0),
 ('knowledge-nobility','Knowledge (nobility and royalty)','Conhecimento (nobreza e realeza)','int',1,0,0),
 ('knowledge-religion','Knowledge (religion)','Conhecimento (religião)','int',1,0,0),
 ('knowledge-planes','Knowledge (the planes)','Conhecimento (os planos)','int',1,0,0),
 ('listen','Listen','Ouvir','wis',0,0,0),
 ('move-silently','Move Silently','Furtividade','dex',0,1,0),
 ('open-lock','Open Lock','Abrir Fechaduras','dex',1,0,0),
 ('perform','Perform','Atuação','cha',0,0,1),
 ('profession','Profession','Profissão','wis',1,0,1),
 ('ride','Ride','Cavalgar','dex',0,0,0),
 ('search','Search','Procurar','int',0,0,0),
 ('sense-motive','Sense Motive','Sentir Motivação','wis',0,0,0),
 ('sleight-of-hand','Sleight of Hand','Prestidigitação','dex',1,1,0),
 ('speak-language','Speak Language','Falar Idioma','none',1,0,0),
 ('spellcraft','Spellcraft','Identificar Magia','int',1,0,0),
 ('spot','Spot','Observar','wis',0,0,0),
 ('survival','Survival','Sobrevivência','wis',0,0,0),
 ('swim','Swim','Natação','str',0,2,0),
 ('tumble','Tumble','Acrobacia','dex',1,1,0),
 ('use-magic-device','Use Magic Device','Usar Instrumento Mágico','cha',1,0,0),
 ('use-rope','Use Rope','Usar Cordas','dex',0,0,0),
]
KNOW = [s[0] for s in SKILLS if s[0].startswith('knowledge-')]

# sinergias: (de, para, condição ou None)
SYN = [
 ('bluff','diplomacy',None),('bluff','intimidate',None),('bluff','sleight-of-hand',None),
 ('bluff','disguise','atuando um papel'),
 ('craft','appraise','itens relacionados ao ofício'),
 ('decipher-script','use-magic-device','pergaminhos'),
 ('escape-artist','use-rope','amarras'),
 ('handle-animal','ride',None),
 ('jump','tumble',None),
 ('knowledge-arcana','spellcraft',None),
 ('knowledge-architecture','search','portas secretas e compartimentos'),
 ('knowledge-dungeoneering','survival','no subterrâneo'),
 ('knowledge-geography','survival','evitar se perder / perigos naturais'),
 ('knowledge-local','gather-information',None),
 ('knowledge-nature','survival','ambientes naturais na superfície'),
 ('knowledge-nobility','diplomacy',None),
 ('knowledge-planes','survival','em outros planos'),
 ('search','survival','seguir rastros'),
 ('sense-motive','diplomacy',None),
 ('spellcraft','use-magic-device','pergaminhos'),
 ('survival','knowledge-nature',None),
 ('tumble','balance',None),('tumble','jump',None),
 ('use-magic-device','spellcraft','decifrar magias em pergaminhos'),
 ('use-rope','climb','escalar com cordas'),('use-rope','escape-artist','escapar de cordas'),
]

skills = []
for sid, en, pt, ab, to, acp, sub in SKILLS:
    skills.append({'id': sid, 'name': en, 'name_pt': pt, 'ability': ab,
                   'trained_only': bool(to), 'acp': acp, 'subtypes': bool(sub),
                   'book': 'PH', 'page': 62})
synergies = [{'from': a, 'to': b, **({'cond': c} if c else {})} for a, b, c in SYN]

# ---------------------------------------------------------------- tabelas de magia
def rows(s):
    return [[int(x) for x in r.split(',')] if r else [] for r in s.split('|')]

CLERIC_DAY = rows('3,1|4,2|4,2,1|5,3,2|5,3,2,1|5,3,3,2|6,4,3,2,1|6,4,3,3,2|6,4,4,3,2,1|6,4,4,3,3,2|'
                  '6,5,4,4,3,2,1|6,5,4,4,3,3,2|6,5,5,4,4,3,2,1|6,5,5,4,4,3,3,2|6,5,5,5,4,4,3,2,1|'
                  '6,5,5,5,4,4,3,3,2|6,5,5,5,5,4,4,3,2,1|6,5,5,5,5,4,4,3,3,2|6,5,5,5,5,5,4,4,3,3|6,5,5,5,5,5,4,4,4,4')
WIZ_DAY = [[min(r[0], 4)] + r[1:] for r in CLERIC_DAY]
SORC_DAY = rows('5,3|6,4|6,5|6,6,3|6,6,4|6,6,5,3|6,6,6,4|6,6,6,5,3|6,6,6,6,4|6,6,6,6,5,3|6,6,6,6,6,4|'
                '6,6,6,6,6,5,3|6,6,6,6,6,6,4|6,6,6,6,6,6,5,3|6,6,6,6,6,6,6,4|6,6,6,6,6,6,6,5,3|'
                '6,6,6,6,6,6,6,6,4|6,6,6,6,6,6,6,6,5,3|6,6,6,6,6,6,6,6,6,4|6,6,6,6,6,6,6,6,6,6')
SORC_KNOWN = rows('4,2|5,2|5,3|6,3,1|6,4,2|7,4,2,1|7,5,3,2|8,5,3,2,1|8,5,4,3,2|9,5,4,3,2,1|9,5,5,4,3,2|'
                  '9,5,5,4,3,2,1|9,5,5,4,4,3,2|9,5,5,4,4,3,2,1|9,5,5,4,4,4,3,2|9,5,5,4,4,4,3,2,1|'
                  '9,5,5,4,4,4,3,3,2|9,5,5,4,4,4,3,3,2,1|9,5,5,4,4,4,3,3,3,2|9,5,5,4,4,4,3,3,3,3')
BARD_DAY = rows('2|3,0|3,1|3,2,0|3,3,1|3,3,2|3,3,2,0|3,3,3,1|3,3,3,2|3,3,3,2,0|3,3,3,3,1|3,3,3,3,2|'
                '3,3,3,3,2,0|4,3,3,3,3,1|4,4,3,3,3,2|4,4,4,3,3,2,0|4,4,4,4,3,3,1|4,4,4,4,4,3,2|'
                '4,4,4,4,4,4,3|4,4,4,4,4,4,4')
BARD_KNOWN = rows('4|5,2|6,3|6,3,2|6,4,3|6,4,3|6,4,4,2|6,4,4,3|6,4,4,3|6,4,4,4,2|6,4,4,4,3|6,4,4,4,3|'
                  '6,4,4,4,4,2|6,4,4,4,4,3|6,4,4,4,4,3|6,5,4,4,4,4,2|6,5,5,4,4,4,3|6,5,5,5,4,4,3|'
                  '6,5,5,5,5,4,4|6,5,5,5,5,5,4')
# paladino/ranger: começam no nível de magia 1; vazio = sem magias ainda
PAL_DAY = rows('|||0|0|1|1|1,0|1,0|1,1|1,1,0|1,1,1|1,1,1|2,1,1,0|2,1,1,1|2,2,1,1|2,2,2,1|3,2,2,1|3,3,3,2|3,3,3,3')
ADEPT_DAY = rows('3,1|3,1|3,2|3,2,0|3,2,1|3,2,1|3,3,2|3,3,2,0|3,3,2,1|3,3,2,1|3,3,3,2|3,3,3,2,0|'
                 '3,3,3,2,1|3,3,3,2,1|3,3,3,3,2|3,3,3,3,2,0|3,3,3,3,2,1|3,3,3,3,2,1|3,3,3,3,3,2|3,3,3,3,3,2')

def feat_lv(levels, name, text='', effects=None, pt=None):
    return [{'level': l, 'name': name, **({'name_pt': pt} if pt else {}), **({'text': text} if text else {}),
             **({'effects': effects} if effects else {})} for l in levels]

def klass(id, name, pt, hd, sp, bab, good, skills, page, book='PH', features=None, spell=None,
          bonus_feats=None, resources=None, buffs=None, effects=None, prestige=False, max_level=20,
          starting_gold=None, alignment=None):
    return {'id': id, 'name': name, 'name_pt': pt, 'book': book, 'page': page, 'hit_die': hd,
            'skill_points': sp, 'bab': bab, 'good_saves': good, 'class_skills': skills,
            'features': features or [], 'spellcasting': spell, 'bonus_feat_levels': bonus_feats or [],
            'resources': resources or [], 'buffs': buffs or [], 'effects': effects or [],
            'prestige': prestige, 'max_level': max_level, 'starting_gold': starting_gold,
            **({'alignment': alignment} if alignment else {})}

C = []  # classes
# --- Bárbaro
rage_str = 'if(gte(@class.barbarian,20),8,if(gte(@class.barbarian,11),6,4))'
C.append(klass('barbarian','Barbarian','Bárbaro',12,4,'full',['fort'],
  ['climb','craft','handle-animal','intimidate','jump','listen','ride','survival','swim'],24,
  features=feat_lv([1],'Fast movement','+10 pés de deslocamento (armadura leve/média)',[E('speed.land',10,'not_heavy')],'Movimento rápido')
   + feat_lv([1],'Illiteracy','', None,'Analfabetismo')
   + feat_lv([1],'Rage','Fúria (ver recurso)',None,'Fúria')
   + feat_lv([2],'Uncanny dodge','Mantém Des na CA quando surpreendido',None,'Esquiva sobrenatural')
   + feat_lv([3,6,9,12,15,18],'Trap sense','+1 Reflexos e CA contra armadilhas por incremento',None,'Sentir armadilhas')
   + feat_lv([5],'Improved uncanny dodge','',None,'Esquiva sobrenatural aprimorada')
   + feat_lv([7,10,13,16,19],'Damage reduction','RD 1/— por incremento (7,10,13,16,19)',None,'Redução de dano')
   + feat_lv([11],'Greater rage','',None,'Fúria maior')
   + feat_lv([14],'Indomitable will','+4 Vontade contra encantamentos em fúria',None,'Vontade indomável')
   + feat_lv([17],'Tireless rage','',None,'Fúria incansável')
   + feat_lv([20],'Mighty rage','',None,'Fúria poderosa'),
  resources=[{'id':'rage','name':'Rage','name_pt':'Fúria','per':'day',
              'max':'1+floor(@class.barbarian/4)+if(gte(@class.barbarian,20),1,0)-if(gte(@class.barbarian,20),1,0)'}],
  buffs=[{'id':'rage','name':'Rage','name_pt':'Fúria','duration':'3+@abil.con.mod',
          'effects':[E('abil.str',rage_str,'morale'),E('abil.con',rage_str,'morale'),
                     E('save.will',f'({rage_str})/2','morale'),E('ac','-2')]}],
  starting_gold='4d4*10'))
# fúria/dia: 1 (1), 2 (4), 3 (8), 4 (12), 5 (16), 6 (20)
C[-1]['resources'][0]['max'] = '1+floor(@class.barbarian/4)'

# --- Bardo
C.append(klass('bard','Bard','Bardo',6,6,'3/4',['ref','will'],
  ['appraise','balance','bluff','climb','concentration','craft','decipher-script','diplomacy','disguise',
   'escape-artist','gather-information','hide','jump']+KNOW+['listen','move-silently','perform','profession',
   'sense-motive','sleight-of-hand','speak-language','spellcraft','swim','tumble','use-magic-device'],26,
  features=feat_lv([1],'Bardic music','Usos por dia = nível de bardo',None,'Música de bardo')
   + feat_lv([1],'Bardic knowledge','Nível de bardo + Int',None,'Conhecimento de bardo')
   + feat_lv([1],'Countersong','',None,'Contramúsica') + feat_lv([1],'Fascinate','',None,'Fascinar')
   + feat_lv([1,8,14,20],'Inspire courage','+1/+2/+3/+4',None,'Inspirar coragem')
   + feat_lv([3],'Inspire competence','',None,'Inspirar competência')
   + feat_lv([6],'Suggestion','',None,'Sugestão') + feat_lv([9],'Inspire greatness','',None,'Inspirar grandeza')
   + feat_lv([12],'Song of freedom','',None,'Canção da liberdade') + feat_lv([15],'Inspire heroics','',None,'Inspirar heroísmo')
   + feat_lv([18],'Mass suggestion','',None,'Sugestão em massa'),
  spell={'type':'arcane','style':'spontaneous','ability':'cha','list':'Brd','start':0,'per_day':BARD_DAY,'known':BARD_KNOWN},
  resources=[{'id':'bardic-music','name':'Bardic music','name_pt':'Música de bardo','per':'day','max':'@class.bard'}],
  buffs=[{'id':'inspire-courage','name':'Inspire courage','name_pt':'Inspirar coragem','duration':'',
          'effects':[E('attack.all','1+gte(@class.bard,8)+gte(@class.bard,14)+gte(@class.bard,20)','morale'),
                     E('damage.all','1+gte(@class.bard,8)+gte(@class.bard,14)+gte(@class.bard,20)','morale'),
                     E('save.all','1+gte(@class.bard,8)+gte(@class.bard,14)+gte(@class.bard,20)','morale','contra medo e encantamento (feitiço)')]}],
  starting_gold='4d4*10'))

# --- Clérigo
C.append(klass('cleric','Cleric','Clérigo',8,2,'3/4',['fort','will'],
  ['concentration','craft','diplomacy','heal','knowledge-arcana','knowledge-history','knowledge-religion',
   'knowledge-planes','profession','spellcraft'],30,
  features=feat_lv([1],'Turn or rebuke undead','3 + Car por dia',None,'Expulsar/fascinar mortos-vivos')
   + feat_lv([1],'Domains','Dois domínios: magias de domínio e poderes concedidos',None,'Domínios')
   + feat_lv([1],'Spontaneous casting','Curar/infligir espontâneo',None,'Conjuração espontânea'),
  spell={'type':'divine','style':'prepared','ability':'wis','list':'Clr','start':0,'per_day':CLERIC_DAY,'domain_slots':True},
  resources=[{'id':'turn-undead','name':'Turn undead','name_pt':'Expulsar mortos-vivos','per':'day','max':'3+@abil.cha.mod'}],
  starting_gold='5d4*10'))

# --- Druida
C.append(klass('druid','Druid','Druida',8,4,'3/4',['fort','will'],
  ['concentration','craft','diplomacy','handle-animal','heal','knowledge-nature','listen','profession','ride',
   'spellcraft','spot','survival','swim'],34,
  features=feat_lv([1],'Animal companion','',None,'Companheiro animal')
   + feat_lv([1],'Nature sense','+2 Conhecimento (natureza) e Sobrevivência',
             [E('skill.knowledge-nature',2),E('skill.survival',2)],'Sentido da natureza')
   + feat_lv([1],'Wild empathy','',None,'Empatia selvagem') + feat_lv([2],'Woodland stride','',None,'Caminho da floresta')
   + feat_lv([3],'Trackless step','',None,'Rastro invisível')
   + feat_lv([4],'Resist nature\'s lure','+4 contra fey',[E('save.all',4,cond='contra habilidades de fadas')],'Resistir à tentação da natureza')
   + feat_lv([5],'Wild shape','Forma selvagem',None,'Forma selvagem')
   + feat_lv([9],'Venom immunity','',None,'Imunidade a venenos') + feat_lv([13],'A thousand faces','',None,'Mil faces')
   + feat_lv([15],'Timeless body','',None,'Corpo atemporal'),
  spell={'type':'divine','style':'prepared','ability':'wis','list':'Drd','start':0,'per_day':CLERIC_DAY},
  resources=[{'id':'wild-shape','name':'Wild shape','name_pt':'Forma selvagem','per':'day',
              'max':'if(gte(@class.druid,5),1,0)+gte(@class.druid,6)+gte(@class.druid,7)+gte(@class.druid,10)+gte(@class.druid,14)+gte(@class.druid,18)'}],
  starting_gold='2d4*10', alignment='any neutral'))

# --- Guerreiro
C.append(klass('fighter','Fighter','Guerreiro',10,2,'full',['fort'],
  ['climb','craft','handle-animal','intimidate','jump','ride','swim'],37,
  bonus_feats=[1,2,4,6,8,10,12,14,16,18,20], starting_gold='6d4*10'))

# --- Monge
monk_ac = '@abil.wis.mod*gte(@abil.wis.mod,0)+floor(@class.monk/5)'
C.append(klass('monk','Monk','Monge',8,4,'3/4',['fort','ref','will'],
  ['balance','climb','concentration','craft','diplomacy','escape-artist','hide','jump','knowledge-arcana',
   'knowledge-religion','listen','move-silently','perform','profession','sense-motive','spot','swim','tumble'],39,
  features=feat_lv([1],'AC bonus','Sab + 1 a cada 5 níveis (sem armadura)',None,'Bônus na CA')
   + feat_lv([1],'Flurry of blows','',None,'Rajada de golpes') + feat_lv([1],'Unarmed strike','',None,'Ataque desarmado')
   + feat_lv([2],'Evasion','',None,'Evasão') + feat_lv([3],'Still mind','+2 contra encantamentos',
        [E('save.all',2,cond='contra magias e efeitos de encantamento')],'Mente tranquila')
   + feat_lv([4],'Ki strike (magic)','',None,'Golpe ki (mágico)') + feat_lv([4],'Slow fall','',None,'Queda lenta')
   + feat_lv([5],'Purity of body','',None,'Pureza corporal') + feat_lv([7],'Wholeness of body','',None,'Integridade corporal')
   + feat_lv([9],'Improved evasion','',None,'Evasão aprimorada') + feat_lv([10],'Ki strike (lawful)','',None,'Golpe ki (ordeiro)')
   + feat_lv([11],'Diamond body','',None,'Corpo de diamante') + feat_lv([12],'Abundant step','',None,'Passo etéreo')
   + feat_lv([13],'Diamond soul','RM 10 + nível',None,'Alma de diamante') + feat_lv([15],'Quivering palm','',None,'Palma vibrante')
   + feat_lv([16],'Ki strike (adamantine)','',None,'Golpe ki (adamante)') + feat_lv([17],'Timeless body','',None,'Corpo atemporal')
   + feat_lv([17],'Tongue of the sun and moon','',None,'Língua do sol e da lua') + feat_lv([19],'Empty body','',None,'Corpo vazio')
   + feat_lv([20],'Perfect self','',None,'Auto-perfeição'),
  bonus_feats=[1,2,6],
  effects=[E('ac',monk_ac,'monk_unarmored'),
           E('speed.land','floor(@class.monk/3)*10','monk_unarmored'),
           E('sr','if(gte(@class.monk,13),10+@class.monk,0)')],
  starting_gold='5d4', alignment='any lawful'))

# --- Paladino
C.append(klass('paladin','Paladin','Paladino',10,2,'full',['fort'],
  ['concentration','craft','diplomacy','handle-animal','heal','knowledge-nobility','knowledge-religion',
   'profession','ride','sense-motive'],42,
  features=feat_lv([1],'Aura of good','',None,'Aura do bem') + feat_lv([1],'Detect evil','',None,'Detectar o mal')
   + feat_lv([1,5,10,15,20],'Smite evil','1/dia +1 a cada 5 níveis',None,'Destruir o mal')
   + feat_lv([2],'Divine grace','Car nos testes de resistência',None,'Graça divina')
   + feat_lv([2],'Lay on hands','Nível × Car PV/dia',None,'Cura pelas mãos')
   + feat_lv([3],'Aura of courage','',None,'Aura de coragem') + feat_lv([3],'Divine health','',None,'Saúde divina')
   + feat_lv([4],'Turn undead','Como clérigo de nível -3',None,'Expulsar mortos-vivos')
   + feat_lv([5],'Special mount','',None,'Montaria especial')
   + feat_lv([6,9,12,15,18],'Remove disease','',None,'Remover doença'),
  spell={'type':'divine','style':'prepared','ability':'wis','list':'Pal','start':1,'per_day':PAL_DAY,'cl_factor':0.5},
  effects=[E('save.all','if(gte(@class.paladin,2),max(0,@abil.cha.mod),0)')],
  resources=[{'id':'smite-evil','name':'Smite evil','name_pt':'Destruir o mal','per':'day','max':'1+floor(@class.paladin/5)'},
             {'id':'lay-on-hands','name':'Lay on hands (hp)','name_pt':'Cura pelas mãos (PV)','per':'day',
              'max':'if(gte(@class.paladin,2),@class.paladin*max(0,@abil.cha.mod),0)'}],
  starting_gold='6d4*10', alignment='lawful good'))

# --- Ranger
C.append(klass('ranger','Ranger','Ranger',8,6,'full',['fort','ref'],
  ['climb','concentration','craft','handle-animal','heal','hide','jump','knowledge-dungeoneering',
   'knowledge-geography','knowledge-nature','listen','move-silently','profession','ride','search','spot',
   'survival','swim','use-rope'],46,
  features=feat_lv([1,5,10,15,20],'Favored enemy','+2 (ver texto)',None,'Inimigo predileto')
   + feat_lv([1],'Track','Talento Rastrear',None,'Rastrear') + feat_lv([1],'Wild empathy','',None,'Empatia selvagem')
   + feat_lv([2],'Combat style','Arquearia ou combate com duas armas',None,'Estilo de combate')
   + feat_lv([3],'Endurance','',None,'Tolerância') + feat_lv([4],'Animal companion','',None,'Companheiro animal')
   + feat_lv([6],'Improved combat style','',None,'Estilo de combate aprimorado')
   + feat_lv([7],'Woodland stride','',None,'Caminho da floresta') + feat_lv([8],'Swift tracker','',None,'Rastreador rápido')
   + feat_lv([9],'Evasion','',None,'Evasão') + feat_lv([11],'Combat style mastery','',None,'Maestria no estilo de combate')
   + feat_lv([13],'Camouflage','',None,'Camuflagem') + feat_lv([17],'Hide in plain sight','',None,'Esconder-se à plena vista'),
  spell={'type':'divine','style':'prepared','ability':'wis','list':'Rgr','start':1,'per_day':PAL_DAY,'cl_factor':0.5},
  starting_gold='6d4*10'))

# --- Ladino
C.append(klass('rogue','Rogue','Ladino',6,8,'3/4',['ref'],
  ['appraise','balance','bluff','climb','craft','decipher-script','diplomacy','disable-device','disguise',
   'escape-artist','forgery','gather-information','hide','intimidate','jump','knowledge-local','listen',
   'move-silently','open-lock','perform','profession','search','sense-motive','sleight-of-hand','spot','swim',
   'tumble','use-magic-device','use-rope'],48,
  features=feat_lv([1,3,5,7,9,11,13,15,17,19],'Sneak attack','+1d6 por incremento',None,'Ataque furtivo')
   + feat_lv([1],'Trapfinding','',None,'Encontrar armadilhas') + feat_lv([2],'Evasion','',None,'Evasão')
   + feat_lv([3,6,9,12,15,18],'Trap sense','',None,'Sentir armadilhas') + feat_lv([4],'Uncanny dodge','',None,'Esquiva sobrenatural')
   + feat_lv([8],'Improved uncanny dodge','',None,'Esquiva sobrenatural aprimorada')
   + feat_lv([10,13,16,19],'Special ability','Habilidade especial à escolha',None,'Habilidade especial'),
  starting_gold='5d4*10'))

# --- Feiticeiro
C.append(klass('sorcerer','Sorcerer','Feiticeiro',4,2,'1/2',['will'],
  ['bluff','concentration','craft','knowledge-arcana','profession','spellcraft'],51,
  features=feat_lv([1],'Summon familiar','',None,'Invocar familiar'),
  spell={'type':'arcane','style':'spontaneous','ability':'cha','list':'Sor/Wiz','start':0,'per_day':SORC_DAY,'known':SORC_KNOWN},
  starting_gold='3d4*10'))

# --- Mago
C.append(klass('wizard','Wizard','Mago',4,2,'1/2',['will'],
  ['concentration','craft','decipher-script']+KNOW+['profession','spellcraft'],55,
  features=feat_lv([1],'Summon familiar','',None,'Invocar familiar') + feat_lv([1],'Scribe Scroll','Talento bônus',None,'Escrever Pergaminho'),
  bonus_feats=[5,10,15,20],
  spell={'type':'arcane','style':'prepared','ability':'int','list':'Sor/Wiz','start':0,'per_day':WIZ_DAY,'spellbook':True,
         'school_slots':True},
  starting_gold='3d4*10'))

# --- Classes de PdM (DMG)
C.append(klass('adept','Adept','Adepto',6,2,'1/2',['will'],
  ['concentration','craft','handle-animal','heal']+KNOW+['profession','spellcraft','survival'],107,book='DMG',
  spell={'type':'divine','style':'prepared','ability':'wis','list':'Adp','start':0,'per_day':ADEPT_DAY}))
C.append(klass('aristocrat','Aristocrat','Aristocrata',8,4,'3/4',['will'],
  ['appraise','bluff','diplomacy','disguise','forgery','gather-information','handle-animal','intimidate']+KNOW+
  ['listen','perform','ride','sense-motive','speak-language','spot','swim','survival'],108,book='DMG'))
C.append(klass('commoner','Commoner','Plebeu',4,2,'1/2',[],
  ['climb','craft','handle-animal','jump','listen','profession','ride','spot','swim','use-rope'],108,book='DMG'))
C.append(klass('expert','Expert','Especialista',6,6,'3/4',['will'],[],109,book='DMG',
  features=feat_lv([1],'Class skills','Escolha 10 perícias de classe',None,'Perícias de classe')))
C.append(klass('warrior','Warrior','Combatente',8,2,'full',['fort'],
  ['climb','handle-animal','intimidate','jump','ride','swim'],109,book='DMG'))

# proficiências por classe (PH cap. 3)
PROF = {
 'barbarian': (['simple','martial'], ['light','medium','shield']),
 'bard': (['simple','Longsword','Rapier','Sap','Sword, short','Shortbow','Whip'], ['light','shield']),
 'cleric': (['simple'], ['light','medium','heavy','shield']),
 'druid': (['Club','Dagger','Dart','Quarterstaff','Scimitar','Sickle','Shortspear','Sling','Spear'], ['light','medium','shield']),
 'fighter': (['simple','martial'], ['light','medium','heavy','shield','tower']),
 'monk': (['Club','Crossbow, light','Crossbow, heavy','Dagger','Handaxe','Javelin','Kama','Nunchaku','Quarterstaff','Sai','Shuriken','Siangham','Sling'], []),
 'paladin': (['simple','martial'], ['light','medium','heavy','shield']),
 'ranger': (['simple','martial'], ['light','shield']),
 'rogue': (['simple','Crossbow, hand','Rapier','Sap','Shortbow','Sword, short'], ['light']),
 'sorcerer': (['simple'], []),
 'wizard': (['Club','Dagger','Crossbow, heavy','Crossbow, light','Quarterstaff'], []),
 'adept': (['simple'], []), 'aristocrat': (['simple','martial'], ['light','medium','heavy','shield']),
 'commoner': ([], []), 'expert': (['simple'], ['light']),
 'warrior': (['simple','martial'], ['light','medium','heavy','shield']),
}
for c in C:
    w, a = PROF.get(c['id'], ([], []))
    c['weapon_prof'] = w; c['armor_prof'] = a

# ---------------------------------------------------------------- raças
def race(id, name, pt, page, size='medium', speed=30, adj=None, la=0, favored='any', effects=None,
         features=None, bonus_feats=0, bonus_sp=0, languages='Common', vision=''):
    return {'id': id, 'name': name, 'name_pt': pt, 'book': 'PH', 'page': page, 'size': size,
            'speed': speed, 'ability_adj': adj or {}, 'la': la, 'favored_class': favored,
            'effects': effects or [], 'features': features or [], 'bonus_feats': bonus_feats,
            'bonus_skill_points': bonus_sp, 'languages': languages, 'vision': vision, 'type': 'humanoid'}

R = [
 race('human','Human','Humano',12,bonus_feats=1,bonus_sp=1,features=['+1 talento no 1º nível','+4 pontos de perícia no 1º nível e +1 por nível']),
 race('dwarf','Dwarf','Anão',14,speed=20,adj={'con':2,'cha':-2},favored='fighter',vision='Visão no escuro 18 m',
      effects=[E('save.all',2,'racial','contra veneno'),E('save.all',2,'racial','contra magias e efeitos similares'),
               E('attack.melee',1,'racial','contra orcs e goblinoides'),E('ac',4,'dodge','contra gigantes'),
               E('skill.appraise',2,'racial','itens de pedra ou metal'),E('skill.craft',2,'racial','pedra ou metal'),
               E('abilitycheck',4,'racial','resistir a encontrão ou imobilização (estabilidade)'),
               E('skill.search',2,'racial','trabalhos em pedra (conhecimento de pedras)'),
               E('flag.armor_no_slow',1)],
      features=['Deslocamento não é reduzido por armadura ou carga','Conhecimento de pedras','Estabilidade','Familiaridade com armas (machado de guerra anão, urgrosh)'],
      languages='Common, Dwarven'),
 race('elf','Elf','Elfo',15,adj={'dex':2,'con':-2},favored='wizard',vision='Visão na penumbra',
      effects=[E('save.all',2,'racial','contra magias e efeitos de encantamento'),
               E('skill.listen',2,'racial'),E('skill.search',2,'racial'),E('skill.spot',2,'racial')],
      features=['Imune a sono mágico','Proficiência: espada longa, rapieira, arcos longos e curtos','Detecta portas secretas ao passar a 1,5 m'],
      languages='Common, Elven'),
 race('gnome','Gnome','Gnomo',16,size='small',speed=20,adj={'con':2,'str':-2},favored='bard',vision='Visão na penumbra',
      effects=[E('save.all',2,'racial','contra ilusões'),E('attack.all',1,'racial','contra kobolds e goblinoides'),
               E('ac',4,'dodge','contra gigantes'),E('skill.listen',2,'racial'),E('skill.craft',2,'racial','alquimia'),
               E('spelldc.all',1,'untyped','magias de ilusão')],
      features=['Falar com animais (mamíferos escavadores) 1/dia','Pequenas magias: luzes dançantes, som fantasma, prestidigitação (Car ≥ 10)'],
      languages='Common, Gnome'),
 race('half-elf','Half-Elf','Meio-Elfo',18,
      effects=[E('save.all',2,'racial','contra magias e efeitos de encantamento'),
               E('skill.listen',1,'racial'),E('skill.search',1,'racial'),E('skill.spot',1,'racial'),
               E('skill.diplomacy',2,'racial'),E('skill.gather-information',2,'racial')],
      vision='Visão na penumbra', features=['Imune a sono mágico','Sangue élfico'], languages='Common, Elven'),
 race('half-orc','Half-Orc','Meio-Orc',18,adj={'str':2,'int':-2,'cha':-2},favored='barbarian',vision='Visão no escuro 18 m',
      features=['Sangue orc'],languages='Common, Orc'),
 race('halfling','Halfling','Halfling',19,size='small',speed=20,adj={'dex':2,'str':-2},favored='rogue',
      effects=[E('skill.climb',2,'racial'),E('skill.jump',2,'racial'),E('skill.move-silently',2,'racial'),
               E('skill.listen',2,'racial'),E('save.all',1,'racial'),E('save.all',2,'morale','contra medo'),
               E('attack.ranged',1,'racial','armas de arremesso e fundas')],
      languages='Common, Halfling'),
]

# ---------------------------------------------------------------- talentos (PH cap. 5)
def P(kind, key=None, val=None):
    d = {'k': kind}
    if key is not None: d['key'] = key
    if val is not None: d['v'] = val
    return d
def feat(name, pt, types='general', prereq=None, effects=None, choice=None, multiple=False, text=''):
    return {'name': name, 'name_pt': pt, 'types': types.split(','), 'prereq': prereq or [],
            'effects': effects or [], 'choice': choice, 'multiple': multiple, 'text': text, 'book': 'PH'}
F = lambda n: P('feat', n)
A = lambda a, v: P('abil', a, v)
B = lambda v: P('bab', None, v)
CL = lambda v: P('cl', None, v)
SK = lambda s, v: P('skill', s, v)
FL = lambda c, v: P('class', c, v)
def sk2(a, b): return [E(f'skill.{a}',2), E(f'skill.{b}',2)]

FEATS = [
 feat('Acrobatic','Acrobático',effects=sk2('jump','tumble')),
 feat('Agile','Ágil',effects=sk2('balance','escape-artist')),
 feat('Alertness','Prontidão',effects=sk2('listen','spot')),
 feat('Animal Affinity','Afinidade com Animais',effects=sk2('handle-animal','ride')),
 feat('Armor Proficiency (Light)','Usar Armadura (Leve)'),
 feat('Armor Proficiency (Medium)','Usar Armadura (Média)',prereq=[F('Armor Proficiency (Light)')]),
 feat('Armor Proficiency (Heavy)','Usar Armadura (Pesada)',prereq=[F('Armor Proficiency (Light)'),F('Armor Proficiency (Medium)')]),
 feat('Athletic','Atlético',effects=sk2('climb','swim')),
 feat('Augment Summoning','Invocação Aprimorada',prereq=[F('Spell Focus (Conjuration)')]),
 feat('Blind-Fight','Lutar às Cegas','general,fighter'),
 feat('Brew Potion','Preparar Poção','item creation',[CL(3)]),
 feat('Cleave','Trespassar','general,fighter',[A('str',13),F('Power Attack')]),
 feat('Combat Casting','Magia em Combate',effects=[E('skill.concentration',4,cond='conjurar na defensiva ou agarrado')]),
 feat('Combat Expertise','Especialização em Combate','general,fighter',[A('int',13)]),
 feat('Combat Reflexes','Reflexos de Combate','general,fighter'),
 feat('Craft Magic Arms and Armor','Criar Armas e Armaduras Mágicas','item creation',[CL(5)]),
 feat('Craft Rod','Criar Bastão','item creation',[CL(9)]),
 feat('Craft Staff','Criar Cajado','item creation',[CL(12)]),
 feat('Craft Wand','Criar Varinha','item creation',[CL(5)]),
 feat('Craft Wondrous Item','Criar Item Maravilhoso','item creation',[CL(3)]),
 feat('Deceitful','Enganador',effects=sk2('disguise','forgery')),
 feat('Deflect Arrows','Desviar Objetos','general,fighter',[A('dex',13),F('Improved Unarmed Strike')]),
 feat('Deft Hands','Mãos Leves',effects=sk2('sleight-of-hand','use-rope')),
 feat('Diehard','Duro de Matar',prereq=[F('Endurance')]),
 feat('Diligent','Diligente',effects=sk2('appraise','decipher-script')),
 feat('Dodge','Esquiva','general,fighter',[A('dex',13)],[E('ac',1,'dodge','contra um oponente escolhido')]),
 feat('Empower Spell','Potencializar Magia','metamagic'),
 feat('Endurance','Tolerância',effects=[E('skill.swim',4,cond='resistir a dano por exaustão'),E('abilitycheck',4,cond='testes de Constituição contra exaustão')]),
 feat('Enlarge Spell','Ampliar Magia','metamagic'),
 feat('Eschew Materials','Dispensar Componentes','metamagic'),
 feat('Exotic Weapon Proficiency','Usar Arma Exótica','general,fighter',[B(1)],choice='weapon',multiple=True),
 feat('Extend Spell','Estender Magia','metamagic'),
 feat('Extra Turning','Expulsão Adicional',prereq=[P('ability','turn undead')],multiple=True),
 feat('Far Shot','Tiro Longo','general,fighter',[F('Point Blank Shot')]),
 feat('Forge Ring','Forjar Anel','item creation',[CL(12)]),
 feat('Great Cleave','Trespassar Maior','general,fighter',[A('str',13),F('Cleave'),F('Power Attack'),B(4)]),
 feat('Great Fortitude','Fortitude Maior',effects=[E('save.fort',2)]),
 feat('Greater Spell Focus','Foco em Magia Maior',prereq=[F('Spell Focus ({choice})')],choice='school',multiple=True,
      effects=[E('spelldc.school:{choice}',1)]),
 feat('Greater Spell Penetration','Magia Penetrante Maior',prereq=[F('Spell Penetration')]),
 feat('Greater Two-Weapon Fighting','Combater com Duas Armas Maior','general,fighter',[A('dex',19),F('Improved Two-Weapon Fighting'),F('Two-Weapon Fighting'),B(11)]),
 feat('Greater Weapon Focus','Foco em Arma Maior','general,fighter',[F('Weapon Focus ({choice})'),FL('fighter',8)],
      [E('attack.weapon:{choice}',1)],choice='weapon',multiple=True),
 feat('Greater Weapon Specialization','Especialização em Arma Maior','general,fighter',
      [F('Greater Weapon Focus ({choice})'),F('Weapon Focus ({choice})'),F('Weapon Specialization ({choice})'),FL('fighter',12)],
      [E('damage.weapon:{choice}',2)],choice='weapon',multiple=True),
 feat('Heighten Spell','Elevar Magia','metamagic'),
 feat('Improved Bull Rush','Encontrão Aprimorado','general,fighter',[A('str',13),F('Power Attack')]),
 feat('Improved Counterspell','Contramágica Aprimorada'),
 feat('Improved Critical','Sucesso Decisivo Aprimorado','general,fighter',[B(8)],[E('critrange.weapon:{choice}',1)],choice='weapon',multiple=True),
 feat('Improved Disarm','Desarmar Aprimorado','general,fighter',[A('int',13),F('Combat Expertise')]),
 feat('Improved Familiar','Familiar Aprimorado',prereq=[P('ability','familiar')]),
 feat('Improved Feint','Fintar Aprimorado','general,fighter',[A('int',13),F('Combat Expertise')]),
 feat('Improved Grapple','Agarrar Aprimorado','general,fighter',[A('dex',13),F('Improved Unarmed Strike')],[E('grapple',4)]),
 feat('Improved Initiative','Iniciativa Aprimorada','general,fighter',effects=[E('init',4)]),
 feat('Improved Overrun','Atropelar Aprimorado','general,fighter',[A('str',13),F('Power Attack')]),
 feat('Improved Precise Shot','Tiro Certeiro Aprimorado','general,fighter',[A('dex',19),F('Point Blank Shot'),F('Precise Shot'),B(11)]),
 feat('Improved Shield Bash','Ataque com Escudo Aprimorado','general,fighter',[P('feat','Shield Proficiency')]),
 feat('Improved Sunder','Separar Aprimorado','general,fighter',[A('str',13),F('Power Attack')]),
 feat('Improved Trip','Imobilização Aprimorada','general,fighter',[A('int',13),F('Combat Expertise')]),
 feat('Improved Turning','Expulsão Aprimorada',prereq=[P('ability','turn undead')]),
 feat('Improved Two-Weapon Fighting','Combater com Duas Armas Aprimorado','general,fighter',[A('dex',17),F('Two-Weapon Fighting'),B(6)]),
 feat('Improved Unarmed Strike','Ataque Desarmado Aprimorado','general,fighter'),
 feat('Investigator','Investigador',effects=sk2('gather-information','search')),
 feat('Iron Will','Vontade de Ferro',effects=[E('save.will',2)]),
 feat('Leadership','Liderança',prereq=[P('level',None,6)]),
 feat('Lightning Reflexes','Reflexos Rápidos',effects=[E('save.ref',2)]),
 feat('Magical Aptitude','Aptidão Mágica',effects=sk2('spellcraft','use-magic-device')),
 feat('Manyshot','Tiro Múltiplo','general,fighter',[A('dex',17),F('Point Blank Shot'),F('Rapid Shot'),B(6)]),
 feat('Martial Weapon Proficiency','Usar Arma Comum',choice='weapon',multiple=True),
 feat('Maximize Spell','Maximizar Magia','metamagic'),
 feat('Mobility','Mobilidade','general,fighter',[A('dex',13),F('Dodge')],[E('ac',4,'dodge','contra ataques de oportunidade ao se mover')]),
 feat('Mounted Archery','Arquearia Montada','general,fighter',[SK('ride',1),F('Mounted Combat')]),
 feat('Mounted Combat','Combate Montado','general,fighter',[SK('ride',1)]),
 feat('Natural Spell','Magia Natural',prereq=[A('wis',13),P('ability','wild shape')]),
 feat('Negotiator','Negociador',effects=sk2('diplomacy','sense-motive')),
 feat('Nimble Fingers','Dedos Mágicos',effects=sk2('disable-device','open-lock')),
 feat('Persuasive','Persuasivo',effects=sk2('bluff','intimidate')),
 feat('Point Blank Shot','Tiro Certeiro','general,fighter',effects=[E('attack.ranged',1,cond='alvos a até 9 m'),E('damage.ranged',1,cond='alvos a até 9 m')]),
 feat('Power Attack','Ataque Poderoso','general,fighter',[A('str',13)]),
 feat('Precise Shot','Tiro Preciso','general,fighter',[F('Point Blank Shot')]),
 feat('Quick Draw','Saque Rápido','general,fighter',[B(1)]),
 feat('Quicken Spell','Acelerar Magia','metamagic'),
 feat('Rapid Reload','Recarga Rápida','general,fighter',choice='weapon',multiple=True),
 feat('Rapid Shot','Tiro Rápido','general,fighter',[A('dex',13),F('Point Blank Shot')]),
 feat('Ride-By Attack','Investida Montada','general,fighter',[SK('ride',1),F('Mounted Combat')]),
 feat('Run','Corrida'),
 feat('Scribe Scroll','Escrever Pergaminho','item creation',[CL(1)]),
 feat('Self-Sufficient','Autossuficiente',effects=sk2('heal','survival')),
 feat('Shield Proficiency','Usar Escudo','general,fighter'),
 feat('Shot on the Run','Tiro em Movimento','general,fighter',[A('dex',13),F('Dodge'),F('Mobility'),F('Point Blank Shot'),B(4)]),
 feat('Silent Spell','Magia Silenciosa','metamagic'),
 feat('Simple Weapon Proficiency','Usar Armas Simples'),
 feat('Skill Focus','Foco em Perícia',effects=[E('skill.{choice}',3)],choice='skill',multiple=True),
 feat('Snatch Arrows','Apanhar Objetos','general,fighter',[A('dex',15),F('Deflect Arrows'),F('Improved Unarmed Strike')]),
 feat('Spell Focus','Foco em Magia',effects=[E('spelldc.school:{choice}',1)],choice='school',multiple=True),
 feat('Spell Mastery','Domínio de Magia',prereq=[FL('wizard',1)],multiple=True),
 feat('Spell Penetration','Magia Penetrante'),
 feat('Spirited Charge','Investida Implacável','general,fighter',[SK('ride',1),F('Mounted Combat'),F('Ride-By Attack')]),
 feat('Spring Attack','Ataque em Movimento','general,fighter',[A('dex',13),F('Dodge'),F('Mobility'),B(4)]),
 feat('Stealthy','Furtivo',effects=sk2('hide','move-silently')),
 feat('Still Spell','Magia sem Gestos','metamagic'),
 feat('Stunning Fist','Ataque Atordoante','general,fighter',[A('dex',13),A('wis',13),F('Improved Unarmed Strike'),B(8)]),
 feat('Toughness','Vitalidade',effects=[E('hp.max',3)],multiple=True),
 feat('Tower Shield Proficiency','Usar Escudo de Corpo','general,fighter',[F('Shield Proficiency')]),
 feat('Track','Rastrear'),
 feat('Trample','Pisotear','general,fighter',[SK('ride',1),F('Mounted Combat')]),
 feat('Two-Weapon Defense','Defesa com Duas Armas','general,fighter',[A('dex',15),F('Two-Weapon Fighting')],[E('ac',1,'shield','empunhando duas armas')]),
 feat('Two-Weapon Fighting','Combater com Duas Armas','general,fighter',[A('dex',15)]),
 feat('Weapon Finesse','Acuidade com Arma','general,fighter',[B(1)]),
 feat('Weapon Focus','Foco em Arma','general,fighter',[B(1)],[E('attack.weapon:{choice}',1)],choice='weapon',multiple=True),
 feat('Weapon Specialization','Especialização em Arma','general,fighter',[F('Weapon Focus ({choice})'),FL('fighter',4)],
      [E('damage.weapon:{choice}',2)],choice='weapon',multiple=True),
 feat('Whirlwind Attack','Ataque Giratório','general,fighter',[A('dex',13),A('int',13),F('Combat Expertise'),F('Dodge'),F('Mobility'),F('Spring Attack'),B(4)]),
 feat('Widen Spell','Ampliar Área','metamagic'),
]

# ---------------------------------------------------------------- armas (PH tabela 7-5)
# nome, pt, categoria, empunhadura, dano P, dano M, decisivo, incremento(pés), peso(lb), custo(po), tipo
W = '''Gauntlet|Manopla|simple|light|1d2|1d3|x2|0|1|2|B
Unarmed strike|Ataque desarmado|simple|light|1d2|1d3|x2|0|0|0|B
Dagger|Adaga|simple|light|1d3|1d4|19-20/x2|10|1|2|P/S
Dagger, punching|Adaga de soco|simple|light|1d3|1d4|x3|0|1|2|P
Gauntlet, spiked|Manopla com cravos|simple|light|1d3|1d4|x2|0|1|5|P
Mace, light|Maça leve|simple|light|1d4|1d6|x2|0|4|5|B
Sickle|Foice curta|simple|light|1d4|1d6|x2|0|2|6|S
Club|Clava|simple|one|1d4|1d6|x2|10|3|0|B
Mace, heavy|Maça pesada|simple|one|1d6|1d8|x2|0|8|12|B
Morningstar|Maça-estrela|simple|one|1d6|1d8|x2|0|6|8|B/P
Shortspear|Lança curta|simple|one|1d4|1d6|x2|20|3|1|P
Longspear|Lança longa|simple|two|1d6|1d8|x3|0|9|5|P
Quarterstaff|Bordão|simple|two|1d4/1d4|1d6/1d6|x2|0|4|0|B
Spear|Lança|simple|two|1d6|1d8|x3|20|6|2|P
Crossbow, heavy|Besta pesada|simple|ranged|1d8|1d10|19-20/x2|120|8|50|P
Crossbow, light|Besta leve|simple|ranged|1d6|1d8|19-20/x2|80|4|35|P
Dart|Dardo|simple|thrown|1d3|1d4|x2|20|0.5|0.5|P
Javelin|Azagaia|simple|thrown|1d4|1d6|x2|30|2|1|P
Sling|Funda|simple|ranged|1d3|1d4|x2|50|0|0|B
Axe, throwing|Machadinha de arremesso|martial|light|1d4|1d6|x2|10|2|8|S
Hammer, light|Martelo leve|martial|light|1d3|1d4|x2|20|2|1|B
Handaxe|Machadinha|martial|light|1d4|1d6|x3|0|3|6|S
Kukri|Kukri|martial|light|1d3|1d4|18-20/x2|0|2|8|S
Pick, light|Picareta leve|martial|light|1d3|1d4|x4|0|3|4|P
Sap|Porrete|martial|light|1d4|1d6|x2|0|2|1|B
Sword, short|Espada curta|martial|light|1d4|1d6|19-20/x2|0|2|10|P
Battleaxe|Machado de batalha|martial|one|1d6|1d8|x3|0|6|10|S
Flail|Mangual|martial|one|1d6|1d8|x2|0|5|8|B
Longsword|Espada longa|martial|one|1d6|1d8|19-20/x2|0|4|15|S
Pick, heavy|Picareta pesada|martial|one|1d4|1d6|x4|0|6|8|P
Rapier|Rapieira|martial|one|1d4|1d6|18-20/x2|0|2|20|P
Scimitar|Cimitarra|martial|one|1d4|1d6|18-20/x2|0|4|15|S
Trident|Tridente|martial|one|1d6|1d8|x2|10|4|15|P
Warhammer|Martelo de guerra|martial|one|1d6|1d8|x3|0|5|12|B
Falchion|Falchion|martial|two|1d6|2d4|18-20/x2|0|8|75|S
Glaive|Glaive|martial|two|1d8|1d10|x3|0|10|8|S
Greataxe|Machado grande|martial|two|1d10|1d12|x3|0|12|20|S
Greatclub|Clava grande|martial|two|1d8|1d10|x2|0|8|5|B
Flail, heavy|Mangual pesado|martial|two|1d8|1d10|19-20/x2|0|10|15|B
Greatsword|Espada larga|martial|two|1d10|2d6|19-20/x2|0|8|50|S
Guisarme|Bisarma|martial|two|1d6|2d4|x3|0|12|9|S
Halberd|Alabarda|martial|two|1d8|1d10|x3|0|12|10|P/S
Lance|Lança de montaria|martial|two|1d6|1d8|x3|0|10|10|P
Ranseur|Ranseur|martial|two|1d6|2d4|x3|0|12|10|P
Scythe|Gadanho|martial|two|1d6|2d4|x4|0|10|18|P/S
Longbow|Arco longo|martial|ranged|1d6|1d8|x3|100|3|75|P
Longbow, composite|Arco longo composto|martial|ranged|1d6|1d8|x3|110|3|100|P
Shortbow|Arco curto|martial|ranged|1d4|1d6|x3|60|2|30|P
Shortbow, composite|Arco curto composto|martial|ranged|1d4|1d6|x3|70|2|75|P
Kama|Kama|exotic|light|1d4|1d6|x2|0|2|2|S
Nunchaku|Nunchaku|exotic|light|1d4|1d6|x2|0|2|2|B
Sai|Sai|exotic|light|1d3|1d4|x2|10|1|1|B
Siangham|Siangham|exotic|light|1d4|1d6|x2|0|1|3|P
Sword, bastard|Espada bastarda|exotic|one|1d8|1d10|19-20/x2|0|6|35|S
Waraxe, dwarven|Machado de guerra anão|exotic|one|1d8|1d10|x3|0|8|30|S
Whip|Chicote|exotic|one|1d2|1d3|x2|0|2|1|S
Axe, orc double|Machado duplo orc|exotic|two|1d6/1d6|1d8/1d8|x3|0|15|60|S
Chain, spiked|Corrente com cravos|exotic|two|1d6|2d4|x2|0|10|25|P
Flail, dire|Mangual atroz|exotic|two|1d6/1d6|1d8/1d8|x2|0|10|90|B
Hammer, gnome hooked|Martelo-gancho gnomo|exotic|two|1d6/1d4|1d8/1d6|x3/x4|0|6|20|B/P
Sword, two-bladed|Espada de lâmina dupla|exotic|two|1d6/1d6|1d8/1d8|19-20/x2|0|10|100|S
Urgrosh, dwarven|Urgrosh anão|exotic|two|1d6/1d4|1d8/1d6|x3|0|12|50|S/P
Bolas|Boleadeira|exotic|thrown|1d3|1d4|x2|10|2|5|B
Crossbow, hand|Besta de mão|exotic|ranged|1d3|1d4|19-20/x2|30|2|100|P
Crossbow, repeating heavy|Besta de repetição pesada|exotic|ranged|1d8|1d10|19-20/x2|120|12|400|P
Crossbow, repeating light|Besta de repetição leve|exotic|ranged|1d6|1d8|19-20/x2|80|6|250|P
Net|Rede|exotic|thrown|—|—|—|10|6|20|—
Shuriken|Shuriken|exotic|thrown|1d2|1d3|x2|10|0.5|1|P'''
FINESSE = {'Rapier','Whip','Chain, spiked'}
weapons = []
for line in W.split('\n'):
    n, pt, cat, hand, ds, dm, crit, rng, wt, cost, dt = line.split('|')
    cr, mult = 20, 2
    for part in crit.split('/'):
        if '-' in part: cr = int(part.split('-')[0])
    mults = [int(p[1:]) for p in crit.split('/') if p.startswith('x')]
    if mults: mult = mults[0]
    weapons.append({'name': n, 'name_pt': pt, 'category': cat, 'handed': hand, 'dmg_s': ds, 'dmg_m': dm,
                    'crit_range': cr, 'crit_mult': mult, 'crit_text': crit, 'range': int(rng), 'weight': float(wt),
                    'cost': float(cost), 'dtype': dt, 'finesse': hand == 'light' or n in FINESSE,
                    'book': 'PH', 'page': 116})

# ---------------------------------------------------------------- armaduras (PH tabela 7-6)
AR = '''Padded|Acolchoada|light|1|8|0|5|30|20|10|5
Leather|Couro|light|2|6|0|10|30|20|15|10
Studded leather|Couro batido|light|3|5|-1|15|30|20|20|25
Chain shirt|Camisão de cota de malha|light|4|4|-2|20|30|20|25|100
Hide|Gibão de peles|medium|3|4|-3|20|20|15|25|15
Scale mail|Brunea|medium|4|3|-4|25|20|15|30|50
Chainmail|Cota de malha|medium|5|2|-5|30|20|15|40|150
Breastplate|Peitoral de aço|medium|5|3|-4|25|20|15|30|200
Splint mail|Loriga segmentada|heavy|6|0|-7|40|20|15|45|200
Banded mail|Cota de talas|heavy|6|1|-6|35|20|15|35|250
Half-plate|Meia armadura|heavy|7|0|-7|40|20|15|50|600
Full plate|Armadura completa|heavy|8|1|-6|35|20|15|50|1500
Buckler|Broquel|shield|1|99|-1|5|0|0|5|15
Shield, light wooden|Escudo leve de madeira|shield|1|99|-1|5|0|0|5|3
Shield, light steel|Escudo leve de aço|shield|1|99|-1|5|0|0|6|9
Shield, heavy wooden|Escudo pesado de madeira|shield|2|99|-2|15|0|0|10|7
Shield, heavy steel|Escudo pesado de aço|shield|2|99|-2|15|0|0|15|20
Shield, tower|Escudo de corpo|shield|4|2|-10|50|0|0|45|30'''
armors = []
for line in AR.split('\n'):
    n, pt, cat, b, md, acp, asf, s30, s20, wt, cost = line.split('|')
    armors.append({'name': n, 'name_pt': pt, 'category': cat, 'bonus': int(b),
                   'max_dex': None if int(md) == 99 else int(md), 'acp': int(acp), 'asf': int(asf),
                   'speed30': int(s30), 'speed20': int(s20), 'weight': float(wt), 'cost': float(cost),
                   'book': 'PH', 'page': 123})

# ---------------------------------------------------------------- condições (DMG p. 300 / PH glossário)
def cond(id, name, pt, text, effects=None):
    return {'id': id, 'name': name, 'name_pt': pt, 'text': text, 'effects': effects or [], 'book': 'DMG', 'page': 300}
CHECKS = lambda v: [E('attack.all',v),E('save.all',v),E('skill.all',v),E('abilitycheck',v)]
conditions = [
 cond('blinded','Blinded','Cego','-2 CA, perde Des na CA, -4 em perícias de For/Des, metade do deslocamento, 50% de falha',
      [E('ac',-2),E('flag.lose_dex_ac',1),E('skillabil.str',-4),E('skillabil.dex',-4),E('flag.half_speed',1)]),
 cond('confused','Confused','Confuso','Age aleatoriamente (role 1d100)'),
 cond('cowering','Cowering','Encolhido','-2 CA, perde Des na CA',[E('ac',-2),E('flag.lose_dex_ac',1)]),
 cond('dazed','Dazed','Pasmo','Não pode agir; sem penalidade na CA'),
 cond('dazzled','Dazzled','Ofuscado','-1 ataque, Procurar e Observar',[E('attack.all',-1),E('skill.search',-1),E('skill.spot',-1)]),
 cond('deafened','Deafened','Surdo','-4 iniciativa, 20% de falha em magias com componente verbal',[E('init',-4)]),
 cond('disabled','Disabled','Incapacitado','0 PV: só uma ação de movimento ou padrão por rodada'),
 cond('dying','Dying','Morrendo','-1 a -9 PV: inconsciente, perde 1 PV por rodada'),
 cond('entangled','Entangled','Enredado','-2 ataque, -4 Des, metade do deslocamento',[E('attack.all',-2),E('abil.dex',-4),E('flag.half_speed',1),E('flag.no_run',1)]),
 cond('exhausted','Exhausted','Exausto','-6 For e Des, metade do deslocamento',[E('abil.str',-6),E('abil.dex',-6),E('flag.half_speed',1),E('flag.no_run',1)]),
 cond('fascinated','Fascinated','Fascinado','-4 em Ouvir e Observar como reação',[E('skill.listen',-4),E('skill.spot',-4)]),
 cond('fatigued','Fatigued','Fatigado','-2 For e Des; não pode correr nem investir',[E('abil.str',-2),E('abil.dex',-2),E('flag.no_run',1)]),
 cond('flat-footed','Flat-Footed','Surpreendido','Perde Des (e esquiva) na CA',[E('flag.lose_dex_ac',1)]),
 cond('frightened','Frightened','Amedrontado','-2 ataque, resistências, perícias e testes de atributo; foge',CHECKS(-2)),
 cond('grappling','Grappling','Agarrado','Perde Des na CA contra quem não está agarrando; sem ataques de oportunidade',[E('flag.lose_dex_ac',1,cond='contra quem não está no agarrão')]),
 cond('helpless','Helpless','Indefeso','Des efetiva 0 (-5); golpe de misericórdia',[E('flag.dex_zero',1)]),
 cond('invisible','Invisible','Invisível','+2 ataque; alvos perdem Des na CA',[E('attack.all',2,cond='contra oponentes que não o veem')]),
 cond('nauseated','Nauseated','Nauseado','Só uma ação de movimento por rodada'),
 cond('panicked','Panicked','Em pânico','-2 resistências, perícias e testes de atributo; larga o que segura e foge',[E('save.all',-2),E('skill.all',-2),E('abilitycheck',-2)]),
 cond('paralyzed','Paralyzed','Paralisado','For e Des efetivas 0; indefeso',[E('flag.dex_zero',1),E('flag.str_zero',1)]),
 cond('pinned','Pinned','Imobilizado (agarrão)','Perde Des na CA, -4 CA contra outros',[E('flag.lose_dex_ac',1),E('ac',-4,cond='contra quem não o imobiliza')]),
 cond('prone','Prone','Caído','-4 ataque corpo a corpo; +4 CA contra distância, -4 CA contra corpo a corpo',
      [E('attack.melee',-4),E('ac',4,cond='contra ataques à distância'),E('ac',-4,cond='contra ataques corpo a corpo')]),
 cond('shaken','Shaken','Abalado','-2 ataque, resistências, perícias e testes de atributo',CHECKS(-2)),
 cond('sickened','Sickened','Enjoado','-2 ataque, dano, resistências, perícias e testes de atributo',CHECKS(-2)+[E('damage.all',-2)]),
 cond('stable','Stable','Estável','Inconsciente, não perde mais PV'),
 cond('staggered','Staggered','Zonzo','Só uma ação padrão ou de movimento por rodada'),
 cond('stunned','Stunned','Atordoado','-2 CA, perde Des na CA, larga o que segura, não age',[E('ac',-2),E('flag.lose_dex_ac',1)]),
 cond('unconscious','Unconscious','Inconsciente','Indefeso',[E('flag.dex_zero',1)]),
 cond('petrified','Petrified','Petrificado','Transformado em pedra; inconsciente'),
 cond('turned','Turned','Expulso','Foge da fonte de expulsão'),
 cond('raging-fatigue','Fatigued after rage','Fadiga pós-fúria','Fatigado até o fim do encontro',[E('abil.str',-2),E('abil.dex',-2),E('flag.no_run',1)]),
]

# ---------------------------------------------------------------- tabelas gerais
tables = {
  'sizes': {
    'fine':       {'pt':'Minúsculo','mod':8,'grapple':-16,'hide':16,'carry':0.125,'reach':0},
    'diminutive': {'pt':'Diminuto','mod':4,'grapple':-12,'hide':12,'carry':0.25,'reach':0},
    'tiny':       {'pt':'Miúdo','mod':2,'grapple':-8,'hide':8,'carry':0.5,'reach':0},
    'small':      {'pt':'Pequeno','mod':1,'grapple':-4,'hide':4,'carry':0.75,'reach':5},
    'medium':     {'pt':'Médio','mod':0,'grapple':0,'hide':0,'carry':1,'reach':5},
    'large':      {'pt':'Grande','mod':-1,'grapple':4,'hide':-4,'carry':2,'reach':10},
    'huge':       {'pt':'Enorme','mod':-2,'grapple':8,'hide':-8,'carry':4,'reach':15},
    'gargantuan': {'pt':'Imenso','mod':-4,'grapple':12,'hide':-12,'carry':8,'reach':20},
    'colossal':   {'pt':'Colossal','mod':-8,'grapple':16,'hide':-16,'carry':16,'reach':30},
  },
  'size_order': ['fine','diminutive','tiny','small','medium','large','huge','gargantuan','colossal'],
  # carga pesada máxima por Força 1..29 (PH tabela 9-1); acima de 29: ×4 a cada +10
  'heavy_load': [10,20,30,40,50,60,70,80,90,100,115,130,150,175,200,230,260,300,350,400,460,520,600,700,800,920,1040,1200,1400],
  # riqueza do personagem por nível (DMG tabela 5-1); 21+ estimado ×1,3 por nível (ver ELH)
  'wealth_by_level': [0,900,2700,5400,9000,13000,19000,27000,36000,49000,66000,88000,110000,150000,200000,
                      260000,340000,440000,580000,760000],
  'point_buy': {'8':0,'9':1,'10':2,'11':3,'12':4,'13':5,'14':6,'15':8,'16':10,'17':13,'18':16},
  'elite_array': [15,14,13,12,10,8],
  'nonelite_array': [13,12,11,10,9,8],
  'schools': ['Abjuration','Conjuration','Divination','Enchantment','Evocation','Illusion','Necromancy','Transmutation','Universal'],
  'schools_pt': ['Abjuração','Conjuração','Adivinhação','Encantamento','Evocação','Ilusão','Necromancia','Transmutação','Universal'],
  'alignments': ['LG','NG','CG','LN','N','CN','LE','NE','CE'],
  'alignments_pt': ['Leal e Bom','Neutro e Bom','Caótico e Bom','Leal e Neutro','Neutro','Caótico e Neutro','Leal e Mau','Neutro e Mau','Caótico e Mau'],
  # progressão de dano por categoria de tamanho (para armas Grandes+)
  'damage_steps': ['1','1d2','1d3','1d4','1d6','1d8','2d6','3d6','4d6','6d6','8d6','12d6'],
}

core = {'version': 1, 'source': 'SRD 3.5 (OGL) — ver LICENSE-OGL.txt',
        'skills': skills, 'synergies': synergies, 'classes': C, 'races': R, 'feats': FEATS,
        'weapons': weapons, 'armors': armors, 'conditions': conditions, 'tables': tables}

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(core, f, ensure_ascii=False, separators=(',', ':'))
print('ok', OUT, os.path.getsize(OUT), 'bytes;', len(C), 'classes', len(R), 'raças', len(FEATS), 'talentos',
      len(weapons), 'armas', len(armors), 'armaduras', len(conditions), 'condições')
