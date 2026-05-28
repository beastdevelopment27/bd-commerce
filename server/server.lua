local sales = {}
local TABLE_NAME = 'bd_commerce_sales'
local SELLER_WALLET_TABLE = 'bd_commerce_seller_wallet'
local COUPON_TABLE = 'bd_commerce_coupons'
local PURCHASE_TABLE = 'bd_commerce_purchases'
local RATING_TABLE = 'bd_commerce_seller_ratings'
local RATING_STATS_TABLE = 'bd_commerce_seller_rating_stats'
local BIDS_TABLE = 'bd_commerce_bids'
local REPORT_TABLE = 'bd_commerce_reports'
local BLOCKED_SELLERS_TABLE = 'bd_commerce_blocked_sellers'
local CLAIMS_TABLE = 'bd_commerce_claims'
local CACHE = {
  dashboard = {},
  publicSales = {},
  mySales = {},
  inventory = {},
  playerSearch = {},
}
local CACHE_TTL_SECONDS = {
  dashboard = 7,
  publicSales = 5,
  mySales = 5,
  inventory = 10,
  playerSearch = 3,
}
local CACHE_LIMITS = {
  dashboard = 200,
  mySales = 200,
  inventory = 256,
  playerSearch = 200,
}
local CACHE_DEBUG = false
local CHARACTER_NAME_CACHE = {}
local DEBUG_QUERY_TIMINGS = false
local ADMIN_CACHE_TTL = 5
local ADMIN_SALES_LIMIT = 500
local ADMIN_SALES_CACHE = {
  data = nil,
  time = 0,
}
local REPORTS_CACHE_TTL = 3
local REPORTS_CACHE = {
  key = '',
  time = 0,
  data = nil,
}
local ACTIVE_ADMIN_REQUESTS = {}
local ACTIVE_SALE_CHECKOUT_LOCKS = {}
local NAME_CACHE_MAX_KEYS = 3000
local REPORT_LAST_SUBMIT_AT = {}

local function notifyPlayer(src, notifyType, title, message)
  if type(CommerceNotify) ~= 'function' then return end
  CommerceNotify(src, {
    type = notifyType,
    title = title,
    message = message,
  })
end

AddEventHandler('playerDropped', function()
  REPORT_LAST_SUBMIT_AT[source] = nil
end)

local function sanitizeString(value)
  if type(value) ~= 'string' then return '' end
  return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local DEFAULT_INVENTORY_IMAGE_PATH = 'ox_inventory/web/images'

local function getConfiguredInventoryImagePath()
  local path = Config and Config.InventoryImagePath
  if type(path) ~= 'string' or path == '' then
    return DEFAULT_INVENTORY_IMAGE_PATH
  end
  return path
end

local RESTRICTED_ITEM_LOOKUP = nil

local function getRestrictedItemLookup()
  if RESTRICTED_ITEM_LOOKUP then
    return RESTRICTED_ITEM_LOOKUP
  end

  RESTRICTED_ITEM_LOOKUP = {}
  local list = Config and Config.RestrictedItems
  if type(list) == 'table' then
    for _, itemName in ipairs(list) do
      if type(itemName) == 'string' then
        local normalized = itemName:gsub('^%s+', ''):gsub('%s+$', ''):lower()
        if normalized ~= '' then
          RESTRICTED_ITEM_LOOKUP[normalized] = true
        end
      end
    end
  end

  return RESTRICTED_ITEM_LOOKUP
end

local function isRestrictedInventoryItem(itemName)
  if type(itemName) ~= 'string' or itemName == '' then
    return false
  end
  return getRestrictedItemLookup()[itemName:lower()] == true
end

local function annotateInventoryRestrictions(items)
  if type(items) ~= 'table' then
    return items
  end

  for i = 1, #items do
    local item = items[i]
    if type(item) == 'table' then
      item.restricted = isRestrictedInventoryItem(item.name)
    end
  end

  return items
end

local function getConfiguredInventoryImageUrl(itemName)
  if type(itemName) ~= 'string' or itemName == '' then return '' end

  local path = getConfiguredInventoryImagePath()
  local resource = path:match('^([^/]+)') or 'ox_inventory'
  local subPath = path:match('^[^/]+/(.+)$') or 'web/images'
  local file = itemName
  if not file:match('%.%w+$') then
    file = file .. '.png'
  end

  if GetResourceState(resource) == 'started' then
    return ('https://cfx-nui-%s/%s/%s'):format(resource, subPath, file)
  end

  return ''
end

local function toInteger(value)
  local num = tonumber(value)
  if not num then return nil end
  return math.floor(num + 0.0)
end

local function toNumber(value)
  local num = tonumber(value)
  if not num then return nil end
  return num + 0.0
end

local function roundCurrency(value)
  return math.floor((value + 0.000001) * 100 + 0.5) / 100
end

