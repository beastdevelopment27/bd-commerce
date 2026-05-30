CommerceSociety = CommerceSociety or {}

local BuiltInPresets = {
  ['qb-banking'] = {
    resource = 'qb-banking',
    deposit = function(job, amount, reason)
      return exports['qb-banking']:AddMoney(job, amount, reason or 'bd_commerce tax')
    end,
  },

  ['Renewed-Banking'] = {
    resource = 'Renewed-Banking',
    deposit = function(job, amount, reason)
      return exports['Renewed-Banking']:addAccountMoney(job, amount, reason)
    end,
  },

  ['okokBanking'] = {
    resource = 'okokBanking',
    deposit = function(job, amount)
      return exports['okokBanking']:AddMoney(job, amount)
    end,
  },

  ['esx_society'] = {
    resource = 'es_extended',
    deposit = function(job, amount)
      local societyAccount = ('society_%s'):format(job)
      TriggerEvent('esx_addonaccount:getSharedAccount', societyAccount, function(account)
        if account then
          account.addMoney(amount)
        end
      end)
      return true
    end,
  },

  ['tgg-banking'] = {
    resource = 'tgg-banking',
    deposit = function(job, amount)
      return exports['tgg-banking']:AddSocietyMoney(job, amount)
    end,
  },

  ['crm-banking'] = {
    resource = 'crm-banking',
    deposit = function(job, amount)
      return exports['crm-banking']:addSocietyMoney(job, amount)
    end,
  },

  ['fd_banking'] = {
    resource = 'fd_banking',
    deposit = function(job, amount)
      return exports['fd_banking']:AddMoney(job, amount)
    end,
  },

  ['p_banking'] = {
    resource = 'p_banking',
    deposit = function(job, amount)
      return exports['p_banking']:addAccountMoney(job, amount)
    end,
  },
}

local ActiveBank = nil
local ActiveBankName = nil

local function sanitizeString(value)
  if type(value) ~= 'string' then return '' end
  return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function getSocietyConfig()
  local cfg = type(Config) == 'table' and Config.CommerceTaxSociety or {}
  return {
    enabled = cfg.Enabled ~= false,
    jobName = sanitizeString(tostring(cfg.JobName or '')):lower(),
    reason = sanitizeString(tostring(cfg.DepositReason or 'bd_commerce marketplace tax')),
    bankingPreset = sanitizeString(tostring(cfg.BankingPreset or 'auto')):lower(),
    autoDetectOrder = type(cfg.AutoDetectOrder) == 'table' and cfg.AutoDetectOrder or {},
    customBanking = type(cfg.CustomBanking) == 'table' and cfg.CustomBanking or nil,
  }
end

local function isResourceStarted(name)
  return type(name) == 'string' and name ~= '' and GetResourceState(name) == 'started'
end

local function callCustomDeposit(job, amount, reason, custom)
  local resource = sanitizeString(tostring(custom.Resource or ''))
  local exportName = sanitizeString(tostring(custom.DepositExport or ''))
  if resource == '' or exportName == '' then
    return false
  end
  if not isResourceStarted(resource) then
    return false
  end

  local exportFn = exports[resource] and exports[resource][exportName]
  if type(exportFn) ~= 'function' then
    print(('[bd_commerce] Custom banking: export %s:%s not found'):format(resource, exportName))
    return false
  end

  local ok, result
  local argOrder = sanitizeString(tostring(custom.ArgOrder or 'job_amount'))
  local includeReason = custom.IncludeReason == true

  if argOrder == 'amount_job' then
    if includeReason then
      ok, result = pcall(exportFn, amount, job, reason)
    else
      ok, result = pcall(exportFn, amount, job)
    end
  else
    if includeReason then
      ok, result = pcall(exportFn, job, amount, reason)
    else
      ok, result = pcall(exportFn, job, amount)
    end
  end

  if not ok then
    print(('[bd_commerce] Custom banking error (%s:%s): %s'):format(resource, exportName, tostring(result)))
    return false
  end

  return result ~= false
end

