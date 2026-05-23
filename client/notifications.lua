local ESX = nil
local QBCore = nil
local detectedNotificationType = nil
local notificationDetected = false

CreateThread(function()
  if GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
  end
  if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
  end
end)

local function getNotificationConfig()
  return type(Config) == 'table' and Config.Notifications or {}
end

local function isResourceStarted(name)
  return type(name) == 'string' and name ~= '' and GetResourceState(name) == 'started'
end

local function normalizeType(notifyType)
  local value = type(notifyType) == 'string' and notifyType:lower() or 'success'
  if value == 'success' or value == 'good' then return 'success' end
  if value == 'error' or value == 'danger' or value == 'err' then return 'error' end
  if value == 'warning' or value == 'warn' then return 'warning' end
  if value == 'primary' then return 'primary' end
  return 'info'
end

local function buildMessage(payload)
  if type(payload) ~= 'table' then
    return tostring(payload or ''), getNotificationConfig().DefaultTitle or 'Commerce'
  end
  local title = payload.title or payload.header or getNotificationConfig().DefaultTitle or 'Commerce'
  local message = payload.message or payload.description or payload.text or ''
  title = type(title) == 'string' and title or 'Commerce'
  message = type(message) == 'string' and message or ''
  if message == '' and title ~= '' and title ~= (getNotificationConfig().DefaultTitle or 'Commerce') then
    message = title
    title = getNotificationConfig().DefaultTitle or 'Commerce'
  end
  return message, title
end

local function isProviderAvailable(entry)
  if type(entry) ~= 'table' then return false end
  local name = entry.name or ''

  if entry.fallback or name == 'gta-default' then
    return true
  end

  if name == 'esx' then
    return isResourceStarted('es_extended') or isResourceStarted('esx')
  end

  if name == 'qbox' then
    return isResourceStarted('qbox') or isResourceStarted('qb-core') or isResourceStarted('qbx_core')
  end

  return isResourceStarted(entry.resource)
end

function DetectNotificationSystem()
  local cfg = getNotificationConfig()
  local forced = type(cfg.Provider) == 'string' and cfg.Provider:lower() or 'auto'

  if forced ~= 'auto' and forced ~= '' then
    detectedNotificationType = forced
    notificationDetected = true
    return detectedNotificationType
  end

  local list = cfg.Notifications
  if type(list) ~= 'table' then
    detectedNotificationType = 'gta-default'
    notificationDetected = true
    return detectedNotificationType
  end

  local keys = {}
  for key in pairs(list) do
    keys[#keys + 1] = key
  end
  table.sort(keys)

  for _, key in ipairs(keys) do
    local entry = list[key]
    if isProviderAvailable(entry) and entry.name ~= 'gta-default' then
      detectedNotificationType = entry.name
      notificationDetected = true
      return detectedNotificationType
    end
  end

  detectedNotificationType = 'gta-default'
  notificationDetected = true
  return detectedNotificationType
end

local function getNotificationType()
  if not notificationDetected then
    DetectNotificationSystem()
  end
  return detectedNotificationType or 'gta-default'
end

local function notifyGtaDefault(message)
  AddTextEntry('bd_commerce_notify', message)
  BeginTextCommandThefeedPost('bd_commerce_notify')
  EndTextCommandThefeedPostTicker(false, true)
end

local function dispatchNotification(message, notifyType, duration, title)
  local cfg = getNotificationConfig()
  notifyType = normalizeType(notifyType)
  duration = tonumber(duration) or cfg.DefaultDuration or 5000
  title = title or cfg.DefaultTitle or 'Commerce'

  local notifType = getNotificationType()

  if notifType == 'g-notifications' then
    local gCfg = cfg.GNotifications or {}
    exports['g-notifications']:Notify({
      title = title,
      description = message,
      type = notifyType,
      duration = duration,
      position = gCfg.position or 'top-right',
    })
  elseif notifType == 'okokNotify' then
    local okCfg = cfg.OkOk or {}
    exports.okokNotify:Alert(notifyType, message, duration, notifyType, false)
  elseif notifType == 'qbox' then
    local qType = notifyType
    if qType == 'info' then
      qType = 'primary'
    end
    if not QBCore and isResourceStarted('qb-core') then
      QBCore = exports['qb-core']:GetCoreObject()
    end
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
      QBCore.Functions.Notify(message, qType, duration)
    elseif isResourceStarted('qbox') and exports.qbox and exports.qbox.Notify then
      exports.qbox:Notify(message, qType, duration)
    elseif isResourceStarted('qbx_core') and exports.qbx_core then
      exports.qbx_core:Notify(message, qType, duration)
    end
  elseif notifType == 'qb-notify' then
    exports['qb-notify']:Notify(message, notifyType, duration)
  elseif notifType == 'ox-lib' then
    local oxCfg = cfg.OxLib or {}
    local data = {
      title = title,
      description = message,
      type = notifyType,
      duration = duration,
      position = oxCfg.position or 'top-right',
    }
    if lib and lib.notify then
      lib.notify(data)
    else
      exports.ox_lib:notify(data)
    end
  elseif notifType == 'mythic_notify' then
    exports.mythic_notify:SendAlert(notifyType, message, duration)
  elseif notifType == 'esx' then
    if ESX and ESX.ShowNotification then
      ESX.ShowNotification(message)
    else
      notifyGtaDefault(message)
    end
  elseif notifType == 'lation_ui' then
    local lCfg = cfg.LationUi or {}
    exports.lation_ui:notify({
      title = title,
      message = message,
      type = notifyType,
      duration = duration,
      position = lCfg.position or 'top-right',
    })
  elseif notifType == 'wasabi_notify' then
    exports.wasabi_notify:notify(title, message, duration, notifyType)
  elseif notifType == 'custom' then
    TriggerEvent(cfg.CustomClientEvent or 'bd_commerce:customNotify', {
      title = title,
      message = message,
      type = notifyType,
      duration = duration,
    })
  else
    notifyGtaDefault(message)
  end
end

--- Same style as g_bridge: NOTIFICATION(message, type, duration)
function NOTIFICATION(message, notifyType, duration)
  dispatchNotification(tostring(message or ''), notifyType, duration, getNotificationConfig().DefaultTitle)
end

--- Table payload: { type?, title?, message?, duration? }
function CommerceNotify(payload, notifyType, duration)
  if type(payload) == 'string' then
    NOTIFICATION(payload, notifyType, duration)
    return
  end
  if type(payload) ~= 'table' then return end

  local message, title = buildMessage(payload)
  if message == '' then return end

  dispatchNotification(
    message,
    payload.type,
    payload.duration,
    title
  )
end

RegisterNetEvent('bd_commerce:client:notify', function(payload)
  CommerceNotify(payload)
end)

RegisterNUICallback('notifyServer', function(data, cb)
  CommerceNotify(data or {})
  cb({ ok = true })
end)

exports('Notify', CommerceNotify)
exports('NOTIFICATION', NOTIFICATION)
exports('DetectNotificationSystem', DetectNotificationSystem)
