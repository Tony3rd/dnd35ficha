#!/usr/bin/env python3
"""Passo 1: extrai o texto de cada PDF do catálogo (uma página por \\f).

Uso: python3 extract_text.py <pasta dnd3.5> <pasta de saída>
Requer `pdftotext` (poppler). Livros já extraídos são pulados.
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(__file__))
from catalog import BOOKS  # noqa: E402


def one(src_root, out_root, rel, bid):
    src = os.path.join(src_root, rel)
    out = os.path.join(out_root, f'{bid}.txt')
    if os.path.exists(out) or not os.path.exists(src):
        return bid, 'skip'
    tmp = out + '.tmp'
    r = subprocess.run(['pdftotext', '-enc', 'UTF-8', src, tmp], capture_output=True)
    if r.returncode != 0:
        return bid, 'erro: ' + r.stderr.decode(errors='replace')[:200]
    os.replace(tmp, out)
    with open(out, encoding='utf-8', errors='replace') as f:
        pages = f.read().split('\f')
    filled = sum(1 for p in pages if len(p.strip()) > 200)
    return bid, f'{len(pages)} páginas, {filled} com texto'


def main():
    src_root, out_root = sys.argv[1], sys.argv[2]
    os.makedirs(out_root, exist_ok=True)
    with ThreadPoolExecutor(max_workers=2) as ex:
        for bid, msg in ex.map(lambda b: one(src_root, out_root, b[0], b[1]), BOOKS):
            if msg != 'skip':
                print(bid, msg, flush=True)


if __name__ == '__main__':
    main()
