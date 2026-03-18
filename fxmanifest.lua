fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lm_model'
author 'Lumen Model'
description 'Standalone synced model library'
version '1.0.0'

dependencies {
    'ox_lib',
}

server_scripts {
    '@ox_lib/init.lua',
    'server/registry.lua',
}

files {
    'shared/**/*.lua',
    'client/**/*.lua',
}