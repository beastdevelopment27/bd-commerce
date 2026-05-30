Config = Config or {}

--- Marketplace panel header (top bar title + subtitle in NUI).
Config.PanelTitle = 'ABay'
Config.PanelSubtitle = 'System to Sell and Buy items'

-- Inventory image base path: {resource}/{folder inside that resource}.
-- The first segment MUST match the resource folder name exactly (as in server.cfg / `ensure`).
-- No trailing slash. Examples:
--   ox_inventory:  'ox_inventory/web/images'
--   qb-inventory:  'qb-inventory/html/images'
--   ps-inventory:  'ps-inventory/html/images'
Config.InventoryImagePath = 'qb-inventory/html/images'

-- Percentage fee deducted from each sale payout before seller credit.
-- The fee amount is deposited to the job society configured in config/society.lua.
Config.CommerceTaxPercent = 5.0

--- ESX/QBCore groups that can access Admin Sale and Reports (case-insensitive).
Config.AdminGroups = {
  'admin',
  'superadmin',
}

--- Inventory item names that cannot be listed for sale (case-insensitive).
Config.RestrictedItems = {
  'money',
  'black_money',
  'id_card',
  'driver_license',
}

--- Listing categories (id is stored in DB; label is shown in NUI).
Config.CommerceCategories = {
  { id = 'misc', label = 'Misc' },
  { id = 'weapons', label = 'Weapons' },
  { id = 'ammo', label = 'Ammo' },
  { id = 'food', label = 'Food & Drinks' },
  { id = 'medical', label = 'Medical' },
  { id = 'vehicles', label = 'Vehicles' },
  { id = 'parts', label = 'Vehicle Parts' },
  { id = 'tools', label = 'Tools' },
  { id = 'materials', label = 'Materials' },
}
