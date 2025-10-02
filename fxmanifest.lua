fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'tan_pizza_tempjob'
author 'TanjiroDev'
description 'Job intérimaire de livraison de pizzas (ox_lib/ox_target/ox_inventory)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/fr.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies { 'ox_lib', 'ox_target', 'ox_inventory' }

