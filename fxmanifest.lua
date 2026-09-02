fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbmultijob'
author 'qbcore2'
version '1.0.0'
description 'Saved multi-job roster for qbcore'

dependency 'qblib'
dependency 'qbsql'
dependency 'qbcore'

ui_page 'web/build/index.html'

shared_scripts {
    '@qblib/init.lua',
    '@qbsql/init.lua',
    '@qbcore/init.lua',
    'config.lua',
}

server_scripts {
    'server.lua',
}

client_scripts {
    'client.lua',
}

files {
    'web/build/index.html',
    'web/build/**/*',
    'sql/001_jobs.sql',
}