local function buildCustomBankAdapter(custom)
  return {
    resource = sanitizeString(tostring(custom.Resource or '')),
    deposit = function(job, amount, reason)
      return callCustomDeposit(job, amount, reason, custom)
    end,
  }
end

local function presetIsAvailable(presetName)
  local preset = BuiltInPresets[presetName]
  if not preset then
    return false
  end
  return isResourceStarted(preset.resource)
end

local function detectBank()
  local cfg = getSocietyConfig()

  if cfg.bankingPreset == 'custom' and cfg.customBanking then
    if isResourceStarted(cfg.customBanking.Resource) then
      ActiveBank = buildCustomBankAdapter(cfg.customBanking)
      ActiveBankName = ('custom:%s'):format(sanitizeString(tostring(cfg.customBanking.Resource)))
      return ActiveBank, ActiveBankName
    end
    return nil, nil
  end

  if cfg.bankingPreset ~= '' and cfg.bankingPreset ~= 'auto' then
    local presetKey = cfg.bankingPreset
    for name in pairs(BuiltInPresets) do
      if name:lower() == presetKey then
        presetKey = name
        break
      end
    end
    local preset = BuiltInPresets[presetKey]
    if preset and presetIsAvailable(presetKey) then
      ActiveBank = preset
      ActiveBankName = presetKey
      return ActiveBank, ActiveBankName
    end
    print(('[bd_commerce] Banking preset "%s" not available (resource not started).'):format(presetKey))
    return nil, nil
  end

  if ActiveBank then
    return ActiveBank, ActiveBankName
  end

  local order = cfg.autoDetectOrder
  if #order == 0 then
    for presetName in pairs(BuiltInPresets) do
      order[#order + 1] = presetName
    end
  end

  for _, presetName in ipairs(order) do
    if type(presetName) == 'string' and presetIsAvailable(presetName) then
      ActiveBank = BuiltInPresets[presetName]
      ActiveBankName = presetName
      print(('[bd_commerce] Tax society banking (auto): %s'):format(presetName))
      return ActiveBank, ActiveBankName
    end
  end

  return nil, nil
end

local function depositSocietyMoney(societyName, amount, reason)
  if not societyName or societyName == '' or not amount or amount <= 0 then
    return false
  end

  local bank = detectBank()
  if not bank or not bank.deposit then
    return false
  end

  local ok, result = pcall(bank.deposit, societyName, amount, reason)
  if not ok then
    print(('[bd_commerce] Tax deposit error: %s'):format(tostring(result)))
    return false
  end

  return result ~= false
end

function CommerceSociety.IsEnabled()
  local cfg = getSocietyConfig()
  return cfg.enabled and cfg.jobName ~= ''
end

function CommerceSociety.GetJobName()
  return getSocietyConfig().jobName
end

function CommerceSociety.GetActiveBankingResource()
  local _, name = detectBank()
  return name
end

function CommerceSociety.DepositTax(amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then
    return false
  end

  local cfg = getSocietyConfig()
  if not cfg.enabled or cfg.jobName == '' then
    return false
  end

  local bank, bankName = detectBank()
  if not bank then
    print(('[bd_commerce] Tax deposit skipped: no banking configured/started ($%.2f -> %s)'):format(
      amount,
      cfg.jobName
    ))
    return false
  end

  local ok = depositSocietyMoney(cfg.jobName, amount, cfg.reason)
  if not ok then
    print(('[bd_commerce] Tax deposit failed: $%.2f -> society "%s" via %s'):format(
      amount,
      cfg.jobName,
      tostring(bankName)
    ))
    return false
  end

  return true
end

function CommerceSociety.SumTaxFromCredits(sellerCredits)
  local total = 0.0
  if type(sellerCredits) ~= 'table' then
    return 0.0
  end

  for _, credit in pairs(sellerCredits) do
    if type(credit) == 'table' then
      local gross = tonumber(credit.gross) or 0
      local net = tonumber(credit.net) or 0
      local tax = gross - net
      if tax > 0 then
        total = total + tax
      end
    end
  end

  return math.floor((total + 0.000001) * 100 + 0.5) / 100
end
