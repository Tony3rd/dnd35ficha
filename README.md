# Grimório 3.5

Gerenciador de fichas de D&D 3.5, portátil (roda de pendrive, sem instalação). Interface em português e inglês.

## Funções
- **Ficha completa calculada:** atributos, perícias (com sinergias e penalidade de armadura), BBA e ataques iterativos, resistências, CA (total/toque/surpresa), iniciativa, agarrar, deslocamento e carga.
- **Regras do jogo aplicadas:** empilhamento de bônus por tipo, progressão épica (níveis 21+), penalidade de XP por multiclasse e validação de pré-requisitos.
- **Em jogo:** PV (dano, não letal, temporários), condições com efeitos automáticos, magias e buffs ligáveis, durações por rodada, recursos diários, dano/dreno de atributo, níveis negativos e descanso.
- **Magias:** magias por dia com bônus de atributo, CDs, domínios, escola especializada, grimório/conhecidas, preparação e uso.
- **Armas e armaduras:** bônus de ataque e dano por arma (acuidade, duas mãos, mão inábil, arco composto, foco/especialização, decisivo aprimorado/afiada) e Ataque Poderoso.
- **Assistente de criação** para qualquer nível, inclusive épico. A distribuição automática de perícias facilita fichas de nível alto.
- **Biblioteca:** busca por nome, termos ou texto integral das páginas. Mostra o conteúdo de cada livro e em quais livros um item aparece. Quando há versões diferentes, pergunta qual usar (ou usa a mais recente). Cada ficha pode restringir os livros permitidos.
- **Homebrew:** livros próprios com raças, classes, talentos, magias, itens e regras, que entram nos cálculos. Só esses livros são exportáveis (`.d35book`).
- **Ficha imprimível** em PDF, no formato da ficha oficial do Livro do Jogador 3.5.
- **Formato próprio em XML** para as fichas (`.d35x`).

## Estrutura
- `lib/engine` — motor de regras puro em Dart, com testes em `test/`.
- `lib/model` — modelo da ficha e serialização XML.
- `lib/data` — biblioteca SQLite/FTS5 e homebrew.
- `lib/ui` — telas em Flutter.
- `lib/print` — geração do PDF.
- `assets/srd/core.json` — núcleo SRD 3.5 (OGL), gerado por `tools/srd/gen_core.py`.
- `tools/dbbuild` — extrator que monta `rules.sqlite` a partir dos PDFs do próprio usuário. **A base não é versionada nem distribuída.**

## Build
O GitHub Actions (`.github/workflows/build.yml`) gera:
- `Grimorio35-windows-portable`: pasta com o `.exe`, as DLLs e o runtime do Visual C++.
- `Grimorio35-linux-portable`.

A pasta `data/` ao lado do executável guarda as fichas, os livros homebrew e a base de regras.
