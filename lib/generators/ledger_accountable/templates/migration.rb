class CreateLedgerEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :ledger_entries do |t|
      t.references :owner, polymorphic: true, null: false
      t.references :ledger_item, polymorphic: true, type: :string, null: false
      t.integer :transaction_type, null: false
      t.integer :entry_type, null: false
      t.integer :amount_cents, default: 0, null: false
      t.text :metadata

      t.timestamps
    end

    add_index :ledger_entries, [:owner_type, :owner_id, :transaction_type],
              name: 'index_ledger_entries_on_owner_and_transaction_type'
    add_index :ledger_entries, [:owner_type, :owner_id, :entry_type],
              name: 'index_ledger_entries_on_owner_and_entry_type'
    add_index :ledger_entries, [:owner_type, :owner_id, :created_at, :id],
              name: 'index_ledger_entries_on_owner_and_created_at_and_id'
    add_index :ledger_entries, [:ledger_item_type, :ledger_item_id, :created_at, :id],
              name: 'index_ledger_entries_on_item_and_created_at_and_id'
  end
end
