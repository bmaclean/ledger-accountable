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
  end
end
