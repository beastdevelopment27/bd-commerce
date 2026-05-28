CommerceFramework = CommerceFramework or {}

local ESX = nil
local QBCore = nil
local activeFramework = nil

local function sanitizeString(value)
  if type(value) ~= 'string' then return '' end
  return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function getResources()
  return type(Config.FrameworkResources) == 'table' and Config.FrameworkResources or {}
end

local function isStarted(name)
  return type(name) == 'string' and name ~= '' and GetResourceState(name) == 'started'
end

local function normalizeFramework(value)
  value = type(value) == 'string' and value:lower() or 'auto'
  if value == 'qb' or value == 'qb-core' or value == 'qbcore' then return 'qbcore' end
  if value == 'qbx' or value == 'qbox' then return 'qbox' end
  if value == 'esx' or value == 'es_extended' then return 'esx' end
  return value
end

local function detectFramework()
  local forced = normalizeFramework(Config.Framework)
  if forced ~= 'auto' then
    return forced
  end

  local res = getResources()
  if isStarted(res.ESX or 'es_extended') then
    return 'esx'
  end
  if isStarted(res.QBox or 'qbx_core') or isStarted(res.QBoxAlt or 'qbox') then
    return 'qbox'
  end
  if isStarted(res.QBCore or 'qb-core') then
    return 'qbcore'
  end

  return 'esx'
end

CreateThread(function()
  local res = getResources()
  activeFramework = detectFramework()

  if activeFramework == 'esx' and isStarted(res.ESX or 'es_extended') then
    ESX = exports[res.ESX or 'es_extended']:getSharedObject()
  elseif activeFramework == 'qbcore' and isStarted(res.QBCore or 'qb-core') then
    QBCore = exports[res.QBCore or 'qb-core']:GetCoreObject()
  elseif activeFramework == 'qbox' then
    if isStarted(res.QBCore or 'qb-core') then
      QBCore = exports[res.QBCore or 'qb-core']:GetCoreObject()
    elseif isStarted(res.QBox or 'qbx_core') and exports[res.QBox or 'qbx_core'] and exports[res.QBox or 'qbx_core'].GetCoreObject then
      QBCore = exports[res.QBox or 'qbx_core']:GetCoreObject()
    end
  end

  print(('[bd_commerce] Framework: %s'):format(activeFramework or 'unknown'))
end)

function CommerceFramework.GetActive()
  if not activeFramework then
    activeFramework = detectFramework()
  end
  return activeFramework
end

function CommerceFramework.GetESX()
  return ESX
end

function CommerceFramework.GetQBCore()
  return QBCore
end

local function getQbPlayer(src)
  if not QBCore or not QBCore.Functions or not QBCore.Functions.GetPlayer then
    return nil
  end
  return QBCore.Functions.GetPlayer(src)
end

local function identifierFromSourceFallback(src)
  local identifiers = GetPlayerIdentifiers(src)
  for _, identifier in ipairs(identifiers) do
    if identifier:match('^char%d+:') then
      return identifier
    end
  end
  for _, identifier in ipairs(identifiers) do
    if identifier:match('^license:') then
      return identifier
    end
  end
  return identifiers[1] or ('src:%s'):format(src)
end

function CommerceFramework.GetOwnerIdentifier(src)
  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getIdentifier then
      local identifier = xPlayer.getIdentifier()
      if type(identifier) == 'string' and identifier ~= '' then
        return identifier
      end
    end
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if player and player.PlayerData then
      local license = player.PlayerData.license
      if type(license) == 'string' and license ~= '' then
        if not license:match('^license:') then
          return ('license:%s'):format(license)
        end
        return license
      end
      local citizenid = player.PlayerData.citizenid
      if type(citizenid) == 'string' and citizenid ~= '' then
        return citizenid
      end
    end
  end

  return identifierFromSourceFallback(src)
end

