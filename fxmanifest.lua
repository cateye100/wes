fx_version 'cerulean'
game 'gta5'

name 'qb-vehicle-target'
author 'Ville + ChatGPT'
description 'Fordonstillägg för qb-target (inuti & utanpå): lås, dörrar, fönster, bälte (ALT-håll)'
version '1.0.1'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'qb-target'
}
