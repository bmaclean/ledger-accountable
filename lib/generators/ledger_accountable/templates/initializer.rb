LedgerAccountable.setup do |config|
  # The time at which ledger entries began.
  # Defaults to Unix Epoch (1970-01-01 00:00:00 +0000)
  # config.epoch = Time.at(0),
  # 
  # Toggle for whether ledger entry creation should be required for updates to
  # LedgerAccountable objects.
  # If set to `true`, failed ledger entries will roll back all changes.
  # Defaults to all non-production environments.
  # config.require_successful_entries = !Rails.env.production?
end
