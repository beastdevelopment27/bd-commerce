Config = Config or {}

--- Server framework for player data, jobs, money, and inventory fallbacks.
---   auto   = detect es_extended / qbx_core / qbox / qb-core
---   esx    = ESX Legacy (es_extended)
---   qbox   = QBox / QBX (qbx_core or qbox)
---   qbcore = QB-Core (qb-core)
Config.Framework = 'auto'

--- Resource names (change if your server renames them)
Config.FrameworkResources = {
  ESX = 'es_extended',
  QBCore = 'qb-core',
  QBox = 'qbx_core',
  QBoxAlt = 'qbox',
}
