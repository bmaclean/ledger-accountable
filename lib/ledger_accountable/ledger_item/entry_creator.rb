# frozen_string_literal: true

module LedgerAccountable
  module LedgerItem
    # Creates a single LedgerEntry.
    class EntryCreator
      def self.create(item:, owner:, amount:, type:, entry_type:, metadata: {})
        LedgerEntry.create!(
          # create! will raise if the ledger entry fails to be created,
          # which will rollback the attempt to save the LedgerAccountable object
          owner: owner,
          ledger_item: item,
          transaction_type: type,
          entry_type: entry_type,
          amount_cents: amount,
          metadata: metadata
        )
      end
    end
  end
end