local function tryAcquireSaleCheckoutLocks(lockIds, lockOwner)
  local acquired = {}
  for _, saleId in ipairs(lockIds) do
    if ACTIVE_SALE_CHECKOUT_LOCKS[saleId] and ACTIVE_SALE_CHECKOUT_LOCKS[saleId] ~= lockOwner then
      for _, acquiredId in ipairs(acquired) do
        if ACTIVE_SALE_CHECKOUT_LOCKS[acquiredId] == lockOwner then
          ACTIVE_SALE_CHECKOUT_LOCKS[acquiredId] = nil
        end
      end
      return false
    end
    ACTIVE_SALE_CHECKOUT_LOCKS[saleId] = lockOwner
    acquired[#acquired + 1] = saleId
  end
  return true
end

local function releaseSaleCheckoutLocks(lockIds, lockOwner)
  for _, saleId in ipairs(lockIds) do
    if ACTIVE_SALE_CHECKOUT_LOCKS[saleId] == lockOwner then
      ACTIVE_SALE_CHECKOUT_LOCKS[saleId] = nil
    end
  end
end

local function cacheLog(message)
  if CACHE_DEBUG then
    print(('[bd_commerce][cache] %s'):format(message))
  end
end

local function getUnixSeconds()
  return os.time()
end

local function toMysqlDateTime(unixSeconds)
  return os.date('!%Y-%m-%d %H:%M:%S', unixSeconds)
end

local function countTableKeys(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

local function pruneCacheBucket(bucketName)
  local bucket = CACHE[bucketName]
  local limit = CACHE_LIMITS[bucketName]
  if type(bucket) ~= 'table' or not limit then return end
  if countTableKeys(bucket) <= limit then return end
  CACHE[bucketName] = {}
  cacheLog(('PRUNE %s bucket (limit=%s)'):format(bucketName, limit))
end

local function getCacheEntry(bucketName, key, ttlSeconds)
  local bucket = CACHE[bucketName]
  if type(bucket) ~= 'table' then return nil end
  local entry = bucket[key]
  if not entry then return nil end
  if (getUnixSeconds() - (entry.time or 0)) >= ttlSeconds then
    bucket[key] = nil
    return nil
  end
  return entry.data
end

local function setCacheEntry(bucketName, key, value)
  local bucket = CACHE[bucketName]
  if type(bucket) ~= 'table' then return end
  bucket[key] = {
    data = value,
    time = getUnixSeconds(),
  }
  pruneCacheBucket(bucketName)
end

local function getPublicSalesBaseCache()
  return getCacheEntry('publicSales', 'base', CACHE_TTL_SECONDS.publicSales)
end

local function setPublicSalesBaseCache(rows)
  setCacheEntry('publicSales', 'base', rows)
end

local function getDashboardCache(ownerIdentifier)
  return getCacheEntry('dashboard', ownerIdentifier, CACHE_TTL_SECONDS.dashboard)
end

local function setDashboardCache(ownerIdentifier, payload)
  setCacheEntry('dashboard', ownerIdentifier, payload)
end

local function getMySalesCache(ownerIdentifier)
  return getCacheEntry('mySales', ownerIdentifier, CACHE_TTL_SECONDS.mySales)
end

local function setMySalesCache(ownerIdentifier, salesRows)
  setCacheEntry('mySales', ownerIdentifier, salesRows)
end

local function getInventoryCache(src)
  return getCacheEntry('inventory', tostring(src), CACHE_TTL_SECONDS.inventory)
end

local function setInventoryCache(src, items)
  setCacheEntry('inventory', tostring(src), items)
end

local function invalidateInventoryCache(src)
  if src then
    CACHE.inventory[tostring(src)] = nil
  end
end

local function getPlayerSearchCache(query)
  return getCacheEntry('playerSearch', query, CACHE_TTL_SECONDS.playerSearch)
end

local function setPlayerSearchCache(query, players)
  setCacheEntry('playerSearch', query, players)
end

local function invalidateReportsCache()
  REPORTS_CACHE.key = ''
  REPORTS_CACHE.time = 0
  REPORTS_CACHE.data = nil
end

local function invalidateListingCaches(src)
  CACHE.publicSales = {}
  cacheLog('INVALIDATE publicSales')
  ADMIN_SALES_CACHE.data = nil
  ADMIN_SALES_CACHE.time = 0
  invalidateReportsCache()
  if src then
    invalidateInventoryCache(src)
  end
end

local function invalidateCommerceCaches(ownerIdentifier, src, playerSearchQuery)
  CACHE.publicSales = {}
  cacheLog('INVALIDATE publicSales')

  if ownerIdentifier and ownerIdentifier ~= '' then
    CACHE.dashboard[ownerIdentifier] = nil
    CACHE.mySales[ownerIdentifier] = nil
    cacheLog(('INVALIDATE owner caches owner=%s'):format(ownerIdentifier))
  else
    CACHE.dashboard = {}
    CACHE.mySales = {}
    cacheLog('INVALIDATE all owner caches')
  end

  if src then
    invalidateInventoryCache(src)
  end

  if playerSearchQuery and playerSearchQuery ~= '' then
    CACHE.playerSearch[playerSearchQuery] = nil
  else
    CACHE.playerSearch = {}
  end

  ADMIN_SALES_CACHE.data = nil
  ADMIN_SALES_CACHE.time = 0
  invalidateReportsCache()
end

local function getCommerceTaxPercent()
  local tax = tonumber(Config and Config.CommerceTaxPercent) or 0
  if tax < 0 then tax = 0 end
  if tax > 100 then tax = 100 end
  return tax
end

local function queryTimerStart()
  if not DEBUG_QUERY_TIMINGS then return nil end
  return os.clock()
end

local function queryTimerEnd(startedAt, label)
  if not startedAt then return end
  local elapsedMs = (os.clock() - startedAt) * 1000
  print(('[bd_commerce][perf] %s took %.2f ms'):format(label, elapsedMs))
end

local function getOwnerIdentifier(src)
  return CommerceFramework.GetOwnerIdentifier(src)
end

local function getCharacterIdentifierFromSource(src)
  return CommerceFramework.GetCharacterIdentifierFromSource(src)
end

local function getPlayerDisplayName(src)
  return CommerceFramework.GetPlayerDisplayName(src)
end

local function getPlayerJobKeys(src)
  return CommerceFramework.GetPlayerJobKeys(src)
end

local function isAdminSource(src)
  return CommerceFramework.IsAdminSource(src)
end

local function isSellerBlocked(ownerIdentifier)
  local oid = sanitizeString(ownerIdentifier)
  if oid == '' then return false end
  local row = MySQL.single.await(
    ('SELECT seller_id FROM `%s` WHERE seller_id = ? LIMIT 1'):format(BLOCKED_SELLERS_TABLE),
    { oid }
  )
  return row ~= nil
end

local function getAvailableJobTargets()
  return CommerceFramework.GetAvailableJobTargets()
end

local function findPlayerByCharacterIdentifier(characterIdentifier)
  for _, playerSrc in ipairs(GetPlayers()) do
    local src = tonumber(playerSrc)
    if src and getCharacterIdentifierFromSource(src) == characterIdentifier then
      return src
    end
  end

  return nil
end

local function searchOnlinePlayers(query)
  local needle = sanitizeString(query):lower()
  local results = {}
  local numericQuery = tonumber(needle)

  for _, playerSrc in ipairs(GetPlayers()) do
    local src = tonumber(playerSrc)
    if src then
      local charIdentifier = getCharacterIdentifierFromSource(src)
      if charIdentifier then
        local displayName = getPlayerDisplayName(src)
        local lowerName = displayName:lower()
        local sourceStr = tostring(src)
        local matches = false

        if numericQuery then
          matches = sourceStr == needle
        elseif needle == '' then
          matches = true
        else
          matches = lowerName:find(needle, 1, true) ~= nil
        end

        if matches then
          results[#results + 1] = {
            serverId = src,
            name = displayName,
            identifier = charIdentifier,
          }
        end
      end
    end
  end

  return results
end

local function searchCharacterProfiles(query)
  local needle = sanitizeString(query)
  local likeQuery = ('%%%s%%'):format(needle)
  local rows = {}

  if needle == '' then
    rows = MySQL.query.await([[
      SELECT identifier, firstname, lastname
      FROM users
      WHERE identifier LIKE "char%:%"
      ORDER BY firstname ASC, lastname ASC
      LIMIT 200
    ]]) or {}
  else
    rows = MySQL.query.await([[
      SELECT identifier, firstname, lastname
      FROM users
      WHERE identifier LIKE "char%:%"
        AND (
          identifier LIKE ?
          OR firstname LIKE ?
          OR lastname LIKE ?
          OR CONCAT(COALESCE(firstname, ''), ' ', COALESCE(lastname, '')) LIKE ?
        )
      ORDER BY firstname ASC, lastname ASC
      LIMIT 200
    ]], { likeQuery, likeQuery, likeQuery, likeQuery }) or {}
  end

  local results = {}
  for _, row in ipairs(rows) do
    local identifier = tostring(row.identifier or '')
    if identifier ~= '' then
      local first = sanitizeString(row.firstname)
      local last = sanitizeString(row.lastname)
      local fullName = sanitizeString(('%s %s'):format(first, last))
      if fullName == '' then
        fullName = identifier
      end

      results[#results + 1] = {
        identifier = identifier,
        name = fullName,
      }
    end
  end

  return results
end

local function getCharacterDisplayNameByIdentifier(identifier)
  local normalized = sanitizeString(identifier)
  if normalized == '' then return '' end

  local onlineSrc = findPlayerByCharacterIdentifier(normalized)
  if onlineSrc then
    return getPlayerDisplayName(onlineSrc)
  end

  local cached = CHARACTER_NAME_CACHE[normalized]
  if type(cached) == 'string' and cached ~= '' then
    return cached
  end

  local queryStart = queryTimerStart()
  local row = MySQL.single.await(
    'SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1',
    { normalized }
  )
  queryTimerEnd(queryStart, 'resolveCharacterDisplayName')

  if row then
    local first = sanitizeString(row.firstname)
    local last = sanitizeString(row.lastname)
    local fullName = sanitizeString(('%s %s'):format(first, last))
    if fullName ~= '' then
      CHARACTER_NAME_CACHE[normalized] = fullName
      return fullName
    end
  end

  return normalized
end

local function countKeys(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

local function pruneCharacterNameCacheIfNeeded()
  if countKeys(CHARACTER_NAME_CACHE) <= NAME_CACHE_MAX_KEYS then return end
  CHARACTER_NAME_CACHE = {}
end

local function getOnlineCharacterNameMap()
  local onlineMap = {}
  for _, playerSrc in ipairs(GetPlayers()) do
    local src = tonumber(playerSrc)
    if src then
      local identifier = getCharacterIdentifierFromSource(src)
      if identifier and identifier ~= '' then
        onlineMap[identifier] = getPlayerDisplayName(src)
      end
    end
  end
  return onlineMap
end

local function buildPlaceholders(count)
  if count <= 0 then return '' end
  local placeholders = {}
  for i = 1, count do
    placeholders[i] = '?'
  end
  return table.concat(placeholders, ',')
end

local function buildIdentifierNameMap(identifierSet)
  local unresolvedIdentifiers = {}
  local onlineNames = getOnlineCharacterNameMap()
  local resolvedNames = {}

  for identifier in pairs(identifierSet) do
    local onlineName = onlineNames[identifier]
    if onlineName and onlineName ~= '' then
      resolvedNames[identifier] = onlineName
      CHARACTER_NAME_CACHE[identifier] = onlineName
    else
      local cached = CHARACTER_NAME_CACHE[identifier]
      if cached and cached ~= '' then
        resolvedNames[identifier] = cached
      else
        unresolvedIdentifiers[#unresolvedIdentifiers + 1] = identifier
      end
    end
  end

  if #unresolvedIdentifiers > 0 then
    local placeholders = buildPlaceholders(#unresolvedIdentifiers)
    if placeholders ~= '' then
      local queryStart = queryTimerStart()
      local profileRows = MySQL.query.await(
        ('SELECT identifier, firstname, lastname FROM users WHERE identifier IN (%s)'):format(placeholders),
        unresolvedIdentifiers
      ) or {}
      queryTimerEnd(queryStart, 'getAdminSalesNameBatch')

      for _, profile in ipairs(profileRows) do
        local identifier = tostring(profile.identifier or '')
        if identifier ~= '' then
          local fullName = sanitizeString(('%s %s'):format(
            sanitizeString(profile.firstname),
            sanitizeString(profile.lastname)
          ))
          if fullName == '' then
            fullName = identifier
          end
          resolvedNames[identifier] = fullName
          CHARACTER_NAME_CACHE[identifier] = fullName
        end
      end
    end
  end

  for _, identifier in ipairs(unresolvedIdentifiers) do
    if not resolvedNames[identifier] then
      resolvedNames[identifier] = identifier
      CHARACTER_NAME_CACHE[identifier] = identifier
    end
  end

  pruneCharacterNameCacheIfNeeded()
  return resolvedNames
end

local function buildIdentifierNameMapFromRows(rows)
  local identifierSet = {}
  for _, row in ipairs(rows) do
    local ownerIdentifier = tostring(row.owner_identifier or '')
    local playerTargetIdentifier = tostring(row.player_target or '')
    if ownerIdentifier ~= '' then identifierSet[ownerIdentifier] = true end
    if playerTargetIdentifier ~= '' then identifierSet[playerTargetIdentifier] = true end
  end
  return buildIdentifierNameMap(identifierSet)
end

local function getReportsCacheKey(statusFilter, reasonFilter, page, pageSize)
  return ('%s|%s|%d|%d'):format(statusFilter or '', reasonFilter or '', page, pageSize)
end

local function resolvePersonTargetInput(rawTarget)
  local target = sanitizeString(rawTarget)
  if target == '' then
    return nil, 'Player target is required for person sale type.'
  end

  if target:match('^char%d+:') then
    return target
  end

  local asServerId = tonumber(target)
  if asServerId then
    if not GetPlayerName(asServerId) then
      return nil, 'Player not found or not online.'
    end

    local charIdentifier = getCharacterIdentifierFromSource(asServerId)
    if not charIdentifier then
      return nil, 'Online player has no character identifier.'
    end

    return charIdentifier
  end

  local matches = searchOnlinePlayers(target)
  if #matches == 1 then
    return matches[1].identifier
  end
  if #matches > 1 then
    return nil, 'Multiple players matched. Please use a more specific name.'
  end

  return nil, 'Player not found or not online.'
end

local function getPlayerInventoryItems(src)
  local items = {}
  local lookup = {}
  local function addOrMergeItem(name, label, count, image)
    local existing = lookup[name]
    if existing then
      existing.count = existing.count + count
      return
    end

    local normalized = {
      name = tostring(name),
      label = tostring(label or name),
      count = count,
      image = tostring(image or ''),
    }
    items[#items + 1] = normalized
    lookup[normalized.name] = normalized
  end

  if GetResourceState('ox_inventory') == 'started' and exports.ox_inventory and exports.ox_inventory.GetInventoryItems then
    local oxItems = exports.ox_inventory:GetInventoryItems(src) or {}
    for _, item in pairs(oxItems) do
      local count = tonumber(item.count) or 0
      if count > 0 and item.name then
        local itemName = tostring(item.name)
        local image = getConfiguredInventoryImageUrl(itemName)
        addOrMergeItem(itemName, item.label or item.name, count, image)
      end
    end
    return items, lookup
  end

  local esxInventory = CommerceFramework.GetEsxInventoryItems(src)
  if esxInventory then
    for _, item in ipairs(esxInventory) do
      local count = tonumber(item.count) or 0
      if count > 0 and item.name then
        addOrMergeItem(item.name, item.label or item.name, count, getConfiguredInventoryImageUrl(item.name))
      end
    end
    return items, lookup
  end

  local qbPlayer = CommerceFramework.GetQbPlayer(src)
  if qbPlayer and qbPlayer.PlayerData and qbPlayer.PlayerData.items then
    for _, item in pairs(qbPlayer.PlayerData.items) do
      if item and item.name then
        local count = tonumber(item.amount or item.count) or 0
        if count > 0 then
          addOrMergeItem(item.name, item.label or item.name, count, getConfiguredInventoryImageUrl(item.name))
        end
      end
    end
    return items, lookup
  end

  return items, lookup
end

local function removeInventoryItem(src, itemName, amount)
  if amount <= 0 then return false end

  if GetResourceState('ox_inventory') == 'started' and exports.ox_inventory and exports.ox_inventory.RemoveItem then
    local success = exports.ox_inventory:RemoveItem(src, itemName, amount) == true
    if success then invalidateInventoryCache(src) end
    return success
  end

  local success = CommerceFramework.RemoveInventoryItem(src, itemName, amount)
  if success then invalidateInventoryCache(src) end
  return success
end

local function addInventoryItem(src, itemName, amount)
  if amount <= 0 then return false end

  if GetResourceState('ox_inventory') == 'started' and exports.ox_inventory and exports.ox_inventory.AddItem then
    local success = exports.ox_inventory:AddItem(src, itemName, amount) == true
    if success then invalidateInventoryCache(src) end
    return success
  end

  local success = CommerceFramework.AddInventoryItem(src, itemName, amount)
  if success then invalidateInventoryCache(src) end
  return success
end

local function getAccountBalance(src, accountType)
  return CommerceFramework.GetAccountBalance(src, accountType)
end

local function removePlayerMoney(src, accountType, amount)
  return CommerceFramework.RemovePlayerMoney(src, accountType, amount)
end

local function addPlayerMoney(src, accountType, amount)
  return CommerceFramework.AddPlayerMoney(src, accountType, amount)
end

local function getSellerWallet(ownerIdentifier)
  local wallet = MySQL.single.await(
    ('SELECT owner_identifier, balance, total_sales, total_revenue, total_withdrawn FROM `%s` WHERE owner_identifier = ? LIMIT 1'):format(SELLER_WALLET_TABLE),
    { ownerIdentifier }
  )

  if wallet then
    return {
      ownerIdentifier = tostring(wallet.owner_identifier),
      balance = roundCurrency(tonumber(wallet.balance) or 0),
      totalSales = tonumber(wallet.total_sales) or 0,
      totalRevenue = roundCurrency(tonumber(wallet.total_revenue) or 0),
      totalWithdrawn = roundCurrency(tonumber(wallet.total_withdrawn) or 0),
    }
  end

  return {
    ownerIdentifier = ownerIdentifier,
    balance = 0,
    totalSales = 0,
    totalRevenue = 0,
    totalWithdrawn = 0,
  }
end

local function creditSellerWallet(ownerIdentifier, grossAmount, netAmount)
  MySQL.query.await(
    ([[
      INSERT INTO `%s` (owner_identifier, balance, total_sales, total_revenue, total_withdrawn)
      VALUES (?, ?, 1, ?, 0.00)
      ON DUPLICATE KEY UPDATE
        balance = balance + VALUES(balance),
        total_sales = total_sales + 1,
        total_revenue = total_revenue + VALUES(total_revenue)
    ]]):format(SELLER_WALLET_TABLE),
    { ownerIdentifier, netAmount, grossAmount }
  )
  invalidateCommerceCaches(ownerIdentifier)
end

local function addSellerWalletBalance(ownerIdentifier, amount)
  MySQL.query.await(
    ([[
      INSERT INTO `%s` (owner_identifier, balance, total_sales, total_revenue, total_withdrawn)
      VALUES (?, ?, 0, 0.00, 0.00)
      ON DUPLICATE KEY UPDATE
        balance = balance + VALUES(balance)
    ]]):format(SELLER_WALLET_TABLE),
    { ownerIdentifier, amount }
  )
  invalidateCommerceCaches(ownerIdentifier)
end

local function debitSellerWallet(ownerIdentifier, amount)
  local affectedRows = MySQL.update.await(
    ('UPDATE `%s` SET balance = balance - ?, total_withdrawn = total_withdrawn + ? WHERE owner_identifier = ? AND balance >= ?'):format(SELLER_WALLET_TABLE),
    { amount, amount, ownerIdentifier, amount }
  )
  local success = affectedRows and affectedRows > 0
  if success then
    invalidateCommerceCaches(ownerIdentifier)
  end
  return success
end

local function parseSaleId(saleId)
  local normalized = sanitizeString(saleId)
  local numeric = normalized:match('^sale%-(%d+)$') or normalized:match('^(%d+)$')
  return tonumber(numeric)
end

local function parseClaimId(claimId)
  local normalized = sanitizeString(tostring(claimId or ''))
  local numeric = normalized:match('^claim%-(%d+)$') or normalized:match('^(%d+)$')
  return tonumber(numeric)
end

local CLAIM_TYPE_LABELS = {
  auction_win = 'Auction won',
  listing_removed = 'Listing removed',
  auction_expired = 'Auction ended (no bids)',
}

local function rowToClaim(row)
  local claimType = sanitizeString(tostring(row.claim_type or ''))
  return {
    id = ('claim-%s'):format(row.id),
    claimType = claimType,
    claimTypeLabel = CLAIM_TYPE_LABELS[claimType] or claimType,
    inventoryItem = tostring(row.inventory_item or ''),
    quantity = tonumber(row.quantity) or 0,
    productName = tostring(row.product_name or ''),
    saleId = row.sale_id and ('sale-%s'):format(row.sale_id) or nil,
    sourceNote = tostring(row.source_note or ''),
    createdAt = row.created_at and tostring(row.created_at) or nil,
  }
end

local function hasPendingClaim(recipientIdentifier, saleId, claimType)
  if recipientIdentifier == '' or not saleId or claimType == '' then
    return false
  end
  local existing = MySQL.scalar.await(
    ('SELECT id FROM `%s` WHERE recipient_identifier = ? AND sale_id = ? AND claim_type = ? AND claimed_at IS NULL LIMIT 1'):format(CLAIMS_TABLE),
    { recipientIdentifier, saleId, claimType }
  )
  return existing ~= nil
end

local function createPendingClaim(recipientIdentifier, claimType, inventoryItem, quantity, productName, saleId, sourceNote)
  recipientIdentifier = sanitizeString(tostring(recipientIdentifier or ''))
  claimType = sanitizeString(tostring(claimType or ''))
  inventoryItem = sanitizeString(tostring(inventoryItem or ''))
  productName = sanitizeString(tostring(productName or ''))
  sourceNote = sanitizeString(tostring(sourceNote or ''))
  quantity = math.floor(tonumber(quantity) or 0)
  saleId = tonumber(saleId)

  if recipientIdentifier == '' or claimType == '' or inventoryItem == '' or quantity < 1 then
    return false
  end

  if saleId and hasPendingClaim(recipientIdentifier, saleId, claimType) then
    return false
  end

  if saleId then
    local anyPendingForSale = MySQL.scalar.await(
      ('SELECT id FROM `%s` WHERE sale_id = ? AND recipient_identifier = ? AND claimed_at IS NULL LIMIT 1'):format(CLAIMS_TABLE),
      { saleId, recipientIdentifier }
    )
    if anyPendingForSale then
      return false
    end
  end

  MySQL.insert.await(
    ('INSERT INTO `%s` (recipient_identifier, claim_type, inventory_item, quantity, product_name, sale_id, source_note) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(CLAIMS_TABLE),
    { recipientIdentifier, claimType, inventoryItem, quantity, productName, saleId, sourceNote }
  )
  return true
end

local function queueSellerListingReturnClaim(saleRow, sourceNote)
  if type(saleRow) ~= 'table' then return false end
  local sellerIdentifier = tostring(saleRow.owner_identifier or '')
  local inventoryItem = tostring(saleRow.inventory_item or '')
  local quantity = tonumber(saleRow.quantity) or 0
  local productName = tostring(saleRow.product_name or '')
  local saleId = tonumber(saleRow.id)
  if sellerIdentifier == '' or inventoryItem == '' or quantity < 1 or not saleId then
    return false
  end
  return createPendingClaim(sellerIdentifier, 'listing_removed', inventoryItem, quantity, productName, saleId, sourceNote)
end

local function queueAuctionWinClaim(saleRow)
  if type(saleRow) ~= 'table' then return false end
  local winnerIdentifier = tostring(saleRow.highest_bidder or '')
  local inventoryItem = tostring(saleRow.inventory_item or '')
  local quantity = tonumber(saleRow.quantity) or 0
  local productName = tostring(saleRow.product_name or '')
  local saleId = tonumber(saleRow.id)
  if winnerIdentifier == '' or inventoryItem == '' or quantity < 1 or not saleId then
    return false
  end
  return createPendingClaim(winnerIdentifier, 'auction_win', inventoryItem, quantity, productName, saleId, 'Won auction')
end

local function queueExpiredAuctionSellerClaim(saleRow)
  if type(saleRow) ~= 'table' then return false end
  local sellerIdentifier = tostring(saleRow.owner_identifier or '')
  local inventoryItem = tostring(saleRow.inventory_item or '')
  local quantity = tonumber(saleRow.quantity) or 0
  local productName = tostring(saleRow.product_name or '')
  local saleId = tonumber(saleRow.id)
  if sellerIdentifier == '' or inventoryItem == '' or quantity < 1 or not saleId then
    return false
  end
  return createPendingClaim(sellerIdentifier, 'auction_expired', inventoryItem, quantity, productName, saleId, 'Auction expired with no winning bid')
end

local function buildSqlPlaceholders(count)
  if count <= 0 then
    return ''
  end
  return table.concat((function()
    local placeholders = {}
    for i = 1, count do
      placeholders[i] = '?'
    end
    return placeholders
  end)(), ',')
end

local function getCommerceCategorySet()
  local allowed = {}
  local categories = Config and Config.CommerceCategories
  if type(categories) == 'table' then
    for _, entry in ipairs(categories) do
      if type(entry) == 'table' then
        local id = sanitizeString(tostring(entry.id or '')):lower()
        if id ~= '' then
          allowed[id] = true
        end
      end
    end
  end
  if next(allowed) == nil then
    allowed['misc'] = true
  end
  return allowed
end

local function normalizeCommerceCategory(rawId)
  local id = sanitizeString(tostring(rawId or '')):lower()
  if id == '' then
    id = 'misc'
  end
  local allowed = getCommerceCategorySet()
  if allowed[id] then
    return id
  end
  return 'misc'
end

local function getSellerRatingStatsMap(identifiers)
  local map = {}
  if type(identifiers) ~= 'table' then
    return map
  end

  local unique = {}
  local seen = {}
  for _, rawId in ipairs(identifiers) do
    local id = sanitizeString(tostring(rawId or ''))
    if id ~= '' and not seen[id] then
      seen[id] = true
      unique[#unique + 1] = id
    end
  end

  if #unique == 0 then
    return map
  end

  local placeholders = buildSqlPlaceholders(#unique)
  local rows = MySQL.query.await(
    ('SELECT seller_identifier, avg_rating, rating_count FROM `%s` WHERE seller_identifier IN (%s)')
      :format(RATING_STATS_TABLE, placeholders),
    unique
  ) or {}

  for _, row in ipairs(rows) do
    local sid = sanitizeString(tostring(row.seller_identifier or ''))
    if sid ~= '' then
      map[sid] = {
        avg_rating = tonumber(row.avg_rating) or 0,
        rating_count = tonumber(row.rating_count) or 0,
      }
    end
  end

  return map
end

local function updateSellerRatingStats(sellerIdentifier, stars)
  local sid = sanitizeString(tostring(sellerIdentifier or ''))
  if sid == '' then
    return false
  end
  local s = math.min(5, math.max(1, math.floor(tonumber(stars) or 0)))
  if s < 1 then
    return false
  end

  local row = MySQL.single.await(
    ('SELECT total_stars, rating_count FROM `%s` WHERE seller_identifier = ? LIMIT 1'):format(RATING_STATS_TABLE),
    { sid }
  )
  local prevCount = row and tonumber(row.rating_count) or 0
  local prevSum = row and tonumber(row.total_stars) or 0
  local newCount = prevCount + 1
  local newSum = prevSum + s
  local newAvg = newCount > 0 and (newSum / newCount) or 0
  newAvg = math.floor((newAvg + 0.0001) * 100 + 0.5) / 100

  MySQL.update.await(
    ([[
      INSERT INTO `%s` (seller_identifier, total_stars, rating_count, avg_rating)
      VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        total_stars = ?,
        rating_count = ?,
        avg_rating = ?
    ]]):format(RATING_STATS_TABLE),
    { sid, newSum, newCount, newAvg, newSum, newCount, newAvg }
  )
  return true
end

local function rowToSale(row, sellerStatsMap)
  sellerStatsMap = type(sellerStatsMap) == 'table' and sellerStatsMap or {}
  local image = tostring(row.image or '')
  if GetResourceState('ox_inventory') == 'started' then
    if image == '' and tostring(row.inventory_item or '') ~= '' then
      image = ('%s.png'):format(tostring(row.inventory_item))
    end
  end

  local ownerId = tostring(row.owner_identifier or '')
  local stats = sellerStatsMap[ownerId]
  local ratingCount = stats and tonumber(stats.rating_count) or 0
  local avgRating = stats and tonumber(stats.avg_rating) or nil
  if not ratingCount or ratingCount < 1 then
    ratingCount = 0
    avgRating = nil
  end

  local category = normalizeCommerceCategory(row.category)
  local auctionEndsAtRaw = tostring(row.auction_end_time or '')
  local auctionStatusRaw = sanitizeString(tostring(row.auction_status or ''))

  return {
    id = ('sale-%s'):format(row.id),
    productName = tostring(row.product_name),
    description = tostring(row.description),
    inventoryItem = tostring(row.inventory_item),
    playerTarget = tostring(row.player_target or ''),
    jobTarget = tostring(row.job_target or ''),
    quantity = tostring(row.quantity),
    price = tostring(row.price),
    discount = tostring(row.discount),
    saleType = tostring(row.sale_type),
    category = category,
    image = image,
    owner = ownerId,
    createdAt = row.created_at,
    sellerRatingAvg = avgRating,
    sellerRatingCount = ratingCount,
    startingPrice = tostring(tonumber(row.starting_price) or 0),
    currentHighestBid = row.current_highest_bid ~= nil and tostring(tonumber(row.current_highest_bid) or 0) or '',
    highestBidder = tostring(row.highest_bidder or ''),
    auctionEndTime = auctionEndsAtRaw ~= '' and auctionEndsAtRaw or nil,
    bidIncrement = tostring(tonumber(row.bid_increment) or 1),
    auctionStatus = auctionStatusRaw ~= '' and auctionStatusRaw or nil,
  }
end

local function rowToAdminSale(row, sellerStatsMap)
  local mapped = rowToSale(row, sellerStatsMap)
  local ownerIdentifier = tostring(row.owner_identifier or '')
  local playerTargetIdentifier = tostring(row.player_target or '')

  mapped.ownerIdentifier = ownerIdentifier
  mapped.ownerName = getCharacterDisplayNameByIdentifier(ownerIdentifier)
  mapped.playerTargetIdentifier = playerTargetIdentifier
  mapped.playerTargetName = playerTargetIdentifier ~= '' and getCharacterDisplayNameByIdentifier(playerTargetIdentifier) or ''

  return mapped
end

local function canPlayerSeeSaleRow(row, ownerIdentifier, viewerJobKeys)
  local saleType = tostring(row.sale_type or '')
  if saleType == 'Public' then
    return true
  end

  if saleType == 'Person' then
    return tostring(row.player_target or '') == ownerIdentifier
  end

  if saleType == 'Job' then
    local targetJob = sanitizeString(tostring(row.job_target or '')):lower()
    return targetJob ~= '' and viewerJobKeys[targetJob] == true
  end

  if saleType == 'Auction' then
    local auctionStatus = sanitizeString(tostring(row.auction_status or '')):lower()
    return auctionStatus == '' or auctionStatus == 'open'
  end

  return false
end

local function getVisibleSalesForSource(src)
  local ownerIdentifier = getOwnerIdentifier(src)
  local viewerJobKeys = getPlayerJobKeys(src)
  local rows = getPublicSalesBaseCache()
  if not rows then
    rows = MySQL.query.await(
      ('SELECT * FROM `%s` WHERE sale_type = ? OR sale_type = ? OR sale_type = ? OR sale_type = ? ORDER BY created_at DESC, id DESC'):format(TABLE_NAME),
      { 'Public', 'Person', 'Job', 'Auction' }
    ) or {}
    setPublicSalesBaseCache(rows)
    cacheLog('MISS publicSales')
  else
    cacheLog('HIT publicSales')
  end

  local visibleRows = {}
  for _, row in ipairs(rows) do
    if canPlayerSeeSaleRow(row, ownerIdentifier, viewerJobKeys) then
      visibleRows[#visibleRows + 1] = row
    end
  end

  local ownerIds = {}
  for _, row in ipairs(visibleRows) do
    ownerIds[#ownerIds + 1] = tostring(row.owner_identifier or '')
  end
  local statsMap = getSellerRatingStatsMap(ownerIds)

  local visibleSales = {}
  for _, row in ipairs(visibleRows) do
    visibleSales[#visibleSales + 1] = rowToSale(row, statsMap)
  end

  return visibleSales
end

local function validateSalePayload(payload)
  if type(payload) ~= 'table' then
    return false, 'Invalid request payload.'
  end

  local productName = sanitizeString(payload.productName)
  local description = sanitizeString(payload.description)
  local inventoryItem = sanitizeString(payload.inventoryItem)
  local playerTarget = sanitizeString(payload.playerTarget)
  local jobTarget = sanitizeString(payload.jobTarget)
  local quantity = toInteger(payload.quantity)
  local price = toNumber(payload.price)
  local discount = toNumber(payload.discount) or 0
  local saleType = sanitizeString(payload.saleType)
  local startingPrice = toNumber(payload.startingPrice)
  local bidIncrement = toNumber(payload.bidIncrement) or 1
  local auctionDurationMinutes = toInteger(payload.auctionDurationMinutes)

  if productName == '' then return false, 'Product name is required.' end
  if description == '' then return false, 'Description is required.' end
  if inventoryItem == '' then return false, 'Inventory item is required.' end
  if isRestrictedInventoryItem(inventoryItem) then
    return false, 'This item cannot be listed on the marketplace.'
  end
  if not quantity or quantity < 1 then return false, 'Quantity must be at least 1.' end
  if saleType ~= 'Auction' and (not price or price < 0) then return false, 'Price must be 0 or greater.' end
  if discount < 0 or discount > 100 then return false, 'Discount must be between 0 and 100.' end
  if saleType ~= 'Public' and saleType ~= 'Person' and saleType ~= 'Job' and saleType ~= 'Auction' then
    return false, 'Invalid sale type.'
  end

  local category = normalizeCommerceCategory(payload.category)

  if saleType == 'Person' and playerTarget == '' then
    return false, 'Player target is required for person sale type.'
  end
  if saleType == 'Job' and jobTarget == '' then
    return false, 'Job target is required for job sale type.'
  end
  if saleType == 'Auction' then
    price = startingPrice
    if not startingPrice or startingPrice < 0 then
      return false, 'Starting price must be 0 or greater.'
    end
    if not bidIncrement or bidIncrement <= 0 then
      return false, 'Bid increment must be greater than 0.'
    end
    if not auctionDurationMinutes or auctionDurationMinutes < 1 then
      return false, 'Auction duration must be at least 1 minute.'
    end
    if auctionDurationMinutes > 10080 then
      return false, 'Auction duration cannot exceed 7 days.'
    end
  end

  return true, {
    productName = productName,
    description = description,
    inventoryItem = inventoryItem,
    playerTarget = playerTarget,
    jobTarget = jobTarget,
    quantity = tostring(quantity),
    price = tostring(price),
    discount = tostring(discount),
    saleType = saleType,
    category = category,
    startingPrice = tostring(startingPrice or 0),
    bidIncrement = tostring(bidIncrement),
    auctionDurationMinutes = tostring(auctionDurationMinutes or 0),
  }
end

local function validateCouponPayload(payload)
  if type(payload) ~= 'table' then
    return false, 'Invalid coupon payload.'
  end

  local code = sanitizeString(payload.code):upper()
  local discountType = sanitizeString(payload.discountType):lower()
  local discountValue = toNumber(payload.discountValue)
  local maxUses = toInteger(payload.maxUses)
  local expiresAt = sanitizeString(payload.expiresAt)
  local isActive = payload.isActive == false and 0 or 1

  if code == '' then
    return false, 'Coupon code is required.'
  end
  if #code > 32 then
    return false, 'Coupon code is too long (max 32).'
  end
  if not code:match('^[A-Z0-9_%-%+]+$') then
    return false, 'Coupon code can only include A-Z, 0-9, _, -, +.'
  end
  if discountType ~= 'percent' and discountType ~= 'fixed' then
    return false, 'Invalid discount type.'
  end
  if not discountValue or discountValue <= 0 then
    return false, 'Discount value must be greater than 0.'
  end
  if discountType == 'percent' and discountValue > 100 then
    return false, 'Percent discount cannot exceed 100.'
  end
  if maxUses and maxUses < 1 then
    return false, 'Max uses must be at least 1.'
  end

  local normalizedExpiresAt = nil
  if expiresAt ~= '' then
    if not expiresAt:match('^%d%d%d%d%-%d%d%-%d%d[T ]%d%d:%d%d') then
      return false, 'Invalid expiry datetime format.'
    end
    normalizedExpiresAt = expiresAt:gsub('T', ' ')
  end

  return true, {
    code = code,
    discountType = discountType,
    discountValue = roundCurrency(discountValue),
    maxUses = maxUses,
    expiresAt = normalizedExpiresAt,
    isActive = isActive,
  }
end

local function getValidCouponByCode(rawCode)
  local code = sanitizeString(rawCode):upper()
  if code == '' then
    return nil, 'Coupon code is required.'
  end

  local row = MySQL.single.await(
    ([[
      SELECT
        id,
        code,
        discount_type,
        discount_value,
        max_uses,
        used_count,
        is_active,
        expires_at,
        created_by,
        CASE
          WHEN expires_at IS NOT NULL AND expires_at <= NOW() THEN 1
          ELSE 0
        END AS is_expired
      FROM `%s`
      WHERE code = ?
      LIMIT 1
    ]]):format(COUPON_TABLE),
    { code }
  )

  if not row then
    return nil, 'Coupon code does not exist.'
  end

  if tonumber(row.is_active) ~= 1 then
    return nil, 'Coupon is inactive.'
  end

  local maxUses = tonumber(row.max_uses)
  local usedCount = tonumber(row.used_count) or 0
  if maxUses and usedCount >= maxUses then
    return nil, 'Coupon usage limit reached.'
  end

  if tonumber(row.is_expired) == 1 then
    return nil, 'Coupon has expired.'
  end

  local discountType = sanitizeString(tostring(row.discount_type or '')):lower()
  local discountValue = tonumber(row.discount_value) or 0
  if (discountType ~= 'percent' and discountType ~= 'fixed') or discountValue <= 0 then
    return nil, 'Coupon configuration is invalid.'
  end

  return {
    id = tonumber(row.id),
    code = tostring(row.code or code),
    discountType = discountType,
    discountValue = discountValue,
    createdBy = tostring(row.created_by or ''),
  }
end

local function schemaStopError(message)
  print(('^1[bd_commerce] %s^7'):format(message))
  StopResource(GetCurrentResourceName())
end

local function schemaTableExists(databaseName, tableName)
  local rows = MySQL.query.await([[
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = ?
      AND table_name = ?
    LIMIT 1
  ]], { databaseName, tableName }) or {}
  return #rows > 0
end

local function getSchemaColumns(databaseName, tableName)
  local rows = MySQL.query.await([[
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = ?
      AND table_name = ?
  ]], { databaseName, tableName }) or {}

  local columns = {}
  for _, row in ipairs(rows) do
    local columnName = tostring(row.COLUMN_NAME or row.column_name or '')
    if columnName ~= '' then
      columns[columnName] = true
    end
  end

  return columns
end

local function assertSchema()
  local databaseRow = MySQL.single.await('SELECT DATABASE() AS db') or {}
  local databaseName = tostring(databaseRow.db or '')
  if databaseName == '' then
    schemaStopError('Could not detect active database. Check oxmysql configuration.')
    return false
  end

  local requiredSchema = {
    [TABLE_NAME] = {
      'id',
      'owner_identifier',
      'product_name',
      'description',
      'inventory_item',
      'player_target',
      'job_target',
      'quantity',
      'price',
      'discount',
      'sale_type',
      'category',
      'image',
      'starting_price',
      'current_highest_bid',
      'highest_bidder',
      'auction_end_time',
      'bid_increment',
      'auction_status',
      'created_at',
    },
    [SELLER_WALLET_TABLE] = {
      'owner_identifier',
      'balance',
      'total_sales',
      'total_revenue',
      'total_withdrawn',
    },
    [COUPON_TABLE] = {
      'id',
      'code',
      'discount_type',
      'discount_value',
      'max_uses',
      'used_count',
      'is_active',
      'created_by',
      'expires_at',
      'created_at',
    },
    [PURCHASE_TABLE] = {
      'id',
      'buyer_identifier',
      'seller_identifier',
      'sale_id',
      'product_name',
      'quantity',
      'line_total',
      'created_at',
    },
    [RATING_TABLE] = {
      'id',
      'purchase_id',
      'buyer_identifier',
      'seller_identifier',
      'stars',
      'created_at',
    },
    [RATING_STATS_TABLE] = {
      'seller_identifier',
      'total_stars',
      'rating_count',
      'avg_rating',
    },
    [BIDS_TABLE] = {
      'id',
      'sale_id',
      'bidder_identifier',
      'bid_amount',
      'created_at',
    },
    [REPORT_TABLE] = {
      'id',
      'listing_id',
      'reporter_id',
      'seller_id',
      'reason',
      'description',
      'status',
      'created_at',
    },
    [BLOCKED_SELLERS_TABLE] = {
      'seller_id',
      'reason',
      'created_at',
    },
  }

  for tableName, columns in pairs(requiredSchema) do
    if not schemaTableExists(databaseName, tableName) then
      schemaStopError(('Missing required table `%s` in database `%s`. Create it manually before starting this resource.'):format(tableName, databaseName))
      return false
    end

    local existingColumns = getSchemaColumns(databaseName, tableName)
    for _, columnName in ipairs(columns) do
      if not existingColumns[columnName] then
        schemaStopError(('Missing required column `%s`.`%s` in database `%s`. Add it manually before starting this resource.'):format(tableName, columnName, databaseName))
        return false
      end
    end
  end

  return true
end

local function getLatestListings(ownerIdentifier, limit)
  local safeLimit = math.max(1, math.min(tonumber(limit) or 3, 20))
  local rows = MySQL.query.await(
    ('SELECT * FROM `%s` WHERE owner_identifier = ? ORDER BY created_at DESC, id DESC LIMIT %d'):format(TABLE_NAME, safeLimit),
    { ownerIdentifier }
  ) or {}

  local statsMap = getSellerRatingStatsMap({ ownerIdentifier })
  local listings = {}
  for _, row in ipairs(rows) do
    local mapped = rowToSale(row, statsMap)
    local price = tonumber(row.price) or 0
    local discount = math.min(math.max(tonumber(row.discount) or 0, 0), 100)
    local unitPrice = roundCurrency(price - ((price * discount) / 100))
    if unitPrice < 0 then unitPrice = 0 end
    mapped.unitPrice = unitPrice
    listings[#listings + 1] = mapped
  end

  return listings
end

CreateThread(function()
  assertSchema()
end)

RegisterNetEvent('bd_commerce:server:getInventoryItems', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getInventoryItemsResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      items = {},
    })
    return
  end

  local items = getInventoryCache(src)
  if not items then
    items = getPlayerInventoryItems(src)
    setInventoryCache(src, items)
    cacheLog(('MISS inventory src=%s'):format(src))
  else
    cacheLog(('HIT inventory src=%s'):format(src))
  end

  annotateInventoryRestrictions(items)

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Inventory loaded successfully.',
    items = items,
  })
end)

RegisterNetEvent('bd_commerce:server:searchPlayerTargets', function(requestId, query)
  local src = source
  local responseEvent = 'bd_commerce:client:searchPlayerTargetsResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      players = {},
    })
    return
  end

  local normalizedQuery = sanitizeString(query)
  local cachedPlayers = getPlayerSearchCache(normalizedQuery)
  if cachedPlayers then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = true,
      message = 'Player list loaded.',
      players = cachedPlayers,
    })
    cacheLog(('HIT playerSearch query=%s'):format(normalizedQuery))
    return
  end

  local players = searchOnlinePlayers(normalizedQuery)
  local byIdentifier = {}
  for _, player in ipairs(players) do
    byIdentifier[player.identifier] = player
  end

  local characterProfiles = searchCharacterProfiles(normalizedQuery)
  for _, profile in ipairs(characterProfiles) do
    if not byIdentifier[profile.identifier] then
      players[#players + 1] = {
        serverId = 0,
        name = profile.name,
        identifier = profile.identifier,
      }
    end
  end

  setPlayerSearchCache(normalizedQuery, players)
  cacheLog(('MISS playerSearch query=%s'):format(normalizedQuery))

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Player list loaded.',
    players = players,
  })
end)

RegisterNetEvent('bd_commerce:server:getJobTargets', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getJobTargetsResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      jobs = {},
    })
    return
  end

  local jobs = getAvailableJobTargets()
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Job list loaded.',
    jobs = jobs,
  })
