Config = Config or {}

-- Percentage fee deducted from each sale payout before seller credit.
Config.CommerceTaxPercent = 5.0

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
