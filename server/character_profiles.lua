CommerceCharacterProfiles = CommerceCharacterProfiles or {}

local function sanitizeString(value)
  if type(value) ~= 'string' then return '' end
  return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function quoteIdent(name)
  if type(name) ~= 'string' or not name:match('^[%w_]+$') then
    return nil
  end
  return ('`%s`'):format(name)
end

local RESOLVED_CFG = nil

local function getFrameworkDefaultProfile()
  local framework = CommerceFramework and CommerceFramework.GetActive and CommerceFramework.GetActive() or 'esx'
  if framework == 'qbcore' or framework == 'qbox' then
    return {
      enabled = true,
      table = 'players',
      idCol = 'license',
      firstCol = nil,
      lastCol = nil,
      jsonCol = 'charinfo',
      jsonFirstKey = 'firstname',
      jsonLastKey = 'lastname',
      idLikePattern = nil,
      stripPrefix = false,
      idPrefix = 'license:',
    }
  end

  return {
    enabled = true,
    table = 'users',
    idCol = 'identifier',
    firstCol = 'firstname',
    lastCol = 'lastname',
    jsonCol = nil,
    jsonFirstKey = 'firstname',
    jsonLastKey = 'lastname',
    idLikePattern = 'char%:%',
    stripPrefix = false,
    idPrefix = '',
  }
end

local function resolveProfileConfig()
  if RESOLVED_CFG then
    return RESOLVED_CFG
  end

  local cfg = type(Config) == 'table' and Config.CharacterProfiles or {}
  local defaults = getFrameworkDefaultProfile()

  RESOLVED_CFG = {
    enabled = cfg.Enabled ~= false and defaults.enabled,
    table = quoteIdent(cfg.Table) or quoteIdent(defaults.table),
    idCol = quoteIdent(cfg.IdentifierColumn) or quoteIdent(defaults.idCol),
    firstCol = cfg.FirstNameColumn and quoteIdent(cfg.FirstNameColumn) or defaults.firstCol and quoteIdent(defaults.firstCol),
    lastCol = cfg.LastNameColumn and quoteIdent(cfg.LastNameColumn) or defaults.lastCol and quoteIdent(defaults.lastCol),
    jsonCol = cfg.CharInfoJsonColumn and quoteIdent(cfg.CharInfoJsonColumn) or (defaults.jsonCol and quoteIdent(defaults.jsonCol)),
    jsonFirstKey = sanitizeString(cfg.CharInfoFirstNameKey) ~= '' and sanitizeString(cfg.CharInfoFirstNameKey) or defaults.jsonFirstKey,
    jsonLastKey = sanitizeString(cfg.CharInfoLastNameKey) ~= '' and sanitizeString(cfg.CharInfoLastNameKey) or defaults.jsonLastKey,
    idLikePattern = cfg.IdentifierLikePattern ~= nil and cfg.IdentifierLikePattern or defaults.idLikePattern,
    stripPrefix = cfg.StripIdentifierPrefixForQuery == true,
    idPrefix = type(cfg.IdentifierPrefix) == 'string' and cfg.IdentifierPrefix
      or (defaults.idPrefix or ''),
  }

  if RESOLVED_CFG.jsonCol and (not RESOLVED_CFG.firstCol or not RESOLVED_CFG.lastCol) then
    RESOLVED_CFG.firstCol = nil
    RESOLVED_CFG.lastCol = nil
  end

  if not RESOLVED_CFG.jsonCol and (not RESOLVED_CFG.firstCol or not RESOLVED_CFG.lastCol) then
    RESOLVED_CFG.enabled = false
  end

  return RESOLVED_CFG
end

