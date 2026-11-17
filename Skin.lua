local ADDON, ns = ...

-- Fixed window measures. The final art is drawn to these numbers, so the
-- layout code reads them from here and nowhere else.
ns.Skin = {
  W = 896, H = 560,
  inset = { l = 48, r = 48, t = 72, b = 48 },
  filterW = 160, detailW = 230, rowH = 20,
  texture = nil, -- set once Art/Frame.tga exists
}