end)

RegisterNetEvent('bd_commerce:server:checkPlayerTargetStatus', function(requestId, query)
  local src = source
  local responseEvent = 'bd_commerce:client:checkPlayerTargetStatusResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      status = 'unknown',
    })
    return
  end

  local normalizedQuery = sanitizeString(query)
  if normalizedQuery == '' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = true,
      message = 'No target specified.',
      status = 'unknown',
    })
    return
  end

  if normalizedQuery:match('^char%d+:') then
    local targetSrc = findPlayerByCharacterIdentifier(normalizedQuery)
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = true,
      message = targetSrc and 'Player is online.' or 'Player is offline.',
      status = targetSrc and 'online' or 'offline',
    })
    return
  end

  local queryAsId = tonumber(normalizedQuery)
  if queryAsId then
    local isOnline = GetPlayerName(queryAsId) ~= nil
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = true,
      message = isOnline and 'Player is online.' or 'Player is offline.',
      status = isOnline and 'online' or 'offline',
    })
    return
  end

  local matches = searchOnlinePlayers(normalizedQuery)
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = #matches > 0 and 'Player is online.' or 'Player is offline.',
    status = #matches > 0 and 'online' or 'offline',
  })
end)

RegisterNetEvent('bd_commerce:server:getMySales', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getMySalesResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      sales = {},
    })
    return
  end

  local ownerIdentifier = getOwnerIdentifier(src)
  local rows = getMySalesCache(ownerIdentifier)
  if not rows then
    rows = MySQL.query.await(
      ('SELECT * FROM `%s` WHERE owner_identifier = ? ORDER BY created_at DESC, id DESC'):format(TABLE_NAME),
      { ownerIdentifier }
    ) or {}
    setMySalesCache(ownerIdentifier, rows)
    cacheLog(('MISS mySales owner=%s'):format(ownerIdentifier))
  else
    cacheLog(('HIT mySales owner=%s'):format(ownerIdentifier))
  end

  local statsMap = getSellerRatingStatsMap({ ownerIdentifier })
  local mySales = {}
  for _, row in ipairs(rows) do
    mySales[#mySales + 1] = rowToSale(row, statsMap)
  end

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Sales loaded successfully.',
    sales = mySales,
  })
