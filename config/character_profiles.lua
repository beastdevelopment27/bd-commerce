Config = Config or {}

--- Offline player name lookup (admin sales, reports, player search, etc.).
--- Match your framework database — ESX uses `users`, QBCore uses `players` + JSON `charinfo`.
Config.CharacterProfiles = {
  Enabled = true,

  --- QBCore / QBox (default for most QB servers)
  Table = 'players',
  IdentifierColumn = 'license',
  CharInfoJsonColumn = 'charinfo',
  CharInfoFirstNameKey = 'firstname',
  CharInfoLastNameKey = 'lastname',

  --- ESX Legacy — uncomment and comment the QBCore block above instead:
  -- Table = 'users',
  -- IdentifierColumn = 'identifier',
  -- FirstNameColumn = 'firstname',
  -- LastNameColumn = 'lastname',
  -- CharInfoJsonColumn = nil,
  -- IdentifierLikePattern = 'char%:%',

  --- Optional WHERE filter for profile search (ESX multichar: 'char%:%'). nil = no extra filter.
  IdentifierLikePattern = nil,

  --- If commerce stores `license:hash` but your DB column stores only the hash part, set to true.
  StripIdentifierPrefixForQuery = false,

  --- Prefix stripped when StripIdentifierPrefixForQuery is true (default license:).
  IdentifierPrefix = 'license:',
}
