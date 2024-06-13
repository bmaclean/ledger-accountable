class CreateLedgerEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :ledger_entries do |t|
      t.references :owner, polymorphic: true, null: false
      t.references :ledger_item, polymorphic: true, null: false
      t.integer :entry_type, null: false
      t.decimal :amount, precision: 10, scale: 2, default: 0.0, null: false
      t.text :metadata

      t.timestamps
    end
  end
end