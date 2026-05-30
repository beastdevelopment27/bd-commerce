fx_version "cerulean"

description "Basic React (TypeScript) & Lua Game Scripts Boilerplate"
author "Project Error"
version '1.0.0'
repository 'https://github.com/project-error/fivem-react-boilerplate-lua'

lua54 'yes'

games {
  "gta5"
}

dependency 'oxmysql'

-- NUI page (must match Vite outDir: "build"). Run: cd web && npm run build
ui_page 'web/build/index.html'

client_script "client/**/*"
server_script "@oxmysql/lib/MySQL.lua"
server_script {
  "server/**/*",
}
shared_scripts {
    'config/**/*',
}

files {

	'web/build/index.html',
	'web/build/**/*',
}

-- escrow_ignore {
--   'config/config.lua',
--   'config/notifications.lua',
--   'server/sv_discord.lua',
--   'server/sv_society.lua',
--   'server/sv_inventory.lua',
-- }