-- =========================
--  tan_pizza — server (optimisé)
-- =========================
-- ⚠️ fxmanifest: shared_script '@ox_lib/init.lua'

-- --------- Garde-fous pizzaconfig ---------
pizzaconfig = pizzaconfig or {}
pizzaconfig.Inventory       = pizzaconfig.Inventory or 'auto'     -- 'auto' | 'ox' | 'esx'
pizzaconfig.ItemName        = pizzaconfig.ItemName or 'pizza_box'
pizzaconfig.StartBoxes      = math.max(0, tonumber(pizzaconfig.StartBoxes or 1))
pizzaconfig.DeliverPerStop  = math.max(1, tonumber(pizzaconfig.DeliverPerStop or 1))
pizzaconfig.RestockAmount   = math.max(0, tonumber(pizzaconfig.RestockAmount or 1))
pizzaconfig.Pay             = pizzaconfig.Pay or { payTo = 'cash' }
pizzaconfig.SellBack        = pizzaconfig.SellBack or { pricePerBox = 0 }
pizzaconfig.Debug           = pizzaconfig.Debug == true

local ITEM = pizzaconfig.ItemName

-- --------- Détection dynamique + lazy exports ---------
local function hasRes(name) return GetResourceState(name) == 'started' end

local env = {
    esx     = false,
    qb      = false,
    ox_core = false,
    ox_inv  = false,
}

local ESX, QBCore, OX = nil, nil, nil

local function refreshEnv()
    env.esx     = hasRes('es_extended')
    env.qb      = hasRes('qb-core')
    env.ox_core = hasRes('ox_core')
    env.ox_inv  = hasRes('ox_inventory')
end
refreshEnv()

local function getESX()
    if not ESX and env.esx then ESX = exports['es_extended']:getSharedObject() end
    return ESX
end
local function getQB()
    if not QBCore and env.qb then QBCore = exports['qb-core']:GetCoreObject() end
    return QBCore
end
local function getOX()
    if not OX and env.ox_core then OX = exports.ox_core end
    return OX
end

-- actualise si une res démarre après coup
AddEventHandler('onResourceStart', function(res)
    if res == 'es_extended' or res == 'qb-core' or res == 'ox_core' or res == 'ox_inventory' then
        refreshEnv()
        ESX, QBCore, OX = nil, nil, nil  -- force un re-lazy-load propre
        if pizzaconfig.Debug then print(('[tan_pizza] env refresh after %s start'):format(res)) end
    end
end)

-- --------- Bridge: joueur / argent / inventaire ---------
local function getPlayer(src)
    if env.esx then
        local esx = getESX()
        return esx and esx.GetPlayerFromId(src) or nil
    end
    if env.qb then
        local qb = getQB()
        return qb and qb.Functions.GetPlayer(src) or nil
    end
    if env.ox_core then
        local ox = getOX()
        return (ox and ox.GetPlayer) and ox.GetPlayer(src) or nil
    end
    return nil
end

local function addMoney(src, amount, account)
    amount  = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    account = account or (pizzaconfig.Pay and pizzaconfig.Pay.payTo) or 'cash'

    if env.esx then
        local xPlayer = getPlayer(src); if not xPlayer then return end
        if account == 'bank' then xPlayer.addAccountMoney('bank', amount) else xPlayer.addMoney(amount) end
        return
    end
    if env.qb then
        local p = getPlayer(src); if not p then return end
        if account == 'bank' then p.Functions.AddMoney('bank', amount) else p.Functions.AddMoney('cash', amount) end
        return
    end
    if env.ox_core then
        local p = getPlayer(src); if not p then return end
        -- ox_core varie selon version; on tente addAccountMoney s’il existe
        if p.addAccountMoney then
            if account == 'bank' then p.addAccountMoney('bank', amount) else p.addAccountMoney('money', amount) end
            return
        end
    end
    -- Fallback: donne l’item “money” si ox_inventory dispo
    if env.ox_inv then exports.ox_inventory:AddItem(src, 'money', amount) end
end

local function invAdd(src, name, count)
    name  = name or ITEM
    count = math.max(1, tonumber(count or 1))
    if pizzaconfig.Inventory == 'ox' or (pizzaconfig.Inventory == 'auto' and env.ox_inv) then
        return exports.ox_inventory:AddItem(src, name, count) ~= false
    elseif pizzaconfig.Inventory == 'esx' or (pizzaconfig.Inventory == 'auto' and env.esx) then
        local xPlayer = getPlayer(src); if not xPlayer then return false end
        xPlayer.addInventoryItem(name, count); return true
    end
    return false
end

