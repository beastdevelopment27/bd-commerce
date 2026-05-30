Config = Config or {}

-- Marketplace tax → job society. BankingPreset: 'auto', 'qb-banking', or 'custom' + CustomBanking.
Config.CommerceTaxSociety = {
  Enabled = true,
  JobName = 'police',
  DepositReason = 'ABay marketplace tax',
  BankingPreset = 'auto',
  AutoDetectOrder = {
    'qb-banking',
    'Renewed-Banking',
    'okokBanking',
    'esx_society',
    'tgg-banking',
    'crm-banking',
    'fd_banking',
    'p_banking',
  },
  CustomBanking = nil,
}

-- Custom banking (set BankingPreset = 'custom' and uncomment CustomBanking above):
--   Resource        = resource folder name (same as ensure in server.cfg)
--   DepositExport   = server export that adds money to job society
--   IncludeReason   = true if export is (job, amount, reason); false for (job, amount) only
--   ArgOrder        = 'job_amount' (default) or 'amount_job' if your export swaps args
--
-- Example (qb-banking style):
--   BankingPreset = 'custom',
--   CustomBanking = {
--     Resource = 'qb-banking',
--     DepositExport = 'AddMoney',
--     IncludeReason = true,
--     ArgOrder = 'job_amount',
--   },
--
-- Example (two args, job first):
--   CustomBanking = {
--     Resource = 'my-bank',
--     DepositExport = 'AddSocietyMoney',
--     IncludeReason = false,
--     ArgOrder = 'job_amount',
--   },