end)

RegisterNetEvent('bd_commerce:server:getDashboardOverview', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getDashboardOverviewResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      latestListings = {},
      monthlyRevenue = {},
      performance = {},
      kpi = {
        totalListings = 0,
        totalUnits = 0,
        totalValue = 0,
        discountedListings = 0,
      },
    })
    return
  end

  local ownerIdentifier = getOwnerIdentifier(src)
  local cachedPayload = getDashboardCache(ownerIdentifier)
  if cachedPayload then
    TriggerClientEvent(responseEvent, src, requestId, cachedPayload)
    cacheLog(('HIT dashboard owner=%s'):format(ownerIdentifier))
    return
  end

  local kpiRow = MySQL.single.await(([[
    SELECT
      COUNT(*) AS total_listings,
      COALESCE(SUM(quantity), 0) AS total_units,
      COALESCE(SUM(quantity * (price - ((price * discount) / 100))), 0) AS total_value,
      COALESCE(SUM(CASE WHEN discount > 0 THEN 1 ELSE 0 END), 0) AS discounted_listings,
      COALESCE(SUM(CASE WHEN sale_type = 'Public' THEN 1 ELSE 0 END), 0) AS public_count,
      COALESCE(SUM(CASE WHEN sale_type = 'Person' THEN 1 ELSE 0 END), 0) AS person_count,
      COALESCE(SUM(CASE WHEN sale_type = 'Job' THEN 1 ELSE 0 END), 0) AS job_count
    FROM `%s`
    WHERE owner_identifier = ?
  ]]):format(TABLE_NAME), { ownerIdentifier }) or {}

  local monthlyRows = MySQL.query.await(([[
    SELECT
      MONTH(created_at) AS month_idx,
      COALESCE(SUM(quantity * (price - ((price * discount) / 100))), 0) AS revenue
    FROM `%s`
    WHERE owner_identifier = ?
      AND YEAR(created_at) = YEAR(CURDATE())
    GROUP BY MONTH(created_at)
  ]]):format(TABLE_NAME), { ownerIdentifier }) or {}

  local monthlyRevenue = {}
  for monthIndex = 1, 12 do
    monthlyRevenue[monthIndex] = 0
  end
  for _, row in ipairs(monthlyRows) do
    local monthIndex = tonumber(row.month_idx)
    if monthIndex and monthIndex >= 1 and monthIndex <= 12 then
      monthlyRevenue[monthIndex] = roundCurrency(tonumber(row.revenue) or 0)
    end
  end

  local performance = {
    { label = 'Public', value = tonumber(kpiRow.public_count) or 0 },
    { label = 'Person', value = tonumber(kpiRow.person_count) or 0 },
    { label = 'Job', value = tonumber(kpiRow.job_count) or 0 },
  }

  local latestListings = getLatestListings(ownerIdentifier, 3)

  local payload = {
    ok = true,
    message = 'Dashboard overview loaded successfully.',
    wallet = getSellerWallet(ownerIdentifier),
    taxPercent = getCommerceTaxPercent(),
    kpi = {
      totalListings = tonumber(kpiRow.total_listings) or 0,
      totalUnits = tonumber(kpiRow.total_units) or 0,
      totalValue = roundCurrency(tonumber(kpiRow.total_value) or 0),
      discountedListings = tonumber(kpiRow.discounted_listings) or 0,
    },
    monthlyRevenue = monthlyRevenue,
    performance = performance,
    latestListings = latestListings,
  }

  setDashboardCache(ownerIdentifier, payload)
  cacheLog(('MISS dashboard owner=%s'):format(ownerIdentifier))
  TriggerClientEvent(responseEvent, src, requestId, payload)
end)

RegisterNetEvent('bd_commerce:server:getPublicSales', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getPublicSalesResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      sales = {},
    })
    return
  end

  local publicSales = getVisibleSalesForSource(src)

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Visible sales loaded successfully.',
    sales = publicSales,
  })
end)

