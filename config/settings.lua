Config = Config or {}

-- NUI path for inventory item images (used as nui://{path}/{filename} in the marketplace UI).
-- First segment is the resource name (e.g. ox_inventory). Change if you use qb-inventory, qs-inventory, etc.
Config.InventoryImagePath = 'ox_inventory/web/images'

-- Percentage fee deducted from each sale payout before seller credit.
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
