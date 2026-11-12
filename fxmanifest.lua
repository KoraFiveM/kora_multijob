fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_multijob'
author 'qbcore2'
version '0.2.0'
description 'Saved multi-job roster for kora_core'

dependency 'kora_theme'
dependency 'kora_lib'
dependency 'kora_sql'
dependency 'kora_core'

shared_scripts {
    '@kora_lib/init.lua',
    '@kora_core/init.lua',
    'config.lua',
}

server_scripts {
    '@kora_sql/init.lua',
    'schema.lua',
    'server.lua',
}

client_script 'client.lua'

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
