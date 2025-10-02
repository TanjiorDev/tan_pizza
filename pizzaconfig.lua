pizzaconfig = pizzaconfig or {}

-- Inventaire backend: 'auto' | 'ox' | 'esx'
-- ======= Defaults / garde-fous =======
pizzaconfig.Pay                = pizzaconfig.Pay or {min=140,max=220,tipChance=35,tipMin=10,tipMax=60,streakBonus=30,payTo='cash'}
pizzaconfig.Blips              = pizzaconfig.Blips or {}
pizzaconfig.Blips.base         = pizzaconfig.Blips.base or { sprite=267, color=1, scale=0.8, label='Pizza Intérim' }
pizzaconfig.Blips.drop         = pizzaconfig.Blips.drop or { sprite=280, color=5, scale=0.8, label='Livraison pizza' }
-- Optionnel: couleur du tracé GPS (1=rouge, 2=vert, 3=bleu, 5=jaune, etc.)
pizzaconfig.Blips.routeColor   = pizzaconfig.Blips.routeColor or 5

-- ✅ Nouveaux switches pour le comportement au spawn
pizzaconfig.ShowBaseBlipOnStart     = (pizzaconfig.ShowBaseBlipOnStart ~= false)  -- par défaut: on montre le blip base
pizzaconfig.AutoRouteToBaseOnStart  = (pizzaconfig.AutoRouteToBaseOnStart == true) -- par défaut: PAS de route au spawn

pizzaconfig.StreakTime         = pizzaconfig.StreakTime or 90
pizzaconfig.ReturnOnEmpty      = pizzaconfig.ReturnOnEmpty or { enabled=true, action='route', radius=3.5, autoRestock=true }
pizzaconfig.RestockAtBase      = (pizzaconfig.RestockAtBase ~= false)
pizzaconfig.Vehicle            = pizzaconfig.Vehicle or { model='faggio', plate='PIZZA', lock=false, spawn=vector4(0.0,0.0,72.0,0.0) }
pizzaconfig.Drops              = pizzaconfig.Drops or {}
pizzaconfig.ReturnAfterDelivery= (pizzaconfig.ReturnAfterDelivery or 'whenEmpty') -- 'always' | 'whenEmpty' | 'never'
pizzaconfig.KeepBaseBlipOnStop = (pizzaconfig.KeepBaseBlipOnStop ~= true) -- true par défaut
-- pizzaconfig.BaseExactZ      = true -- à activer si base en intérieur/MLO
pizzaconfig.Debug              = pizzaconfig.Debug == true

-- 📍 QG (sert de repère pour le retour/teleport & blip base)
-- pizzaconfig.Base = vector4(793.70, -733.66, 27.51, 89.55)

-- 🛵 Scooter du livreur
pizzaconfig.Vehicle = {
    model = 'panto',
    spawn  =  vector4(785.06, -735.79, 26.94, 139.83) ,
    plate  = 'PIZZA',
    lock   = false
}

-- 📦 Inventaire & livraison
pizzaconfig.ItemName       = 'pizza_box'
pizzaconfig.ReturnAfterDelivery = 'never'
pizzaconfig.StartBoxes = 5         -- par ex.
pizzaconfig.DeliverPerStop = 1
pizzaconfig.RestockAtBase  = true
pizzaconfig.RestockAmount  = 5

-- 💵 Paiement des livraisons
pizzaconfig.Pay = {
    min = 5,
    max = 15,
    tipChance   = 35,  -- %
    tipMin      = 10,
    tipMax      = 60,
    streakBonus = 30,
    payTo       = 'cash'   -- 'cash' | 'bank' | 'item'
}

-- ⏱️ Délai max (s) pour garder le bonus de série
pizzaconfig.StreakTime = 180

-- 📮 Points de livraison (portes)
pizzaconfig.Drops = {
        vec3(224.11, 513.52, 140.92),
        vec3(57.51, 449.71, 147.03),
        vec3(-297.81, 379.83, 112.1),
        vec3(-595.78, 393.0, 101.88),
        vec3(-842.68, 466.85, 87.6),
        vec3(-1367.36, 610.73, 133.88),
        vec3(944.44, -463.19, 61.55),
        vec3(970.42, -502.5, 62.14),
        vec3(1099.5, -438.65, 67.79),
        vec3(1229.6, -725.41, 60.96),
        vec3(288.05, -1094.98, 29.42),
        vec3(-32.35, -1446.46, 31.89),
        vec3(-34.29, -1847.21, 26.19),
        vec3(130.59, -1853.27, 25.23),
        vec3(192.2, -1883.3, 25.06),
        vec3(348.64, -1820.87, 28.89),
        vec3(427.28, -1842.14, 28.46),
        vec3(291.48, -1980.15, 21.6),
        vec3(279.87, -2043.67, 19.77),
        vec3(1297.25, -1618.04, 54.58),
        vec3(1381.98, -1544.75, 57.11),
        vec3(1245.4, -1626.85, 53.28),
        vec3(315.09, -128.31, 69.98),
}

-- 🗺️ Blips
pizzaconfig.Blips = {
    base = { sprite = 267, color = 1, scale = 0.8, label = 'Pizza Intérim' },
    drop = { sprite = 280, color = 5, scale = 0.8, label = 'Livraison pizza' }
}

-- PNJ livraison/revente (désactivés pour l’instant)
pizzaconfig.DeliveryNPC = { enabled = false, useTarget = false }
pizzaconfig.SellBack    = {
    enabled = false, pricePerBox = 80, payTo = 'cash',
    ped = { model = 's_m_y_chef_01', coords = vector4(804.90, -761.30, 26.78, 90.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
    useInputAmount = true
}

-- 🔁 Retour auto au QG quand inventaire vide
pizzaconfig.ReturnOnEmpty = {
    enabled = true,          -- activer
    action  = 'route',       -- 'route' (blip + trajet) ou 'teleport'
    radius  = 3.5,           -- rayon d’arrivée au QG en mode 'route'
    autoRestock = true       -- restock auto à l’arrivée
}

pizzaconfig.Debug = false

-- 🧍 PNJ(s)
-- Ajout d’un champ `role` pour contrôler qui a les options start/stop:
--  - 'base' = PNJ principal (start/stop/restock)
--  - 'sell' = (quand tu activeras SellBack) revente
pizzaconfig.NPCs = {
    {
        role = 'base',
        model = "s_m_y_chef_01",
        coords = vector4(793.70, -733.66, 27.51, 89.55),
        freeze = true,
        invincible = true,
        text = "🍕 Intérim Pizza\n~E~ pour interagir"
    }
}

-- =========================
-- tan_pizza — pizzaconfig commandes
-- =========================
pizzaconfig.Commands = pizzaconfig.Commands or {
    enabled  = true,           -- désactiver = false
    name     = 'pizza',        -- nom de la commande: /pizza
    aliases  = { 'pizzajob' }, -- alias optionnels: /pizzajob
    showHelp = true,           -- affiche une suggestion dans le chat (si res 'chat' actif)
    helpText = '/pizza start | stop'
    -- (optionnel) keybinds plus tard si tu veux
}