RegisterNetEvent('bd_commerce:server:checkoutCart', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:checkoutCartResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      sales = {},
    })
    return
  end

  if type(payload) ~= 'table' or type(payload.items) ~= 'table' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid checkout payload.',
      sales = {},
    })
    return
  end

  local paymentMethod = sanitizeString(tostring(payload.paymentMethod or '')):lower()
  if paymentMethod ~= 'cash' and paymentMethod ~= 'bank' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Please choose cash or bank for checkout.',
      sales = getVisibleSalesForSource(src),
    })
    return
  end

  local requestedItems = {}
  local requestedBySaleId = {}
  local requestedSaleIds = {}
  local checkoutLockOwner = ('%s:%s'):format(src, requestId)
  local acquiredCheckoutLocks = false
  local ownerIdentifier = getOwnerIdentifier(src)
  local viewerJobKeys = getPlayerJobKeys(src)
  local totalCost = 0.0
  local couponDiscount = 0.0
  local couponCode = sanitizeString(tostring(payload.couponCode or '')):upper()
  local appliedCoupon = nil
  local taxPercent = getCommerceTaxPercent()

  local function releaseCheckoutLocks()
    if not acquiredCheckoutLocks then return end
    releaseSaleCheckoutLocks(requestedSaleIds, checkoutLockOwner)
    acquiredCheckoutLocks = false
  end

  for _, entry in ipairs(payload.items) do
    if type(entry) == 'table' then
      local dbSaleId = parseSaleId(entry.id or '')
      local quantity = toInteger(entry.quantity)
      if dbSaleId and quantity and quantity > 0 then
        if requestedBySaleId[dbSaleId] then
          requestedBySaleId[dbSaleId] = requestedBySaleId[dbSaleId] + quantity
        else
          requestedBySaleId[dbSaleId] = quantity
          requestedSaleIds[#requestedSaleIds + 1] = dbSaleId
        end
      end
    end
  end

  if #requestedSaleIds == 0 then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Your cart is empty.',
      sales = getVisibleSalesForSource(src),
    })
    return
  end

  table.sort(requestedSaleIds, function(a, b)
    return a < b
  end)
  acquiredCheckoutLocks = tryAcquireSaleCheckoutLocks(requestedSaleIds, checkoutLockOwner)
  if not acquiredCheckoutLocks then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'One or more selected listings are busy. Please retry.',
      sales = getVisibleSalesForSource(src),
    })
    return
  end

  local placeholders = buildSqlPlaceholders(#requestedSaleIds)
  local rows = MySQL.query.await(
    ('SELECT * FROM `%s` WHERE id IN (%s)'):format(TABLE_NAME, placeholders),
    requestedSaleIds
  ) or {}

  local rowsById = {}
  for _, row in ipairs(rows) do
    rowsById[tonumber(row.id)] = row
  end

  for _, dbSaleId in ipairs(requestedSaleIds) do
    local quantity = requestedBySaleId[dbSaleId] or 0
    local row = rowsById[dbSaleId]

    if not row then
      releaseCheckoutLocks()
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'One or more listings are no longer available.',
        sales = getVisibleSalesForSource(src),
      })
      return
    end

    if not canPlayerSeeSaleRow(row, ownerIdentifier, viewerJobKeys) then
      releaseCheckoutLocks()
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'You cannot buy one or more selected listings.',
        sales = getVisibleSalesForSource(src),
      })
      return
    end
    if tostring(row.sale_type or '') == 'Auction' then
      releaseCheckoutLocks()
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Auction listings must be purchased via bids.',
        sales = getVisibleSalesForSource(src),
      })
      return
    end

    local availableQuantity = tonumber(row.quantity) or 0
    if availableQuantity < quantity then
      releaseCheckoutLocks()
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'One or more listings do not have enough stock.',
        sales = getVisibleSalesForSource(src),
      })
      return
    end

    local basePrice = tonumber(row.price) or 0
    local discount = math.min(math.max(tonumber(row.discount) or 0, 0), 100)
    local unitPrice = basePrice - ((basePrice * discount) / 100)
    if unitPrice < 0 then unitPrice = 0 end
    local grossAmount = roundCurrency(unitPrice * quantity)
    totalCost = totalCost + grossAmount
    local netAmount = roundCurrency(grossAmount * ((100 - taxPercent) / 100))

    requestedItems[#requestedItems + 1] = {
      dbSaleId = dbSaleId,
      quantity = quantity,
      inventoryItemName = tostring(row.inventory_item or ''),
      sellerIdentifier = tostring(row.owner_identifier or ''),
      productName = tostring(row.product_name or ''),
      grossAmount = grossAmount,
      netAmount = netAmount,
    }
  end

  totalCost = math.floor((totalCost * 100) + 0.5) / 100
  if couponCode ~= '' then
    local couponTargetSeller = nil
    for _, requestItem in ipairs(requestedItems) do
      local sellerIdentifier = tostring(requestItem.sellerIdentifier or '')
      if sellerIdentifier == '' then
        releaseCheckoutLocks()
        TriggerClientEvent(responseEvent, src, requestId, {
          ok = false,
          message = 'Invalid listing owner.',
          sales = getVisibleSalesForSource(src),
        })
        return
      end

      if couponTargetSeller == nil then
        couponTargetSeller = sellerIdentifier
      elseif couponTargetSeller ~= sellerIdentifier then
        releaseCheckoutLocks()
        TriggerClientEvent(responseEvent, src, requestId, {
          ok = false,
          message = 'Coupon can only be used when all cart items are from one seller.',
          sales = getVisibleSalesForSource(src),
        })
        return
      end
    end

    local coupon, couponError = getValidCouponByCode(couponCode)
    if not coupon then
      releaseCheckoutLocks()
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = couponError or 'Coupon not available.',
        sales = getVisibleSalesForSource(src),
      })
      return
    end

    if coupon.createdBy == '' or coupon.createdBy ~= couponTargetSeller then
      releaseCheckoutLocks()
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Coupon not available for selected products.',
        sales = getVisibleSalesForSource(src),
      })
      return
    end

    appliedCoupon = coupon
    if coupon.discountType == 'percent' then
      couponDiscount = roundCurrency(totalCost * (coupon.discountValue / 100))
    else
      couponDiscount = roundCurrency(coupon.discountValue)
    end
    if couponDiscount > totalCost then
      couponDiscount = totalCost
    end
    totalCost = roundCurrency(math.max(totalCost - couponDiscount, 0))
  end

  local balance = getAccountBalance(src, paymentMethod)
  if balance == nil then
    releaseCheckoutLocks()
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not read your account balance.',
      sales = getVisibleSalesForSource(src),
    })
    return
  end

  if balance < totalCost then
    releaseCheckoutLocks()
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = ('Not enough %s balance. Need $%.2f.'):format(paymentMethod, totalCost),
      sales = getVisibleSalesForSource(src),
    })
    return
  end

  if totalCost > 0 and not removePlayerMoney(src, paymentMethod, totalCost) then
    releaseCheckoutLocks()
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = ('Could not deduct money from %s.'):format(paymentMethod),
      sales = getVisibleSalesForSource(src),
    })
    return
  end

  local grantedItems = {}
  local sellerCredits = {}
  local processedItems = {}
  local txError = nil

  local function isLockContentionError(err)
    if type(err) ~= 'string' then return false end
    local lowered = err:lower()
    return lowered:find('lock wait timeout', 1, true) ~= nil
      or lowered:find('deadlock', 1, true) ~= nil
  end

  local function safeQueryAwait(query, params)
    local ok, result = pcall(MySQL.query.await, query, params)
    if not ok then
      return nil, tostring(result)
    end
    return result, nil
  end

  local function safeUpdateAwait(query, params)
    local ok, result = pcall(MySQL.update.await, query, params)
    if not ok then
      return nil, tostring(result)
    end
    return result, nil
  end

  local function rollbackProcessedItems()
    for _, processed in ipairs(processedItems) do
      safeUpdateAwait(
        ('UPDATE `%s` SET quantity = quantity + ? WHERE id = ?'):format(TABLE_NAME),
        { processed.quantity, processed.dbSaleId }
      )
      if processed.inventoryItemName ~= '' then
        removeInventoryItem(src, processed.inventoryItemName, processed.quantity)
      end
    end
  end

  local _, txStartError = safeQueryAwait('START TRANSACTION')
  if txStartError then
    if totalCost > 0 then addPlayerMoney(src, paymentMethod, totalCost) end
    releaseCheckoutLocks()
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not start checkout transaction. Please try again.',
      sales = getVisibleSalesForSource(src),
    })
    return
  end
  local committed = false
  local txFailed = false
  local txFailureMessage = 'Could not reserve one or more listings. Please try again.'
  local MAX_STOCK_UPDATE_RETRIES = 2

  for _, requestItem in ipairs(requestedItems) do
    local updatedRows, updateError = nil, nil
    for attempt = 1, (MAX_STOCK_UPDATE_RETRIES + 1) do
      updatedRows, updateError = safeUpdateAwait(
        ('UPDATE `%s` SET quantity = quantity - ? WHERE id = ? AND quantity >= ?'):format(TABLE_NAME),
        { requestItem.quantity, requestItem.dbSaleId, requestItem.quantity }
      )

      if not updateError then
        break
      end

      if not isLockContentionError(updateError) then
        break
      end

      if attempt <= MAX_STOCK_UPDATE_RETRIES then
        Wait(75 * attempt)
      end
    end

    if updateError then
      txFailed = true
      txError = updateError
      if isLockContentionError(updateError) then
        txFailureMessage = 'Listing is currently busy. Please retry checkout.'
      else
        txFailureMessage = 'Database error during checkout. Please try again.'
      end
      break
    end
    if not updatedRows or updatedRows < 1 then
      txFailed = true
      break
    end

    if requestItem.inventoryItemName == '' or not addInventoryItem(src, requestItem.inventoryItemName, requestItem.quantity) then
      txFailed = true
      txFailureMessage = 'Could not add one or more purchased items to your inventory.'
      break
    end

    grantedItems[#grantedItems + 1] = {
      item = requestItem.inventoryItemName,
      amount = requestItem.quantity,
    }
    processedItems[#processedItems + 1] = requestItem

    if requestItem.sellerIdentifier ~= '' and requestItem.netAmount > 0 then
      local existing = sellerCredits[requestItem.sellerIdentifier] or { gross = 0, net = 0 }
      existing.gross = roundCurrency(existing.gross + requestItem.grossAmount)
      existing.net = roundCurrency(existing.net + requestItem.netAmount)
      sellerCredits[requestItem.sellerIdentifier] = existing
    end
  end

  if txFailed then
    safeQueryAwait('ROLLBACK')
    rollbackProcessedItems()
    if totalCost > 0 then addPlayerMoney(src, paymentMethod, totalCost) end
    releaseCheckoutLocks()
    if txError then
      print(('[bd_commerce] checkout transaction failed: %s'):format(txError))
    end
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = txFailureMessage,
      sales = getVisibleSalesForSource(src),
    })
    return
  end

  local _, commitError = safeQueryAwait('COMMIT')
  if commitError then
    safeQueryAwait('ROLLBACK')
    rollbackProcessedItems()
    if totalCost > 0 then addPlayerMoney(src, paymentMethod, totalCost) end
    releaseCheckoutLocks()
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Checkout failed to commit. Please try again.',
      sales = getVisibleSalesForSource(src),
    })
    return
  end
  committed = true
  if not committed then
    rollbackProcessedItems()
    if totalCost > 0 then addPlayerMoney(src, paymentMethod, totalCost) end
    releaseCheckoutLocks()
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Checkout failed to commit. Please try again.',
      sales = getVisibleSalesForSource(src),
    })
    return
  end

  local pendingRatingsPayload = {}
  for _, requestItem in ipairs(requestedItems) do
    local sellerId = tostring(requestItem.sellerIdentifier or '')
    if sellerId ~= '' and requestItem.dbSaleId then
      local purchaseId = MySQL.insert.await(
        ('INSERT INTO `%s` (buyer_identifier, seller_identifier, sale_id, product_name, quantity, line_total) VALUES (?, ?, ?, ?, ?, ?)'):format(
          PURCHASE_TABLE
        ),
        {
          ownerIdentifier,
          sellerId,
          requestItem.dbSaleId,
          requestItem.productName ~= '' and requestItem.productName or ('Sale #%s'):format(requestItem.dbSaleId),
          requestItem.quantity,
          roundCurrency(requestItem.grossAmount or 0),
        }
      )
      if purchaseId then
        local displayName = getCharacterDisplayNameByIdentifier(sellerId)
        pendingRatingsPayload[#pendingRatingsPayload + 1] = {
          purchaseId = tonumber(purchaseId) or purchaseId,
          sellerIdentifier = sellerId,
          sellerName = displayName ~= '' and displayName or sellerId,
          productName = requestItem.productName ~= '' and requestItem.productName or ('Item #%s'):format(requestItem.dbSaleId),
        }
      end
    end
  end

  for sellerIdentifier, credit in pairs(sellerCredits) do
    creditSellerWallet(sellerIdentifier, credit.gross, credit.net)
  end

  if appliedCoupon and appliedCoupon.code and appliedCoupon.createdBy and appliedCoupon.createdBy ~= '' then
    local couponRows = MySQL.update.await(
      ([[
        UPDATE `%s`
        SET used_count = used_count + 1
        WHERE code = ?
          AND created_by = ?
          AND is_active = 1
          AND (max_uses IS NULL OR used_count < max_uses)
          AND (expires_at IS NULL OR expires_at > NOW())
      ]]):format(COUPON_TABLE),
      { tostring(appliedCoupon.code), tostring(appliedCoupon.createdBy) }
    ) or 0

    if couponRows < 1 then
      print(('[bd_commerce] coupon usage was not incremented for code=%s creator=%s'):format(
        tostring(appliedCoupon.code),
        tostring(appliedCoupon.createdBy)
      ))
    end
  end

  local invalidatedSellers = {}
  for _, requestItem in ipairs(requestedItems) do
    local sellerIdentifier = tostring(requestItem.sellerIdentifier or '')
    if sellerIdentifier ~= '' and not invalidatedSellers[sellerIdentifier] then
      invalidatedSellers[sellerIdentifier] = true
      invalidateCommerceCaches(sellerIdentifier, src)
    end
  end

  releaseCheckoutLocks()
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = ('Checkout completed successfully. Paid $%.2f via %s.'):format(totalCost, paymentMethod),
    sales = {},
    receivedItems = grantedItems,
    totalPaid = totalCost,
    couponCode = appliedCoupon and appliedCoupon.code or nil,
    couponDiscount = couponDiscount,
    paymentMethod = paymentMethod,
    taxPercent = taxPercent,
    pendingRatings = pendingRatingsPayload,
  })
end)

RegisterNetEvent('bd_commerce:server:getCommerceMeta', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getCommerceMetaResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      categories = {},
    })
    return
  end

  local categories = {}
  local list = Config and Config.CommerceCategories
  if type(list) == 'table' then
    for _, entry in ipairs(list) do
      if type(entry) == 'table' then
        local id = sanitizeString(tostring(entry.id or '')):lower()
        local label = sanitizeString(tostring(entry.label or entry.id or ''))
        if id ~= '' then
          categories[#categories + 1] = {
            id = id,
            label = label ~= '' and label or id,
          }
        end
      end
    end
  end

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Commerce metadata loaded.',
    categories = categories,
    inventoryImagePath = getConfiguredInventoryImagePath(),
    isAdmin = isAdminSource(src),
  })
end)

RegisterNetEvent('bd_commerce:server:getPendingRatings', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getPendingRatingsResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      pending = {},
    })
    return
  end

  local buyerIdentifier = getOwnerIdentifier(src)
  local rows = MySQL.query.await(
    ([[
      SELECT p.id AS purchase_id, p.seller_identifier, p.product_name
      FROM `%s` p
      LEFT JOIN `%s` r ON r.purchase_id = p.id
      WHERE p.buyer_identifier = ?
        AND r.id IS NULL
      ORDER BY p.created_at DESC
      LIMIT 50
    ]]):format(PURCHASE_TABLE, RATING_TABLE),
    { buyerIdentifier }
  ) or {}

  local pending = {}
  for _, row in ipairs(rows) do
    local pid = tonumber(row.purchase_id) or row.purchase_id
    local sid = tostring(row.seller_identifier or '')
    if pid and sid ~= '' then
      local displayName = getCharacterDisplayNameByIdentifier(sid)
      pending[#pending + 1] = {
        purchaseId = pid,
        sellerIdentifier = sid,
        sellerName = displayName ~= '' and displayName or sid,
        productName = tostring(row.product_name or ''),
      }
    end
  end

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Pending ratings loaded.',
    pending = pending,
  })
end)

RegisterNetEvent('bd_commerce:server:submitSellerRating', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:submitSellerRatingResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  if type(payload) ~= 'table' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid payload.',
    })
    return
  end

  local purchaseId = toInteger(payload.purchaseId)
  local stars = toInteger(payload.stars)
  if not purchaseId or not stars or stars < 1 or stars > 5 then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Select a valid rating (1-5).',
    })
    return
  end

  local buyerIdentifier = getOwnerIdentifier(src)
  local purchaseRow = MySQL.single.await(
    ('SELECT buyer_identifier, seller_identifier FROM `%s` WHERE id = ? LIMIT 1'):format(PURCHASE_TABLE),
    { purchaseId }
  )

  if not purchaseRow or tostring(purchaseRow.buyer_identifier or '') ~= buyerIdentifier then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Purchase not found.',
    })
    return
  end

  local sellerIdentifier = tostring(purchaseRow.seller_identifier or '')
  if sellerIdentifier == '' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid seller for this purchase.',
    })
    return
  end

  local existingRating = MySQL.single.await(
    ('SELECT id FROM `%s` WHERE purchase_id = ? LIMIT 1'):format(RATING_TABLE),
    { purchaseId }
  )
  if existingRating then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'This purchase was already rated.',
    })
    return
  end

  local insertOk, insertError = pcall(function()
    MySQL.insert.await(
      ('INSERT INTO `%s` (purchase_id, buyer_identifier, seller_identifier, stars) VALUES (?, ?, ?, ?)'):format(RATING_TABLE),
      { purchaseId, buyerIdentifier, sellerIdentifier, stars }
    )
  end)

  if not insertOk then
    print(('[bd_commerce] submitSellerRating insert failed: %s'):format(tostring(insertError)))
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not save rating. Try again.',
    })
    return
  end

  updateSellerRatingStats(sellerIdentifier, stars)

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Thanks for your feedback.',
  })
end)

