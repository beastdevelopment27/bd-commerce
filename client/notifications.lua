local ESX = nil
local QBCore = nil
local detectedProvider = nil
local detectionDone = false

CreateThread(function()
  if GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
  end
  if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
  end
end)

local function getCfg()
  return type(Config.Notifications) == 'table' and Config.Notifications or {}
end

local function isStarted(name)
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
  local cfg = getCfg()
  if type(payload) ~= 'table' then
    return tostring(payload or ''), cfg.DefaultTitle or 'Commerce'
  end
  local title = payload.title or payload.header or cfg.DefaultTitle or 'Commerce'
  local message = payload.message or payload.description or payload.text or ''
  title = type(title) == 'string' and title or 'Commerce'
  message = type(message) == 'string' and message or ''
  if message == '' and title ~= '' and title ~= (cfg.DefaultTitle or 'Commerce') then
    message = title
    title = cfg.DefaultTitle or 'Commerce'
  end
  return message, title
end

local function isEntryAvailable(entry)
  if type(entry) ~= 'table' then return false end
  local name = entry.name or ''
  if entry.fallback or name == 'gta-default' then return true end
  if name == 'esx' then
    return isStarted('es_extended') or isStarted('esx')
  end
  if name == 'qbox' then
    return isStarted('qbox') or isStarted('qbx_core')
  end
  if name == 'qbcore' then
    return isStarted('qb-core')
  end
  return isStarted(entry.resource)
end

function DetectNotificationSystem()
  local cfg = getCfg()
  local forced = type(cfg.Provider) == 'string' and cfg.Provider:lower() or 'auto'

  if forced ~= 'auto' and forced ~= '' then
    detectedProvider = forced
    detectionDone = true
    return detectedProvider
  end

  local list = cfg.Notifications
  if type(list) ~= 'table' then
    detectedProvider = 'gta-default'
    detectionDone = true
    return detectedProvider
  end

  local keys = {}
  for key in pairs(list) do
    keys[#keys + 1] = key
  end
  table.sort(keys)

  for _, key in ipairs(keys) do
    local entry = list[key]
    if isEntryAvailable(entry) and entry.name ~= 'gta-default' then
      detectedProvider = entry.name
      detectionDone = true
      return detectedProvider
    end
  end

  detectedProvider = 'gta-default'
  detectionDone = true
  return detectedProvider
end

local function getProvider()
  if not detectionDone then
    DetectNotificationSystem()
  end
  return detectedProvider or 'gta-default'
end

local function notifyGtaDefault(message)
  AddTextEntry('bd_commerce_notify', message)
  BeginTextCommandThefeedPost('bd_commerce_notify')
  EndTextCommandThefeedPostTicker(false, true)
end

local function dispatchNotification(message, notifyType, duration, title)
  local cfg = getCfg()
  notifyType = normalizeType(notifyType)
  duration = tonumber(duration) or cfg.DefaultDuration or 5000
  title = title or cfg.DefaultTitle or 'Commerce'

  local provider = getProvider()

  if provider == 'g-notifications' then
    local gCfg = cfg.GNotifications or {}
    exports['g-notifications']:Notify({
      title = title,
      description = message,
      type = notifyType,
      duration = duration,
      position = gCfg.position or 'top-right',
    })
  elseif provider == 'okokNotify' then
    exports.okokNotify:Alert(notifyType, message, duration, notifyType, false)
  elseif provider == 'qbox' then
    local qType = notifyType == 'info' and 'primary' or notifyType
    if isStarted('qbox') and exports.qbox and exports.qbox.Notify then
      exports.qbox:Notify(message, qType, duration)
    elseif isStarted('qbx_core') and exports.qbx_core then
      exports.qbx_core:Notify(message, qType, duration)
    end
  elseif provider == 'qb-notify' then
    exports['qb-notify']:Notify(message, notifyType, duration)
  elseif provider == 'qbcore' then
    local qType = notifyType == 'info' and 'primary' or notifyType
    if not QBCore and isStarted('qb-core') then
      QBCore = exports['qb-core']:GetCoreObject()
    end
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
      QBCore.Functions.Notify(message, qType, duration)
    end
  elseif provider == 'ox-lib' then
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
  elseif provider == 'mythic_notify' then
    exports.mythic_notify:SendAlert(notifyType, message, duration)
  elseif provider == 'esx' then
    if ESX and ESX.ShowNotification then
      ESX.ShowNotification(message)
    else
      notifyGtaDefault(message)
    end
  elseif provider == 'lation_ui' then
    local lCfg = cfg.LationUi or {}
    exports.lation_ui:notify({
      title = title,
      message = message,
      type = notifyType,
      duration = duration,
      position = lCfg.position or 'top-right',
    })
  elseif provider == 'wasabi_notify' then
    exports.wasabi_notify:notify(title, message, duration, notifyType)
  elseif provider == 'custom' then
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

function NOTIFICATION(message, notifyType, duration)
  dispatchNotification(tostring(message or ''), notifyType, duration, getCfg().DefaultTitle)
end

function CommerceNotify(payload, notifyType, duration)
  if type(payload) == 'string' then
    NOTIFICATION(payload, notifyType, duration)
    return
  end
  if type(payload) ~= 'table' then return end

  local message, title = buildMessage(payload)
  if message == '' then return end

  dispatchNotification(message, payload.type, payload.duration, title)
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
