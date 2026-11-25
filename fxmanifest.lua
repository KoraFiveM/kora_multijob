fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_multijob'
author 'Kora'
version '0.2.2'
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

-- Client-side Kora.lang reads these with LoadResourceFile, which only sees
-- files shipped to the client.
files { 'locales/*.lua' }

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'

server_script 'kora_versioncheck.lua'
