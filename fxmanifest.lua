fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_multijob'
author 'qbcore2'
version '0.1.0'
description 'Saved multi-job roster for kora_core'

dependency 'kora_theme'
dependency 'kora_lib'
dependency 'kora_sql'
dependency 'kora_core'

shared_scripts {
    '@kora_lib/init.lua',
    '@kora_core/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@kora_sql/init.lua',
    'server/schema.lua',
    'server/server.lua',
}

client_script 'client/client.lua'

files {
    'locales/*.lua',
}

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
