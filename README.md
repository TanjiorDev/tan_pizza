# ─────────────────────────────────────────────────────────────────────────────
# README.md
# ─────────────────────────────────────────────────────────────────────────────
# tan_pizza_tempjob (ox)

## Prérequis
- ox_lib
- ox_target
- ox_inventory (item `pizza_box`)
- (Optionnel) ESX, QBCore ou ox_core pour gérer l’argent (auto-détecté). Sinon, fallback en item `money` via ox_inventory.

## Installation
1. Déposez `tan_pizza_tempjob` dans `resources/`.
2. Ajoutez l’item dans ox_inventory (voir items_ox_inventory.lua) ou votre système.
3. Ajoutez au `server.cfg` :
   ```
   ensure ox_lib
   ensure ox_target
   ensure ox_inventory
   ensure tan_pizza_tempjob
   ```
4. (ESX) Optionnel : items_esx.sql pour créer `pizza_box` si vous utilisez aussi l’items table ESX.

## Utilisation
- Allez voir le PNJ au marqueur « Pizza Intérim » et utilisez ox_target :
  - Commencer le job
  - Arrêter le job
  - Reprendre des pizzas (si activé)
- Fallback commandes : `/pizza start`, `/pizza stop`, `/pizza restock`

## Config
- Éditez `config.lua` (quantités, paies, points, véhicule, labels blips, etc.).

## Personnalisation rapide
- Changer `Config.ItemName` si votre item s’appelle autrement.
- Ajouter des points dans `Config.Drops`.
- Remplacer `faggio2` par votre scooter/veh pizza.
- Basculer paiement sur cash/bank/item.

## Dépannage
- Le scooter ne spawn pas ? Vérifiez la place libre et vos coordonnées `Config.Vehicle.spawn`.
- Pas de pizzas ? Vérifiez l’item ox_inventory et son nom.
- Pas d’argent reçu ? Assurez-vous qu’un framework est démarré (es_extended / qb-core / ox_core) ou que l’item `money` existe dans ox_inventory.

# ─────────────────────────────────────────────────────────────────────────────
# items_ox_inventory.lua (exemple pour data/items.lua)
# ─────────────────────────────────────────────────────────────────────────────
-- À coller dans votre items.lua de ox_inventory
['pizza_box'] = {
    label = 'Boîte de pizza',
    weight = 500,
    stack = true,
    close = true,
    description = 'Une délicieuse pizza prête à livrer.'
},

-- (optionnel) si fallback argent en item
['money'] = {
    label = 'Cash',
    weight = 0,
    stack = true,
    close = false,
    description = 'Billets.'
},

# ─────────────────────────────────────────────────────────────────────────────
# items_esx.sql (optionnel si vous utilisez encore la table items ESX en parallèle)
# ─────────────────────────────────────────────────────────────────────────────
INSERT INTO items (name, label) VALUES
('pizza_box', 'Boîte de pizza');