local function toDbIdentifier(storedId)
  local cfg = resolveProfileConfig()
  local id = sanitizeString(storedId)
  if id == '' then return id end

  if cfg.stripPrefix and cfg.idPrefix ~= '' and id:sub(1, #cfg.idPrefix) == cfg.idPrefix then
    return id:sub(#cfg.idPrefix + 1)
  end

  return id
end

local function fromDbIdentifier(dbId, originalByDb)
  if type(originalByDb) == 'table' and originalByDb[dbId] then
    return originalByDb[dbId]
  end
  return dbId
end

local function buildSelectList(cfg)
  local idExpr = cfg.idCol

  if cfg.jsonCol then
    local firstExpr = ("JSON_UNQUOTE(JSON_EXTRACT(%s, '$.%s'))"):format(cfg.jsonCol, cfg.jsonFirstKey)
    local lastExpr = ("JSON_UNQUOTE(JSON_EXTRACT(%s, '$.%s'))"):format(cfg.jsonCol, cfg.jsonLastKey)
    return ('%s AS identifier, %s AS firstname, %s AS lastname'):format(idExpr, firstExpr, lastExpr)
  end

  return ('%s AS identifier, %s AS firstname, %s AS lastname'):format(idExpr, cfg.firstCol, cfg.lastCol)
end

local function rowToFullName(row)
  if type(row) ~= 'table' then return '' end
  local first = sanitizeString(tostring(row.firstname or ''))
  local last = sanitizeString(tostring(row.lastname or ''))
  local fullName = sanitizeString(('%s %s'):format(first, last))
  if fullName == '' then
    fullName = sanitizeString(tostring(row.identifier or ''))
  end
  return fullName
end

function CommerceCharacterProfiles.IsEnabled()
  local cfg = resolveProfileConfig()
  return cfg.enabled and cfg.table and cfg.idCol
end

function CommerceCharacterProfiles.MapRowNames(rows, originalByDb)
  local resolved = {}
  for _, row in ipairs(rows or {}) do
    local dbId = sanitizeString(tostring(row.identifier or ''))
    if dbId ~= '' then
      local storedId = fromDbIdentifier(dbId, originalByDb)
      local fullName = rowToFullName(row)
      if fullName ~= '' then
        resolved[storedId] = fullName
      end
    end
  end
  return resolved
end

function CommerceCharacterProfiles.BuildDbLookupMap(identifiers)
  local originalByDb = {}
  local dbIds = {}
  local seen = {}

  for _, storedId in ipairs(identifiers or {}) do
    local normalized = sanitizeString(storedId)
    if normalized ~= '' then
      local dbId = toDbIdentifier(normalized)
      if dbId ~= '' and not seen[dbId] then
        seen[dbId] = true
        dbIds[#dbIds + 1] = dbId
        originalByDb[dbId] = normalized
      end
    end
  end

  return dbIds, originalByDb
end

function CommerceCharacterProfiles.QueryByIdentifiers(identifiers)
  if not CommerceCharacterProfiles.IsEnabled() then
    return {}
  end

  local cfg = resolveProfileConfig()
  local dbIds, originalByDb = CommerceCharacterProfiles.BuildDbLookupMap(identifiers)
  if #dbIds == 0 then
    return {}
  end

  local placeholders = {}
  for i = 1, #dbIds do
    placeholders[i] = '?'
  end

  local sql = ('SELECT %s FROM %s WHERE %s IN (%s)'):format(
    buildSelectList(cfg),
    cfg.table,
    cfg.idCol,
    table.concat(placeholders, ',')
  )

  local rows = MySQL.query.await(sql, dbIds) or {}
  return CommerceCharacterProfiles.MapRowNames(rows, originalByDb)
end

function CommerceCharacterProfiles.QuerySingle(identifier)
  local map = CommerceCharacterProfiles.QueryByIdentifiers({ identifier })
  return map[sanitizeString(identifier)]
end

function CommerceCharacterProfiles.Search(query)
  if not CommerceCharacterProfiles.IsEnabled() then
    return {}
  end

  local cfg = resolveProfileConfig()
  local needle = sanitizeString(query)
  local likeQuery = ('%%%s%%'):format(needle)
  local rows = {}
  local selectList = buildSelectList(cfg)

  if needle == '' then
    if cfg.idLikePattern then
      rows = MySQL.query.await(
        ('SELECT %s FROM %s WHERE %s LIKE ? ORDER BY firstname ASC, lastname ASC LIMIT 200'):format(
          selectList,
          cfg.table,
          cfg.idCol
        ),
        { cfg.idLikePattern }
      ) or {}
    else
      rows = MySQL.query.await(
        ('SELECT %s FROM %s ORDER BY firstname ASC, lastname ASC LIMIT 200'):format(selectList, cfg.table)
      ) or {}
    end
  else
    if cfg.jsonCol then
      local firstExpr = ("JSON_UNQUOTE(JSON_EXTRACT(%s, '$.%s'))"):format(cfg.jsonCol, cfg.jsonFirstKey)
      local lastExpr = ("JSON_UNQUOTE(JSON_EXTRACT(%s, '$.%s'))"):format(cfg.jsonCol, cfg.jsonLastKey)
      local matchClause = ('(%s LIKE ? OR %s LIKE ? OR %s LIKE ? OR CONCAT(COALESCE(%s, ''''), '' '', COALESCE(%s, '''')) LIKE ?)'):format(
        cfg.idCol,
        firstExpr,
        lastExpr,
        firstExpr,
        lastExpr
      )
      local params = { likeQuery, likeQuery, likeQuery, likeQuery }

      if cfg.idLikePattern then
        rows = MySQL.query.await(
          ('SELECT %s FROM %s WHERE %s LIKE ? AND %s ORDER BY firstname ASC, lastname ASC LIMIT 200'):format(
            selectList,
            cfg.table,
            cfg.idCol,
            matchClause
          ),
          { cfg.idLikePattern, likeQuery, likeQuery, likeQuery, likeQuery }
        ) or {}
      else
        rows = MySQL.query.await(
          ('SELECT %s FROM %s WHERE %s ORDER BY firstname ASC, lastname ASC LIMIT 200'):format(
            selectList,
            cfg.table,
            matchClause
          ),
          params
        ) or {}
      end
    elseif cfg.idLikePattern then
      rows = MySQL.query.await(
        ('SELECT %s FROM %s WHERE %s LIKE ? AND (%s LIKE ? OR %s LIKE ? OR %s LIKE ? OR CONCAT(COALESCE(%s, ''''), '' '', COALESCE(%s, '''')) LIKE ?) ORDER BY firstname ASC, lastname ASC LIMIT 200'):format(
          selectList,
          cfg.table,
          cfg.idCol,
          cfg.idCol,
          cfg.firstCol,
          cfg.lastCol,
          cfg.firstCol,
          cfg.lastCol
        ),
        { cfg.idLikePattern, likeQuery, likeQuery, likeQuery, likeQuery }
      ) or {}
    else
      rows = MySQL.query.await(
        ('SELECT %s FROM %s WHERE %s LIKE ? OR %s LIKE ? OR %s LIKE ? OR CONCAT(COALESCE(%s, ''''), '' '', COALESCE(%s, '''')) LIKE ? ORDER BY firstname ASC, lastname ASC LIMIT 200'):format(
          selectList,
          cfg.table,
          cfg.idCol,
          cfg.firstCol,
          cfg.lastCol,
          cfg.firstCol,
          cfg.lastCol
        ),
        { likeQuery, likeQuery, likeQuery, likeQuery }
      ) or {}
    end
  end

  local results = {}
  for _, row in ipairs(rows) do
    local identifier = sanitizeString(tostring(row.identifier or ''))
    if identifier ~= '' then
      local fullName = rowToFullName(row)
      results[#results + 1] = {
        identifier = identifier,
        name = fullName,
      }
    end
  end

  return results
end
