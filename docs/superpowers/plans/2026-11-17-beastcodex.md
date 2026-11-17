# Beast Codex Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Addon de WoW Forever que lista as feras de caçador (domáveis e
indomáveis), com filtros, modelo 3D, pins no mapa e janela com arte própria.

**Architecture:** Scripts Python em `tools/` juntam três fontes (Huntmaster,
Petopia, Wowhead) e geram `Data/Creatures.lua`. O addon em Lua puro lê essa
tabela, filtra em memória e desenha uma janela de tamanho fixo cujas medidas
vêm de `Skin.lua`, para a arte final ser só troca de textura. O addon fica
na raiz do repositório; `tools/install.ps1` copia para a pasta do jogo.

**Tech Stack:** Lua (API do cliente Forever, Interface 16001), LibStub,
CallbackHandler, LibDataBroker, LibDBIcon, HereBeDragons-2.0 e
HereBeDragons-Pins-2.0 (embutidas, copiadas de
`.cache/sources/Huntmaster/libs`). Python 3 só com biblioteca padrão e
`unittest`. PowerShell para instalar e tirar prints.

**Spec:** `docs/superpowers/specs/2026-11-17-beastcodex-design.md`

## Global Constraints

- `.toc` declara só `## Interface: 16001`.
- Conferir se cada função da API existe antes de chamar (`C_Map`, `C_Spell`,
  `C_Item`). Nunca supor.
- Só o dono roda o jogo. Resultado de teste no jogo chega pelo disco, depois
  de `/reload`: `WTF\Account\<conta>\SavedVariables\BeastCodex*.lua`,
  `BugSack.lua` e prints.
- Arquivo novo no addon exige fechar e abrir o jogo; por isso cada tarefa de
  addon cria todos os seus arquivos antes do ponto de conferência.
- O addon nunca acessa a internet. Os scripts só rodam quando o dono pede,
  com cache em `.cache/` (fora do Git) e 1,5 s entre requisições.
- Nenhuma imagem ou texto descritivo do Petopia é copiado. Nenhum dado de
  TameDex, Hunter's Field Guide ou Hunter's Handbook.
- Aviso de direitos do Huntmaster (Yurri Studio, Justin Moody) no README e
  em `THIRD-PARTY.md`.
- Sem emojis de bandeira em README ou descrições.
- Idiomas: enUS, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW.
- Publicação (Tarefa 13) não sai sem a arte aprovada pelo dono e sem a
  decisão dele sobre a permissão do Petopia.

## Review Focus

1. Criatura sem coordenadas ou sem `map`: o botão do mapa fica desativado e
   o painel mostra `L.LOCATION_UNKNOWN`. Sem erro. (Tarefa 10)
2. Combinação de filtros sem resultado: a lista mostra `L.NO_RESULTS`, não
   fica em branco nem quebra a rolagem. (Tarefa 8)
3. `BeastCodexDB` ausente, de versão antiga ou com filtro que não existe
   mais nos dados (zona removida): cai nos padrões. (Tarefa 6)
4. Idioma do cliente fora dos 11, ou chave faltando num idioma: texto em
   inglês, nunca `nil` na tela. (Tarefa 6)
5. Modelo 3D que não carrega (criatura fora do cache do cliente): o painel
   mostra os dados em texto e um espaço vazio, sem erro. (Tarefa 9)

## Estrutura de arquivos

```
BeastCodex.toc          manifesto
Core.lua                namespace, dados salvos, comando, botão do minimapa
Skin.lua                medidas da janela e caminhos de textura
Filter.lua              filtragem e agrupamento, sem interface
SelfTest.lua            /beastcodex selftest
UI/Window.lua           moldura, filtros, busca
UI/List.lua             lista com rolagem virtual
UI/Detail.lua           painel de detalhes e modelo 3D
Map.lua                 pins
Locales/<idioma>.lua    11 arquivos
Data/Creatures.lua      GERADO
Libs/                   bibliotecas embutidas
Art/                    texturas TGA
Probe/                  addon de sondagem descartável (não é empacotado)
tools/huntmaster.py petopia.py wowhead.py build_data.py make_skin.py
tools/test_*.py tools/fixtures/
tools/install.ps1 tools/screenshot.ps1
```

Convenção Lua: todo arquivo começa com `local ADDON, ns = ...`.

## Contratos compartilhados

