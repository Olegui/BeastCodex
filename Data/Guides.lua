local ADDON, ns = ...

-- Written by hand: how to get a beast, by NPC ID, one list of lines per client
-- language (a language without its own falls back to enUS). Names the game
-- knows are placeholders, filled in by the client in the player's language:
-- {name} the beast, and the keys of `names`: an item, an area or an ability,
-- each with its English name for when the client has none yet.
ns.Guides = {
  -- Wowhead comment (2026-11-16) and Icy Veins.
  [268231] = {
    names = {
      item = { item = 276909, en = "Corrupted Cat Figurine" },
      scar = { area = 17050, en = "Felblood Scar" },
      rest = { area = 16868, en = "Mourning's Rest" },
      prowl = { ability = "Prowl" },
      cower = { ability = "Cower" },
    },
    text = {
      enUS = {
        "Secret tame, found on 2026-11-16.",
        "1. Get the {item}: it lies in a fel pool with bones around it in {scar}, at 47 75. It has also been seen at 48 82, 44 76, 44 82 and 46 76.",
        "2. With it in your bags, click the lonely lantern on the hillside above the {rest} cave, at 26 65.",
        "3. {name} appears at level 57 or 58. It teaches {prowl} 3 and {cower} 6, with a 1.0 attack speed.",
      },
      ptBR = {
        "Domação secreta, descoberta em 16/11/2026.",
        "1. Pegue o item {item}: ele está numa poça vil com ossos em volta, em {scar}, em 47 75. Também foi visto em 48 82, 44 76, 44 82 e 46 76.",
        "2. Com ele na bolsa, clique na lanterna solitária na encosta acima da caverna de {rest}, em 26 65.",
        "3. {name} aparece no nível 57 ou 58. Ensina {prowl} 3 e {cower} 6, com velocidade de ataque 1.0.",
      },
      deDE = {
        "Geheime Zähmung, entdeckt am 16.11.2026.",
        "1. Hol dir den Gegenstand {item}: Er liegt in einem Teufelstümpel mit Knochen ringsum in {scar}, bei 47 75. Er wurde auch bei 48 82, 44 76, 44 82 und 46 76 gesehen.",
        "2. Klicke mit ihm im Gepäck auf die einsame Laterne am Hang über der Höhle von {rest}, bei 26 65.",
        "3. {name} erscheint auf Stufe 57 oder 58. Lehrt {prowl} 3 und {cower} 6, mit 1,0 Angriffsgeschwindigkeit.",
      },
      esES = {
        "Domesticación secreta, descubierta el 16/11/2026.",
        "1. Consigue el objeto {item}: está en una charca vil con huesos alrededor, en {scar}, en 47 75. También se ha visto en 48 82, 44 76, 44 82 y 46 76.",
        "2. Con él en la bolsa, haz clic en el farol solitario de la ladera sobre la cueva de {rest}, en 26 65.",
        "3. {name} aparece a nivel 57 o 58. Enseña {prowl} 3 y {cower} 6, con velocidad de ataque 1,0.",
      },
      frFR = {
        "Apprivoisement secret, découvert le 16/11/2026.",
        "1. Récupérez l'objet {item} : il se trouve dans une mare gangrenée entourée d'ossements, à {scar}, en 47 75. Il a aussi été vu en 48 82, 44 76, 44 82 et 46 76.",
        "2. Avec l'objet dans vos sacs, cliquez sur la lanterne solitaire à flanc de colline au-dessus de la grotte de {rest}, en 26 65.",
        "3. {name} apparaît au niveau 57 ou 58. Il apprend {prowl} 3 et {cower} 6, avec une vitesse d'attaque de 1,0.",
      },
      itIT = {
        "Addomesticamento segreto, scoperto il 16/11/2026.",
        "1. Prendi l'oggetto {item}: si trova in una pozza vile circondata da ossa, a {scar}, in 47 75. È stato visto anche in 48 82, 44 76, 44 82 e 46 76.",
        "2. Con l'oggetto nelle borse, clicca sulla lanterna solitaria sul pendio sopra la grotta di {rest}, in 26 65.",
        "3. {name} compare al livello 57 o 58. Insegna {prowl} 3 e {cower} 6, con velocità d'attacco 1,0.",
      },
      koKR = {
        "2026년 11월 16일에 발견된 비밀 길들이기입니다.",
        "1. {item} 아이템을 얻으세요: {scar}의 47 75, 뼈로 둘러싸인 지옥 웅덩이에 있습니다. 48 82, 44 76, 44 82, 46 76에서도 발견되었습니다.",
        "2. 아이템을 가방에 넣은 채로 {rest} 동굴 위 언덕에 있는 외로운 등불(26 65)을 클릭하세요.",
        "3. {name}: 57 또는 58레벨로 나타납니다. {prowl} 3과 {cower} 6을 가르치며 공격 속도는 1.0입니다.",
      },
      ruRU = {
        "Секретное приручение, обнаружено 16.11.2026.",
        "1. Добудьте предмет {item}: он лежит в луже скверны с костями вокруг, в локации {scar}, на 47 75. Его также видели на 48 82, 44 76, 44 82 и 46 76.",
        "2. С ним в сумке нажмите на одинокий фонарь на склоне над пещерой {rest}, на 26 65.",
        "3. {name} появляется на 57 или 58 уровне. Обучает {prowl} 3 и {cower} 6, скорость атаки 1,0.",
      },
      zhCN = {
        "秘密驯服，发现于2026年11月16日。",
        "1. 获取{item}：它位于{scar}一处周围有骨头的邪能水池中，坐标47 75。也曾在48 82、44 76、44 82和46 76出现。",
        "2. 将其放在背包中，点击{rest}洞穴上方山坡上的孤灯，坐标26 65。",
        "3. {name}出现时为57或58级。教授{prowl} 3和{cower} 6，攻击速度1.0。",
      },
      zhTW = {
        "秘密馴服，發現於2026年11月16日。",
        "1. 取得{item}：它位於{scar}一處周圍有骨頭的魔化水池中，座標47 75。也曾在48 82、44 76、44 82和46 76出現。",
        "2. 將其放在背包中，點擊{rest}洞穴上方山坡上的孤燈，座標26 65。",
        "3. {name}出現時為57或58級。教授{prowl} 3和{cower} 6，攻擊速度1.0。",
      },
    },
  },
}
ns.Guides[268231].text.esMX = ns.Guides[268231].text.esES
