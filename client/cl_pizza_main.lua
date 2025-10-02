-- =========================
--  tan_pizza — client (optimisé) — NO GPS ON SPAWN
-- =========================

if not pizzaconfig then
    print('^1[tan_pizza] pizzaconfig is nil. Assure-toi que pizzaconfig.lua est dans shared_scripts avant client.^0')
    return
end



local ox_target = exports.ox_target
local notify = function(args) lib.notify(args) end

-- ==== State ====
local jobActive         = false
local dropPoint         = nil        -- { coords, blip, zone, remove() }
local baseReturnPoint   = nil
local vehNet            = nil
local baseBlip          = nil
local currentRouteBlip  = nil
local deliveredCount    = 0
local streak            = 0
local lastDeliver       = 0
local deliverCooldownMs = 700        -- anti double clic ox_target
local lastSelectAt      = 0

-- ===== Helpers coords =====
local function ensureVec4(v)
    if type(v) == 'vector4' then return v end
    if type(v) == 'vector3' then return vector4(v.x, v.y, v.z, 0.0) end
    if type(v) == 'table' then return vector4(v.x or 0.0, v.y or 0.0, v.z or 72.0, v.w or v.h or 0.0) end
    return vector4(0.0,0.0,72.0,0.0)
end
local function ensureVec3(v)
    if type(v) == 'vector3' then return v end
    if type(v) == 'vector4' then return vector3(v.x, v.y, v.z) end
    if type(v) == 'table' then return vector3(v.x or 0.0, v.y or 0.0, v.z or 72.0) end
    return vector3(0.0,0.0,72.0)
end

-- ==== Helpers sol/route sûrs ====
local function waitCollisionAt(x, y, z, timeout)
    timeout = timeout or 1500
    local t = GetGameTimer()
    RequestCollisionAtCoord(x, y, z)
    while (GetGameTimer() - t) < timeout do
        if HasCollisionLoadedAroundEntity(cache.ped) then break end
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
end

local function findSafePedCoord(x, y, z, useExact)
    if useExact then return vector3(x, y, z) end
    local found, outPos = GetSafeCoordForPed(x + 0.0, y + 0.0, z + 1.0, false, 16)
    if found and outPos then return outPos end
    local okG, gz = GetGroundZFor_3dCoord(x, y, z + 50.0, true)
    if okG then return vector3(x, y, gz) end
    return vector3(x, y, z)
end

local function findVehicleSpawnNear(x, y, z, defaultHeading)
    local ok, nodePos, nodeHeading = GetClosestVehicleNodeWithHeading(x, y, z, 1, 3.0, 0)
    if ok and nodePos then return vector4(nodePos.x, nodePos.y, nodePos.z, nodeHeading or (defaultHeading or 0.0)) end
    return vector4(x + 3.0, y + 0.8, z, defaultHeading or 0.0)
end

-- ===== Base coords =====
local BaseCoord do
  if pizzaconfig.NPCs and pizzaconfig.NPCs[1] and pizzaconfig.NPCs[1].coords then
        BaseCoord = ensureVec4(pizzaconfig.NPCs[1].coords)
    else
        BaseCoord = ensureVec4(pizzaconfig.Vehicle.spawn)
    end
end

-- ==== Route helper (fix) ====
local function setRoute(blip, enable)
    if enable and blip and DoesBlipExist(blip) then
        if currentRouteBlip and DoesBlipExist(currentRouteBlip) and currentRouteBlip ~= blip then
            SetBlipRoute(currentRouteBlip, false)
        end
        SetBlipRoute(blip, true)
        if pizzaconfig.Blips and pizzaconfig.Blips.routeColor then
            SetBlipRouteColour(blip, pizzaconfig.Blips.routeColor)
        end
        currentRouteBlip = blip
    else
        if currentRouteBlip and DoesBlipExist(currentRouteBlip) then
            SetBlipRoute(currentRouteBlip, false)
        end
        currentRouteBlip = nil
    end
end