Tabela gerada (`Data/Creatures.lua`):

```lua
ns.Looks      = { wolfskinblack = { name = "Charcoal Black Wolf", family = "wolf" } }
ns.FamilyDiet = { wolf = "Meat" }
ns.MaxLevel   = 60            -- maior nível nos dados
ns.Creatures  = {             -- ordenado por família, aparência, nome
  { id = 5356, name = "Snarler", family = "wolf", look = "wolfskinblack",
    min = 42, max = 42, cls = "rare",   -- nil | "rare" | "elite" | "rareelite"
    zone = "Feralas", map = 1444,       -- map = uiMapID, pode ser nil
    tame = true, note = nil, speed = 2.0,
    abilities = { { "Bite", 6 }, { "Furious Howl", 3 } },
    coords = { 28.4, 66.4, 28.6, 67.6 } }, -- pares x,y em 0-100; pode ser {}
}
```

`look` é `nil` para criatura do Huntmaster que o Petopia não lista; ela é
agrupada sob o nome da família. `family` usa os identificadores do Petopia
(`bat`, `bear`, `birdofprey`, `boar`, `carrionbird`, `cat`, `corehound`,
`crab`, `crocolisk`, `fox`, `gorilla`, `hyena`, `raptor`, `scorpid`,
`spider`, `tallstrider`, `turtle`, `windserpent`, `wolf`).

Medidas (`Skin.lua`), fixas para a arte:

```lua
ns.Skin = { W = 896, H = 560, inset = { l = 48, r = 48, t = 72, b = 48 },
            filterW = 160, detailW = 230, rowH = 20, texture = nil }
```

Dados salvos: `BeastCodexDB = { minimap = {}, filters = { family, zone,
bucket, showUntameable = true, search = "" } }`.

---

### Task 1: Sondagem no jogo

Addon descartável que responde às incertezas do cliente Forever antes de
qualquer outra coisa.

**Files:**
- Create: `Probe/BeastCodexProbe.toc`, `Probe/Probe.lua`, `Probe/Libs/`
  (LibStub, CallbackHandler, HereBeDragons-2.0, HereBeDragons-Pins-2.0)
- Create: `tools/install.ps1`, `tools/screenshot.ps1`
- Create: `docs/probe-results.md`

**Interfaces:**
- Produces: `tools/install.ps1 [-Probe]` copia o addon (ou `Probe/` como
  `BeastCodexProbe`) para
  `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`,
  excluindo `.git`, `.cache`, `docs`, `tools`, `Probe`. Falha com mensagem
  clara se a pasta não existir ou não for gravável.
- Produces: `docs/probe-results.md` com um sim/não por pergunta abaixo.

- [ ] **Step 1:** Escrever `Probe.lua`. No comando `/bcprobe`, grava em
  `BeastCodexProbeDB` (SavedVariables) e imprime no chat:
  - `build`: retorno de `GetBuildInfo()`; `locale`: `GetLocale()`.
  - `api`: existência (true/false) de `C_Map.GetMapInfo`,
    `C_Map.GetBestMapForUnit`, `C_Map.GetAreaInfo`,
    `WorldMapFrame`, `OpenWorldMap`, `CreateFrame("PlayerModel")`,
    `PlayerModel.SetCreature`, `PlayerModel.SetDisplayInfo`.
  - `map1444`: `C_Map.GetMapInfo(1444)` (nome e tipo) e o mesmo para 1429.
  - `model`: cria um `PlayerModel` 200x200 no centro da tela, chama
    `SetCreature(5356)`, e depois de 2 s grava `GetModelFileID()` (ou
    `GetModel()`), para saber se carregou.
  - `pin`: `HereBeDragons-Pins-2.0:AddWorldMapIconMap` com um ícone em
    1444 (Feralas) a 50,50 e grava se a chamada deu erro (`pcall`).
  - `name`: nome da criatura 5356 por tooltip escondido com
    `SetHyperlink("unit:Creature-0-0-0-0-5356")`, lendo a primeira linha.
- [ ] **Step 2:** Escrever `install.ps1` e `screenshot.ps1` (captura da tela
  principal para `.cache/shots/<data-hora>.png`).
- [ ] **Step 3:** Rodar `powershell -File tools/install.ps1 -Probe`.
  Esperado: lista dos arquivos copiados.
