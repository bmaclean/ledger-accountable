# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/generators/ledger_accountable/ledger_accountable_generator'

class GeneratorTemplatesTest < ActiveSupport::TestCase
  def test_create_table_migration_includes_default_indexes
    content = File.read(File.expand_path('../lib/generators/ledger_accountable/templates/migration.rb', __dir__))

    assert_includes content, "index_ledger_entries_on_owner_and_transaction_type"
    assert_includes content, "index_ledger_entries_on_owner_and_entry_type"
    assert_includes content, "index_ledger_entries_on_owner_and_created_at_and_id"
    assert_includes content, "index_ledger_entries_on_item_and_created_at_and_id"
  end

  def test_add_indexes_migration_uses_postgresql_concurrent_path
    content = File.read(File.expand_path('../lib/generators/ledger_accountable/templates/add_indexes_migration.rb', __dir__))

    assert_includes content, 'disable_ddl_transaction!'
    assert_includes content, 'options[:algorithm] = :concurrently if postgresql?'
    assert_includes content, "connection.adapter_name.downcase.include?('postgres')"
  end

  def test_add_indexes_migration_is_idempotent
    content = File.read(File.expand_path('../lib/generators/ledger_accountable/templates/add_indexes_migration.rb', __dir__))

    assert_includes content, 'return if index_exists?(table_name, columns, name: name)'
    assert_includes content, 'return unless index_exists?(table_name, name: name)'
  end

  def test_generator_exposes_add_indexes_option
    add_indexes_option = LedgerAccountableGenerator.class_options['add_indexes']

    refute_nil add_indexes_option
    assert_equal false, add_indexes_option.default
  end
end
