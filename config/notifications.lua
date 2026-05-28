Config = Config or {}

--- Notification script (framework is set in config/framework.lua: esx | qbox | qbcore).
--- Provider = 'auto' uses the first running resource in Notifications below.
--- Provider = 'ox-lib' (etc.) forces that notify script.
Config.Notifications = {
  Provider = 'auto',
  DefaultDuration = 5000,
  DefaultTitle = 'Commerce',

  Notifications = {
    [1] = { name = 'g-notifications', resource = 'g-notifications' },
    [2] = { name = 'okokNotify', resource = 'okokNotify' },
    [3] = { name = 'qb-notify', resource = 'qb-notify' },
    [4] = { name = 'qbox', resource = 'qbox' },
    [5] = { name = 'ox-lib', resource = 'ox_lib' },
    [6] = { name = 'mythic_notify', resource = 'mythic_notify' },
    [7] = { name = 'lation_ui', resource = 'lation_ui' },
    [8] = { name = 'wasabi_notify', resource = 'wasabi_notify' },
    [9] = { name = 'esx', resource = 'es_extended' },
    [10] = { name = 'qbcore', resource = 'qb-core' },
    [11] = { name = 'gta-default', resource = 'gta_default', fallback = true },
  },

  CustomClientEvent = 'bd_commerce:customNotify',
  CustomServerEvent = nil,

  OxLib = { position = 'top-right' },
  OkOk = { position = 'top-right' },
  GNotifications = { position = 'top-right' },
  LationUi = { position = 'top-right' },
}
