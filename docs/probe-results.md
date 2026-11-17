# Resultado da sondagem no cliente (2026-11-17)

Cliente: 1.60.1 build 70959, interface 16001, ptBR, WOW_PROJECT_ID 18.

| Pergunta | Resultado |
|---|---|
| APIs de mapa (`C_Map.GetMapInfo`, `GetAreaInfo`, `GetMapChildrenInfo`, `WorldMapFrame:SetMapID`, `OpenWorldMap`) | existem |
| IDs de mapa do Huntmaster (1444 Feralas, 1429 Elwynn) | válidos, nomes já traduzidos pelo jogo |
| Pin pelo HereBeDragons-Pins | adicionado sem erro e visível no mapa |
| Menus (`UIDropDownMenu_Initialize`, `MenuUtil`) e rolagem (`FauxScrollFrame`, `ScrollBox`) | existem |
| `BackdropTemplateMixin`, `UISpecialFrames` | existem |
| Modelo 3D por `SetCreature(5356)` | chamada sem erro; `GetModelFileID` voltou nil, então depende do que o dono viu na tela |
| Nome traduzido da criatura por tooltip | não funcionou (texto vazio) |
| Erros no BugSack | nenhum do BeastCodexProbe |

Decisões:
- Pins: HereBeDragons-Pins, como planejado.
- Nomes de criatura ficam em inglês na versão 1. Zonas usam o nome do jogo.
- Modelo: `SetCreature(id)` funciona (o dono viu o lobo). Não é preciso ID de exibição.