local function invRemove(src, name, count)
    name  = name or ITEM
    count = math.max(1, tonumber(count or 1))
    if pizzaconfig.Inventory == 'ox' or (pizzaconfig.Inventory == 'auto' and env.ox_inv) then
        return exports.ox_inventory:RemoveItem(src, name, count) ~= false
    elseif pizzaconfig.Inventory == 'esx' or (pizzaconfig.Inventory == 'auto' and env.esx) then
        local xPlayer = getPlayer(src); if not xPlayer then return false end
        local it = xPlayer.getInventoryItem(name)
        if it and (it.count or 0) >= count then xPlayer.removeInventoryItem(name, count) return true end
        return false
    end
    return false
end

local function invCount(src, name)
    name = name or ITEM
    if pizzaconfig.Inventory == 'ox' or (pizzaconfig.Inventory == 'auto' and env.ox_inv) then
        return exports.ox_inventory:Search(src, 'count', name) or 0
    elseif pizzaconfig.Inventory == 'esx' or (pizzaconfig.Inventory == 'auto' and env.esx) then
        local xPlayer = getPlayer(src); if not xPlayer then return 0 end
        local it = xPlayer.getInventoryItem(name)
        return (it and it.count) or 0
    end
    return 0
end

-- --------- Callbacks ---------
-- Nettoyage total des boîtes
lib.callback.register('tan_pizza:server:clearBoxes', function(source, item)
    item = item or ITEM
    local count = invCount(source, item)
    if count > 0 then invRemove(source, item, count) end
    if pizzaconfig.Debug then print(('[tan_pizza] clearBoxes %d x %s'):format(count, item)) end
    return count
end)

-- Démarrer mission
lib.callback.register('tan_pizza:server:start', function(source)
    local have = invCount(source, ITEM)
    if have <= 0 and pizzaconfig.StartBoxes > 0 then
        local ok = invAdd(source, ITEM, pizzaconfig.StartBoxes)
        if not ok then
            print(('[^1tan_pizza^0] start: addItem(%s, %d) a échoué (inv=%s, env ox=%s esx=%s)')
                :format(ITEM, pizzaconfig.StartBoxes, tostring(pizzaconfig.Inventory), tostring(env.ox_inv), tostring(env.esx)))
            return false, have, 'addItem a échoué (inventaire indisponible)'
        end
        have = pizzaconfig.StartBoxes
    end
    return true, have
end)

-- Restock
lib.callback.register('tan_pizza:server:restock', function(source)
    if pizzaconfig.RestockAmount <= 0 then return false, 0 end
    local ok = invAdd(source, ITEM, pizzaconfig.RestockAmount)
    if not ok then
        print(('[^1tan_pizza^0] restock: addItem(%s, %d) a échoué'):format(ITEM, pizzaconfig.RestockAmount))
        return false, 0
    end
    return true, pizzaconfig.RestockAmount
end)

-- Prendre 1 stop (ok, remaining)
lib.callback.register('tan_pizza:server:takebox', function(source)
    local ok = invRemove(source, ITEM, pizzaconfig.DeliverPerStop)
    local remaining = invCount(source, ITEM)
    if pizzaconfig.Debug then print(('[tan_pizza] takebox ok=%s remaining=%d'):format(tostring(ok), remaining)) end
    return ok, remaining
end)

-- Compter
lib.callback.register('tan_pizza:server:getCount', function(source)
    return invCount(source, ITEM)
end)

-- Poids d’un item (ox_inventory)
lib.callback.register('tan_pizza:server:getItemWeight', function(source, item)
    item = item or ITEM
    if not env.ox_inv then return 0 end
    local items = exports.ox_inventory:Items()
    local def = items and items[item]
    local w = (def and def.weight) or 0
    return w
end)

-- Paiement
RegisterNetEvent('tan_pizza:server:pay', function(amount)
    addMoney(source, amount, pizzaconfig.Pay and pizzaconfig.Pay.payTo)
end)

-- Revente
RegisterNetEvent('tan_pizza:server:sell', function(amount)
    local src = source
    amount = tonumber(amount) or 0

    local have = invCount(src, ITEM)
    if have <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { title='Pizza', description='Tu n’as aucune boîte à revendre.', type='error' })
        return
    end

    if amount <= 0 or amount > have then amount = have end
    local ok = invRemove(src, ITEM, amount)
    if not ok then
        TriggerClientEvent('ox_lib:notify', src, { title='Pizza', description='Impossible de retirer les boîtes.', type='error' })
        return
    end

    local pay = math.max(0, (pizzaconfig.SellBack.pricePerBox or 0) * amount)
    if pay > 0 then addMoney(src, pay, 'cash') end

    TriggerClientEvent('ox_lib:notify', src, {
        title='Pizza',
        description=('Tu as vendu %d boîte(s) pour $%d (cash).'):format(amount, pay),
        type='success'
    })
end)

-- ✅ IMPORTANT :
-- Ne mets PAS de RegisterCommand('pizza', ...) côté serveur pour start/stop :
-- ces fonctions sont côté client (startJob/stopJobWithCleanup). Garde la commande dans client.lua uniquement.