-- ==== Blips ====
local function setDropBlip(pos)
    if dropPoint and dropPoint.blip and DoesBlipExist(dropPoint.blip) then RemoveBlip(dropPoint.blip) end
    local bl = pizzaconfig.Blips.drop
    local b = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(b, bl.sprite or 280)
    SetBlipColour(b, bl.color or 5)
    if bl.scale then SetBlipScale(b, bl.scale) end
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(bl.label or 'Livraison'); EndTextCommandSetBlipName(b)
    setRoute(b, true) -- on trace la route UNIQUEMENT pour une livraison
    return b
end

-- ⚠️ Changement : on ne route PLUS automatiquement sur la base
local function setBaseBlip(route)
    if baseBlip and DoesBlipExist(baseBlip) then RemoveBlip(baseBlip) end
    local bl = pizzaconfig.Blips.base
    baseBlip = AddBlipForCoord(BaseCoord.x, BaseCoord.y, BaseCoord.z)
    SetBlipSprite(baseBlip, bl.sprite or 267)
    SetBlipColour(baseBlip, bl.color or 1)
    if bl.scale then SetBlipScale(baseBlip, bl.scale) end
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(bl.label or 'Base'); EndTextCommandSetBlipName(baseBlip)
    setRoute(route and baseBlip or nil, route == true)
    return baseBlip
end

local function ensureBaseBlipVisible(route)
    if not baseBlip or not DoesBlipExist(baseBlip) then setBaseBlip(route == true) else
        setRoute(route and baseBlip or nil, route == true)
    end
end

-- ==== Points / Zones ====
local function clearCurrentPoint()
    if dropPoint then
        if dropPoint.remove then dropPoint:remove() end
        dropPoint = nil
    end
    setRoute(nil, false)
end

-- === Sol sûr autour d'une porte (évite route/toit) ===
local function groundAt(x,y,z)
    local ok,gz = GetGroundZFor_3dCoord(x, y, z + 50.0, true)
    return vector3(x, y, ok and gz or z)
end

local function snapDoorGround(pos)
    local base = groundAt(pos.x, pos.y, pos.z)
    local gz0 = base.z
    local maxElevDiff = 2.0
    if not IsPointOnRoad(base.x, base.y, base.z, 0) then return base end
    for radius = 2, 10, 2 do
        for a = 0, 315, 45 do
            local rad = a * math.pi / 180.0
            local tx, ty = pos.x + math.cos(rad)*radius, pos.y + math.sin(rad)*radius
            local cand = groundAt(tx, ty, pos.z)
            if not IsPointOnRoad(cand.x, cand.y, cand.z, 0) and math.abs(cand.z - gz0) <= maxElevDiff then
                return cand
            end
        end
    end
    local cand = vector3(base.x + 1.6, base.y, base.z)
    if IsPointOnRoad(cand.x, cand.y, cand.z, 0) then cand = vector3(base.x - 1.6, base.y, base.z) end
    return cand
end