function CommerceFramework.GetCharacterIdentifierFromSource(src)
  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getIdentifier then
      local identifier = xPlayer.getIdentifier()
      if type(identifier) == 'string' and identifier:match('^char%d+:') then
        return identifier
      end
    end
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if player and player.PlayerData then
      local citizenid = player.PlayerData.citizenid
      if type(citizenid) == 'string' and citizenid ~= '' then
        return citizenid
      end
      local license = player.PlayerData.license
      if type(license) == 'string' and license ~= '' then
        if license:match('^license:') then
          return license
        end
        return ('license:%s'):format(license)
      end
    end
  end

  local identifiers = GetPlayerIdentifiers(src)
  for _, identifier in ipairs(identifiers) do
    if identifier:match('^char%d+:') then
      return identifier
    end
  end

  return nil
end

function CommerceFramework.GetPlayerDisplayName(src)
  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getName then
      local name = xPlayer.getName()
      if type(name) == 'string' and name ~= '' then
        return name
      end
    end
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if player and player.PlayerData and player.PlayerData.charinfo then
      local charinfo = player.PlayerData.charinfo
      local first = sanitizeString(tostring(charinfo.firstname or ''))
      local last = sanitizeString(tostring(charinfo.lastname or ''))
      local full = sanitizeString((first .. ' ' .. last))
      if full ~= '' then
        return full
      end
    end
  end

  return GetPlayerName(src) or ('ID %s'):format(src)
end

function CommerceFramework.GetPlayerJobKeys(src)
  local keys = {}
  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and type(xPlayer.job) == 'table' then
      local jobName = sanitizeString(tostring(xPlayer.job.name or '')):lower()
      local jobLabel = sanitizeString(tostring(xPlayer.job.label or '')):lower()
      if jobName ~= '' then keys[jobName] = true end
      if jobLabel ~= '' then keys[jobLabel] = true end
    end
    return keys
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if player and player.PlayerData and type(player.PlayerData.job) == 'table' then
      local job = player.PlayerData.job
      local jobName = sanitizeString(tostring(job.name or '')):lower()
      local jobLabel = sanitizeString(tostring(job.label or '')):lower()
      if jobName ~= '' then keys[jobName] = true end
      if jobLabel ~= '' then keys[jobLabel] = true end
    end
  end

  return keys
end

local function isConfiguredAdminGroup(groupName)
  local normalized = sanitizeString(tostring(groupName or '')):lower()
  if normalized == '' then
    return false
  end

  local groups = Config and Config.AdminGroups
  if type(groups) ~= 'table' then
    return normalized == 'admin' or normalized == 'superadmin'
  end

  for _, allowed in ipairs(groups) do
    if sanitizeString(tostring(allowed or '')):lower() == normalized then
      return true
    end
  end

  return false
end

function CommerceFramework.IsAdminSource(src)
  if not src or src == 0 then return true end
  if IsPlayerAceAllowed(src, 'bd_commerce.admin') or IsPlayerAceAllowed(src, 'command') then
    return true
  end

  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getGroup then
      if isConfiguredAdminGroup(xPlayer.getGroup()) then
        return true
      end
    end
  end

  if (framework == 'qbcore' or framework == 'qbox') and QBCore and QBCore.Functions then
    if QBCore.Functions.HasPermission and QBCore.Functions.HasPermission(src, 'admin') then
      return true
    end
    if QBCore.Functions.HasPermission and QBCore.Functions.HasPermission(src, 'god') then
      return true
    end
  end

  return false
end

