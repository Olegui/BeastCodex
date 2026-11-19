local ADDON, ns = ...
local L = ns.L

-- Cards above the list with what is new (Data/News.lua). A header line with a
-- button folds them away; the list then starts right under the header.
local News = {}
ns.News = News

local MAX_CARDS = 2 -- side by side; more would be too narrow to read

-- One text of an item in the client's language, else English.
function News.Text(t, locale)
  return t and (t[locale or GetLocale()] or t.enUS) or nil
end

function News.Creature(id)
  for _, c in ipairs(ns.Creatures) do
    if c.id == id then return c end
  end
end

-- How far below the top of the list rectangle the list starts.
function News.Height(rowH, collapsed)
  if collapsed then return rowH + 4 end
  return rowH + 2 + News.CardHeight(rowH) + 8
end

function News.CardHeight(rowH)
  return rowH * 3 + 12
end

-- An item's icon texture: `icon` is a spell ID (its icon, from the client) or a texture path.
function News.Icon(icon)
  if type(icon) ~= "number" then return icon end
  local ok, tex = pcall(function()
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(icon) end
    return GetSpellTexture(icon)
  end)
  return ok and tex or nil
end

local function newCard(parent, item, w, h)
  local c = ns.Skin.colors
  local card = CreateFrame("Button", nil, parent)
  card:SetSize(w, h)
  -- Set apart from the rows: the selected row's accent rim and glow, as a box.
  if not ns.UI.Slice(card, "BACKGROUND", "cardFeatured") then ns.UI.Box(card) end
  -- Hover lights the box like a hovered row: the hover slice laid over it.
  local hl = CreateFrame("Frame", nil, card)
  hl:SetAllPoints()
  hl:Hide()
  if not ns.UI.Slice(hl, "ARTWORK", "cardHover") then
    local t = hl:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetColorTexture(c.hover[1], c.hover[2], c.hover[3], c.hover[4])
  end

  -- The game's icon, round, in the theme's round rim, beside the title.
  local size = ns.Skin.rowH
  local tex = News.Icon(item.icon)
  local icon
  if tex then
    icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetPoint("TOPLEFT", 8, -7)
    icon:SetTexture(tex)
    if card.CreateMaskTexture then
      local mask = card:CreateMaskTexture()
      mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(icon)
      icon:AddMaskTexture(mask)
    end
    local rim = ns.UI.Atlas(card, "BORDER", "box")
    if rim then
      rim:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
      rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
    end
  end

  local title = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  if icon then
    title:SetPoint("LEFT", icon, "RIGHT", 7, 0)
  else
    title:SetPoint("TOPLEFT", 8, -7)
  end
  title:SetWidth(w - 16 - (icon and size + 7 or 0))
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  title:SetTextColor(c.header[1], c.header[2], c.header[3])
  title:SetText(News.Text(item.title))
  local text = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  text:SetPoint("TOPLEFT", 8, -(7 + (icon and size + 5 or 16)))
  text:SetWidth(w - 16)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  text:SetWordWrap(true)
  if text.SetMaxLines then text:SetMaxLines(3) end
  text:SetTextColor(c.text[1], c.text[2], c.text[3])
  text:SetText(News.Text(item.text))
  ns.UI.Flat(title)
  ns.UI.Flat(text)

  -- Like a list row: hovering previews the beast, clicking pins it.
  local creature = item.creature and News.Creature(item.creature)
  local more = News.Text(item.more)
  card:SetScript("OnEnter", function(self)
    hl:Show()
    if creature and ns.List.onEnter then ns.List.onEnter(creature) end
    if not more and creature and ns.ShowGuide(self, creature, "ANCHOR_BOTTOM") then return end
    if more then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(News.Text(item.title))
      GameTooltip:AddLine(more, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  card:SetScript("OnLeave", function()
    hl:Hide()
    GameTooltip:Hide()
    if creature and ns.List.onLeave then ns.List.onLeave() end
  end)
  card:SetScript("OnClick", function()
    if creature and ns.List.onClick then ns.List.onClick(creature) end
  end)
  return card
end

-- Builds the block at the top of the list rectangle `r`. Needs ns.List built.
function News:Create(parent, r)
  local items = ns.NewsItems or {}
  if #items == 0 then return end -- nothing new: the list keeps its whole rectangle
  local S = ns.Skin
  local c, rowH = S.colors, S.rowH
  -- Same width as the rows, which leave room for the scroll bar.
  local width = r.w - (S.scroll and S.scroll.width or 16) - 6

  local header = CreateFrame("Button", nil, parent)
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", r.x, -r.y)
  header:SetSize(width, rowH)
  local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("LEFT", 4, 0)
  title:SetTextColor(c.header[1], c.header[2], c.header[3])
  title:SetText(L.NEWS)
  ns.UI.Flat(title)
  local toggle = ns.UI.IconButton(header, rowH - 4, "chevUp", L.NEWS_COLLAPSE)
  toggle:SetPoint("RIGHT")

  local n, gap = math.min(#items, MAX_CARDS), 6
  local cardW, cardH = (width - gap * (n - 1)) / n, News.CardHeight(rowH)
  local cards = {}
  for i = 1, n do
    local card = newCard(parent, items[i], cardW, cardH)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", r.x + (i - 1) * (cardW + gap), -(r.y + rowH + 2))
    cards[i] = card
  end

  local function apply()
    local collapsed = ns.db.newsCollapsed
    for _, card in ipairs(cards) do card:SetShown(not collapsed) end
    ns.UI.SetIcon(toggle.icon, collapsed and "chevDown" or "chevUp")
    toggle.tooltip = collapsed and L.NEWS_EXPAND or L.NEWS_COLLAPSE
    ns.List:SetTop(News.Height(rowH, collapsed))
  end
  local function flip()
    ns.db.newsCollapsed = not ns.db.newsCollapsed or nil
    apply()
    if GameTooltip:IsOwned(toggle) then toggle:GetScript("OnEnter")(toggle) end
  end
  toggle:SetScript("OnClick", flip)
  header:SetScript("OnClick", flip)
  apply()
end

-- Self-checks ---------------------------------------------------------------

table.insert(ns.tests, { "news: texts fall back to English, cards name real beasts", function()
  local t = { enUS = "Tip", ptBR = "Dica" }
  assert(News.Text(t, "ptBR") == "Dica" and News.Text(t, "deDE") == "Tip" and News.Text(nil) == nil)
  for i, item in ipairs(ns.NewsItems) do
    assert(News.Text(item.title, "enUS") and News.Text(item.text, "enUS"), "news item " .. i .. " has no English text")
    assert(item.creature == nil or News.Creature(item.creature), "news item " .. i .. " names a missing beast")
  end
end })

table.insert(ns.tests, { "news: folded cards give the list its room back", function()
  assert(News.Height(25, true) < News.Height(25, false))
  assert(News.Height(25, false) == 25 + 2 + News.CardHeight(25) + 8)
end })

table.insert(ns.tests, { "news: an icon is a texture path or a spell's icon", function()
  local old = C_Spell
  C_Spell = { GetSpellTexture = function(id) return id == 1130 and 132212 or nil end }
  local spell, path, none = News.Icon(1130), News.Icon("Interface\\Icons\\X"), News.Icon(nil)
  C_Spell = old
  assert(spell == 132212 and path == "Interface\\Icons\\X" and none == nil)
end })
