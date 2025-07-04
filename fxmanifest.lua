fx_version 'cerulean'
game 'gta5'
author 'Virgil Dev'
description 'small container thing idk'
version '0.1.0'

shared_script {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script {
    '@qbx_core/modules/playerdata.lua',
    'client/*.lua'
}

server_script {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
    'sv_config.lua'
}

lua54 'yes'