RegisterNetEvent('bd_commerce:server:submitReport', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:submitReportResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  if type(payload) ~= 'table' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid report payload.',
    })
    return
  end

  local now = os.time()
  local lastAt = REPORT_LAST_SUBMIT_AT[src] or 0
  if (now - lastAt) < 2 then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Please wait a moment before submitting another report.',
    })
    return
  end
  REPORT_LAST_SUBMIT_AT[src] = now

  local dbSaleId = parseSaleId(payload.listingId or '')
  local reason = sanitizeString(payload.reason)
  local description = sanitizeString(payload.description)
  if not dbSaleId then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid listing id.',
    })
    return
  end
  if reason ~= 'Scam' and reason ~= 'Wrong Price' and reason ~= 'Abuse' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid report reason.',
    })
    return
  end
  if #description > 500 then
    description = description:sub(1, 500)
  end

  local reporterId = getOwnerIdentifier(src)
  if reporterId == '' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not resolve reporter.',
    })
    return
  end

  local listingRow = MySQL.single.await(
    ([[
      SELECT
        s.id,
        s.owner_identifier,
        (
          SELECT r.id
          FROM `%s` r
          WHERE r.listing_id = s.id AND r.reporter_id = ?
          LIMIT 1
        ) AS existing_report_id
      FROM `%s` s
      WHERE s.id = ?
      LIMIT 1
    ]]):format(REPORT_TABLE, TABLE_NAME),
    { reporterId, dbSaleId }
  )
  if not listingRow then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Listing no longer exists.',
    })
    return
  end

  if listingRow.existing_report_id then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'You already reported this listing.',
    })
    return
  end

  local sellerId = tostring(listingRow.owner_identifier or '')
  if sellerId == '' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not resolve seller.',
    })
    return
  end

  local insertId = MySQL.insert.await(
    ('INSERT INTO `%s` (listing_id, reporter_id, seller_id, reason, description, status) VALUES (?, ?, ?, ?, ?, ?)'):format(REPORT_TABLE),
    { dbSaleId, reporterId, sellerId, reason, description ~= '' and description or nil, 'pending' }
  )

  if not insertId then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not submit report. Try again.',
    })
    return
  end

  invalidateReportsCache()

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Report submitted. Admins will review it shortly.',
  })
end)

RegisterNetEvent('bd_commerce:server:getReports', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:getReportsResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      reports = {},
      total = 0,
    })
    return
  end

  if not isAdminSource(src) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Admin permission required.',
      reports = {},
      total = 0,
    })
    return
  end

  payload = type(payload) == 'table' and payload or {}
  local statusFilter = sanitizeString(payload.status):lower()
  local reasonFilter = sanitizeString(payload.reason)
  local page = math.max(1, toInteger(payload.page) or 1)
  local pageSize = math.max(1, math.min(100, toInteger(payload.pageSize) or 20))
  local offset = (page - 1) * pageSize
  local cacheKey = getReportsCacheKey(statusFilter, reasonFilter, page, pageSize)
  local now = os.time()
  if REPORTS_CACHE.data and REPORTS_CACHE.key == cacheKey and (now - REPORTS_CACHE.time) < REPORTS_CACHE_TTL then
    TriggerClientEvent(responseEvent, src, requestId, REPORTS_CACHE.data)
    return
  end

  local whereParts = {}
  local whereParams = {}
  if statusFilter == 'pending' or statusFilter == 'resolved' or statusFilter == 'reviewed' then
    whereParts[#whereParts + 1] = 'r.status = ?'
    whereParams[#whereParams + 1] = statusFilter
  end
  if reasonFilter == 'Scam' or reasonFilter == 'Wrong Price' or reasonFilter == 'Abuse' then
    whereParts[#whereParts + 1] = 'r.reason = ?'
    whereParams[#whereParams + 1] = reasonFilter
  end
  local whereSql = #whereParts > 0 and ('WHERE ' .. table.concat(whereParts, ' AND ')) or ''

  local countRows = MySQL.query.await(
    ([[
      SELECT COUNT(*) AS total
      FROM `%s` r
      %s
    ]]):format(REPORT_TABLE, whereSql),
    whereParams
  ) or {}
  local total = tonumber(countRows[1] and countRows[1].total) or 0

  local rows = MySQL.query.await(
    ([[
      SELECT
        r.id,
        r.listing_id,
        r.reporter_id,
        r.seller_id,
        r.reason,
        r.description,
        r.status,
        r.created_at,
        s.product_name,
        s.price
      FROM `%s` r
      LEFT JOIN `%s` s ON s.id = r.listing_id
      %s
      ORDER BY r.created_at DESC, r.id DESC
      LIMIT %d OFFSET %d
    ]]):format(REPORT_TABLE, TABLE_NAME, whereSql, pageSize, offset),
    whereParams
  ) or {}

  local identifierSet = {}
  for _, row in ipairs(rows) do
    local sellerId = tostring(row.seller_id or '')
    local reporterId = tostring(row.reporter_id or '')
    if sellerId ~= '' then identifierSet[sellerId] = true end
    if reporterId ~= '' then identifierSet[reporterId] = true end
  end
  local nameMap = buildIdentifierNameMap(identifierSet)

  local reports = {}
  for _, row in ipairs(rows) do
    local sellerId = tostring(row.seller_id or '')
    local reporterId = tostring(row.reporter_id or '')
    reports[#reports + 1] = {
      id = tonumber(row.id) or 0,
      listingId = tonumber(row.listing_id) or 0,
      listingTitle = tostring(row.product_name or ('Listing #%s'):format(tostring(row.listing_id or '?'))),
      listingPrice = tonumber(row.price) or 0,
      sellerId = sellerId,
      sellerName = nameMap[sellerId] or sellerId,
      reporterId = reporterId,
      reporterName = nameMap[reporterId] or reporterId,
      reason = tostring(row.reason or ''),
      description = tostring(row.description or ''),
      status = tostring(row.status or 'pending'),
      createdAt = row.created_at,
    }
  end

  local responsePayload = {
    ok = true,
    message = 'Reports loaded.',
    reports = reports,
    total = total,
    page = page,
    pageSize = pageSize,
  }
  REPORTS_CACHE.key = cacheKey
  REPORTS_CACHE.time = now
  REPORTS_CACHE.data = responsePayload

  TriggerClientEvent(responseEvent, src, requestId, responsePayload)
end)

RegisterNetEvent('bd_commerce:server:moderateReportAction', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:moderateReportActionResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  if not isAdminSource(src) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Admin permission required.',
    })
    return
  end

  payload = type(payload) == 'table' and payload or {}
  local reportId = toInteger(payload.reportId)
  local action = sanitizeString(payload.action):lower()
  if not reportId or (action ~= 'resolve' and action ~= 'remove_listing' and action ~= 'ban_seller') then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid moderation request.',
    })
    return
  end

  local reportRow = MySQL.single.await(
    ('SELECT id, listing_id, seller_id FROM `%s` WHERE id = ? LIMIT 1'):format(REPORT_TABLE),
    { reportId }
  )
  if not reportRow then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Report not found.',
    })
    return
  end

  local listingId = tonumber(reportRow.listing_id) or 0
  local sellerId = tostring(reportRow.seller_id or '')

  if action == 'remove_listing' then
    local listingRow = MySQL.single.await(
      ('SELECT id, owner_identifier, inventory_item, product_name, quantity FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME),
      { listingId }
    )
    if listingRow then
      queueSellerListingReturnClaim(listingRow, 'Listing removed by moderation')
    end
    MySQL.update.await(
      ('DELETE FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME),
      { listingId }
    )
    MySQL.update.await(
      ('UPDATE `%s` SET status = ? WHERE listing_id = ? AND status = ?'):format(REPORT_TABLE),
      { 'resolved', listingId, 'pending' }
    )
    invalidateListingCaches(src)
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = true,
      message = 'Listing removed and related reports resolved.',
    })
    return
  end

  if action == 'ban_seller' then
    if sellerId == '' then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Invalid seller id.',
      })
      return
    end

    MySQL.update.await(
      ([[
        INSERT INTO `%s` (seller_id, reason)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE reason = VALUES(reason)
      ]]):format(BLOCKED_SELLERS_TABLE),
      { sellerId, 'Banned by admin moderation action' }
    )
    MySQL.update.await(
      ('UPDATE `%s` SET status = ? WHERE seller_id = ? AND status = ?'):format(REPORT_TABLE),
      { 'resolved', sellerId, 'pending' }
    )
    invalidateReportsCache()
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = true,
      message = 'Seller banned and reports resolved.',
    })
    return
  end

  MySQL.update.await(
    ('UPDATE `%s` SET status = ? WHERE id = ?'):format(REPORT_TABLE),
    { 'resolved', reportId }
  )
  invalidateReportsCache()
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Report marked as resolved.',
  })
end)

RegisterNetEvent('bd_commerce:server:validateCoupon', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:validateCouponResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  if type(payload) ~= 'table' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid coupon payload.',
    })
    return
  end

  local code = payload.code
  local saleIdsPayload = type(payload.saleIds) == 'table' and payload.saleIds or {}
  local saleIds = {}
  local seenSaleIds = {}
  for _, rawSaleId in ipairs(saleIdsPayload) do
    local parsedSaleId = parseSaleId(rawSaleId)
    if parsedSaleId and not seenSaleIds[parsedSaleId] then
      seenSaleIds[parsedSaleId] = true
      saleIds[#saleIds + 1] = parsedSaleId
    end
  end

  if #saleIds == 0 then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Add items to cart before applying coupon.',
    })
    return
  end

  local placeholders = buildSqlPlaceholders(#saleIds)
  local rows = MySQL.query.await(
    ('SELECT id, owner_identifier, sale_type, player_target, job_target FROM `%s` WHERE id IN (%s)'):format(TABLE_NAME, placeholders),
    saleIds
  ) or {}
  if #rows ~= #saleIds then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'One or more listings are no longer available.',
    })
    return
  end

  local ownerIdentifier = getOwnerIdentifier(src)
  local viewerJobKeys = getPlayerJobKeys(src)
  local targetSeller = nil
  for _, row in ipairs(rows) do
    if not canPlayerSeeSaleRow(row, ownerIdentifier, viewerJobKeys) then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'You cannot use coupon for one or more selected listings.',
      })
      return
    end

    local sellerIdentifier = tostring(row.owner_identifier or '')
    if sellerIdentifier == '' then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Invalid listing owner.',
      })
      return
    end

    if targetSeller == nil then
      targetSeller = sellerIdentifier
    elseif targetSeller ~= sellerIdentifier then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Coupon can only be used when all cart items are from one seller.',
      })
      return
    end
  end

  local coupon, couponError = getValidCouponByCode(code)
  if not coupon then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = couponError or 'Coupon not available.',
    })
    return
  end

  if coupon.createdBy == '' or coupon.createdBy ~= targetSeller then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Coupon not available for selected products.',
    })
    return
  end

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Coupon applied.',
    code = coupon.code,
    discountType = coupon.discountType,
    discountValue = coupon.discountValue,
  })
end)

RegisterNetEvent('bd_commerce:server:getSellerWallet', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getSellerWalletResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      wallet = nil,
      taxPercent = getCommerceTaxPercent(),
    })
    return
  end

  local ownerIdentifier = getOwnerIdentifier(src)
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Seller wallet loaded.',
    wallet = getSellerWallet(ownerIdentifier),
    taxPercent = getCommerceTaxPercent(),
  })
end)

RegisterNetEvent('bd_commerce:server:withdrawSellerEarnings', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:withdrawSellerEarningsResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      wallet = nil,
    })
    return
  end

  local amount = roundCurrency(tonumber(payload and payload.amount) or 0)
  if amount <= 0 then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Withdraw amount must be greater than 0.',
      wallet = getSellerWallet(getOwnerIdentifier(src)),
    })
    return
  end

  local ownerIdentifier = getOwnerIdentifier(src)
  if not debitSellerWallet(ownerIdentifier, amount) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Insufficient wallet balance.',
      wallet = getSellerWallet(ownerIdentifier),
    })
    return
  end

  if not addPlayerMoney(src, 'cash', amount) then
    addSellerWalletBalance(ownerIdentifier, amount)
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not withdraw to cash.',
      wallet = getSellerWallet(ownerIdentifier),
    })
    return
  end

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = ('Withdrew $%.2f to cash.'):format(amount),
    wallet = getSellerWallet(ownerIdentifier),
  })
end)

RegisterNetEvent('bd_commerce:server:createSale', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:createSaleResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.'
    })
    return
  end

  local ok, validatedOrMessage = validateSalePayload(payload)
  if not ok then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = validatedOrMessage,
    })
    return
  end

  local validated = validatedOrMessage
  if validated.saleType == 'Person' then
    local resolvedTarget, resolveError = resolvePersonTargetInput(validated.playerTarget)
    if not resolvedTarget then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = resolveError,
      })
      return
    end
    validated.playerTarget = resolvedTarget
    validated.jobTarget = ''
  elseif validated.saleType == 'Job' then
    validated.playerTarget = ''
    validated.jobTarget = sanitizeString(validated.jobTarget):lower()
  else
    validated.playerTarget = ''
    validated.jobTarget = ''
  end
  local isAuction = validated.saleType == 'Auction'
  local auctionEndAt = nil
  if isAuction then
    local durationMinutes = tonumber(validated.auctionDurationMinutes) or 0
    auctionEndAt = toMysqlDateTime(getUnixSeconds() + math.floor(durationMinutes * 60))
    validated.price = tostring(tonumber(validated.startingPrice) or 0)
    validated.discount = '0'
  end

  local ownerIdentifier = getOwnerIdentifier(src)
  if isSellerBlocked(ownerIdentifier) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Your seller account is blocked from creating listings.',
    })
    return
  end
  local _, inventoryLookup = getPlayerInventoryItems(src)
  local selectedInventory = inventoryLookup[validated.inventoryItem]
  local listingQuantity = tonumber(validated.quantity) or 0

  if not selectedInventory or selectedInventory.count < listingQuantity then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Sale quantity cannot be higher than your inventory count.',
    })
    return
  end

  if not removeInventoryItem(src, validated.inventoryItem, listingQuantity) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not remove item from your inventory.',
    })
    return
  end

  local insertId = nil
  local insertOk, insertError = pcall(function()
    insertId = MySQL.insert.await(
      ('INSERT INTO `%s` (owner_identifier, product_name, description, inventory_item, player_target, job_target, quantity, price, discount, sale_type, category, image, starting_price, current_highest_bid, highest_bidder, auction_end_time, bid_increment, auction_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'):format(TABLE_NAME),
      {
        ownerIdentifier,
        validated.productName,
        validated.description,
        validated.inventoryItem,
        validated.playerTarget,
        validated.jobTarget,
        listingQuantity,
        tonumber(validated.price),
        tonumber(validated.discount),
        validated.saleType,
        validated.category,
        ('%s.png'):format(validated.inventoryItem),
        isAuction and (tonumber(validated.startingPrice) or 0) or 0,
        nil,
        '',
        isAuction and auctionEndAt or nil,
        isAuction and (tonumber(validated.bidIncrement) or 1) or 1,
        isAuction and 'open' or '',
      }
    )
  end)

  if not insertOk or not insertId then
    if not insertOk then
      print(('[bd_commerce] createSale insert failed: %s'):format(tostring(insertError)))
    else
      print('[bd_commerce] createSale insert failed: insertId is nil. Check table schema/constraints.')
    end
    addInventoryItem(src, validated.inventoryItem, listingQuantity)
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Database error while creating sale. Check server console.',
    })
    return
  end

  local sale = {
    id = ('sale-%s'):format(insertId),
    productName = validated.productName,
    description = validated.description,
    inventoryItem = validated.inventoryItem,
    playerTarget = validated.playerTarget,
    jobTarget = validated.jobTarget,
    quantity = validated.quantity,
    price = validated.price,
    discount = validated.discount,
    saleType = validated.saleType,
    category = validated.category,
    startingPrice = validated.startingPrice,
    currentHighestBid = '',
    highestBidder = '',
    auctionEndTime = auctionEndAt,
    bidIncrement = validated.bidIncrement,
    auctionStatus = isAuction and 'open' or nil,
    image = ('%s.png'):format(validated.inventoryItem),
    owner = ownerIdentifier,
    createdAt = os.time(),
  }

  sales[sale.id] = sale
  invalidateCommerceCaches(ownerIdentifier, src)

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Sale created successfully.',
    sale = sale,
  })
