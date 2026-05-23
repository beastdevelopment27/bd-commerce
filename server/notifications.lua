local function getNotificationConfig()
  return type(Config) == 'table' and Config.Notifications or {}
end

local function buildMessage(payload)
  if type(payload) ~= 'table' then
    return tostring(payload or '')
  end
  local title = payload.title or payload.header or ''
  local message = payload.message or payload.description or payload.text or ''
  title = type(title) == 'string' and title or ''
  message = type(message) == 'string' and message or ''
  if title ~= '' and message ~= '' then
    return ('%s: %s'):format(title, message)
  end
  if title ~= '' then return title end
  return message
end

--- Send a notification to a player (relays to client provider from config).
---@param src number
---@param payload table|string { type?, title?, message?, duration? }
function CommerceNotify(src, payload)
  src = tonumber(src)
  if not src or src < 1 then return end

  if type(payload) == 'string' then
    payload = { message = payload, type = 'info' }
  end
  if type(payload) ~= 'table' then return end

  local cfg = getNotificationConfig()
  local provider = type(cfg.Provider) == 'string' and cfg.Provider:lower() or 'auto'

  if provider == 'custom' and type(cfg.CustomServerEvent) == 'string' and cfg.CustomServerEvent ~= '' then
    TriggerEvent(cfg.CustomServerEvent, src, payload)
    return
  end

  TriggerClientEvent('bd_commerce:client:notify', src, payload)
end

exports('Notify', CommerceNotify)