function CommerceFramework.GetAvailableJobTargets()
  local jobs = {}
  local seen = {}
  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX and ESX.GetJobs then
    local esxJobs = ESX.GetJobs() or {}
    for jobName, jobData in pairs(esxJobs) do
      local normalizedName = sanitizeString(tostring(jobName or '')):lower()
      local label = ''
      if type(jobData) == 'table' then
        label = sanitizeString(tostring(jobData.label or ''))
      end
      if normalizedName ~= '' and not seen[normalizedName] then
        seen[normalizedName] = true
        jobs[#jobs + 1] = { value = normalizedName, label = label ~= '' and label or normalizedName }
      end
    end
  elseif (framework == 'qbcore' or framework == 'qbox') and QBCore and QBCore.Shared and QBCore.Shared.Jobs then
    for jobName, jobData in pairs(QBCore.Shared.Jobs) do
      local normalizedName = sanitizeString(tostring(jobName or '')):lower()
      local label = ''
      if type(jobData) == 'table' then
        label = sanitizeString(tostring(jobData.label or ''))
      end
      if normalizedName ~= '' and not seen[normalizedName] then
        seen[normalizedName] = true
        jobs[#jobs + 1] = { value = normalizedName, label = label ~= '' and label or normalizedName }
      end
    end
  end

  table.sort(jobs, function(a, b)
    return a.label:lower() < b.label:lower()
  end)

  return jobs
end

function CommerceFramework.GetAccountBalance(src, accountType)
  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return nil end
    if accountType == 'cash' and xPlayer.getMoney then
      return tonumber(xPlayer.getMoney()) or 0
    end
    if accountType == 'bank' and xPlayer.getAccount then
      local bankAccount = xPlayer.getAccount('bank')
      if type(bankAccount) == 'table' then
        return tonumber(bankAccount.money) or 0
      end
    end
    return nil
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if not player or not player.Functions or not player.Functions.GetMoney then
      return nil
    end
    if accountType == 'cash' then
      return tonumber(player.Functions.GetMoney('cash')) or 0
    end
    if accountType == 'bank' then
      return tonumber(player.Functions.GetMoney('bank')) or 0
    end
  end

  return nil
end

function CommerceFramework.RemovePlayerMoney(src, accountType, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return false end

  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    if accountType == 'cash' and xPlayer.removeMoney then
      xPlayer.removeMoney(amount)
      return true
    end
    if accountType == 'bank' and xPlayer.removeAccountMoney then
      xPlayer.removeAccountMoney('bank', amount)
      return true
    end
    return false
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if player and player.Functions and player.Functions.RemoveMoney then
      return player.Functions.RemoveMoney(accountType, amount, 'bd_commerce') == true
        or player.Functions.RemoveMoney(accountType, amount) == true
    end
  end

  return false
end

function CommerceFramework.AddPlayerMoney(src, accountType, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return false end

  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    if accountType == 'cash' and xPlayer.addMoney then
      xPlayer.addMoney(amount)
      return true
    end
    if accountType == 'bank' and xPlayer.addAccountMoney then
      xPlayer.addAccountMoney('bank', amount)
      return true
    end
    return false
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if player and player.Functions and player.Functions.AddMoney then
      return player.Functions.AddMoney(accountType, amount, 'bd_commerce') == true
        or player.Functions.AddMoney(accountType, amount) == true
    end
  end

  return false
end

function CommerceFramework.AddInventoryItem(src, itemName, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return false end

  if GetResourceState('ox_inventory') == 'started' and exports.ox_inventory and exports.ox_inventory.AddItem then
    return exports.ox_inventory:AddItem(src, itemName, amount) == true
  end

  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.addInventoryItem then
      xPlayer.addInventoryItem(itemName, amount)
      return true
    end
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if player and player.Functions and player.Functions.AddItem then
      return player.Functions.AddItem(itemName, amount) == true
    end
  end

  return false
end

function CommerceFramework.RemoveInventoryItem(src, itemName, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return false end

  if GetResourceState('ox_inventory') == 'started' and exports.ox_inventory and exports.ox_inventory.RemoveItem then
    return exports.ox_inventory:RemoveItem(src, itemName, amount) == true
  end

  local framework = CommerceFramework.GetActive()

  if framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.removeInventoryItem then
      xPlayer.removeInventoryItem(itemName, amount)
      return true
    end
  end

  if framework == 'qbcore' or framework == 'qbox' then
    local player = getQbPlayer(src)
    if player and player.Functions and player.Functions.RemoveItem then
      return player.Functions.RemoveItem(itemName, amount) == true
    end
  end

  return false
end

function CommerceFramework.GetEsxInventoryItems(src)
  if not ESX then return nil end
  local xPlayer = ESX.GetPlayerFromId(src)
  if xPlayer and xPlayer.getInventory then
    return xPlayer.getInventory()
  end
  return nil
end

function CommerceFramework.GetQbPlayer(src)
  return getQbPlayer(src)
end