end)

RegisterNetEvent('bd_commerce:server:updateSale', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:updateSaleResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  if type(payload) ~= 'table' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid request payload.',
    })
    return
  end

  local dbSaleId = parseSaleId(payload.id)
  if not dbSaleId then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid sale id.',
    })
    return
  end

  local ownerIdentifier = getOwnerIdentifier(src)
  if isSellerBlocked(ownerIdentifier) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Your seller account is blocked from editing listings.',
    })
    return
  end
  local existingRow = MySQL.single.await(
    ('SELECT id, owner_identifier, inventory_item, quantity, current_highest_bid FROM `%s` WHERE id = ? AND owner_identifier = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId, ownerIdentifier }
  )
  if not existingRow then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Sale not found or you are not the owner.',
    })
    return
  end

  local validated, validatedOrMessage = validateSalePayload(payload)
  if not validated then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = validatedOrMessage,
    })
    return
  end

  local saleData = validatedOrMessage
  if saleData.saleType == 'Person' then
    local resolvedTarget, resolveError = resolvePersonTargetInput(saleData.playerTarget)
    if not resolvedTarget then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = resolveError,
      })
      return
    end
    saleData.playerTarget = resolvedTarget
    saleData.jobTarget = ''
  elseif saleData.saleType == 'Job' then
    saleData.playerTarget = ''
    saleData.jobTarget = sanitizeString(saleData.jobTarget):lower()
  else
    saleData.playerTarget = ''
    saleData.jobTarget = ''
  end
  local isAuction = saleData.saleType == 'Auction'
  if isAuction and tonumber(existingRow.current_highest_bid) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Auction with bids cannot be edited.',
    })
    return
  end
  local auctionEndAt = nil
  if isAuction then
    local durationMinutes = tonumber(saleData.auctionDurationMinutes) or 0
    auctionEndAt = toMysqlDateTime(getUnixSeconds() + math.floor(durationMinutes * 60))
    saleData.price = tostring(tonumber(saleData.startingPrice) or 0)
    saleData.discount = '0'
  end

  local existingInventoryItem = tostring(existingRow.inventory_item or '')
  if saleData.inventoryItem ~= existingInventoryItem then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Inventory item cannot be changed for an existing sale.',
    })
    return
  end

  local oldQuantity = tonumber(existingRow.quantity) or 0
  local newQuantity = tonumber(saleData.quantity) or 0
  local quantityDelta = newQuantity - oldQuantity
  local adjustedAmount = math.abs(quantityDelta)
  local adjustedDirection = 0

  if quantityDelta > 0 then
    if not removeInventoryItem(src, existingInventoryItem, adjustedAmount) then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Could not reserve additional quantity from your inventory.',
      })
      return
    end
    adjustedDirection = 1
  elseif quantityDelta < 0 then
    if not addInventoryItem(src, existingInventoryItem, adjustedAmount) then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Could not return quantity to your inventory.',
      })
      return
    end
    adjustedDirection = -1
  end

  local affectedRows = MySQL.update.await(
    ('UPDATE `%s` SET product_name = ?, description = ?, player_target = ?, job_target = ?, quantity = ?, price = ?, discount = ?, sale_type = ?, category = ?, starting_price = ?, current_highest_bid = ?, highest_bidder = ?, auction_end_time = ?, bid_increment = ?, auction_status = ? WHERE id = ? AND owner_identifier = ?'):format(TABLE_NAME),
    {
      saleData.productName,
      saleData.description,
      saleData.playerTarget,
      saleData.jobTarget,
      newQuantity,
      tonumber(saleData.price),
      tonumber(saleData.discount),
      saleData.saleType,
      saleData.category,
      isAuction and (tonumber(saleData.startingPrice) or 0) or 0,
      nil,
      '',
      isAuction and auctionEndAt or nil,
      isAuction and (tonumber(saleData.bidIncrement) or 1) or 1,
      isAuction and 'open' or '',
      dbSaleId,
      ownerIdentifier,
    }
  )

  if not affectedRows or affectedRows < 1 then
    if adjustedDirection == 1 then
      addInventoryItem(src, existingInventoryItem, adjustedAmount)
    elseif adjustedDirection == -1 then
      removeInventoryItem(src, existingInventoryItem, adjustedAmount)
    end
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Sale not found or you are not the owner.',
    })
    return
  end

  local row = MySQL.single.await(
    ('SELECT * FROM `%s` WHERE id = ? AND owner_identifier = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId, ownerIdentifier }
  )

  local statsMap = getSellerRatingStatsMap({ ownerIdentifier })

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Sale updated successfully.',
    sale = row and rowToSale(row, statsMap) or nil,
  })
  invalidateCommerceCaches(ownerIdentifier, src)
end)

RegisterNetEvent('bd_commerce:server:getAdminSales', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getAdminSalesResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      sales = {},
    })
    return
  end

  if not isAdminSource(src) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Admin permission required.',
      sales = {},
    })
    return
  end

  local now = os.time()
  if ADMIN_SALES_CACHE.data and (now - ADMIN_SALES_CACHE.time) < ADMIN_CACHE_TTL then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = true,
      message = 'Admin sales loaded successfully.',
      sales = ADMIN_SALES_CACHE.data,
    })
    return
  end

  if ACTIVE_ADMIN_REQUESTS[src] then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = true,
      message = 'Admin sales request already in progress.',
      sales = ADMIN_SALES_CACHE.data or {},
    })
    return
  end

  ACTIVE_ADMIN_REQUESTS[src] = true

  local queryStart = queryTimerStart()
  local rows = MySQL.query.await(
    ('SELECT * FROM `%s` ORDER BY created_at DESC, id DESC LIMIT %d'):format(TABLE_NAME, ADMIN_SALES_LIMIT)
  ) or {}
  queryTimerEnd(queryStart, 'getAdminSalesRows')

  local nameMap = buildIdentifierNameMapFromRows(rows)
  local ownerKeys = {}
  local seenOwners = {}
  for _, row in ipairs(rows) do
    local oid = tostring(row.owner_identifier or '')
    if oid ~= '' and not seenOwners[oid] then
      seenOwners[oid] = true
      ownerKeys[#ownerKeys + 1] = oid
    end
  end
  local statsMap = getSellerRatingStatsMap(ownerKeys)
  local salesList = {}
  for _, row in ipairs(rows) do
    local mapped = rowToSale(row, statsMap)
    local ownerIdentifier = tostring(row.owner_identifier or '')
    local playerTargetIdentifier = tostring(row.player_target or '')

    mapped.ownerIdentifier = ownerIdentifier
    mapped.ownerName = nameMap[ownerIdentifier] or ownerIdentifier
    mapped.playerTargetIdentifier = playerTargetIdentifier
    mapped.playerTargetName = playerTargetIdentifier ~= '' and (nameMap[playerTargetIdentifier] or playerTargetIdentifier) or ''

    salesList[#salesList + 1] = mapped
  end

  ADMIN_SALES_CACHE.data = salesList
  ADMIN_SALES_CACHE.time = now
  ACTIVE_ADMIN_REQUESTS[src] = nil

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = ('Admin sales loaded successfully (max %d rows).'):format(ADMIN_SALES_LIMIT),
    sales = salesList,
  })
end)

RegisterNetEvent('bd_commerce:server:adminUpdateSale', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:adminUpdateSaleResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  if type(payload) ~= 'table' then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid request payload.',
    })
    return
  end

  if not isAdminSource(src) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Admin permission required.',
    })
    return
  end

  local dbSaleId = parseSaleId(payload.id)
  if not dbSaleId then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid sale id.',
    })
    return
  end

  local existingRow = MySQL.single.await(
    ('SELECT id, owner_identifier, inventory_item, quantity, current_highest_bid FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId }
  )
  if not existingRow then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Sale not found.',
    })
    return
  end

  local validated, validatedOrMessage = validateSalePayload(payload)
  if not validated then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = validatedOrMessage,
    })
    return
  end

  local saleData = validatedOrMessage
  if saleData.saleType == 'Person' then
    local resolvedTarget, resolveError = resolvePersonTargetInput(saleData.playerTarget)
    if not resolvedTarget then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = resolveError,
      })
      return
    end
    saleData.playerTarget = resolvedTarget
    saleData.jobTarget = ''
  elseif saleData.saleType == 'Job' then
    saleData.playerTarget = ''
    saleData.jobTarget = sanitizeString(saleData.jobTarget):lower()
  else
    saleData.playerTarget = ''
    saleData.jobTarget = ''
  end
  local isAuction = saleData.saleType == 'Auction'
  if isAuction and tonumber(existingRow.current_highest_bid) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Auction with bids cannot be edited.',
    })
    return
  end
  local auctionEndAt = nil
  if isAuction then
    local durationMinutes = tonumber(saleData.auctionDurationMinutes) or 0
    auctionEndAt = toMysqlDateTime(getUnixSeconds() + math.floor(durationMinutes * 60))
    saleData.price = tostring(tonumber(saleData.startingPrice) or 0)
    saleData.discount = '0'
  end

  local existingInventoryItem = tostring(existingRow.inventory_item or '')
  if saleData.inventoryItem ~= existingInventoryItem then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Inventory item cannot be changed for an existing sale.',
    })
    return
  end

  local oldQuantity = tonumber(existingRow.quantity) or 0
  local newQuantity = tonumber(saleData.quantity) or 0
  local quantityDelta = newQuantity - oldQuantity
  local adjustedAmount = math.abs(quantityDelta)
  local adjustedDirection = 0
  local ownerIdentifier = tostring(existingRow.owner_identifier or '')
  local ownerSource = ownerIdentifier ~= '' and findPlayerByCharacterIdentifier(ownerIdentifier) or nil

  if quantityDelta ~= 0 and not ownerSource then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Owner must be online to adjust listing quantity.',
    })
    return
  end

  if quantityDelta > 0 then
    if not removeInventoryItem(ownerSource, existingInventoryItem, adjustedAmount) then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Could not reserve additional quantity from owner inventory.',
      })
      return
    end
    adjustedDirection = 1
  elseif quantityDelta < 0 then
    if not addInventoryItem(ownerSource, existingInventoryItem, adjustedAmount) then
      TriggerClientEvent(responseEvent, src, requestId, {
        ok = false,
        message = 'Could not return quantity to owner inventory.',
      })
      return
    end
    adjustedDirection = -1
  end

  local affectedRows = MySQL.update.await(
    ('UPDATE `%s` SET product_name = ?, description = ?, player_target = ?, job_target = ?, quantity = ?, price = ?, discount = ?, sale_type = ?, category = ?, starting_price = ?, current_highest_bid = ?, highest_bidder = ?, auction_end_time = ?, bid_increment = ?, auction_status = ? WHERE id = ?'):format(TABLE_NAME),
    {
      saleData.productName,
      saleData.description,
      saleData.playerTarget,
      saleData.jobTarget,
      newQuantity,
      tonumber(saleData.price),
      tonumber(saleData.discount),
      saleData.saleType,
      saleData.category,
      isAuction and (tonumber(saleData.startingPrice) or 0) or 0,
      nil,
      '',
      isAuction and auctionEndAt or nil,
      isAuction and (tonumber(saleData.bidIncrement) or 1) or 1,
      isAuction and 'open' or '',
      dbSaleId,
    }
  )

  if not affectedRows or affectedRows < 1 then
    if adjustedDirection == 1 then
      addInventoryItem(ownerSource, existingInventoryItem, adjustedAmount)
    elseif adjustedDirection == -1 then
      removeInventoryItem(ownerSource, existingInventoryItem, adjustedAmount)
    end
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Sale not found.',
    })
    return
  end

  local row = MySQL.single.await(
    ('SELECT * FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId }
  )
  invalidateCommerceCaches(nil, src)

  local ownerForStats = row and tostring(row.owner_identifier or '') or ''
  local statsMap = ownerForStats ~= '' and getSellerRatingStatsMap({ ownerForStats }) or {}

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Sale updated successfully.',
    sale = row and rowToAdminSale(row, statsMap) or nil,
  })
end)

local function canOwnerDeleteSaleRow(row)
  if type(row) ~= 'table' then
    return false, 'Sale not found.'
  end

  if tostring(row.sale_type or '') == 'Auction' then
    local auctionStatus = sanitizeString(tostring(row.auction_status or '')):lower()
    if auctionStatus == 'completed' then
      return false, 'This auction was won by a bidder. The winner collects the item on Claims.'
    end
    if auctionStatus == 'expired' then
      return false, 'This auction ended with no bids. Collect your stock on the Claims page.'
    end
    local highestBid = tonumber(row.current_highest_bid) or 0
    local highestBidder = sanitizeString(tostring(row.highest_bidder or ''))
    if highestBid > 0 or highestBidder ~= '' then
      return false, 'You cannot delete an auction that already has bids.'
    end
  end

  return true, nil
end

local function deleteSaleRowWithClaim(row, sourceNote)
  if type(row) ~= 'table' then
    return false, 'Sale not found.'
  end

  local dbSaleId = tonumber(row.id)
  if not dbSaleId then
    return false, 'Invalid sale id.'
  end

  local quantity = tonumber(row.quantity) or 0
  if quantity > 0 and tostring(row.inventory_item or '') ~= '' then
    queueSellerListingReturnClaim(row, sourceNote)
  end

  local deletedRows = MySQL.update.await(
    ('DELETE FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId }
  )
  if not deletedRows or deletedRows < 1 then
    return false, 'Could not delete sale.'
  end

  return true, nil
end

RegisterNetEvent('bd_commerce:server:deleteSale', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:deleteSaleResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  local dbSaleId = parseSaleId(type(payload) == 'table' and payload.id or '')
  if not dbSaleId then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid sale id.',
    })
    return
  end

  local ownerIdentifier = getOwnerIdentifier(src)
  if isSellerBlocked(ownerIdentifier) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Your seller account is blocked from managing listings.',
    })
    return
  end

  local row = MySQL.single.await(
    ('SELECT id, owner_identifier, inventory_item, product_name, quantity, sale_type, auction_status, current_highest_bid, highest_bidder FROM `%s` WHERE id = ? AND owner_identifier = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId, ownerIdentifier }
  )
  if not row then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Sale not found or you are not the owner.',
    })
    return
  end

  local canDelete, deleteError = canOwnerDeleteSaleRow(row)
  if not canDelete then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = deleteError,
    })
    return
  end

  local deleted, deleteFailure = deleteSaleRowWithClaim(row, 'Listing removed by seller')
  if not deleted then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = deleteFailure or 'Could not delete sale.',
    })
    return
  end

  invalidateCommerceCaches(ownerIdentifier, src)
  notifyPlayer(src, 'info', 'Listing removed', 'Collect your items on the Claims page.')
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Sale removed. Collect your items on the Claims page.',
  })
end)

