#!/usr/bin/env python3
"""Passo 2: monta data/rules.sqlite a partir dos textos extraídos.

Uso: python3 build_db.py <pasta work> <saida.sqlite> [<pasta tormenta>]

Conteúdo:
  books   — catálogo (id, título, cenário, lançamento...)
  pages   — texto integral de cada página, com o número de página impresso
  entries — itens (magias, talentos, classes, raças, itens...) com livro e página;
            campo data (JSON) com regras estruturadas quando detectadas
  *_fts   — índices de busca de texto (FTS5)
Fontes das entradas: (1) análise direta dos livros (magias, talentos, poderes,
manobras, classes com tabela de progressão, itens do MIC) e (2) os índices
"DnD3.5Index" (referência livro/página de raças, classes, itens, divindades...).
"""
import glob
import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(__file__))
from catalog import BOOKS, EXTERNAL, INDEX_ALIASES, TORMENTA  # noqa: E402

WORK = sys.argv[1] if len(sys.argv) > 1 else 'work'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'out/rules.sqlite'
TORM_DIR = sys.argv[3] if len(sys.argv) > 3 else None


def slug(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode()
    s = s.lower().replace("’", '').replace("'", '')
    return re.sub(r'[^a-z0-9]+', '-', s).strip('-')


def clean(s):
    s = s.replace('­', '').replace('ﬁ', 'fi').replace('ﬂ', 'fl').replace('ﬀ', 'ff').replace('ﬃ', 'ffi')
    return re.sub(r'[ \t]+', ' ', s)


def titlecase(s):
    small = {'of', 'the', 'and', 'a', 'an', 'to', 'in', 'on', 'for', 'with', 'from', 'by', 'at', 'or'}
    words = s.lower().split()
    out = []
    for i, w in enumerate(words):
        if i > 0 and w in small:
            out.append(w)
        else:
            out.append('-'.join(p[:1].upper() + p[1:] for p in w.split('-')))
    return ' '.join(out).replace('’S', '’s').replace("'S", "'s")


# ------------------------------------------------------------------ páginas
def page_offset(pages):
    votes = Counter()
    for i, p in enumerate(pages):
        lines = [l.strip() for l in p.split('\n') if l.strip()]
        cand = lines[:3] + lines[-3:]
        for l in cand:
            if re.fullmatch(r'\d{1,3}', l):
                n = int(l)
                if 0 < n < 1000:
                    votes[n - (i + 1)] += 1
    if not votes:
        return 0
    off, n = votes.most_common(1)[0]
    return off if n >= 5 else 0


# ------------------------------------------------------------------ entradas
class Store:
    def __init__(self):
        self.items = {}  # (kind, slug, book) -> dict

    def add(self, kind, name, book, page, summary='', body='', data=None, origin='book'):
        name = name.strip().strip(',;:.').strip()
        if not name or len(name) > 90:
            return
        key = (kind, slug(name), book)
        if not key[1]:
            return
        cur = self.items.get(key)
        if cur is None:
            self.items[key] = dict(kind=kind, name=name, book=book, page=page, summary=summary or '',
                                   body=body or '', data=data or {}, origin=origin)
            return
        # mescla: mantém o texto mais completo e a página do livro analisado
        if body and len(body) > len(cur['body']):
            cur['body'] = body
        if summary and not cur['summary']:
            cur['summary'] = summary
        if data:
            merged = dict(cur['data'])
            for k, v in data.items():
                if k == 'levels' and isinstance(v, dict):
                    merged.setdefault('levels', {}).update(v)
                elif v not in (None, '', [], {}):
                    merged.setdefault(k, v)
            cur['data'] = merged
        if cur['page'] is None and page is not None:
            cur['page'] = page
        if origin != cur['origin']:
            cur['origin'] = 'both'


STORE = Store()

CLASS_LIST_MAP = {
    'sorcerer/wizard': 'Sor/Wiz', 'sor/wiz': 'Sor/Wiz', 'wizard/sorcerer': 'Sor/Wiz', 'cleric': 'Clr', 'clr': 'Clr',
    'druid': 'Drd', 'drd': 'Drd', 'bard': 'Brd', 'brd': 'Brd', 'paladin': 'Pal', 'pal': 'Pal', 'ranger': 'Rgr',
    'rgr': 'Rgr', 'assassin': 'Asn', 'blackguard': 'Blk', 'adept': 'Adp', 'wu jen': 'Wu Jen', 'shugenja': 'Sha',
    'hexblade': 'Hexblade', 'duskblade': 'Duskblade', 'beguiler': 'Beguiler', 'warmage': 'Warmage',
    'wizard': 'Sor/Wiz', 'sorcerer': 'Sor/Wiz', 'spellthief': 'Spellthief', 'healer': 'Healer',
    'sha': 'Sha', 'wu': 'Wu Jen', 'death master': 'Death Master', 'favored soul': 'Clr',
}


def parse_levels(txt):
    out = {}
    for part in re.split(r',\s*', txt):
        m = re.match(r'\s*([A-Za-z][A-Za-z/ \'’()-]*?)\s+(\d)\b', part.strip())
        if not m:
            continue
        k = m.group(1).strip()
        key = CLASS_LIST_MAP.get(k.lower(), k[:1].upper() + k[1:])
        out[key] = int(m.group(2))
    return out


SCHOOL_RE = (r'(Abjuration|Conjuration|Divination|Enchantment|Evocation|Illusion|Necromancy|Transmutation|Universal)'
             r'(?:\s*\(([^)]*)\))?(?:\s*\[([^\]]*)\])?')
SPELL_FIELDS = [('Level', 'level'), ('Components', 'components'), ('Casting Time', 'casting_time'),
                ('Range', 'range'), ('Effect', 'target'), ('Area', 'target'), ('Target', 'target'),
                ('Targets', 'target'), ('Duration', 'duration'), ('Saving Throw', 'save'),
                ('Spell Resistance', 'sr')]


def parse_book_text(bid, pages, offset):
    """Analisa magias, talentos, poderes e manobras no texto de um livro."""
    full = []
    page_of = []  # índice de linha -> página impressa
    for i, p in enumerate(pages):
        for line in clean(p).split('\n'):
            full.append(line.rstrip())
            page_of.append(i + 1 + offset)
    n = len(full)

    def body_from(start, maxlines=120):
        out = []
        for j in range(start, min(n, start + maxlines)):
            l = full[j]
            if j > start + 3 and HEAD_RE.match(l.strip()) and len(l.strip()) > 3:
                # próxima entrada em maiúsculas
                nxt = full[j + 1].strip() if j + 1 < n else ''
                if re.match(SCHOOL_RE, nxt) or FEAT_RE.match(l.strip()) or re.match(r'(Level|Discipline)', nxt):
                    break
            out.append(l)
        return re.sub(r'\n{3,}', '\n\n', '\n'.join(out)).strip()

    for i in range(n - 3):
        line = full[i].strip()
        # ---------------------------------------------------- magias
        m = re.fullmatch(SCHOOL_RE, full[i + 1].strip()) if HEAD_RE.match(line) else None
        if m and 'Level:' in ' '.join(full[i + 2:i + 5]):
            name = titlecase(line)
            data = {'school': m.group(1), 'subschool': m.group(2) or '', 'descriptors': m.group(3) or ''}
            blob = '\n'.join(full[i + 2:i + 16])
            for label, key in SPELL_FIELDS:
                mm = re.search(rf'^{label}:\s*(.+(?:\n(?!\w[\w ]*:).+)?)', blob, re.M)
                if mm and key not in data:
                    data[key] = re.sub(r'\s+', ' ', mm.group(1)).strip()
            if 'level' in data:
                data['levels'] = parse_levels(data.pop('level'))
            body = body_from(i)
            STORE.add('spell', name, bid, page_of[i], body=body, data=data)
            continue
        # ---------------------------------------------------- talentos
        fm = FEAT_RE.match(line)
        if fm and i + 1 < n:
            look = ' '.join(full[i + 1:i + 8])
            if re.search(r'\b(Prerequisites?|Benefit):', look):
                name = titlecase(fm.group(1))
                types = [t.strip().lower() for t in fm.group(2).split(',')]
                body = body_from(i, 60)
                pre = re.search(r'Prerequisites?:\s*(.+?)(?:\n\w+:|\Z)', body, re.S)
                data = {'types': types}
                if pre:
                    data['prereq_text'] = re.sub(r'\s+', ' ', pre.group(1)).strip()
                    data['prereq'] = parse_prereq(data['prereq_text'])
                ben = re.search(r'Benefit:\s*(.+?)(?:\n(?:Normal|Special):|\Z)', body, re.S)
                summary = re.sub(r'\s+', ' ', ben.group(1)).strip()[:200] if ben else ''
                STORE.add('feat', name, bid, page_of[i], summary=summary, body=body, data=data)
                continue
        # ---------------------------------------------------- poderes psiônicos
        if HEAD_RE.match(line) and re.match(r'(Clairsentience|Metacreativity|Psychokinesis|Psychometabolism|Psychoportation|Telepathy)',
                                             full[i + 1].strip()) and 'Manifesting Time' in ' '.join(full[i + 2:i + 9]):
            lv = re.search(r'Level:\s*(.+)', '\n'.join(full[i + 2:i + 6]))
            data = {'discipline': full[i + 1].strip()}
            if lv:
                data['levels'] = parse_levels(lv.group(1))
            STORE.add('power', titlecase(line), bid, page_of[i], body=body_from(i), data=data)
            continue
        # ---------------------------------------------------- manobras (Tome of Battle)
        if HEAD_RE.match(line) and 'Initiation Action' in ' '.join(full[i + 1:i + 7]) and 'Level:' in ' '.join(full[i + 1:i + 5]):
            disc = full[i + 1].strip()
            lv = re.search(r'Level:\s*(.+)', '\n'.join(full[i + 1:i + 5]))
            data = {'discipline': disc}
            if lv:
                data['levels'] = parse_levels(lv.group(1))
            STORE.add('maneuver', titlecase(line), bid, page_of[i], body=body_from(i), data=data)
            continue
        # ---------------------------------------------------- itens (Magic Item Compendium / DMG2)
        if HEAD_RE.match(line) and re.match(r'Price(?: \(Item Level\))?:', full[i + 1].strip()):
            pm = re.search(r'([\d,]+)\s*gp', full[i + 1])
            data = {}
            if pm:
                data['cost'] = float(pm.group(1).replace(',', ''))
            blob = '\n'.join(full[i + 1:i + 8])
            bs = re.search(r'Body Slot:\s*(.+)', blob)
            if bs:
                data['slot'] = bs.group(1).strip()
            wm = re.search(r'Weight:\s*([\d.]+)\s*lb', blob)
            if wm:
                data['weight'] = float(wm.group(1))
            STORE.add('magic-item', titlecase(line), bid, page_of[i], summary=full[i + 1].strip(), body=body_from(i, 50), data=data)


HEAD_RE = re.compile(r"^[A-Z][A-Z0-9’',:\-/() ]{2,60}$")
FEAT_RE = re.compile(r"^([A-Z][A-Z0-9’',\-/() ]{2,60}?)\s*\[([A-Z][A-Za-z ,]+)\]\s*$")


def parse_prereq(t):
    out = []
    for part in re.split(r',\s*(?![^()]*\))|;\s*', t.rstrip('.')):
        p = part.strip().rstrip('.')
        m = re.match(r'^(Str|Dex|Con|Int|Wis|Cha)\s+(\d+)$', p)
        if m:
            out.append({'k': 'abil', 'key': m.group(1).lower(), 'v': int(m.group(2))})
            continue
        m = re.match(r'^[Bb]ase attack bonus \+(\d+)$', p)
        if m:
            out.append({'k': 'bab', 'v': int(m.group(1))})
            continue
        m = re.match(r'^(.+?) (\d+) ranks?$', p)
        if m:
            out.append({'k': 'skill', 'key': slug(m.group(1)), 'v': int(m.group(2))})
            continue
        m = re.match(r'^[Cc]aster level (\d+)(?:st|nd|rd|th)$', p)
        if m:
            out.append({'k': 'cl', 'v': int(m.group(1))})
            continue
        m = re.match(r'^(?:[Cc]haracter level )?(\d+)(?:st|nd|rd|th)[- ]level (\w+)$', p)
        if m:
            out.append({'k': 'class', 'key': slug(m.group(2)), 'v': int(m.group(1))})
            continue
        if re.match(r"^[A-Z][A-Za-z’' \-]+(\s\([^)]*\))?$", p) and len(p) < 45 and not re.search(r'\b(ability|class|level|feature|alignment)\b', p, re.I):
            out.append({'k': 'feat', 'key': p})
    return out


# ------------------------------------------------------------------ classes (tabela de progressão)
SKILL_IDS = {
    'appraise': 'appraise', 'balance': 'balance', 'bluff': 'bluff', 'climb': 'climb', 'concentration': 'concentration',
    'craft': 'craft', 'decipher script': 'decipher-script', 'diplomacy': 'diplomacy', 'disable device': 'disable-device',
    'disguise': 'disguise', 'escape artist': 'escape-artist', 'forgery': 'forgery', 'gather information': 'gather-information',
    'handle animal': 'handle-animal', 'heal': 'heal', 'hide': 'hide', 'intimidate': 'intimidate', 'jump': 'jump',
    'listen': 'listen', 'move silently': 'move-silently', 'open lock': 'open-lock', 'perform': 'perform',
    'profession': 'profession', 'ride': 'ride', 'search': 'search', 'sense motive': 'sense-motive',
    'sleight of hand': 'sleight-of-hand', 'speak language': 'speak-language', 'spellcraft': 'spellcraft', 'spot': 'spot',
    'survival': 'survival', 'swim': 'swim', 'tumble': 'tumble', 'use magic device': 'use-magic-device', 'use rope': 'use-rope',
    'knowledge (arcana)': 'knowledge-arcana', 'knowledge (architecture and engineering)': 'knowledge-architecture',
    'knowledge (dungeoneering)': 'knowledge-dungeoneering', 'knowledge (geography)': 'knowledge-geography',
    'knowledge (history)': 'knowledge-history', 'knowledge (local)': 'knowledge-local', 'knowledge (nature)': 'knowledge-nature',
    'knowledge (nobility and royalty)': 'knowledge-nobility', 'knowledge (religion)': 'knowledge-religion',
    'knowledge (the planes)': 'knowledge-planes', 'autohypnosis': 'autohypnosis', 'psicraft': 'psicraft',
    'use psionic device': 'use-psionic-device', 'martial lore': 'martial-lore', 'truespeak': 'truespeak',
}
KNOW_ALL = [v for k, v in SKILL_IDS.items() if k.startswith('knowledge (')]


def class_skills(txt):
    txt = re.sub(r'\s+', ' ', txt.replace('-\n', ''))
    m = re.search(r'class skills(?: \(and the key ability for each skill\))? are\s+(.+?)\.\s', txt, re.S)
    if not m:
        return []
    s = re.sub(r'\s+', ' ', m.group(1))
    out = []
    for part in re.split(r',\s*(?:and\s+)?|\s+and\s+', s):
        p = re.sub(r'\s*\((Str|Dex|Con|Int|Wis|Cha)\)\s*', '', part).strip().lower()
        p = p.replace('–', '-')
        if p.startswith('knowledge (all skills') or p == 'knowledge (all)' or 'all skills, taken individually' in p:
            out += KNOW_ALL
            continue
        if p in SKILL_IDS:
            out.append(SKILL_IDS[p])
    return sorted(set(out))


def sig(tok):
    return int(tok.split('/')[0].replace('+', '').replace('–', '-'))


def fit_progression(vals):
    """Identifica BBA (full/3-4/1-2) e resistências (boa/ruim) a partir dos valores."""
    n = len(vals)
    lv = range(1, n + 1)
    bab = {'full': [l for l in lv], '3/4': [l * 3 // 4 for l in lv], '1/2': [l // 2 for l in lv]}
    for k, seq in bab.items():
        if vals == seq:
            return ('bab', k)
    good = [2 + l // 2 for l in lv]
    poor = [l // 3 for l in lv]
    good_pr = [(l + 1) // 2 + 1 if False else 2 + l // 2 for l in lv]  # prestígio usa a mesma fórmula
    if vals == good or vals == good_pr:
        return ('save', 'good')
    if vals == poor:
        return ('save', 'poor')
    return None


def parse_class_tables(bid, pages, offset):
    for i, p in enumerate(pages):
        txt = clean(p)
        for tm in re.finditer(r'Table \d+[–-]\d+: The ([A-Z][A-Za-z’\' -]+?)\s*\n', txt):
            cname = tm.group(1).strip()
            if cname.lower().startswith(('the ', 'small', 'large')) or len(cname) > 40:
                continue
            seg = txt[tm.end():tm.end() + 4500]
            nxt = re.search(r'\nTable \d+[–-]\d+:', seg)
            if nxt:
                seg = seg[:nxt.start()]
            ords = re.findall(r'\b(\d{1,2})(?:st|nd|rd|th)\b', seg)
            nlev = 0
            for k, o in enumerate(ords):
                if int(o) == k + 1:
                    nlev = k + 1
                else:
                    break
            if nlev < 3:
                continue
            toks = re.findall(r'(?<![\w/])[+–-]\d+(?:/\+\d+)*', seg)
            vals = [sig(t) for t in toks]
            res = None
            # coluna por coluna (BBA, Fort, Ref, Will)
            if len(vals) >= 4 * nlev:
                cols = [vals[c * nlev:(c + 1) * nlev] for c in range(4)]
                f = [fit_progression(c) for c in cols]
                if f[0] and f[0][0] == 'bab' and all(x and x[0] == 'save' for x in f[1:]):
                    res = f
            # linha por linha
            if res is None and len(vals) >= 4 * nlev:
                rows = []
                pos = 0
                for _ in range(nlev):
                    rows.append(vals[pos:pos + 4])
                    pos += 4
                cols = [[r[c] for r in rows] for c in range(4)]
                f = [fit_progression(c) for c in cols]
                if f[0] and f[0][0] == 'bab' and all(x and x[0] == 'save' for x in f[1:]):
                    res = f
            if res is None:
                continue
            # dados de texto ao redor (mesma página e anteriores)
            ctx = '\n'.join(clean(pages[j]) for j in range(max(0, i - 2), min(len(pages), i + 3)))
            hd = re.search(r'Hit Die:\s*d(\d+)', ctx)
            sp = re.search(r'Skill Points at (?:Each (?:Additional )?Level|1st Level)[^:]*:\s*(?:\()?(\d+)', ctx)
            skills = class_skills(ctx)
            prestige = nlev < 20
            data = {
                'hit_die': int(hd.group(1)) if hd else None,
                'skill_points': int(sp.group(1)) if sp else None,
                'bab': res[0][1],
                'good_saves': [s for s, r in zip(['fort', 'ref', 'will'], res[1:]) if r[1] == 'good'],
                'class_skills': skills,
                'max_level': nlev,
                'prestige': prestige,
            }
            adv = len(re.findall(r'\+1 (?:level of existing|to existing)', seg))
            if adv >= nlev - 1:
                data['advances_casting'] = list(range(1, nlev + 1))
            if data['hit_die'] is None or data['skill_points'] is None:
                data = {k: v for k, v in data.items() if k not in ('hit_die', 'skill_points')}
            req = re.search(r'REQUIREMENTS?\s*\n(.+?)(?:\n[A-Z ]{6,}\n|Class Skills|CLASS SKILLS)', ctx, re.S)
            if req:
                data['requirements'] = re.sub(r'\s+', ' ', req.group(1)).strip()[:600]
            STORE.add('prestige' if prestige else 'class', titlecase(cname), bid, i + 1 + offset,
                      summary=f"d{data.get('hit_die', '?')} · {data.get('skill_points', '?')}+Int · BBA {data['bab']} · {'/'.join(data['good_saves'])}",
                      body=txt[:4000], data=data)


# ------------------------------------------------------------------ índices
SRC_RE = re.compile(r"\(([A-Za-z0-9.&+']{1,12}) ?p ?(\d{1,3})\)")


def norm_src(s):
    s = s.rstrip('+')
    return INDEX_ALIASES.get(s, s)


def index_spells(path):
    txt = open(path, encoding='utf-8', errors='replace').read()
    txt = re.sub(r'\s*\n\s*', ' ', txt)
    pat = re.compile(r"([A-Z][A-Za-z’',:/ \-]{1,60}?)((?:\s?\([A-Za-z0-9.&']{1,12} ?p ?\d{1,3}\))+)\+?\s*\[([^\]]{1,200})\]\s*[–-]\s*")
    ms = list(pat.finditer(txt))
    for k, m in enumerate(ms):
        end = ms[k + 1].start() if k + 1 < len(ms) else min(len(txt), m.end() + 300)
        summary = txt[m.end():end].strip()[:300]
        name = m.group(1).strip()
        levels = {}
        for t in m.group(3).split():
            mm = re.match(r'^(.+?)(\d)$', t)
            if mm:
                k2 = mm.group(1)
                levels[{'Sor/Wiz': 'Sor/Wiz'}.get(k2, k2)] = int(mm.group(2))
        for src, pg in SRC_RE.findall(m.group(2)):
            STORE.add('spell', name, norm_src(src), int(pg), summary=summary, data={'levels': levels}, origin='index')


def index_table(path, kind):
    """Índices em tabela (layout): o nome fica na 1ª coluna, a fonte abaixo ou ao lado."""
    lines = open(path, encoding='utf-8', errors='replace').read().split('\n')
    for i, l in enumerate(lines):
        for m in SRC_RE.finditer(l):
            c = m.start()
            name = None
            if c < 12 and i > 0:
                for k in range(i - 1, max(-1, i - 3), -1):
                    first = re.split(r'\s{2,}', lines[k].strip())[0] if lines[k].strip() else ''
                    if re.match(r"^[A-Z][A-Za-z’',() \-]{1,45}$", first) and not lines[k].startswith('    '):
                        name = first
                        break
            else:
                for k in range(i, max(-1, i - 4), -1):
                    seg = lines[k][max(0, c - 48):c]
                    parts = [p.strip() for p in re.split(r'\s{2,}', seg) if p.strip()]
                    parts = [p for p in parts if not p.startswith('[') and not SRC_RE.search(p)
                             and re.match(r"^[A-Z][A-Za-z’',() \-]{1,45}$", p)]
                    if parts:
                        name = parts[-1]
                        break
            if name and len(name) > 2:
                STORE.add(kind, name, norm_src(m.group(1)), int(m.group(2)), origin='index')


def index_generic(path, kind, min_len=2):
    """Qualquer "Nome(SRC pNN)" numa linha vira referência livro/página."""
    for line in open(path, encoding='utf-8', errors='replace'):
        for m in re.finditer(r"([A-Z][A-Za-z’',:/ \-]{%d,60}?)\s?((?:\([A-Za-z0-9.&']{1,12} ?p ?\d{1,3}\)\s?)+)" % min_len, line):
            name = m.group(1).strip(' -–,')
            if re.search(r'\b(Page|Table|Index|Source)\b', name):
                continue
            for src, pg in SRC_RE.findall(m.group(2)):
                STORE.add(kind, name, norm_src(src), int(pg), origin='index')


# ------------------------------------------------------------------ Tormenta (OCR, português)
def tormenta_pages(base):
    import xml.etree.ElementTree as ET
    xmlp = os.path.join(TORM_DIR, base + '_djvu.xml')
    pn = os.path.join(TORM_DIR, base + '_page_numbers.json')
    pages = []
    for _, el in ET.iterparse(xmlp, events=('end',)):
        if el.tag == 'OBJECT':
            lines = []
            for line in el.iter('LINE'):
                lines.append(' '.join((w.text or '') for w in line.iter('WORD')))
            pages.append('\n'.join(lines))
            el.clear()
    nums = {}
    if os.path.exists(pn):
        for p in json.load(open(pn, encoding='utf-8'))['pages']:
            if p.get('pageNumber'):
                try:
                    nums[p['leafNum']] = int(p['pageNumber'])
                except ValueError:
                    pass
    return pages, nums


def parse_tormenta(bid, pages, nums):
    for i, p in enumerate(pages):
        page = nums.get(i + 1)
        lines = [l.strip() for l in p.split('\n')]
        for j, l in enumerate(lines):
            nxt = ' '.join(lines[j + 1:j + 6])
            # talentos: "Nome [Tipo]" seguido de Pré-requisito/Benefício
            fm = re.match(r'^([A-ZÁÉÍÓÚÂÊÔÃÕÇ][\wÀ-ÿ’\' \-]{2,50}?)\s*\[([\wÀ-ÿ ,]+)\]$', l)
            if fm and re.search(r'(Pré-requisitos?|Benefício)\s*:', nxt):
                body = '\n'.join(lines[j:j + 25])
                ben = re.search(r'Benefício\s*:\s*(.+)', body)
                STORE.add('feat', fm.group(1).strip().title(), bid, page, summary=(ben.group(1)[:200] if ben else ''),
                          body=body, data={'types': [t.strip().lower() for t in fm.group(2).split(',')]})
                continue
            # magias: linha de escola seguida de "Nível:"
            if re.match(r'^(Abjuração|Adivinhação|Conjuração|Encantamento|Evocação|Ilusão|Necromancia|Transmutação|Universal)', lines[j + 1] if j + 1 < len(lines) else '') \
                    and 'Nível' in nxt and len(l) < 50 and l[:1].isupper():
                body = '\n'.join(lines[j:j + 40])
                lv = re.search(r'Nível\s*:\s*(.+)', body)
                data = {'school': lines[j + 1].split()[0]}
                if lv:
                    data['levels'] = parse_levels(lv.group(1))
                STORE.add('spell', l.title() if l.isupper() else l, bid, page, body=body, data=data)
                continue
            # classes: "Dado de Vida: d8"
            hm = re.match(r'^Dados? de Vida\s*:\s*d(\d+)', l)
            if hm:
                # nome: procura título em maiúsculas nas linhas anteriores
                for k in range(j - 1, max(-1, j - 40), -1):
                    t = lines[k]
                    if t.isupper() and 3 < len(t) < 40 and re.fullmatch(r'[A-ZÀ-Ý ]+', t):
                        ctx = '\n'.join(lines[max(0, j - 5):j + 30])
                        sp = re.search(r'Pontos de Perícia[^:]*:\s*(\d+)', ctx)
                        data = {'hit_die': int(hm.group(1))}
                        if sp:
                            data['skill_points'] = int(sp.group(1))
                        STORE.add('class', t.title(), bid, page, body=ctx, data=data)
                        break


# ------------------------------------------------------------------ montagem
def main():
    os.makedirs(os.path.dirname(OUT) or '.', exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)
    db = sqlite3.connect(OUT)
    db.executescript('''
    CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
    CREATE TABLE books(id TEXT PRIMARY KEY, title TEXT, publisher TEXT, setting TEXT, category TEXT,
                       released INTEGER, language TEXT, pages INTEGER, page_offset INTEGER, edition TEXT, file TEXT);
    CREATE TABLE pages(book TEXT, pdf_page INTEGER, page INTEGER, text TEXT);
    CREATE TABLE entries(id INTEGER PRIMARY KEY, kind TEXT, name TEXT, key TEXT, book TEXT, page INTEGER,
                         summary TEXT, body TEXT, data TEXT, origin TEXT);
    ''')
    text_dir = os.path.join(WORK, 'text')
    for rel, bid, title, rel_date, cat, setting, ed in BOOKS:
        path = os.path.join(text_dir, f'{bid}.txt')
        if not os.path.exists(path):
            continue
        pages = open(path, encoding='utf-8', errors='replace').read().split('\f')
        if pages and not pages[-1].strip():
            pages = pages[:-1]
        filled = sum(1 for p in pages if len(p.strip()) > 200)
        if filled < len(pages) * 0.3:
            ocr = os.path.join(WORK, 'ocr', f'{bid}.txt')
            if os.path.exists(ocr):
                pages = open(ocr, encoding='utf-8', errors='replace').read().split('\f')
            else:
                print(f'  {bid}: sem texto (digitalização sem OCR) — só referências de índice')
                pages = []
        off = page_offset(pages) if pages else 0
        db.execute('INSERT INTO books VALUES (?,?,?,?,?,?,?,?,?,?,?)',
                   (bid, title, 'Wizards of the Coast' if not bid.startswith(('RL', 'D2')) else ('Arthaus' if bid.startswith('RL') else 'WotC/Blizzard'),
                    setting, cat, rel_date, 'en', len(pages), off, ed, rel))
        db.executemany('INSERT INTO pages VALUES (?,?,?,?)',
                       [(bid, i + 1, i + 1 + off, clean(p)) for i, p in enumerate(pages) if p.strip()])
        if pages:
            parse_book_text(bid, pages, off)
            parse_class_tables(bid, pages, off)
        print(f'{bid}: {len(pages)} páginas, deslocamento {off}', flush=True)

    # Tormenta
    if TORM_DIR:
        for base, bid, title, rel_date, cat in TORMENTA:
            if not os.path.exists(os.path.join(TORM_DIR, base + '_djvu.xml')):
                continue
            pages, nums = tormenta_pages(base)
            db.execute('INSERT INTO books VALUES (?,?,?,?,?,?,?,?,?,?,?)',
                       (bid, title, 'Jambô / Talismã', 'Tormenta', cat, rel_date, 'pt', len(pages), 0, '3.5', base))
            db.executemany('INSERT INTO pages VALUES (?,?,?,?)',
                           [(bid, i + 1, nums.get(i + 1, i + 1), p) for i, p in enumerate(pages) if p.strip()])
            parse_tormenta(bid, pages, nums)
            print(f'{bid}: {len(pages)} páginas (OCR)', flush=True)

    # índices
    idx = os.path.join(WORK, 'idx2')
    if os.path.isdir(idx):
        for f in glob.glob(os.path.join(idx, 'DnD3.5Index-Spell-Summaries-by*.txt')):
            index_spells(f)
        for k, kind in {'Feats': 'feat', 'Races': 'race'}.items():
            f = os.path.join(WORK, 'idx', f'DnD3.5Index-{k}.txt')
            if os.path.exists(f):
                index_table(f, kind)
        mapping = {
            'Equipment': 'equipment', 'MagicItems-Personal-byName': 'magic-item',
            'MagicItems-StavesRodsMisc': 'magic-item', 'MagicItems-WeaponsArmor': 'magic-item',
            'Invocations-Warlock': 'invocation', 'Infusions-Artificer': 'infusion', 'Templates': 'template',
            'Monsters-byName': 'monster', 'Creatures': 'monster', 'Skills_Actions': 'rule',
            'Spells-ClericalDomains': 'domain',
        }
        for k, kind in mapping.items():
            f = os.path.join(idx, f'DnD3.5Index-{k}.txt')
            if os.path.exists(f):
                index_generic(f, kind)

    # livros citados nos índices mas ausentes
    known = {r[0] for r in db.execute('SELECT id FROM books')}
    used = {it['book'] for it in STORE.items.values()}
    for b in sorted(used - known):
        title, date = EXTERNAL.get(b, (None, 0))
        if title is None:
            if re.match(r'^DR\d+', b):
                title, date = f'Dragon Magazine #{b[2:]}', 0
            elif re.match(r'^DU\d+', b):
                title, date = f'Dungeon Magazine #{b[2:]}', 0
            else:
                title = b
        db.execute('INSERT INTO books VALUES (?,?,?,?,?,?,?,?,?,?,?)',
                   (b, title, '', '', 'reference', date, 'en', 0, 0, '', ''))

    rows = []
    for it in STORE.items.values():
        rows.append((it['kind'], it['name'], f"{it['kind']}:{slug(it['name'])}", it['book'], it['page'],
                     it['summary'], it['body'], json.dumps(it['data'], ensure_ascii=False) if it['data'] else '', it['origin']))
    db.executemany('INSERT INTO entries(kind,name,key,book,page,summary,body,data,origin) VALUES (?,?,?,?,?,?,?,?,?)', rows)
    db.executescript('''
    CREATE INDEX entries_key ON entries(key);
    CREATE INDEX entries_book ON entries(book, kind);
    CREATE INDEX entries_kind ON entries(kind);
    CREATE INDEX pages_book ON pages(book, page);
    CREATE VIRTUAL TABLE entries_fts USING fts5(name, summary, body, content='entries', content_rowid='id',
        tokenize='unicode61 remove_diacritics 2');
    INSERT INTO entries_fts(rowid, name, summary, body) SELECT id, name, summary, body FROM entries;
    CREATE VIRTUAL TABLE pages_fts USING fts5(text, content='pages', content_rowid='rowid',
        tokenize='unicode61 remove_diacritics 2');
    INSERT INTO pages_fts(rowid, text) SELECT rowid, text FROM pages;
    ''')
    db.execute("INSERT INTO meta VALUES ('version','1')")
    db.execute("INSERT INTO meta VALUES ('built', datetime('now'))")
    db.commit()
    for k, n in db.execute('SELECT kind, COUNT(*) FROM entries GROUP BY kind ORDER BY 2 DESC'):
        print(f'  {k}: {n}')
    print('total entradas:', db.execute('SELECT COUNT(*) FROM entries').fetchone()[0],
          '· páginas:', db.execute('SELECT COUNT(*) FROM pages').fetchone()[0])
    db.execute('VACUUM')
    db.close()


if __name__ == '__main__':
    main()
