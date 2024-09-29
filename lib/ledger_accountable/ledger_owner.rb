
#
# LedgerAccountable::LedgerOwner is intended to be included in models
#
module LedgerAccountable::LedgerOwner
raise 'do not commit me'
  extend ActiveSupport::Concern

  included do
    has_many :ledger_entries, as: :owner
  end

  def balance
    ledger_entries.sum(:amount_cents)
  end

  # The absolute value of the sum of the LedgerOwner's credit entries.
  # This can be used to determine the total amount credited to the ledger -
  # for example, its total revenue.
  def credit_total
    ledger_entries.credits.sum(:amount_cents).abs
  end

  # The absolute value of the sum of the LedgerOwner's debit entries.
  # This can be used to determine the total amount owed to the ledger -
  # for example, the aggregate value of the items sold.
  def debit_total
    ledger_entries.credits.sum(:amount_cents).abs
  end
end