- [ ] **Step 4: Ponto de conferência do dono.** Pedir: abrir o jogo, digitar
  `/bcprobe`, abrir o mapa em Feralas, avisar, depois `/reload`. Tirar print
  com o mapa aberto.
- [ ] **Step 5:** Ler `BeastCodexProbeDB` e `BugSack.lua` do disco; escrever
  `docs/probe-results.md`. Decisões que saem daqui:
  - modelo não carrega por `SetCreature` → Tarefa 5 passa a coletar
    `display` (ID de exibição) do Wowhead e a Tarefa 9 usa `SetDisplayInfo`;
  - pin falha → parar e levar ao dono (o spec prevê cair para "abrir só a
    zona");
  - nome por tooltip falha → nomes de criatura ficam em inglês.
- [ ] **Step 6:** Commit.

### Task 2: Leitor do Huntmaster

**Files:**
- Create: `tools/huntmaster.py`, `tools/test_huntmaster.py`,
  `tools/fixtures/huntmaster_sample.lua` (os registros `"30"` e `"684"`
  recortados do arquivo real, mais um sem `family` e sem `ui_map_id`)

**Interfaces:**
- Produces: `huntmaster.load(path: str) -> dict[int, dict]`. Cada valor:
  `{"id", "name", "family" (identificador do Petopia ou None), "min", "max",
  "cls", "diet", "map" (int ou None), "area" (int), "coords": [(x, y)]}`.
- Produces: `huntmaster.FAMILY_SLUG: dict[str, str]`, de nome do Huntmaster
  para identificador do Petopia (`"Birds of Prey" -> "birdofprey"`,
  `"Carrion Bird" -> "carrionbird"`, `"Wind Serpent" -> "windserpent"`,
  demais em minúsculas).

- [ ] **Step 1: Teste que falha.**

```python
def test_forest_spider(self):
    c = huntmaster.load(FIXTURE)[30]
    self.assertEqual((c["name"], c["family"], c["min"], c["max"]),
                     ("Forest Spider", "spider", 5, 6))
    self.assertEqual((c["map"], c["area"], c["cls"]), (1429, 12, None))
    self.assertEqual(c["coords"][0], (28.4, 66.4))

def test_missing_fields(self):
    c = huntmaster.load(FIXTURE)[113]
    self.assertIsNone(c["family"]); self.assertIsNone(c["map"])

def test_classification(self):   # "Rare Elite" -> "rareelite"
    self.assertEqual(huntmaster.parse_cls("Rare Elite"), "rareelite")
```

- [ ] **Step 2:** `python -m unittest tools.test_huntmaster -v` → FAIL.
- [ ] **Step 3:** Implementar. O arquivo é uma tabela Lua regular gerada por
  máquina: um analisador pequeno de literais Lua (tabelas, strings, números)
  basta. `level_range` `"5-6"` ou `"42"` vira `min`, `max`.
- [ ] **Step 4:** Testes passam. Rodar também contra o arquivo real:
  `python -c "import tools.huntmaster as h; print(len(h.load('.cache/sources/Huntmaster/Data/TameableNPCs.lua')))"`
  → `334`.
- [ ] **Step 5:** Commit.

### Task 3: Coletor do Petopia

**Files:**
- Create: `tools/petopia.py`, `tools/test_petopia.py`
- Create: `tools/fixtures/petopia_home.html`, `petopia_family_wolf.html`,
  `petopia_look_wolfskinblack.html` (baixados uma vez pelo próprio coletor)

**Interfaces:**
- Produces: `petopia.Fetcher(cache_dir: str, delay: float = 1.5).get(url) -> str`
  (lê do cache se existir; `User-Agent` genérico de navegador; erro HTTP
  levanta exceção com a URL).
- Produces: `parse_family_index(html) -> list[str]` (identificadores).
- Produces: `parse_family(html) -> {"name": str, "diet": str,
  "looks": [(look_id, look_name, status)]}`, `status` em `"tameable"`,
  `"unused"`, `"untameable"`.
- Produces: `parse_look(html) -> list[dict]` com `id` (do link
  `wowhead.com/forever/npc=<id>`), `name`, `min`, `max`, `cls`, `zone`,
  `tame` (bool), `note` (str ou None), `speed` (float ou None),
  `abilities` (`[(nome, rank)]`).
- Produces: `crawl(fetcher) -> (looks: dict, diets: dict, creatures: list)`
  percorrendo `/forever/`, `family.php?id=<f>` e `look.php?id=<l>`.

- [ ] **Step 1:** Baixar os três fixtures com `Fetcher` e olhar a estrutura
  real do HTML antes de escrever os testes.
- [ ] **Step 2: Testes que falham**, com os valores conhecidos:

```python
def test_family_index(self):
    self.assertEqual(len(parse_family_index(HOME)), 19)
    self.assertIn("birdofprey", parse_family_index(HOME))

def test_wolf_family(self):
    f = parse_family(WOLF)
    self.assertEqual(f["diet"], "Meat")
    self.assertIn(("wolfskinblack", "Charcoal Black Wolf", "tameable"), f["looks"])

def test_look(self):
    cs = {c["id"]: c for c in parse_look(LOOK)}
    s = cs[5356]
    self.assertEqual((s["name"], s["min"], s["max"], s["cls"], s["zone"]),
                     ("Snarler", 42, 42, "rare", "Feralas"))
    self.assertEqual((s["tame"], s["speed"]), (True, 2.0))
    self.assertEqual(s["abilities"], [("Bite", 6), ("Furious Howl", 3)])
    self.assertEqual((cs[2681]["min"], cs[2681]["max"], cs[2681]["cls"]), (50, 51, "elite"))
    self.assertEqual(sum(c["tame"] for c in cs.values()), 4)
    self.assertFalse(cs[4244]["tame"])
    self.assertEqual(cs[4244]["note"], "Friendly to Alliance players.")
```

- [ ] **Step 3:** `python -m unittest tools.test_petopia -v` → FAIL.
- [ ] **Step 4:** Implementar com `html.parser`. Se algum valor acima não
  bater com o HTML real, o HTML real vence: corrigir o teste e anotar no
  commit.
- [ ] **Step 5:** Testes passam. Rodar `crawl` inteiro uma vez (cerca de
  220 páginas, uns 6 minutos) e conferir: 19 famílias; para cada aparência,
  a contagem de `tame` bate com o "There are N tameable creatures with this
  look" da página. Divergências listadas na saída.
- [ ] **Step 6:** Commit (sem `.cache/`).

### Task 4: Coordenadas do Wowhead

Só para criaturas do Petopia que o Huntmaster não cobre.

**Files:**
- Create: `tools/wowhead.py`, `tools/test_wowhead.py`,
  `tools/fixtures/wowhead_npc_5356.html`

**Interfaces:**
- Consumes: `petopia.Fetcher`.
- Produces: `wowhead.parse_npc(html) -> {"area": int, "coords": [(x, y)],
  "display": int | None} | None` (None quando a página não tem mapa).
- Produces: `wowhead.url(npc_id: int) -> str` =
  `https://www.wowhead.com/forever/npc=<id>`.

- [ ] **Step 1: Teste de viabilidade.** Baixar 10 IDs (5356, 2681, 268558,
  2680, 4244, 11871 e mais 4 de famílias ausentes no Huntmaster). Se o site
  barrar (403, desafio, página sem dados): **parar e levar ao dono**, com as
  alternativas do spec (coleta por navegador, ou botão que abre só a zona).
- [ ] **Step 2:** Olhar onde o mapa está no HTML (dados embutidos em script)
  e escrever o teste com os valores reais de 5356: `area` é o ID de Feralas,
  `coords` não vazio, todo par dentro de 0-100.
- [ ] **Step 3:** FAIL → implementar → PASS.
- [ ] **Step 4:** Commit.

### Task 5: Montagem dos dados

**Files:**
- Create: `tools/build_data.py`, `tools/test_build_data.py`
- Create (gerado): `Data/Creatures.lua`, `docs/data-report.md`

**Interfaces:**
- Consumes: `huntmaster.load`, `petopia.crawl`, `wowhead.parse_npc`.
- Produces: `merge(hm: dict, pet_creatures: list, wh: dict[int, dict]) -> list[dict]`
  no formato de "Contratos compartilhados".
- Produces: `emit_lua(creatures, looks, diets, path)`.
- Produces: `python tools/build_data.py` roda tudo e escreve os dois
  arquivos.

Regras de `merge`:
- chave é o ID do NPC; união das duas fontes;
- `coords` e `map`: Huntmaster, senão Wowhead;
- demais campos: Petopia, senão Huntmaster;
- criatura só no Huntmaster: `tame = true`, `look = None`, `speed = None`,
  `abilities = []`;
- `map` de criatura sem `ui_map_id`: tabela `area -> map` montada a partir
  dos registros do Huntmaster que têm os dois; para criatura só do Petopia
  sem Wowhead, tabela `nome da zona -> map` montada a partir das criaturas
  presentes nas duas fontes;
- se a Tarefa 1 pediu `display`, o campo entra em cada criatura.

- [ ] **Step 1: Testes que falham.**

```python
def test_both_sources(self):      # coords do Huntmaster, resto do Petopia
    out = merge({5356: HM_SNARLER}, [PET_SNARLER], {})[0]
    self.assertEqual(out["coords"], HM_SNARLER_FLAT)
    self.assertEqual((out["look"], out["speed"]), ("wolfskinblack", 2.0))

def test_huntmaster_only(self):
    out = merge({30: HM_SPIDER}, [], {})[0]
    self.assertTrue(out["tame"]); self.assertIsNone(out["look"])

def test_petopia_only_uses_wowhead_and_area_table(self):
    out = merge({30: HM_SPIDER}, [PET_NEW],
                {PET_NEW["id"]: {"area": 12, "coords": [(1.0, 2.0)], "display": None}})
    c = [x for x in out if x["id"] == PET_NEW["id"]][0]
    self.assertEqual((c["map"], c["coords"]), (1429, [1.0, 2.0]))

def test_no_location(self):
    c = merge({}, [PET_NEW], {})[0]
    self.assertEqual((c["map"], c["coords"]), (None, []))

def test_emit_roundtrip(self):    # o Lua gerado volta igual pelo leitor da Tarefa 2
    ...assertEqual(reparsed["Creatures"][0]["name"], "Snarler")

def test_lua_string_escaping(self):   # nome com aspas e barra
    ...
```

- [ ] **Step 2:** FAIL → implementar → PASS.
- [ ] **Step 3:** Rodar `python tools/build_data.py`. `docs/data-report.md`
  lista: total de criaturas, por família, domáveis e indomáveis, quantas sem
  coordenadas, quantas sem `map`, divergências de nível ou zona entre
  Huntmaster e Petopia. Verificações que abortam a geração: ID duplicado,
  coordenada fora de 0-100, família fora da lista de 19.
- [ ] **Step 4:** Mostrar o relatório ao dono (não bloqueia).
- [ ] **Step 5:** Commit, incluindo `Data/Creatures.lua`.

### Task 6: Esqueleto do addon

**Files:**
- Create: `BeastCodex.toc`, `Core.lua`, `Skin.lua`, `Locales/enUS.lua`,
  `Libs/` (LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0,
  HereBeDragons-2.0, HereBeDragons-Pins-2.0), `THIRD-PARTY.md`
- Create vazios e já listados no `.toc`, para as próximas tarefas não
  exigirem reiniciar o jogo: `Filter.lua`, `SelfTest.lua`, `UI/Window.lua`,
  `UI/List.lua`, `UI/Detail.lua`, `Map.lua`, e os outros 10 arquivos de
  `Locales/`

**Interfaces:**
- Produces: `ns.L`: tabela com `__index` que devolve a própria chave.
  `Locales/enUS.lua` define tudo; os outros só sobrescrevem quando
  `GetLocale()` bate.
- Produces: `ns.db` (aponta para `BeastCodexDB` já saneado),
  `ns.Skin` (ver contratos).
- Produces: comandos `/beastcodex` (chama `ns.Window:Toggle()` se existir),
  `/beastcodex selftest`.
- Produces: botão do minimapa via LibDBIcon, nome `"BeastCodex"`, clique
  esquerdo abre a janela.

- [ ] **Step 1:** Escrever os arquivos. Saneamento do `BeastCodexDB` em
  `ADDON_LOADED`: tabela ausente ou campo de tipo errado cai no padrão;
  `filters.family` ou `filters.zone` que não existe nos dados vira `nil`
  (Review Focus 3).
- [ ] **Step 2:** `Core.lua` registra em `ns.tests` (lista de funções) dois
  testes: saneamento de `{ filters = { family = "dragon", bucket = "x" } }`
  resulta em `family == nil` e `bucket == nil`; `ns.L.CHAVE_INEXISTENTE ==
  "CHAVE_INEXISTENTE"` (Review Focus 4).
- [ ] **Step 3:** `SelfTest.lua`: `/beastcodex selftest` roda `ns.tests` com
  `pcall`, imprime `passou/total` e grava a lista de falhas em
  `BeastCodexDB.selftest`.
- [ ] **Step 4:** `powershell -File tools/install.ps1`.
- [ ] **Step 5: Ponto de conferência do dono.** Fechar e abrir o jogo;
  conferir o botão do minimapa na bolsa do FlareUI; `/beastcodex selftest`;
  `/reload`. Ler `BeastCodexDB.selftest` (esperado: sem falhas) e o BugSack
  (esperado: nenhum erro do BeastCodex).
- [ ] **Step 6:** Commit.

### Task 7: Filtro

**Files:**
- Modify: `Filter.lua`

**Interfaces:**
- Consumes: `ns.Creatures`, `ns.Looks`, `ns.L`.
- Produces: `ns.Filter.Apply(creatures, f) -> rows`. `f` tem os campos de
  `BeastCodexDB.filters`. `rows` é uma lista de `{ header = "texto" }` ou
  `{ creature = c }`; cabeçalho só aparece se tiver criatura embaixo.
- Produces: `ns.Filter.Buckets() -> { {lo, hi}, ... }` de 10 em 10 até
  `ns.MaxLevel`.
- Produces: `ns.Filter.Zones() -> lista ordenada de nomes`,
  `ns.Filter.Families() -> lista ordenada de identificadores`.

Regras: família e zona por igualdade; faixa por sobreposição
(`c.min <= hi and c.max >= lo`); `showUntameable = false` esconde
`tame == false`; busca sem diferenciar maiúsculas, por trecho do nome
(usar `string.find` com `plain = true`).

- [ ] **Step 1:** Registrar em `ns.tests` (sobre uma lista fixa de 5
  criaturas montada no próprio teste):
  - faixa 5 (41-50) devolve as criaturas 42-42, 46-47 e 50-51; faixa 6
    (51-60) devolve só a 50-51; faixa 4 (31-40) não devolve nenhuma delas;
  - `showUntameable = false` remove a indomável e o cabeçalho que ficaria
    vazio;
  - busca `"wolf pup"` acha `"Vilebranch Wolf Pup"`; busca `"("` não dá
    erro de padrão;
  - todos os filtros vazios devolvem as 5 criaturas mais os cabeçalhos;
  - criatura com `look == nil` fica sob o cabeçalho da família.
- [ ] **Step 2:** Implementar.
- [ ] **Step 3:** Instalar. **Dono:** `/reload`, `/beastcodex selftest`,
  `/reload`. Ler o resultado do disco: sem falhas.
- [ ] **Step 4:** Commit.

### Task 8: Janela, filtros e lista

**Files:**
- Modify: `UI/Window.lua`, `UI/List.lua`, `Locales/enUS.lua`

**Interfaces:**
- Consumes: `ns.Filter`, `ns.Skin`, `ns.db.filters`, `ns.L`.
- Produces: `ns.Window:Toggle()`, `ns.Window:Refresh()` (reaplica o filtro
  e chama `ns.List:SetRows`).
- Produces: `ns.List:SetRows(rows)`; `ns.List.onEnter(c)`,
  `ns.List.onLeave()`, `ns.List.onClick(c)`: campos que a Tarefa 9
  preenche; a lista chama se não forem `nil`.

- [ ] **Step 1:** `Window.lua`: quadro `ns.Skin.W` x `ns.Skin.H`, móvel,
  fecha com Esc (`UISpecialFrames`), moldura provisória (`BackdropTemplate`
  se existir, senão uma textura de cor sólida). Coluna esquerda de largura
  `filterW`: três menus (família, zona, nível), caixa "mostrar indomáveis",
  contador `L.COUNT_FMT` ("%d of %d"). Caixa de busca no topo. Mudar
  qualquer controle grava em `ns.db.filters` e chama `Refresh`.
  Menus: conferir no cliente qual API de menu existe
  (`UIDropDownMenu_Initialize` ou `MenuUtil`) e usar a que houver.
- [ ] **Step 2:** `List.lua`: rolagem virtual: `floor(alturaÚtil / rowH)`
  linhas reaproveitadas, `FauxScrollFrame` ou roda do mouse com
  deslocamento próprio. Linha de criatura: nome, etiqueta de raro/elite,
  nível (`"42"` ou `"50-51"`), zona; indomável em cinza com ícone. Linha de
  cabeçalho: texto da aparência. Lista vazia mostra `L.NO_RESULTS`
  centralizado (Review Focus 2).
- [ ] **Step 3:** Instalar. **Dono:** `/reload`, abrir, mexer em cada
  filtro, combinar filtros até zerar, rolar até o fim, print. Ler BugSack.
- [ ] **Step 4:** Commit.

### Task 9: Painel de detalhes e modelo 3D

**Files:**
- Modify: `UI/Detail.lua`, `Locales/enUS.lua`

**Interfaces:**
- Consumes: `ns.List.onEnter/onLeave/onClick`, `ns.FamilyDiet`, `ns.Looks`,
  resultado da Tarefa 1 (`SetCreature` ou `SetDisplayInfo`).
- Produces: `ns.Detail:Preview(c)`, `ns.Detail:Pin(c)`,
  `ns.Detail.pinned` (criatura fixada ou `nil`),
  `ns.Detail.mapButton` (a Tarefa 10 liga o clique).

- [ ] **Step 1:** Painel de largura `detailW`: `PlayerModel` no topo girando
  devagar, nome, linha "família, nível, raro/elite", zona (nome localizado
  por `C_Map.GetMapInfo(c.map).name` quando houver, senão `c.zone`),
  habilidades, velocidade de ataque, dieta, nota de indomável, botão
  `L.SHOW_ON_MAP`. Campo `nil` não gera linha.
- [ ] **Step 2:** Ligar `onEnter → Preview`, `onLeave → Preview(pinned)`,
  `onClick → Pin`. A linha fixada fica destacada na lista.
- [ ] **Step 3:** Modelo: `ClearModel()` antes de cada troca; chamada
  dentro de `pcall`; se falhar ou não carregar, o espaço fica vazio e o
  resto do painel aparece (Review Focus 5).
- [ ] **Step 4:** Instalar. **Dono:** `/reload`, passar o cursor por várias
  linhas (inclusive uma indomável e uma rara), clicar numa, tirar o cursor,
  print. Ler BugSack.
- [ ] **Step 5:** Commit.

### Task 10: Pins no mapa

**Files:**
- Modify: `Map.lua`, `Locales/enUS.lua`

**Interfaces:**
- Consumes: `ns.Detail.mapButton`, `ns.Detail.pinned`,
  HereBeDragons-Pins-2.0.
- Produces: `ns.Map.Show(c) -> boolean` (false se não há o que mostrar),
  `ns.Map.Clear()`, `ns.Map.CanShow(c) -> boolean`
  (`c.map ~= nil and #c.coords >= 2`).

- [ ] **Step 1:** Registrar em `ns.tests`: `CanShow` é falso para
  `{ map = nil, coords = {1, 2} }`, para `{ map = 1444, coords = {} }`, e
  verdadeiro para `{ map = 1444, coords = {1, 2} }`.
- [ ] **Step 2:** `Show`: limpa os pins anteriores, cria um por par (quadros
  reaproveitados de um pool), `AddWorldMapIconMap(ns, pin, c.map, x/100,
  y/100)`, abre o mapa do mundo em `c.map`. Cursor sobre o pin mostra o nome
  da criatura. Os pins ficam até `Clear` ou outro `Show`.
- [ ] **Step 3:** `Detail`: botão desativado e texto `L.LOCATION_UNKNOWN`
  quando `CanShow` é falso (Review Focus 1). Segundo botão `L.CLEAR_PINS`
  visível só quando há pins.
- [ ] **Step 4:** Instalar. **Dono:** `/reload`, `/beastcodex selftest`,
  mostrar no mapa uma criatura com muitos pontos e uma com um só, conferir
  uma sem localização, limpar, print do mapa, `/reload`. Ler disco.
- [ ] **Step 5:** Commit.

### Task 11: Idiomas

**Files:**
- Modify: os 10 arquivos de `Locales/` além de `enUS.lua`
- Modify: `UI/List.lua`, `UI/Detail.lua`, `Filter.lua` (nomes de família)

**Interfaces:**
- Consumes: todas as chaves de `Locales/enUS.lua`.
- Produces: chaves `FAMILY_<identificador>` (19) em todos os idiomas, usadas
  no menu de família, nos cabeçalhos sem aparência e no painel.

- [ ] **Step 1:** Traduzir todas as chaves para os 10 idiomas. Nomes de
  família seguem o termo oficial do jogo em cada idioma.
- [ ] **Step 2:** Verificação fora do jogo: um script de uma tela em
  `tools/check_locales.py` confirma que todo arquivo define exatamente as
  chaves de `enUS.lua` (nenhuma a mais, nenhuma a menos) e que os
  marcadores de formato (`%d`, `%s`) batem. Rodar → sem diferenças.
- [ ] **Step 3:** Se a Tarefa 1 confirmou nome por tooltip: a lista e o
  painel usam o nome localizado quando o cliente não é enUS, com `c.name`
  como reserva; a busca procura nos dois.
- [ ] **Step 4:** Instalar. **Dono** (cliente em ptBR): `/reload`, print.
  Conferir que não há texto em inglês fora de nomes de aparência e
  habilidade.
- [ ] **Step 5:** Commit.

### Task 12: Arte

**Files:**
- Create: `docs/art-brief.md`, `tools/make_skin.py`, `Art/Frame.tga`
- Modify: `Skin.lua`, `UI/Window.lua`

**Interfaces:**
- Consumes: `ns.Skin`.
- Produces: `python tools/make_skin.py <imagem> Art/Frame.tga`: remove o
  fundo magenta (`#FF00FF`, tolerância ajustável), redimensiona para
  896x560, coloca no canto superior esquerdo de um TGA 1024x1024 com
  transparência. Pode usar Pillow (dependência só de desenvolvimento, a
  única exceção à regra de biblioteca padrão).
- Produces: `ns.Skin.texture = "Interface\\AddOns\\BeastCodex\\Art\\Frame"`,
  aplicada com `SetTexCoord(0, 896/1024, 0, 560/1024)`.

- [ ] **Step 1:** Escrever `docs/art-brief.md`: um diagrama com as medidas
  (896x560; margens 48 esquerda, 48 direita, 72 topo, 48 base; colunas 160
  e 230) e o prompt para o Nano Banana: proporção 16:10, vista frontal
  chapada, moldura de madeira e couro com folhas e um arco ou espingarda no
  topo, miolo de pergaminho liso sem texto nem desenhos, fundo magenta puro
  fora da moldura, sem sombra projetada, sem letras.
- [ ] **Step 2: Dono** gera a imagem e a coloca em `.cache/art/`.
- [ ] **Step 3:** `make_skin.py` → `Art/Frame.tga`. Conferir visualmente o
  recorte (abrir o PNG de prévia que o script salva ao lado).
- [ ] **Step 4:** Ligar a textura; ajustar cores de texto para contraste no
  pergaminho; trocar a moldura provisória. Se a imagem invadir as áreas
  livres, voltar ao Step 2 com o prompt corrigido; se não houver jeito,
  passar para moldura em peças (cantos, bordas, fundo), como o spec prevê.
- [ ] **Step 5:** Instalar. **Dono:** fechar e abrir o jogo (arquivo novo),
  print. Repetir os Steps 2-5 até o dono aprovar o print.
- [ ] **Step 6:** Commit.

### Task 13: Empacotamento

Só começa com a arte aprovada e a decisão do dono sobre o Petopia.

**Files:**
- Create: `.pkgmeta`, `README.md`, `LICENSE`, `CHANGELOG.md`
- Delete: `Probe/`

- [ ] **Step 1:** Perguntar ao dono a licença do Beast Codex (padrão
  sugerido: a mesma do EAD_SkillPreview).
- [ ] **Step 2:** `.pkgmeta` com `package-as: BeastCodex` e `ignore` de
  `docs`, `tools`, `.cache`. README em inglês com prints, créditos ao
  Huntmaster (aviso MIT completo em `THIRD-PARTY.md`), Petopia e Wowhead.
- [ ] **Step 3:** Montar o zip localmente e conferir a lista de arquivos:
  só o addon, sem `tools/` nem `docs/`.
- [ ] **Step 4: Dono** cria o projeto no CurseForge e liga o webhook.
  Tag e release só com o pedido explícito dele.
- [ ] **Step 5:** Commit.
