module LedgerAccountable
  autoload :LedgerItem, 'ledger_accountable/ledger_item'
  autoload :LedgerOwner, 'ledger_accountable/ledger_owner'

  # Default way to configure LedgerAccountable. Run rails generate ledger_accountable to create
  # or update an initializer with default configuration values.
  def self.setup
    yield self
  end
end
