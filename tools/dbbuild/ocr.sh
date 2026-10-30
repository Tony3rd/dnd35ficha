#!/bin/bash
# OCR de livros digitalizados sem texto: ocr.sh <pdf> <saida.txt>
pdf="$1"; out="$2"; tmp=$(mktemp -d)
n=$(pdfinfo "$pdf" | awk '/^Pages:/{print $2}')
: > "$out.tmp"
for ((p=1; p<=n; p++)); do
  pdftoppm -r 200 -gray -f $p -l $p -png "$pdf" "$tmp/pg" >/dev/null 2>&1
  img=$(ls "$tmp"/pg*.png | head -1)
  tesseract "$img" - -l eng --psm 1 2>/dev/null >> "$out.tmp"
  printf '\f' >> "$out.tmp"
  rm -f "$tmp"/pg*.png
done
mv "$out.tmp" "$out"; rmdir "$tmp"