-- === Drops random ===
local function randDrop()
    return pizzaconfig.Drops[math.random(1, #pizzaconfig.Drops)]
end

-- ====== Poids (affichage) ======
local function fmtWeight(w)
    w = tonumber(w) or 0
    if w >= 100000 then return string.format('%.2f t', w/1000000) end
    if w >= 1000    then return string.format('%.2f kg', w/1000) end
    return string.format('%dg', w)
end

local function showWeightSummary()
    local item = pizzaconfig.ItemName or 'pizza_box'
    lib.callback('tan_pizza:server:getItemWeight', false, function(weight)
        weight = tonumber(weight) or 0
        if weight <= 0 then notify({title='Pizza', description='Poids de la pizza introuvable.', type='error'}); return end
        local per   = fmtWeight(weight)
        local total = fmtWeight(weight * (deliveredCount or 0))
        notify({ title='Pizza', description=('Poids d’une pizza : '..per..'\nPoids total livré (session) : '..total), type='inform' })
    end, item)
end

-- ==== Téléport retour base (réintégré & robuste) ====
local function teleportToBase()
    local x,y,z,h = BaseCoord.x, BaseCoord.y, BaseCoord.z, BaseCoord.w or 0.0
    local useExactZ = (pizzaconfig.BaseExactZ == true)

    DoScreenFadeOut(250); while not IsScreenFadedOut() do Wait(0) end

    if vehNet then
        local veh = NetworkGetEntityFromNetworkId(vehNet)
        if veh and DoesEntityExist(veh) then
            local vpos = findVehicleSpawnNear(x, y, z, h)
            waitCollisionAt(vpos.x, vpos.y, vpos.z)
            SetEntityCoords(veh, vpos.x, vpos.y, vpos.z, false, false, false, true)
            SetEntityHeading(veh, vpos.w or h)
            SetVehicleOnGroundProperly(veh)
        end
    end

    local p = findSafePedCoord(x, y, z, useExactZ)
    waitCollisionAt(p.x, p.y, p.z)
    SetEntityCoords(cache.ped, p.x, p.y, p.z, false, false, false, true)
    SetEntityHeading(cache.ped, h)

    DoScreenFadeIn(250)
end

-- ==== Retour au QG quand vide ====
local function goBackToBase()
    if not (pizzaconfig.ReturnOnEmpty and pizzaconfig.ReturnOnEmpty.enabled) then return end

    clearCurrentPoint()
    notify({title='Pizza', description='Tu n’as plus de boîtes. Retour au QG !', type='inform'})

    if pizzaconfig.ReturnOnEmpty.action == 'teleport' then
        teleportToBase()
        if pizzaconfig.RestockAtBase and (pizzaconfig.ReturnOnEmpty.autoRestock ~= false) then
            lib.callback('tan_pizza:server:restock', false, function(ok, count)
                if ok then
                    notify({title='Pizza', description=('Rechargé : '..count..' boîtes.'), type='success'})
                    nextDelivery()
                else
                    notify({title='Pizza', description='Rechargement impossible.', type='error'})
                end
            end)
        else
            notify({title='Pizza', description='Parle au PNJ pour reprendre des pizzas.', type='inform'})
        end
        return
    end

    -- ✅ Ici on veut guider le joueur : route vers la base activée volontairement
    setBaseBlip(true)
    baseReturnPoint = lib.points.new({
        coords = ensureVec3(BaseCoord),
        distance = 25.0,
        nearby = function(self)
            if #(GetEntityCoords(cache.ped) - self.coords) <= (pizzaconfig.ReturnOnEmpty.radius or 3.5) then
                setRoute(nil,false)
                if pizzaconfig.KeepBaseBlipOnStop then ensureBaseBlipVisible(false) else
                    if baseBlip and DoesBlipExist(baseBlip) then RemoveBlip(baseBlip) end
                    baseBlip = nil
                end
                self:remove(); baseReturnPoint = nil

                if pizzaconfig.RestockAtBase and (pizzaconfig.ReturnOnEmpty.autoRestock ~= false) then
                    lib.callback('tan_pizza:server:restock', false, function(ok, count)
                        if ok then
                            notify({title='Pizza', description=('Rechargé : '..count..' boîtes.'), type='success'})
                            nextDelivery()
                        else
                            notify({title='Pizza', description='Rechargement impossible.', type='error'})
                        end
                    end)
                else
                    notify({title='Pizza', description='Appuie sur ~INPUT_CONTEXT~ au PNJ pour reprendre des pizzas.', type='inform'})
                end
            end
        end
    })
end

-- ==== Livraison ====
local function performDelivery(pointRef)
    local now = GetGameTimer()
    if now - lastSelectAt < deliverCooldownMs then return end
    lastSelectAt = now

    lib.callback('tan_pizza:server:takebox', false, function(ok, remaining)
        if not ok then
            notify({title='Pizza', description=Locales.not_enough or 'Tu n’as plus de boîtes.', type='error'})
            goBackToBase()
            return
        end

        local pay, extra = math.random(pizzaconfig.Pay.min, pizzaconfig.Pay.max), ''
        if math.random(100) <= pizzaconfig.Pay.tipChance then
            local tip = math.random(pizzaconfig.Pay.tipMin, pizzaconfig.Pay.tipMax)
            pay, extra = pay + tip, (Locales.delivered_tip and string.format(Locales.delivered_tip, tip)) or (' +'..tip..'$ pourboire')
        end

        if (GetGameTimer() - lastDeliver) <= (pizzaconfig.StreakTime * 1000) then
            pay = pay + (pizzaconfig.Pay.streakBonus or 0)
            extra = extra .. ((Locales.delivered_streak and string.format(Locales.delivered_streak, pizzaconfig.Pay.streakBonus or 0)) or (' +'..(pizzaconfig.Pay.streakBonus or 0)..'$ série'))
        else
            streak = 0
        end
        streak = streak + 1
        lastDeliver = GetGameTimer()
        deliveredCount = (deliveredCount or 0) + 1

        TriggerServerEvent('tan_pizza:server:pay', pay)
        notify({title='Pizza', description=string.format(Locales.delivered or 'Livré ! +%d$%s', pay, extra), type='success'})

        if pointRef and pointRef.remove then pointRef:remove() end
        setRoute(nil,false)
        dropPoint = nil

        local mode = (pizzaconfig.ReturnAfterDelivery or 'whenEmpty'):lower()
        if mode == 'always' then
            goBackToBase()
            notify({title='Pizza', description=Locales.return_to_base or 'Retour au QG !', type='inform'})
            return
        end

        if mode == 'whenEmpty' and (tonumber(remaining) or 0) <= 0 then
            showWeightSummary()
            goBackToBase()
            return
        end

        dropPoint = nextDelivery()
        if not dropPoint then
            notify({ title='Pizza', description='Pas de nouvelle adresse (liste vide ou erreur).', type='error' })
            if pizzaconfig.ReturnOnEmpty and pizzaconfig.ReturnOnEmpty.enabled then ensureBaseBlipVisible(false) end
            return
        end
        notify({title='Pizza', description=Locales.next_point or 'Nouvelle adresse !', type='inform'})
    end)
end

-- ==== Prochaine livraison (ox_target, closure safe) ====
local function makeDropPoint(pos, zoneId)
    local pt = {
        coords = pos,
        blip   = setDropBlip(pos),
        zone   = zoneId,
        remove = function(self)
            if self.blip and DoesBlipExist(self.blip) then RemoveBlip(self.blip) end
            if self.zone then pcall(function() ox_target:removeZone(self.zone) end) end
            self.blip, self.zone = nil, nil
        end
    }
    return pt
end

function nextDelivery()
    if not jobActive then return nil end
    if not pizzaconfig.Drops or #pizzaconfig.Drops == 0 then
        notify({ title='Pizza', description='Aucun point de livraison dans pizzaconfig.Drops', type='error' })
        return nil
    end

    local raw = randDrop()
    local pos = snapDoorGround(ensureVec3(raw))

    clearCurrentPoint()

    local newPoint = { coords = pos, blip = nil, zone = nil }
    local label = (Locales and (Locales.deliver_target_label or Locales.deliver_prompt)) or 'Livrer la pizza'

    local zoneId = ox_target:addSphereZone({
        coords = pos,
        radius = 1.6,
        debug  = pizzaconfig.Debug or false,
        options = {
            {
                name  = 'pizza:deliver',
                icon  = 'fa-solid fa-pizza-slice',
                label = label,
                distance = 2.0,
                canInteract = function(_, distance) return jobActive == true and distance <= 2.0 end,
                onSelect = function()
                    if not jobActive or not newPoint then return end
                    performDelivery(newPoint)
                end
            }
        }
    })

    newPoint.blip = setDropBlip(pos)
    newPoint.zone = zoneId
    newPoint.remove = function(self)
        if self.blip and DoesBlipExist(self.blip) then RemoveBlip(self.blip) end
        if self.zone then pcall(function() ox_target:removeZone(self.zone) end) end
        self.blip, self.zone = nil, nil
    end

    dropPoint = newPoint
    return newPoint
end

-- ==== Gestion véhicule ====
local function spawnVehicle()
    local model = joaat(pizzaconfig.Vehicle.model)
    if not lib.requestModel(model, 8000) then return false end
    local c = ensureVec4(pizzaconfig.Vehicle.spawn)
    local veh = CreateVehicle(model, c.x, c.y, c.z, c.w, true, true)
    if not DoesEntityExist(veh) then return false end
    SetVehicleNumberPlateText(veh, pizzaconfig.Vehicle.plate or 'PIZZA')
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    if pizzaconfig.Vehicle.lock then SetVehicleDoorsLocked(veh, 2) end
    SetModelAsNoLongerNeeded(model)
    vehNet = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdCanMigrate(vehNet, true)
    local plate = GetVehicleNumberPlateText(veh)
    notify({title='Pizza', description=string.format(Locales.vehicle_spawned or 'Scooter prêt (%s)', plate), type='inform'})
    return true
end

local function deleteVehicle()
    if not vehNet then return end
    local veh = NetworkGetEntityFromNetworkId(vehNet)
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    vehNet = nil
end

-- ==== Start/Stop job ====
local function startJob()
    if jobActive then notify({title='Pizza', description=Locales.already or 'Tu es déjà en mission.', type='error'}); return end
    lib.callback('tan_pizza:server:start', false, function(ok, count, err)
        if not ok then
            notify({ title='Pizza', description='Impossible de démarrer : '..(err or 'callback serveur indisponible'), type='error' })
            print(('[tan_pizza] startJob() a échoué. err=%s, count=%s'):format(tostring(err), tostring(count)))
            return
        end
        if not spawnVehicle() then
            notify({title='Pizza', description=Locales.vehicle_spawn_fail or 'Impossible de sortir le véhicule.', type='error'})
            return
        end
        jobActive, streak, lastDeliver, deliveredCount = true, 0, 0, 0
        notify({title='Pizza', description=string.format(Locales.started or 'Mission lancée (%d boîtes).', count or 0), type='success'})
        nextDelivery()
    end)
end

local function stopJob()
    if not jobActive then notify({title='Pizza', description=Locales.not_on_job or 'Tu n’es pas en mission.', type='error'}); return end
    jobActive = false

    clearCurrentPoint()
    if baseReturnPoint then if baseReturnPoint.remove then baseReturnPoint:remove() end baseReturnPoint = nil end
    setRoute(nil, false)

    if pizzaconfig.KeepBaseBlipOnStop then ensureBaseBlipVisible(false) else
        if baseBlip and DoesBlipExist(baseBlip) then RemoveBlip(baseBlip) end
        baseBlip = nil
    end

    deleteVehicle()
    deliveredCount = 0
    notify({title='Pizza', description=Locales.stopped or 'Mission arrêtée.', type='inform'})
end

-- ==== Nettoyage inventaire & véhicule ====
local function clearInventoryBoxes(cb)
    local item = pizzaconfig.ItemName or 'pizza_box'
    lib.callback('tan_pizza:server:clearBoxes', false, function(removed)
        if removed and removed > 0 then notify({title='Pizza', description=('Boîtes rendues : '..removed), type='inform'}) end
        if cb then cb(removed or 0) end
    end, item)
end

local function parkAndDeleteVehicle()
    if not vehNet then return end
    local veh = NetworkGetEntityFromNetworkId(vehNet)
    if veh and DoesEntityExist(veh) then
        local x,y,z,h = BaseCoord.x, BaseCoord.y, BaseCoord.z, BaseCoord.w or 0.0
        local vpos = findVehicleSpawnNear(x, y, z, h)
        waitCollisionAt(vpos.x, vpos.y, vpos.z)
        SetEntityCoords(veh, vpos.x, vpos.y, vpos.z, false, false, false, true)
        SetEntityHeading(veh, vpos.w or h)
        SetVehicleOnGroundProperly(veh)
        Wait(120)
        DeleteEntity(veh)
    end
    vehNet = nil
end

local function stopJobWithCleanup()
    if not jobActive then notify({title='Pizza', description=Locales.not_on_job or 'Tu n’es pas en mission.', type='error'}); return end
    teleportToBase()
    clearInventoryBoxes(function()
        parkAndDeleteVehicle()
        showWeightSummary()
        stopJob()
    end)
end

-- ==== PNJ base (blip + target) ====
-- ⚠️ Plus de setBaseBlip() forcé ici ; on respecte les switches
CreateThread(function()
    if pizzaconfig.ShowBaseBlipOnStart then
        setBaseBlip(pizzaconfig.AutoRouteToBaseOnStart == true) -- par défaut, PAS de route
    end
end)

local function buildBaseTargetOptions()
    local opts = {
        { name='tan_pizza:start', icon='fa-solid fa-pizza-slice', label=Locales.start_label or 'Commencer la mission', distance=2.0, onSelect = startJob },
        { name='tan_pizza:stop',  icon='fa-solid fa-circle-stop',  label=Locales.stop_label  or 'Arrêter la mission',  distance=2.0, onSelect = stopJobWithCleanup },
    }
    if pizzaconfig.RestockAtBase then
        opts[#opts+1] = {
            name='tan_pizza:restock', icon='fa-solid fa-box-open', label=Locales.restock_label or 'Recharger les boîtes', distance=2.0,
            onSelect=function()
                lib.callback('tan_pizza:server:restock', false, function(ok, count)
                    if ok then notify({title='Pizza', description=string.format(Locales.restocked or 'Rechargé : %d boîtes.', count or 0), type='success'}) end
                end)
            end
        }
    end
    return opts
end

-- Spawn PNJ(s) + target
CreateThread(function()
    for _, npc in pairs(pizzaconfig.NPCs or {}) do
        local model = GetHashKey(npc.model or 's_m_m_linecook')
        RequestModel(model); while not HasModelLoaded(model) do Wait(20) end
        local c = ensureVec4(npc.coords or BaseCoord)
        local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, npc.freeze ~= false)
        SetEntityInvincible(ped, npc.invincible ~= false)
        SetModelAsNoLongerNeeded(model)
        npc.handle = ped
        ox_target:addLocalEntity(ped, buildBaseTargetOptions())
    end
end)

-- 🧾 Texte 3D au-dessus du PNJ (léger)
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    local cam = GetGameplayCamCoords()
    local dist = #(cam - vector3(x, y, z))
    local scale = 0.35 * (1.0 / dist) * 2.0 * (1.0 / GetGameplayCamFov()) * 100
    SetTextScale(0.0, scale); SetTextFont(4); SetTextProportional(1); SetTextCentre(true)
    SetTextColour(255, 255, 255, 200); SetTextEntry("STRING"); AddTextComponentString(text); DrawText(_x, _y)
end

CreateThread(function()
    while true do
        local wait = 1000
        local player = GetEntityCoords(PlayerPedId())
        for _, npc in pairs(pizzaconfig.NPCs or {}) do
            if npc.handle and DoesEntityExist(npc.handle) then
                local ped = GetEntityCoords(npc.handle)
                if #(player - ped) < 10.0 then
                    wait = 0
                    DrawText3D(ped.x, ped.y, ped.z + 1.0, npc.text or "🍕 Intérim Pizza\nUtilise la cible (ox_target)")
                end
            end
        end
        Wait(wait)
    end
end)

-- ==== Commandes (pilotées par pizzaconfig) ====
do
    local cfg = pizzaconfig.Commands or {}
    if cfg.enabled ~= false then
        local function pizzaCmdHandler(_, args)
            local sub = (args[1] or 'help'):lower()
            if sub == 'start' then
                startJob()
            elseif sub == 'stop' then
                stopJobWithCleanup()
            else
                notify({ title='Pizza', description = cfg.helpText or ("/"..(cfg.name or "pizza").." start | stop"), type='inform' })
            end
        end

        RegisterCommand(cfg.name or 'pizza', pizzaCmdHandler)

        if type(cfg.aliases) == 'table' then
            for _, alias in ipairs(cfg.aliases) do
                if alias and alias ~= '' then
                    RegisterCommand(alias, pizzaCmdHandler)
                end
            end
        end

        if cfg.showHelp ~= false then
            local state = GetResourceState and GetResourceState('chat')
            if state == 'starting' or state == 'started' then
                local base = "/"..(cfg.name or 'pizza')
                local help = cfg.helpText or (base.." start | stop")
                TriggerEvent('chat:addSuggestion', base, 'Gestion du job pizza', {
                    { name = 'start', help = 'Commencer la mission' },
                    { name = 'stop',  help = 'Arrêter la mission' }
                })
                if type(cfg.aliases) == 'table' then
                    for _, alias in ipairs(cfg.aliases) do
                        if alias and alias ~= '' then
                            local a = "/"..alias
                            TriggerEvent('chat:addSuggestion', a, help, {
                                { name = 'start', help = 'Commencer la mission' },
                                { name = 'stop',  help = 'Arrêter la mission' }
                            })
                        end
                    end
                end
            end
        end
    end
end
