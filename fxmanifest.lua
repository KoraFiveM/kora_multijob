fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbmultijob'
author 'qbcore2'
version '1.0.0'
description 'Saved multi-job roster for qbcore'

dependency 'qbtheme'
dependency 'qblib'
dependency 'qbsql'
dependency 'qbcore'

shared_scripts {
    '@qblib/init.lua',
    '@qbsql/init.lua',
    '@qbcore/init.lua',
    'config.lua',
}

server_scripts {
    'server.lua',
}

client_script 'client.lua'

files {
    'sql/001_jobs.sql',
    'sql/002_roster_names.sql',
}
