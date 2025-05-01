fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 "yes"

author 'CODE101'
description 'LR-MultiJobs'
version '1.0.0'

shared_scripts { 
    'shared/config.lua',
    'locale.lua',
    'languages/*.lua'
}

client_scripts { 
    'client/c-main.lua',
}

server_scripts {
    'server/s-main.lua',
}