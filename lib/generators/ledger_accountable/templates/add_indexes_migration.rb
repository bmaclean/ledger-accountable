class AddIndexesToLedgerEntries < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    add_index_unless_exists :ledger_entries, [:owner_type, :owner_id, :transaction_type],
                            name: 'index_ledger_entries_on_owner_and_transaction_type'
    add_index_unless_exists :ledger_entries, [:owner_type, :owner_id, :entry_type],
                            name: 'index_ledger_entries_on_owner_and_entry_type'
    add_index_unless_exists :ledger_entries, [:owner_type, :owner_id, :created_at, :id],
                            name: 'index_ledger_entries_on_owner_and_created_at_and_id'
    add_index_unless_exists :ledger_entries, [:ledger_item_type, :ledger_item_id, :created_at, :id],
                            name: 'index_ledger_entries_on_item_and_created_at_and_id'
  end

  def down
    remove_index_if_exists :ledger_entries, name: 'index_ledger_entries_on_owner_and_transaction_type'
    remove_index_if_exists :ledger_entries, name: 'index_ledger_entries_on_owner_and_entry_type'
    remove_index_if_exists :ledger_entries, name: 'index_ledger_entries_on_owner_and_created_at_and_id'
    remove_index_if_exists :ledger_entries, name: 'index_ledger_entries_on_item_and_created_at_and_id'
  end

  private

  def add_index_unless_exists(table_name, columns, name:)
    return if index_exists?(table_name, columns, name: name)

    options = { name: name }
    options[:algorithm] = :concurrently if postgresql?
    add_index(table_name, columns, **options)
  end

  def remove_index_if_exists(table_name, name:)
    return unless index_exists?(table_name, name: name)

    remove_index(table_name, name: name)
  end

  def postgresql?
    connection.adapter_name.downcase.include?('postgres')
  end
end
