local ADDON, ns = ...

-- Written by hand, newest first: what the cards above the list say. Texts are
-- per client language; a language without its own falls back to enUS.
-- `creature` (an NPC ID in Data/Creatures.lua) makes the card open that beast;
-- hovering shows `more`, or else that beast's guide (Data/Guides.lua).
-- `icon`: a spell ID (its icon) or a texture path, shown round beside the title.
ns.NewsItems = {
  {
    creature = 268231,
    icon = "Interface\\Icons\\Ability_Hunter_Pet_Cat", -- the cat family's icon
    title = { enUS = "New pet: Ta'shkal", ptBR = "Novo pet: Ta'shkal" },
    text = {
      enUS = "Green and orange cat in Mount Hyjal, 1.0 attack speed. Hover for how to summon it.",
      ptBR = "Felino verde e laranja em Monte Hyjal, velocidade de ataque 1.0. Passe o cursor para ver como invocá-lo.",
    },
  },
  {
    icon = 1130, -- Hunter's Mark
    title = { enUS = "Tip: target window", ptBR = "Dica: janela de alvo" },
    text = {
      enUS = "Click a beast, then Target window: it stays on screen and targets the beast once it is near.",
      ptBR = "Clique numa fera e use Janela de alvo: ela fica na tela e seleciona a fera quando estiver perto.",
    },
    more = {
      enUS = "The target window stays open while you travel, even with the codex closed, and comes back where you left it after a reload. Show on map marks where the beast spawns.",
      ptBR = "A janela de alvo continua aberta enquanto você viaja, mesmo com o códice fechado, e volta no mesmo lugar depois de um reload. Mostrar no mapa marca onde a fera aparece.",
    },
  },
}