RegisterNetEvent('bd_commerce:server:adminDeleteSale', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:adminDeleteSaleResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  if not isAdminSource(src) then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Admin permission required.',
    })
    return
  end

  local dbSaleId = parseSaleId(type(payload) == 'table' and payload.id or '')
  if not dbSaleId then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Invalid sale id.',
    })
    return
  end

  local queryStart = queryTimerStart()
  local row = MySQL.single.await(
    ('SELECT id, owner_identifier, inventory_item, product_name, quantity, sale_type, auction_status, current_highest_bid, highest_bidder FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId }
  )
  queryTimerEnd(queryStart, 'adminDeleteSaleSelect')
  if not row then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Sale not found.',
    })
    return
  end

  local deleteStart = queryTimerStart()
  local deleted, deleteFailure = deleteSaleRowWithClaim(row, 'Listing deleted by admin')
  queryTimerEnd(deleteStart, 'adminDeleteSaleDelete')

  if not deleted then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = deleteFailure or 'Could not delete sale.',
    })
    return
  end

  invalidateCommerceCaches(tostring(row.owner_identifier or ''), src)
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Sale deleted successfully. Stock was added to the seller claims page.',
  })
end)

RegisterNetEvent('bd_commerce:server:getPendingClaims', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getPendingClaimsResult'
  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', { ok = false, message = 'Invalid request id.', claims = {} })
    return
  end

  local recipientIdentifier = getOwnerIdentifier(src)
  if recipientIdentifier == '' then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Could not resolve your character.', claims = {} })
    return
  end

  local rows = MySQL.query.await(
    ('SELECT * FROM `%s` WHERE recipient_identifier = ? AND claimed_at IS NULL ORDER BY created_at DESC, id DESC LIMIT 100'):format(CLAIMS_TABLE),
    { recipientIdentifier }
  ) or {}

  local claims = {}
  for _, row in ipairs(rows) do
    claims[#claims + 1] = rowToClaim(row)
  end

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Pending claims loaded.',
    claims = claims,
  })
end)

RegisterNetEvent('bd_commerce:server:claimCommerceItem', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:claimCommerceItemResult'
  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', { ok = false, message = 'Invalid request id.' })
    return
  end

  local claimId = parseClaimId(type(payload) == 'table' and payload.id or '')
  if not claimId then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Invalid claim id.' })
    return
  end

  local recipientIdentifier = getOwnerIdentifier(src)
  if recipientIdentifier == '' then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Could not resolve your character.' })
    return
  end

  local row = MySQL.single.await(
    ('SELECT * FROM `%s` WHERE id = ? AND recipient_identifier = ? AND claimed_at IS NULL LIMIT 1'):format(CLAIMS_TABLE),
    { claimId, recipientIdentifier }
  )
  if not row then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Claim not found or already collected.' })
    return
  end

  local inventoryItem = tostring(row.inventory_item or '')
  local quantity = tonumber(row.quantity) or 0
  if inventoryItem == '' or quantity < 1 then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Invalid claim item data.' })
    return
  end

  if not addInventoryItem(src, inventoryItem, quantity) then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Could not add items to your inventory. Make sure you have space.' })
    return
  end

  local marked = MySQL.update.await(
    ('UPDATE `%s` SET claimed_at = UTC_TIMESTAMP() WHERE id = ? AND recipient_identifier = ? AND claimed_at IS NULL'):format(CLAIMS_TABLE),
    { claimId, recipientIdentifier }
  )
  if not marked or marked < 1 then
    removeInventoryItem(src, inventoryItem, quantity)
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Claim could not be completed. Please try again.' })
    return
  end

  local saleId = tonumber(row.sale_id)
  local claimType = sanitizeString(tostring(row.claim_type or ''))
  if saleId and (claimType == 'auction_win' or claimType == 'auction_expired' or claimType == 'listing_removed') then
    MySQL.update.await(('DELETE FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME), { saleId })
  end

  invalidateCommerceCaches(recipientIdentifier, src)
  local claimMessage = ('Claimed %dx %s successfully.'):format(quantity, tostring(row.product_name or inventoryItem))
  notifyPlayer(src, 'success', 'Claim', claimMessage)
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = claimMessage,
    claim = rowToClaim(row),
  })
end)

RegisterNetEvent('bd_commerce:server:createCoupon', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:createCouponResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
    })
    return
  end

  local ok, couponOrMessage = validateCouponPayload(payload)
  if not ok then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = couponOrMessage,
    })
    return
  end

  local coupon = couponOrMessage
  local creatorIdentifier = getOwnerIdentifier(src)

  local insertId = MySQL.insert.await(
    ('INSERT INTO `%s` (code, discount_type, discount_value, max_uses, used_count, is_active, created_by, expires_at) VALUES (?, ?, ?, ?, 0, ?, ?, ?)'):format(COUPON_TABLE),
    {
      coupon.code,
      coupon.discountType,
      coupon.discountValue,
      coupon.maxUses,
      coupon.isActive,
      creatorIdentifier,
      coupon.expiresAt,
    }
  )

  if not insertId then
    TriggerClientEvent(responseEvent, src, requestId, {
      ok = false,
      message = 'Could not create coupon. Code may already exist.',
    })
    return
  end

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Coupon created successfully.',
    coupon = {
      id = insertId,
      code = coupon.code,
      discountType = coupon.discountType,
      discountValue = coupon.discountValue,
      maxUses = coupon.maxUses,
      usedCount = 0,
      isActive = coupon.isActive == 1,
      createdBy = creatorIdentifier,
      expiresAt = coupon.expiresAt,
    },
  })
end)

RegisterNetEvent('bd_commerce:server:getMyCoupons', function(requestId)
  local src = source
  local responseEvent = 'bd_commerce:client:getMyCouponsResult'

  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', {
      ok = false,
      message = 'Invalid request id.',
      coupons = {},
    })
    return
  end

  local rows = MySQL.query.await(
    ([[
      SELECT id, code, discount_type, discount_value, max_uses, used_count, is_active, created_by, expires_at
      FROM `%s`
      ORDER BY created_at DESC, id DESC
      LIMIT 200
    ]]):format(COUPON_TABLE)
  ) or {}

  local coupons = {}
  for _, row in ipairs(rows) do
    local isActiveValue = row.is_active
    local normalizedIsActive = isActiveValue == true
      or tonumber(isActiveValue) == 1
      or tostring(isActiveValue) == '1'

    coupons[#coupons + 1] = {
      id = tonumber(row.id),
      code = tostring(row.code or ''),
      discountType = sanitizeString(tostring(row.discount_type or '')):lower(),
      discountValue = tonumber(row.discount_value) or 0,
      maxUses = row.max_uses and tonumber(row.max_uses) or nil,
      usedCount = tonumber(row.used_count) or 0,
      isActive = normalizedIsActive,
      createdBy = tostring(row.created_by or ''),
      expiresAt = row.expires_at and tostring(row.expires_at) or nil,
    }
  end

  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Coupons loaded.',
    coupons = coupons,
  })
end)

RegisterNetEvent('bd_commerce:server:getAuctionDetails', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:getAuctionDetailsResult'
  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', { ok = false, message = 'Invalid request id.' })
    return
  end
  local dbSaleId = parseSaleId(type(payload) == 'table' and payload.id or '')
  if not dbSaleId then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Invalid sale id.' })
    return
  end
  local row = MySQL.single.await(
    ('SELECT id, sale_type, starting_price, current_highest_bid, highest_bidder, auction_end_time, bid_increment, auction_status FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId }
  )
  if not row or tostring(row.sale_type or '') ~= 'Auction' then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Auction listing not found.' })
    return
  end
  local countRow = MySQL.single.await(('SELECT COUNT(*) AS total FROM `%s` WHERE sale_id = ?'):format(BIDS_TABLE), { dbSaleId }) or {}
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Auction details loaded.',
    details = {
      id = ('sale-%s'):format(dbSaleId),
      startingPrice = tonumber(row.starting_price) or 0,
      currentHighestBid = tonumber(row.current_highest_bid) or nil,
      highestBidder = tostring(row.highest_bidder or ''),
      auctionEndTime = row.auction_end_time and tostring(row.auction_end_time) or nil,
      bidIncrement = tonumber(row.bid_increment) or 1,
      auctionStatus = tostring(row.auction_status or 'open'),
      bidCount = tonumber(countRow.total) or 0,
    },
  })
end)

RegisterNetEvent('bd_commerce:server:placeBid', function(requestId, payload)
  local src = source
  local responseEvent = 'bd_commerce:client:placeBidResult'
  if type(requestId) ~= 'string' or requestId == '' then
    TriggerClientEvent(responseEvent, src, requestId or '', { ok = false, message = 'Invalid request id.' })
    return
  end
  local dbSaleId = parseSaleId(type(payload) == 'table' and payload.id or '')
  local bidAmount = roundCurrency(toNumber(type(payload) == 'table' and payload.amount or nil) or 0)
  if not dbSaleId or bidAmount <= 0 then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Invalid bid payload.' })
    return
  end

  local row = MySQL.single.await(
    ('SELECT id, owner_identifier, sale_type, auction_status, starting_price, current_highest_bid, bid_increment, highest_bidder FROM `%s` WHERE id = ? LIMIT 1'):format(TABLE_NAME),
    { dbSaleId }
  )
  if not row or tostring(row.sale_type or '') ~= 'Auction' then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Auction listing not found.' })
    return
  end
  if sanitizeString(tostring(row.auction_status or 'open')):lower() ~= 'open' then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Auction is closed.' })
    return
  end

  local bidderIdentifier = getOwnerIdentifier(src)
  local sellerIdentifier = tostring(row.owner_identifier or '')
  if bidderIdentifier == '' or bidderIdentifier == sellerIdentifier then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'You cannot bid on your own listing.' })
    return
  end

  local startingPrice = tonumber(row.starting_price) or 0
  local currentBid = tonumber(row.current_highest_bid) or nil
  local bidIncrement = tonumber(row.bid_increment) or 1
  local minAllowed = currentBid and roundCurrency(currentBid + bidIncrement) or roundCurrency(startingPrice)
  if bidAmount < minAllowed then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = ('Minimum bid is $%.2f.'):format(minAllowed) })
    return
  end
  local bankBalance = getAccountBalance(src, 'bank') or 0
  if bankBalance < bidAmount then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Insufficient bank balance for this bid.' })
    return
  end
  if not removePlayerMoney(src, 'bank', bidAmount) then
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Could not reserve bid funds.' })
    return
  end

  local previousHighest = tonumber(row.current_highest_bid) or nil
  local previousHighestBidder = tostring(row.highest_bidder or '')
  local affectedRows = MySQL.update.await(
    ([[
      UPDATE `%s`
      SET current_highest_bid = ?, highest_bidder = ?
      WHERE id = ?
        AND sale_type = 'Auction'
        AND (auction_status = 'open' OR auction_status IS NULL OR auction_status = '')
        AND (auction_end_time IS NULL OR auction_end_time > UTC_TIMESTAMP())
        AND ((current_highest_bid IS NULL AND ? >= starting_price) OR (current_highest_bid IS NOT NULL AND ? >= (current_highest_bid + bid_increment)))
    ]]):format(TABLE_NAME),
    { bidAmount, bidderIdentifier, dbSaleId, bidAmount, bidAmount }
  )
  if not affectedRows or affectedRows < 1 then
    addPlayerMoney(src, 'bank', bidAmount)
    TriggerClientEvent(responseEvent, src, requestId, { ok = false, message = 'Bid was rejected (outbid or auction ended).' })
    return
  end

  MySQL.insert.await(
    ('INSERT INTO `%s` (sale_id, bidder_identifier, bid_amount) VALUES (?, ?, ?)'):format(BIDS_TABLE),
    { dbSaleId, bidderIdentifier, bidAmount }
  )
  if previousHighest and previousHighest > 0 and previousHighestBidder ~= '' then
    local previousSrc = findPlayerByCharacterIdentifier(previousHighestBidder)
    if previousSrc then
      addPlayerMoney(previousSrc, 'bank', previousHighest)
    end
  end
  invalidateCommerceCaches(nil, src)
  local countRow = MySQL.single.await(('SELECT COUNT(*) AS total FROM `%s` WHERE sale_id = ?'):format(BIDS_TABLE), { dbSaleId }) or {}
  TriggerClientEvent(responseEvent, src, requestId, {
    ok = true,
    message = 'Bid placed successfully.',
    details = {
      id = ('sale-%s'):format(dbSaleId),
      currentHighestBid = bidAmount,
      highestBidder = bidderIdentifier,
      bidCount = tonumber(countRow.total) or 0,
    },
  })
end)

CreateThread(function()
  while true do
    Wait(10000)
    local rows = MySQL.query.await(
      ('SELECT id, owner_identifier, inventory_item, product_name, quantity, current_highest_bid, highest_bidder FROM `%s` WHERE sale_type = ? AND (auction_status = ? OR auction_status IS NULL OR auction_status = \'\') AND auction_end_time IS NOT NULL AND auction_end_time <= UTC_TIMESTAMP() LIMIT 50'):format(TABLE_NAME),
      { 'Auction', 'open' }
    ) or {}
    for _, row in ipairs(rows) do
      local saleId = tonumber(row.id)
      if saleId then
        local highestBid = tonumber(row.current_highest_bid) or 0
        local highestBidder = tostring(row.highest_bidder or '')
        local hasWinner = highestBid > 0 and highestBidder ~= ''
        local nextStatus = hasWinner and 'completed' or 'expired'
        local done = MySQL.update.await(
          ('UPDATE `%s` SET auction_status = ? WHERE id = ? AND sale_type = ? AND (auction_status = ? OR auction_status IS NULL OR auction_status = \'\')'):format(TABLE_NAME),
          { nextStatus, saleId, 'Auction', 'open' }
        )
        if done and done > 0 then
          if hasWinner then
            local sellerIdentifier = tostring(row.owner_identifier or '')
            local taxPercent = getCommerceTaxPercent()
            local netAmount = roundCurrency(highestBid * ((100 - taxPercent) / 100))
            addSellerWalletBalance(sellerIdentifier, netAmount)
            MySQL.insert.await(
              ('INSERT INTO `%s` (buyer_identifier, seller_identifier, sale_id, product_name, quantity, line_total) VALUES (?, ?, ?, ?, ?, ?)'):format(PURCHASE_TABLE),
              { highestBidder, sellerIdentifier, saleId, tostring(row.product_name or ''), tonumber(row.quantity) or 1, highestBid }
            )
            row.id = saleId
            row.highest_bidder = highestBidder
            queueAuctionWinClaim(row)
            local winnerSource = findPlayerByCharacterIdentifier(highestBidder)
            if winnerSource then
              notifyPlayer(winnerSource, 'success', 'Auction won', 'You won an auction. Collect the item on Claims.')
            end
            local sellerSource = findPlayerByCharacterIdentifier(sellerIdentifier)
            if sellerSource then
              notifyPlayer(sellerSource, 'success', 'Auction sold', ('Your auction sold for $%.2f.'):format(highestBid))
            end
          else
            row.id = saleId
            queueExpiredAuctionSellerClaim(row)
            local sellerSource = findPlayerByCharacterIdentifier(tostring(row.owner_identifier or ''))
            if sellerSource then
              notifyPlayer(sellerSource, 'info', 'Auction ended', 'No bids received. Collect your stock on Claims.')
            end
          end
        end
      end
    end
    if #rows > 0 then
      invalidateCommerceCaches(nil, nil)
    end
  end
end)

CreateThread(function()
  while true do
    Wait(600000)
    CHARACTER_NAME_CACHE = {}
  end
end)
