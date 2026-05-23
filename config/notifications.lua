Config = Config or {}

--- Notification settings (client + server relay).
--- Set Provider to a `name` from the list below, or `auto` to use the first available entry.
Config.Notifications = {
  Provider = 'auto',
  DefaultDuration = 5000,
  DefaultTitle = 'Commerce',

  --- Detection order: first started resource wins when Provider = 'auto'
  --- Add more entries anywhere in the list.
  Notifications = {
    [1] = { name = 'g-notifications', resource = 'g-notifications' },
    [2] = { name = 'okokNotify', resource = 'okokNotify' },
    [3] = { name = 'qbox', resource = 'qbox' },
    [4] = { name = 'qb-notify', resource = 'qb-notify' },
    [5] = { name = 'ox-lib', resource = 'ox_lib' },
    [6] = { name = 'mythic_notify', resource = 'mythic_notify' },
    [7] = { name = 'esx', resource = 'es_extended' },
    [8] = { name = 'lation_ui', resource = 'lation_ui' },
    [9] = { name = 'wasabi_notify', resource = 'wasabi_notify' },
    [10] = { name = 'gta-default', resource = 'gta_default', fallback = true },
    -- [11] = { name = 'custom', resource = 'my_notify_resource' },
  },

  --- Used when name = 'custom' (optional client event instead of export)
  CustomClientEvent = 'bd_commerce:customNotify',
  CustomServerEvent = nil,

  OxLib = { position = 'top-right' },
  OkOk = { position = 'top-right' },
  GNotifications = { position = 'top-right' },
  LationUi = { position = 'top-right' },
}
