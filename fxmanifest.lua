fx_version 'cerulean'
game 'gta5'

author 'YG_WORKS'
description 'Standalone Panic Button Script'
version '2.2.0'

client_script 'client.lua'
server_script 'server.lua'
shared_script 'config.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/panic.ogg',
    'html/images/police_logo.png', -- Replace with your police logo image url
    'html/images/fire_logo.png', -- Replace with your fire logo image url
    'html/images/ems_logo.png' -- Replace with your ems logo image url
}